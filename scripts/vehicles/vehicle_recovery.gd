class_name VehicleRecovery
extends Node
## Manual (R / gamepad D-pad Up) and automatic vehicle recovery (GDD 5.5),
## played as a holographic sequence (docs/Recovery System.md):
##
##   DISINTEGRATING  0.3 s  the car freezes and dissolves where it is
##   TELEPORTING     0.4 s  gone; it moves to the recovery spot
##   RECONSTRUCTING  0.5 s  it forms again there, standing still
##   PROTECTED       1.0 s  driving again (at 25% of top speed), passing
##                          through other cars
##
## Controls are locked for the first three stages (1.2 s), and while the car
## is hidden nothing can hit, target or draft it, and it can't collect
## anything (it is on no collision layer). Stages run on a timer in
## _physics_process, so they pause with the game and can be cancel()ed.
##
## Tracks the last point on the circuit the car legitimately drove through.
## Resets always return there (minus a small backoff), so resetting can never
## move a car forward, and therefore can't be used as a shortcut.
## A forward move along the track is only accepted if the car actually
## travelled that far, so teleports and shortcuts never advance the safe point.
## total_progress feeds the free-drive lap timer.
##
## Falling off (out of bounds, water, off track) or a manual reset empties
## the car's weapon slots; automatic resets on the road (overturned, stuck)
## keep them.

## A recovery started (emitted at once, before the sequence plays).
signal recovered(reason: String)
## The sequence moved to a new stage.
signal state_changed(state: State)
## The car is back on the road and driving (start of PROTECTED).
signal recovery_finished

enum State { NORMAL, DISINTEGRATING, TELEPORTING, RECONSTRUCTING, PROTECTED }

## Recovery reasons that cost the car its weapons: falling off the track,
## and a manual reset (so it can't be used to dodge the penalty).
const ITEM_LOSS_REASONS: Array[String] = ["out of bounds", "water", "lava", "off track", "manual"]

@export var auto_recovery_enabled: bool = true
@export_group("Sequence")
@export var disintegration_time: float = 0.3
@export var teleport_time: float = 0.4
@export var reconstruction_time: float = 0.5
## Time after reconstruction that the car passes through other cars.
@export var protection_time: float = 1.0
## Speed the car comes back with, as a share of its top speed.
@export var respawn_speed_fraction: float = 0.25
@export_group("Overturned")
## Car up-vector · world-up below this counts as overturned.
@export var overturn_up_dot: float = 0.35
@export var overturn_time: float = 2.5
@export_group("Stuck")
## Forward/backward speed below which a car that is trying to move counts as
## stuck. Sideways creep (e.g. scraping along a wall) does not count as moving.
@export var stuck_speed: float = 1.0
@export var stuck_time: float = 4.0
## A car trying to drive that gains less than no_progress_distance along the
## track in no_progress_time is recovered too (catches cars rocking back and
## forth against a wall, which never count as "stuck").
@export var no_progress_time: float = 8.0
@export var no_progress_distance: float = 15.0
@export_group("Out of bounds")
@export var kill_height: float = -15.0
## On a sloped track (TrackCircuit.sloped) "out of bounds" is this far below
## the nearest road instead of below kill_height.
@export var fall_depth: float = 15.0
## Distance beyond the road edge that counts as out of the playable area.
## (The barrier sits just past the road edge, so this means "outside the circuit".)
@export var off_track_margin: float = 3.0
@export var off_track_time: float = 1.0
@export_group("Placement")
## Metres behind the last safe point to respawn.
@export var reset_backoff: float = 6.0
@export var spawn_height: float = 0.9
@export var reset_cooldown: float = 1.0
## Collision layer(s) used by vehicles, checked so we never respawn inside a racer.
@export_flags_3d_physics var vehicle_layer: int = 2
## Track distance allowed beyond the distance the car actually travelled
## (covers corner cutting and measuring error). Gaining more than this
## without travelling it (teleports, shortcuts) is never accepted.
@export var progress_slack: float = 15.0
## Largest backward move accepted per update.
@export var max_backward_step: float = 25.0

var track: TrackCircuit
var last_safe_offset: float = 0.0
## On a branch route (TrackShortcut.is_branch): the branch and the distance
## along it of the last safe point, so a recovery respawns on that route.
var safe_branch: TrackShortcut
var safe_branch_distance: float = 0.0
## Signed distance driven along the circuit since spawn (forward = positive).
var total_progress: float = 0.0
var last_reason: String = ""
var state: State = State.NORMAL
## Seconds spent in the current stage.
var state_time: float = 0.0
## Where the car comes back (chosen when the recovery starts).
var target_transform: Transform3D
var effect: RecoveryEffect

var _saved_layer: int = 2
var _saved_mask: int = 3

var _overturn_timer: float = 0.0
var _stuck_timer: float = 0.0
var _off_track_timer: float = 0.0
var _no_progress_timer: float = 0.0
var _progress_ref: float = -1.0
var _cooldown: float = 0.0
## Distance travelled since the safe point last moved.
var _travelled: float = 0.0

