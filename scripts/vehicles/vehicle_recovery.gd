class_name VehicleRecovery
extends Node
## Manual (R / gamepad Y) and automatic vehicle recovery (GDD 5.5).
##
## Tracks the last point on the circuit the car legitimately drove through.
## Resets always return there (minus a small backoff), so resetting can never
## move a car forward, and therefore can't be used as a shortcut.
## A forward move along the track is only accepted if the car actually
## travelled that far, so teleports and shortcuts never advance the safe point.
## total_progress feeds the free-drive lap timer.

signal recovered(reason: String)

@export var auto_recovery_enabled: bool = true
@export_group("Overturned")
## Car up-vector · world-up below this counts as overturned.
@export var overturn_up_dot: float = 0.35
@export var overturn_time: float = 1.5
@export_group("Stuck")
## Forward/backward speed below which a car that is trying to move counts as
## stuck. Sideways creep (e.g. scraping along a wall) does not count as moving.
@export var stuck_speed: float = 1.0
@export var stuck_time: float = 3.0
## A car trying to drive that gains less than no_progress_distance along the
## track in no_progress_time is recovered too (catches cars rocking back and
## forth against a wall, which never count as "stuck").
@export var no_progress_time: float = 8.0
@export var no_progress_distance: float = 15.0
@export_group("Out of bounds")
@export var kill_height: float = -15.0
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
## Signed distance driven along the circuit since spawn (forward = positive).
var total_progress: float = 0.0
var last_reason: String = ""

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
	var v := vehicle.linear_velocity
	_travelled += Vector2(v.x, v.z).length() * delta
	_update_safe_point()
	if auto_recovery_enabled and _cooldown <= 0.0:
		_check_automatic(delta)


## Returns true if a recovery happened (it can be refused during the cooldown).
func request_recovery(reason: String) -> bool:
	if track == null or vehicle == null or _cooldown > 0.0:
		return false
	var backoff := reset_backoff
	var target := _find_clear_transform(last_safe_offset - backoff)
	last_safe_offset = track.wrap_offset(last_safe_offset - backoff)
	total_progress -= backoff
	_travelled = 0.0
	vehicle.drift.cancel("recovery")
	vehicle.clear_boost()
	vehicle.teleport(target)
	_cooldown = reset_cooldown
	_clear_timers()
	last_reason = reason
	recovered.emit(reason)
	return true


func _update_safe_point() -> void:
	var up_dot := vehicle.global_transform.basis.y.dot(Vector3.UP)
	if vehicle.grounded_wheels < 3 or up_dot < 0.8:
		return
	var pos := vehicle.global_position
	if not track.is_on_road(pos):
		return
	var offset := track.get_offset_at(pos)
	var step := track.wrapped_delta(last_safe_offset, offset)
	# Missed updates (airborne, scraping the edge) are fine: the car really
	# covered that distance. A teleport or shortcut didn't.
	if step > _travelled + progress_slack or step < -max_backward_step:
		return
	last_safe_offset = offset
	total_progress += step
	_travelled = 0.0


func _check_automatic(delta: float) -> void:
	var pos := vehicle.global_position
	if pos.y < kill_height:
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
		var xf := track.get_safe_transform(offset + candidate.x, candidate.y, spawn_height)
		if _is_clear(xf):
			return xf
	return track.get_safe_transform(offset, 0.0, spawn_height + 2.0)


func _is_clear(xf: Transform3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.4, 5.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = xf
	query.collision_mask = vehicle_layer
	query.exclude = [vehicle.get_rid()]
	var hits := vehicle.get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


func _clear_timers() -> void:
	_overturn_timer = 0.0
	_stuck_timer = 0.0
	_off_track_timer = 0.0
	_no_progress_timer = 0.0
	_progress_ref = -1.0