@onready var vehicle: VehicleController = get_parent() as VehicleController


func set_track(new_track: TrackCircuit, start_offset: float) -> void:
	track = new_track
	last_safe_offset = start_offset
	total_progress = 0.0
	_travelled = 0.0
	_clear_timers()


func _unhandled_input(event: InputEvent) -> void:
	if vehicle != null and vehicle.player_controlled and event.is_action_pressed(vehicle.action(&"reset_vehicle")):
		request_recovery("manual")
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if track == null or vehicle == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if state != State.NORMAL:
		_advance(delta)
	if is_hidden():
		return
	var v := vehicle.linear_velocity
	_travelled += Vector2(v.x, v.z).length() * delta
	_update_safe_point()
	if auto_recovery_enabled and _cooldown <= 0.0 and state == State.NORMAL and not vehicle.is_flying():
		_check_automatic(delta)


## True from the moment the car starts dissolving until it has formed again.
func is_hidden() -> bool:
	return state == State.DISINTEGRATING or state == State.TELEPORTING or state == State.RECONSTRUCTING


## True for the whole sequence, protection included.
func is_busy() -> bool:
	return state != State.NORMAL


## Starts a recovery. Returns false if refused: during the cooldown, or while
## one is already playing (one recovery per incident).
func request_recovery(reason: String) -> bool:
	if track == null or vehicle == null or _cooldown > 0.0 or state != State.NORMAL or vehicle.is_flying():
		return false
	var backoff := reset_backoff
	if safe_branch != null and is_instance_valid(safe_branch):
		target_transform = _find_clear_branch_transform(safe_branch, safe_branch_distance - backoff)
		safe_branch_distance = maxf(0.0, safe_branch_distance - backoff)
	else:
		target_transform = _find_clear_transform(last_safe_offset - backoff)
	last_safe_offset = track.wrap_offset(last_safe_offset - backoff)
	total_progress -= backoff
	_travelled = 0.0
	vehicle.drift.cancel("recovery")
	vehicle.clear_boost()
	if loses_items(reason) and vehicle.inventory != null:
		vehicle.inventory.clear()
	vehicle.slipstream_charge = 0.0
	vehicle.in_slipstream = false
	vehicle.recovery_lock = true
	vehicle.hold_here()
	# On no layer while hidden: no car hits it, no pickup or pad sees it.
	_saved_layer = vehicle.collision_layer
	_saved_mask = vehicle.collision_mask
	vehicle.collision_layer = 0
	vehicle.collision_mask = 1
	_cooldown = reset_cooldown
	_clear_timers()
	last_reason = reason
	if effect == null:
		effect = RecoveryEffect.new()
		effect.name = "RecoveryEffect"
		vehicle.add_child(effect)
		effect.setup(self)
	_enter(State.DISINTEGRATING)
	recovered.emit(reason)
	return true


## Does a recovery for `reason` empty the car's weapon slots?
static func loses_items(reason: String) -> bool:
	return ITEM_LOSS_REASONS.has(reason)


## Ends a recovery at once, putting the car back to normal where it is
## (elimination, the car leaving the scene).
func cancel() -> void:
	if state == State.NORMAL or vehicle == null:
		return
	vehicle.release(0.0)
	vehicle.recovery_lock = false
	if is_hidden():
		vehicle.collision_layer = _saved_layer
		vehicle.collision_mask = _saved_mask
	vehicle.set_ghost(false)
	_enter(State.NORMAL)


func _exit_tree() -> void:
	cancel()


func _stage_length(s: State) -> float:
	match s:
		State.DISINTEGRATING:
			return disintegration_time
		State.TELEPORTING:
			return teleport_time
		State.RECONSTRUCTING:
			return reconstruction_time
		State.PROTECTED:
			return protection_time
	return INF


func _advance(delta: float) -> void:
	state_time += delta
	while state != State.NORMAL and state_time >= _stage_length(state):
		var spare := state_time - _stage_length(state)
		match state:
			State.DISINTEGRATING:
				vehicle.hold_at(target_transform)
				_enter(State.TELEPORTING)
			State.TELEPORTING:
				_enter(State.RECONSTRUCTING)
			State.RECONSTRUCTING:
				vehicle.release(vehicle.stats.top_speed * respawn_speed_fraction)
				vehicle.recovery_lock = false
				vehicle.collision_layer = _saved_layer
				vehicle.collision_mask = _saved_mask
				vehicle.set_ghost(true)
				_enter(State.PROTECTED)
				recovery_finished.emit()
			State.PROTECTED:
				vehicle.set_ghost(false)
				_clear_timers()
				_enter(State.NORMAL)
		state_time = spare


func _enter(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	state_changed.emit(new_state)


func _update_safe_point() -> void:
	var up_dot := vehicle.global_transform.basis.y.dot(Vector3.UP)
	if vehicle.grounded_wheels < 3 or up_dot < 0.8:
		return
	var pos := vehicle.global_position
	if not track.is_on_road(pos):
		return
	var offset := track.get_offset_at(pos)
	var step := track.wrapped_delta(last_safe_offset, offset)
	# On a branch, lap progress moves span / length metres per metre driven.
	var branch := track.get_shortcut_at(pos)
	if branch != null and not branch.is_branch:
		branch = null
	var progress_scale := maxf(1.0, branch.span / maxf(branch.length, 1.0)) if branch != null else 1.0
	# Missed updates (airborne, scraping the edge) are fine: the car really
	# covered that distance. A teleport or shortcut didn't.
	if step > _travelled * progress_scale + progress_slack or step < -max_backward_step:
		return
	if branch != null:
		safe_branch = branch
		safe_branch_distance = branch.local_offset(track.to_local(pos))
	else:
		safe_branch = null
	last_safe_offset = offset
	total_progress += step
	_travelled = 0.0


func _check_automatic(delta: float) -> void:
	var pos := vehicle.global_position
	var floor_y := kill_height
	if track.sloped:
		floor_y = track.road_floor_y(pos) - fall_depth
	if pos.y < floor_y:
		request_recovery("out of bounds")
		return

	if track.get_lateral_distance(pos) > track.road_width * 0.5 + off_track_margin:
		_off_track_timer += delta
		if _off_track_timer > off_track_time:
			request_recovery("off track")
			return
	else:
		_off_track_timer = 0.0

	var up_dot := vehicle.global_transform.basis.y.dot(Vector3.UP)
	if up_dot < overturn_up_dot:
		_overturn_timer += delta
		if _overturn_timer > overturn_time:
			request_recovery("overturned")
			return
	else:
		_overturn_timer = 0.0

	var trying_to_move := vehicle.throttle_input > 0.1 or vehicle.brake_input > 0.1
	if trying_to_move and vehicle.input_enabled:
		var here := track.get_offset_at(pos)
		if _progress_ref < 0.0 or absf(track.wrapped_delta(_progress_ref, here)) > no_progress_distance:
			_progress_ref = here
			_no_progress_timer = 0.0
		else:
			_no_progress_timer += delta
			if _no_progress_timer > no_progress_time:
				request_recovery("no progress")
				return
	if trying_to_move and absf(vehicle.forward_speed) < stuck_speed:
		_stuck_timer += delta
		if _stuck_timer > stuck_time:
			request_recovery("stuck")
			return
	else:
		_stuck_timer = 0.0


func _find_clear_transform(offset: float) -> Transform3D:
	# Try the centre line first, then either side, then further back.
	var candidates: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.0, -4.0), Vector2(0.0, 4.0),
		Vector2(-8.0, 0.0), Vector2(-8.0, -4.0), Vector2(-8.0, 4.0),
		Vector2(-16.0, 0.0),
	]
	for candidate in candidates:
		var lat := track.dodge_columns(offset + candidate.x, candidate.y, 2.5)
		var xf := track.get_safe_transform(offset + candidate.x, lat, spawn_height)
		if _is_clear(xf):
			return xf
	return track.get_safe_transform(offset, track.column_route_lateral(offset), spawn_height + 2.0)


## Respawn on a branch route at a distance along it (clear spot nearby).
func _find_clear_branch_transform(sc: TrackShortcut, distance: float) -> Transform3D:
	var candidates: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.0, -3.0), Vector2(0.0, 3.0),
		Vector2(-8.0, 0.0), Vector2(-8.0, -3.0), Vector2(-8.0, 3.0),
		Vector2(-16.0, 0.0),
	]
	for candidate in candidates:
		var xf := track.global_transform * sc.safe_transform(maxf(0.0, distance + candidate.x), candidate.y, spawn_height)
		if _is_clear(xf):
			return xf
	return track.global_transform * sc.safe_transform(maxf(0.0, distance), 0.0, spawn_height + 2.0)


func _is_clear(xf: Transform3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.4, 5.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = xf
	query.collision_mask = vehicle_layer
	query.exclude = [vehicle.get_rid()]
	var hits := vehicle.get_world_3d().direct_space_state.intersect_shape(query, 1)
	if not hits.is_empty():
		return false
	# Cars that are mid-recovery are on no layer: keep clear of where they'll be.
	for node in vehicle.get_tree().get_nodes_in_group(VehicleController.GROUP):
		var other := node as VehicleController
		if other != null and other != vehicle and other.recovery != null and other.recovery.is_hidden() \
				and other.recovery.target_transform.origin.distance_to(xf.origin) < 5.0:
			return false
	return true


func _clear_timers() -> void:
	_overturn_timer = 0.0
	_stuck_timer = 0.0
	_off_track_timer = 0.0
	_no_progress_timer = 0.0
	_progress_ref = -1.0
