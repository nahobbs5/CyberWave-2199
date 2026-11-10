class_name VehicleController
extends RigidBody3D
## Arcade vehicle physics shared by every car (GDD 3.1, 5, 14.3).
##
## Four RayCast3D wheels give spring/damper suspension. Driving, grip and
## steering shape the body's velocity directly, which keeps handling arcade-like
## and stops the car rolling over in corners. Tuning lives in VehicleStats.
##
## Wheel nodes: RayCast3D children named "Wheel*" (front wheels "WheelF*"),
## each with a "Pivot" Node3D child holding the wheel mesh.
##
## Wheel contact, per physics step (docs/Cyberwave_2199_Vehicle_Physics_
## Implementation_Guide.md):
##   ray hit       the wheel ray reaches the road (ray_hit_wheels)
##   loaded wheel  ...and its spring is compressed (grounded_wheels; tricks,
##                 drifts and recovery read this, so its meaning is fixed)
##   traction      0..1 share of grip/drive/steer: loaded wheels weighted by
##                 how loaded they are (a wheel just kissing the road barely
##                 steers), bridged over brief contact glitches
## Anti-roll bars push the front and rear axles' left/right springs toward
## each other, and a short landing stabiliser damps pitch/roll wobble.

## Drift boost fired (level 1-3).
signal boost_started(level: int)
## Non-drift boost fired (e.g. Nitro Overload).
signal external_boost_started(label: String)
signal boost_ended
## A slipstream boost fired (see Slipstream).
signal slipstream_boost
## Emitted on a sudden large loss of forward speed (barrier hit, etc.).
signal heavy_impact(speed_lost: float)
## Emitted after a teleport/recovery has been applied.
signal teleported

## How much bigger cars look on track than in the menus (visual only: the
## collider, wheel rays and handling keep their tuned size).
const TRACK_VISUAL_SCALE := 1.3
## Half the collider's height: the body is lifted so a bigger chassis still
## sits on the road.
const BODY_HALF_HEIGHT := 0.28

## Every car is in this group (recovery uses it to pass through other cars).
const GROUP := &"vehicles"

## Steering needed to pick a direction when starting a Shift drift.
const SHIFT_DRIFT_STEER_THRESHOLD := 0.3
## Airtime that counts as a real landing for the landing stabiliser.
const LANDING_MIN_AIR_TIME := 0.15

@export var stats: VehicleStats
## When true, inputs are read from the InputMap each physics frame.
## AI (Phase 2) sets this to false and writes the *_input fields directly.
@export var player_controlled: bool = true
## The human racer's car (gets audio cues and the camera). Stays true after the
## player finishes and the autopilot takes over.
@export var is_player: bool = true
## Split screen: this player's action prefix ("p2_"); "" reads every device.
@export var input_prefix: StringName = &""

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0
var drift_left_held: bool = false
var drift_right_held: bool = false
var input_enabled: bool = true
## Set by VehicleRecovery while a recovery sequence has the controls. Kept
## apart from input_enabled, which the race (countdown, elimination) owns.
var recovery_lock: bool = false

## Wheels whose spring is compressed (see the header).
var grounded_wheels: int = 0
## Wheel rays touching the road, loaded or not.
var ray_hit_wheels: int = 0
## Share of grip, drive and steering the tyres give this step (0..1).
var traction_fraction: float = 0.0
## This step's contact per wheel (index matches the Wheel* rays): spring
## length (-1 = no hit), compression (0..rest length) and spring force (N).
var wheel_spring_length: PackedFloat32Array = PackedFloat32Array()
var wheel_compression: PackedFloat32Array = PackedFloat32Array()
var wheel_load: PackedFloat32Array = PackedFloat32Array()
## Anti-roll force (N) on the front and rear axles this step.
var anti_roll_force: Vector2 = Vector2.ZERO
## Seconds with no loaded wheel (0 while on the ground), and since landing.
var air_time: float = 0.0
var since_landing: float = 0.0
## Shows the physics debug readout (F3, debug builds).
static var debug_physics: bool = false
var forward_speed: float = 0.0
var lateral_speed: float = 0.0
var ground_normal: Vector3 = Vector3.UP

var boost_level: int = 0
var boost_time_left: float = 0.0
## Slipstream meter 0..1 and whether we're in someone's tow (set by Slipstream).
var slipstream_charge: float = 0.0
var in_slipstream: bool = false
## What the current boost is called and its colour (for HUD and effects).
var boost_label: String = ""
var boost_color: Color = Color.WHITE

var _boost_extra_speed: float = 0.0
var _pending_kick: float = 0.0
var _pending_speed_scale: float = 1.0
var _has_pending_teleport: bool = false
var _pending_teleport: Transform3D
## Recovery hold: the car is pinned at _held_transform, motionless.
var _held: bool = false
var _held_transform: Transform3D
var _held_moved: bool = false
## Forward speed to give the car on the next step (after a recovery); < 0 none.
var _pending_launch: float = -1.0
## Cars this one passes through for now (recovery protection).
var _ghosted_with: Array[VehicleController] = []
var _ghost: bool = false
## Automated flight (Overdrive): the car is placed on _flight_transform each
## step and moves at _flight_velocity; driving physics is off.
var _flying: bool = false
var _flight_transform: Transform3D
var _flight_velocity: Vector3 = Vector3.ZERO
## Overdrive flight controller (made on first use).
var overdrive: OverdriveController
var _prev_forward_speed: float = 0.0
var _wheel_spin: float = 0.0
var _wheels: Array[RayCast3D] = []
## Wheel index pairs [left, right] for the front and rear axles; empty if
## the wheels aren't a 2 x 2 layout (anti-roll is then off).
var _axles: Array[Vector2i] = []
var _last_traction: float = 0.0
var _grace_left: int = 0
var _stabilize_left: float = 0.0
var _raw_traction: float = 0.0
## Visual size (see set_visual_scale); 1 = as built.
var visual_scale: float = 1.0
## Visual-only body yaw (rad) and hop height (m) from the drift effects;
## the drawn wheels follow them so they stay under the body.
var visual_yaw: float = 0.0
var visual_hop: float = 0.0
## Seconds left of the post-drift grip blend (see drift_recovery_time).
var _recover_left: float = 0.0

@onready var drift: DriftController = $DriftController
@onready var recovery: VehicleRecovery = $VehicleRecovery
## Optional combat nodes (absent cars just ignore weapons).
@onready var status: StatusEffects = get_node_or_null("StatusEffects")
@onready var inventory: ItemInventory = get_node_or_null("ItemInventory")
@onready var targeting: TargetingSystem = get_node_or_null("TargetingSystem")
## Ramp tricks (created in _ready).
var trick: VehicleTrick


func is_tricking() -> bool:
	return trick != null and trick.is_tricking()


func _ready() -> void:
	if stats == null:
		stats = VehicleStats.new()
	for child in get_children():
		if child is RayCast3D and child.name.begins_with("Wheel"):
			var ray := child as RayCast3D
			ray.target_position = Vector3(0.0, -(stats.suspension_rest_length + stats.wheel_radius), 0.0)
			ray.add_exception(self)
			_wheels.append(ray)
	if _wheels.is_empty():
		push_error("VehicleController: no Wheel* RayCast3D children found.")
	wheel_spring_length.resize(_wheels.size())
	wheel_compression.resize(_wheels.size())
	wheel_load.resize(_wheels.size())
	_clear_wheel_cache()
	_axles = find_axles(_wheels.map(func(r: RayCast3D) -> Vector3: return r.position))
	if _axles.is_empty() and _wheels.size() > 0:
		push_warning("VehicleController: wheels aren't a 2 x 2 layout, anti-roll is off.")
	drift.drift_ended.connect(func(_level: int, _boosted: bool) -> void: _recover_left = stats.drift_recovery_time)
	drift.drift_cancelled.connect(func(_reason: String) -> void: _recover_left = stats.drift_recovery_time)
	trick = VehicleTrick.new()
	trick.name = "VehicleTrick"
	add_child(trick)
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if player_controlled:
		_read_player_input()
	_update_wheel_visuals(delta)


## True when the driver (player or AI) may steer and accelerate.
func can_control() -> bool:
	return input_enabled and not recovery_lock and not _flying


## True while an Overdrive flies the car.
func is_flying() -> bool:
	return _flying


## Starts or continues automated flight: put the car at `target`, moving at
## `velocity` (so speed readouts, positions and the camera still work).
func fly_to(target: Transform3D, velocity: Vector3) -> void:
	_flying = true
	_flight_transform = target
	_flight_velocity = velocity
	_has_pending_teleport = false


## Ends automated flight, driving on forward at `speed`.
func end_flight(speed: float = 0.0) -> void:
	if not _flying:
		return
	_flying = false
	_pending_launch = maxf(speed, 0.0)


func _read_player_input() -> void:
	if not can_control():
		throttle_input = 0.0
		brake_input = 0.0
		steer_input = 0.0
		drift_left_held = false
		drift_right_held = false
		return
	throttle_input = Input.get_action_strength(action(&"accelerate"))
	brake_input = Input.get_action_strength(action(&"brake"))
	steer_input = Input.get_axis(action(&"steer_left"), action(&"steer_right"))
	drift_left_held = Input.is_action_pressed(action(&"drift_left"))
	drift_right_held = Input.is_action_pressed(action(&"drift_right"))
	if Input.is_action_pressed(action(&"drift")):
		# Shift drift: steering picks the direction when the drift starts;
		# after that, Shift alone keeps it going (steering just shapes it).
		if drift.is_drifting():
			drift_left_held = drift_left_held or drift.direction < 0
			drift_right_held = drift_right_held or drift.direction > 0
		elif steer_input <= -SHIFT_DRIFT_STEER_THRESHOLD:
			drift_left_held = true
		elif steer_input >= SHIFT_DRIFT_STEER_THRESHOLD:
			drift_right_held = true


## This car's version of an input action (see input_prefix).
func action(base: StringName) -> StringName:
	return InputSetup.action(input_prefix, base)


## Makes the car look `s` times bigger (body, wheels, effects) without
## touching its physics. Call once, after the cosmetics are applied.
func set_visual_scale(s: float) -> void:
	var change := s / visual_scale
	visual_scale = s
	var body := get_node_or_null("Body") as Node3D
	if body != null:
		body.scale *= change
		body.position.y = body_base_y()
	var feedback := get_node_or_null("Feedback") as Node3D
	if feedback != null:
		feedback.scale = Vector3.ONE * s
	for ray in _wheels:
		var mesh := ray.get_node_or_null("Pivot/Mesh") as Node3D
		if mesh != null:
			mesh.scale = Vector3.ONE * s


## Where a drawn wheel sits relative to its ray: out at the (scaled) body's
## corner, turned with the body's drift yaw, lifted by the hop, and raised so
## a bigger wheel's bottom stays on the road.
func _wheel_visual_offset(ray: RayCast3D) -> Vector3:
	var corner := Vector3(ray.position.x, 0.0, ray.position.z)
	var drawn := (corner * visual_scale).rotated(Vector3.UP, visual_yaw)
	return drawn - corner + Vector3(0.0, stats.wheel_radius * (visual_scale - 1.0) + visual_hop, 0.0)


## The body's resting height (raised when the car is drawn bigger).
func body_base_y() -> float:
	return BODY_HALF_HEIGHT * (visual_scale - 1.0)


## Moves the car on the next physics step and clears all motion.
func teleport(target: Transform3D) -> void:
	_pending_teleport = target
	_has_pending_teleport = true


## Pins the car motionless at `target` until release() (recovery). Moving
## a held car somewhere new emits `teleported` (the camera snaps).
func hold_at(target: Transform3D) -> void:
	_held_moved = _held and not target.is_equal_approx(_held_transform)
	_held = true
	_held_transform = target
	_has_pending_teleport = false


## Pins the car where it is now.
func hold_here() -> void:
	hold_at(global_transform)


func is_held() -> bool:
	return _held


## Lets a held car go, moving forward at `speed` m/s.
func release(speed: float = 0.0) -> void:
	if not _held:
		return
	_held = false
	_pending_launch = maxf(speed, 0.0)


## Passes through every other car while on (collisions with the track stay).
## Off restores normal car-to-car contact.
func set_ghost(on: bool) -> void:
	for other in _ghosted_with:
		if is_instance_valid(other):
			remove_collision_exception_with(other)
	_ghosted_with.clear()
	_ghost = on
	if not on or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as VehicleController
		if other != null and other != self:
			add_collision_exception_with(other)
			_ghosted_with.append(other)


## True while a recovery has the car dissolved, gone or still forming: it
## can't be hit, targeted, drafted or collect anything.
func is_recovering_hidden() -> bool:
	return recovery != null and recovery.is_hidden()


func is_ghost() -> bool:
	return _ghost


## Placeholder paint so racers are distinguishable (not a cosmetic system).
## Swaps the driving stats after the car is in the tree (re-aims the wheel rays).
func set_stats(new_stats: VehicleStats) -> void:
	stats = new_stats if new_stats != null else VehicleStats.new()
	for ray in _wheels:
		ray.target_position = Vector3(0.0, -(stats.suspension_rest_length + stats.wheel_radius), 0.0)


## Plain gloss paint on whatever body the car has (model or box car).
func set_body_color(color: Color) -> void:
	VehicleCosmetics.paint_body(self, color)


func is_boosting() -> bool:
	return boost_time_left > 0.0


## The slipstream's own boost is running (the meter filled behind a car).
func is_slipstream_boosting() -> bool:
	return is_boosting() and boost_label == Slipstream.BOOST_LABEL


func get_speed_cap() -> float:
	var multiplier := status.speed_multiplier() if status != null else 1.0
	return (stats.top_speed + _boost_extra_speed) * multiplier


## Keeps this fraction of the current speed on the next physics step (stuns).
func scrub_speed(fraction_kept: float) -> void:
	_pending_speed_scale = minf(_pending_speed_scale, clampf(fraction_kept, 0.0, 1.0))


## A boost that isn't from drifting (Nitro Overload).
func start_external_boost(extra_speed: float, duration: float, kick: float, label: String, color: Color) -> void:
	boost_time_left = maxf(boost_time_left, duration)
	_boost_extra_speed = maxf(_boost_extra_speed, extra_speed)
	_pending_kick = maxf(_pending_kick, kick)
	boost_label = label
	boost_color = color
	external_boost_started.emit(label)


func start_boost(level: int) -> void:
	if level <= 0:
		return
	var index := clampi(level, 1, stats.boost_duration.size()) - 1
	# A stronger or longer boost replaces a weaker one; never shorten an active one.
	boost_level = maxi(boost_level, level)
	boost_time_left = maxf(boost_time_left, stats.boost_duration[index])
	_boost_extra_speed = maxf(_boost_extra_speed, stats.boost_extra_speed[index])
	# The kick is applied through the physics state on the next step.
	_pending_kick = maxf(_pending_kick, stats.boost_kick[index])
	boost_label = DriftController.LEVEL_NAMES[boost_level]
	boost_color = DriftController.LEVEL_COLORS[boost_level]
	boost_started.emit(level)


func clear_boost() -> void:
	var was_boosting := is_boosting()
	boost_level = 0
	boost_time_left = 0.0
	_boost_extra_speed = 0.0
	boost_label = ""
	if was_boosting:
		boost_ended.emit()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _held:
		state.transform = _held_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_kick = 0.0
		_pending_speed_scale = 1.0
		_prev_forward_speed = 0.0
		forward_speed = 0.0
		lateral_speed = 0.0
		_clear_wheel_cache()
		if _held_moved:
			_held_moved = false
			teleported.emit.call_deferred()
		return
	if _flying:
		state.transform = _flight_transform
		state.linear_velocity = _flight_velocity
		state.angular_velocity = Vector3.ZERO
		var basis_now := _flight_transform.basis
		forward_speed = _flight_velocity.dot(-basis_now.z)
		lateral_speed = 0.0
		_prev_forward_speed = forward_speed
		grounded_wheels = 0
		_pending_kick = 0.0
		_pending_speed_scale = 1.0
		_clear_wheel_cache()
		return
	if _pending_launch >= 0.0:
		state.linear_velocity = -state.transform.basis.z * _pending_launch
		state.angular_velocity = Vector3.ZERO
		_prev_forward_speed = _pending_launch
		_pending_launch = -1.0
	if _has_pending_teleport:
		_has_pending_teleport = false
		state.transform = _pending_teleport
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_kick = 0.0
		_pending_speed_scale = 1.0
		_prev_forward_speed = 0.0
		forward_speed = 0.0
		lateral_speed = 0.0
		_clear_wheel_cache()
		teleported.emit.call_deferred()
		return

	var dt := state.step
	var body_basis := state.transform.basis
	var up := body_basis.y
	var fwd := -body_basis.z
	var right := body_basis.x

	_apply_suspension(state, up)
	_apply_anti_roll(state, up)
	var traction := _update_traction()
	_update_landing(state, up, dt)

	var velocity := state.linear_velocity
	forward_speed = velocity.dot(fwd)
	lateral_speed = velocity.dot(right)

	# Major collision check (GDD 4.4: cancels an active drift).
	var speed_lost := _prev_forward_speed - forward_speed
	if speed_lost > stats.major_impact_speed_loss:
		heavy_impact.emit(speed_lost)
		drift.cancel("collision")
	_prev_forward_speed = forward_speed

	# Status effects override the driver's inputs for this step.
	if status != null:
		if not status.can_drive():
			throttle_input = 0.0
			brake_input = 0.0
			steer_input = 0.0
		if not status.can_charge_drift():
			drift_left_held = false
			drift_right_held = false
			drift.cancel("disrupted")

	var boost_to_fire := drift.update(dt, drift_left_held, drift_right_held,
			grounded_wheels >= 2, forward_speed, lateral_speed, stats, steer_input)

	_update_boost_timer(dt)

	if traction > 0.0:
		velocity = _apply_drive(velocity, fwd, dt, traction)
		velocity = _apply_grip(velocity, fwd, dt, traction)
		state.angular_velocity = _apply_steering(state.angular_velocity, up, dt, traction)
	var touching := state.get_contact_count() > 0
	state.angular_velocity = _apply_upright_assist(state.angular_velocity, up, dt, touching)

	if _pending_kick > 0.0:
		if traction > 0.0:
			velocity += fwd * _pending_kick
		_pending_kick = 0.0
	if _pending_speed_scale < 1.0:
		velocity = Vector3(velocity.x * _pending_speed_scale, velocity.y, velocity.z * _pending_speed_scale)
		_pending_speed_scale = 1.0
	state.linear_velocity = velocity

	if boost_to_fire > 0:
		start_boost(boost_to_fire)


func _apply_suspension(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	grounded_wheels = 0
	ray_hit_wheels = 0
	var normal_sum := Vector3.ZERO
	var weight_sum := 0.0
	var full_weight := 0.25 * static_compression()
	# Touching down after real airtime (air_time resets after this step).
	var landing := air_time >= LANDING_MIN_AIR_TIME or _stabilize_left > 0.0
	var damping := stats.suspension_damping * (stats.landing_damping_multiplier if landing else 1.0)
	for i in _wheels.size():
		var ray := _wheels[i]
		wheel_spring_length[i] = -1.0
		wheel_compression[i] = 0.0
		wheel_load[i] = 0.0
		if not ray.is_colliding():
			continue
		ray_hit_wheels += 1
		var hit := ray.get_collision_point()
		var origin := ray.global_position
		# Measure along the car's up axis. The ray hit comes from the previous
		# physics step, so a straight-line distance grows with speed and makes
		# the springs read as uncompressed (the car then sinks onto its belly).
		var spring_length := (origin - hit).dot(up) - stats.wheel_radius
		wheel_spring_length[i] = spring_length
		var compression := stats.suspension_rest_length - spring_length
		if compression <= 0.0:
			continue
		# Past full travel the spring keeps pushing (a bump stop): ramp
		# take-offs rely on it, so only the recorded value is clamped.
		wheel_compression[i] = minf(compression, stats.suspension_rest_length)
		grounded_wheels += 1
		weight_sum += smoothstep(0.0, full_weight, compression)
		normal_sum += ray.get_collision_normal()
		var offset := origin - state.transform.origin
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset)
		var force := stats.suspension_stiffness * compression - damping * point_velocity.dot(up)
		if stats.max_suspension_force > 0.0:
			force = minf(force, stats.max_suspension_force)
		if force > 0.0:
			wheel_load[i] = force
			# An impulse changes velocity immediately, so the drive/grip code
			# below reads (and writes back) a velocity that already includes it.
			state.apply_impulse(up * force * state.step, offset)
	ground_normal = normal_sum.normalized() if grounded_wheels > 0 else Vector3.UP
	_raw_traction = weight_sum / maxf(1.0, float(_wheels.size()))


## Spring compression that holds the car up at rest (m).
func static_compression() -> float:
	var n := maxf(1.0, float(_wheels.size()))
	var g := ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	return mass * g * gravity_scale / (n * maxf(stats.suspension_stiffness, 1.0))


## Anti-roll bars: on each axle with both wheels loaded, push the more
## compressed side up and the other side down by the same amount (no net lift).
func _apply_anti_roll(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	anti_roll_force = Vector2.ZERO
	if stats.anti_roll_stiffness <= 0.0:
		return
	for a in _axles.size():
		var l := _axles[a].x
		var r := _axles[a].y
		if wheel_compression[l] <= 0.0 or wheel_compression[r] <= 0.0:
			continue
		var f := (wheel_compression[l] - wheel_compression[r]) * stats.anti_roll_stiffness
		var origin := state.transform.origin
		state.apply_impulse(up * f * state.step, _wheels[l].global_position - origin)
		state.apply_impulse(-up * f * state.step, _wheels[r].global_position - origin)
		anti_roll_force[a] = f


## Traction for this step: the loaded-wheel weighting, held for a couple of
## steps over a contact glitch.
func _update_traction() -> float:
	if _raw_traction > 0.0:
		_last_traction = _raw_traction
		_grace_left = stats.contact_grace_ticks
		traction_fraction = _raw_traction
	elif _grace_left > 0:
		_grace_left -= 1
		traction_fraction = _last_traction
	else:
		_last_traction = 0.0
		traction_fraction = 0.0
	return traction_fraction


## Air time, and a short pitch/roll damping after a real landing.
func _update_landing(state: PhysicsDirectBodyState3D, up: Vector3, dt: float) -> void:
	if grounded_wheels == 0:
		air_time += dt
		since_landing = 0.0
		_stabilize_left = 0.0
		return
	if air_time >= LANDING_MIN_AIR_TIME and grounded_wheels >= 2:
		_stabilize_left = stats.landing_stabilize_time
	if grounded_wheels >= 2:
		air_time = 0.0
	since_landing += dt
	if _stabilize_left <= 0.0 or stats.landing_stabilize_strength <= 0.0:
		return
	_stabilize_left -= dt
	var angular := state.angular_velocity
	var yaw := up * angular.dot(up)
	var keep := 1.0 - clampf(stats.landing_stabilize_strength * dt, 0.0, 1.0)
	state.angular_velocity = yaw + (angular - yaw) * keep


## Clears this step's wheel contact (hold, flight, teleport), so nothing
## stale carries into the first step back on the road.
func _clear_wheel_cache() -> void:
	wheel_spring_length.fill(-1.0)
	wheel_compression.fill(0.0)
	wheel_load.fill(0.0)
	ray_hit_wheels = 0
	traction_fraction = 0.0
	anti_roll_force = Vector2.ZERO
	_raw_traction = 0.0
	_last_traction = 0.0
	_grace_left = 0
	_stabilize_left = 0.0


## Pairs wheels into axles from their local positions: front (-z) and rear
## (+z), each [left (-x), right (+x)]. Empty unless exactly 2 x 2.
static func find_axles(positions: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if positions.size() != 4:
		return out
	for front in [true, false]:
		var left := -1
		var right := -1
		for i in 4:
			var p: Vector3 = positions[i]
			if (p.z < 0.0) != front:
				continue
			if p.x < 0.0 and left < 0:
				left = i
			elif p.x > 0.0 and right < 0:
				right = i
		if left < 0 or right < 0:
			return [] as Array[Vector2i]
		out.append(Vector2i(left, right))
	return out


func _apply_drive(velocity: Vector3, fwd: Vector3, dt: float, traction: float) -> Vector3:
	var drive_dir := (fwd - ground_normal * fwd.dot(ground_normal)).normalized()
	var cap := get_speed_cap()
	var accel := 0.0

	if throttle_input > 0.0 and forward_speed < cap:
		var ratio := clampf(forward_speed / cap, 0.0, 1.0)
		var accel_scale := status.accel_multiplier() if status != null else 1.0
		accel += throttle_input * stats.acceleration * accel_scale * (1.0 - ratio * ratio)
	if is_boosting() and forward_speed < cap:
		accel += stats.boost_acceleration
	if forward_speed > cap:
		accel -= stats.overspeed_deceleration

	if brake_input > 0.0:
		if forward_speed > 0.5:
			accel -= brake_input * stats.brake_deceleration
		elif forward_speed > -stats.reverse_top_speed:
			accel -= brake_input * stats.reverse_acceleration

	if throttle_input <= 0.0 and brake_input <= 0.0 and not is_boosting():
		# Coast toward a stop without overshooting into reverse.
		var coast := minf(stats.coast_deceleration * dt, absf(forward_speed))
		velocity -= drive_dir * signf(forward_speed) * coast * traction

	return velocity + drive_dir * accel * dt * traction


func _apply_grip(velocity: Vector3, fwd: Vector3, dt: float, traction: float) -> Vector3:
	var drifting := drift.is_drifting()
	var grip_rate := stats.drift_grip if drifting else stats.grip
	var retention := stats.drift_speed_retention if drifting else stats.grip_speed_retention
	if not drifting and _recover_left > 0.0:
		# Just out of a drift: ease back to full grip.
		var t := 1.0 - _recover_left / maxf(stats.drift_recovery_time, 0.001)
		grip_rate = lerpf(stats.drift_grip, stats.grip, t)
		retention = lerpf(stats.drift_speed_retention, stats.grip_speed_retention, t)
		_recover_left = maxf(0.0, _recover_left - dt)
	if status != null:
		grip_rate *= status.grip_multiplier()

	var normal := ground_normal
	var vertical := normal * velocity.dot(normal)
	var planar := velocity - vertical
	var heading := (fwd - normal * fwd.dot(normal)).normalized()
	var along := planar.dot(heading)
	# Target: velocity pointing along the heading, keeping some of the slide's speed.
	var target_speed := lerpf(absf(along), planar.length(), retention) * signf(along)
	var target := heading * target_speed
	var blend := clampf(grip_rate * dt * traction, 0.0, 1.0)
	return planar.lerp(target, blend) + vertical


func _apply_steering(angular: Vector3, up: Vector3, dt: float, traction: float) -> Vector3:
	var speed := absf(forward_speed)
	var low_speed_factor := clampf(speed / stats.steer_full_speed, 0.0, 1.0)
	var target_yaw := 0.0

	if drift.is_drifting():
		# Positive yaw turns left, so a left drift (-1) yaws positive.
		var into_drift := steer_input * float(drift.direction)
		var rate := stats.drift + into_drift * stats.drift_steer_influence
		target_yaw = -float(drift.direction) * rate * low_speed_factor
	else:
		var speed_ratio := clampf(speed / stats.top_speed, 0.0, 1.0)
		var falloff := lerpf(1.0, stats.high_speed_steer_factor, speed_ratio)
		var reverse_sign := -1.0 if forward_speed < -0.5 else 1.0
		target_yaw = -steer_input * stats.handling * low_speed_factor * falloff * reverse_sign

	var current_yaw := angular.dot(up)
	var blend := clampf(stats.steer_response * dt, 0.0, 1.0) * traction
	var new_yaw := lerpf(current_yaw, target_yaw, blend)
	return angular + up * (new_yaw - current_yaw)


func _apply_upright_assist(angular: Vector3, up: Vector3, dt: float, touching: bool) -> Vector3:
	# Rotate gently back toward world-up to resist flipping (GDD 5.4).
	# A car resting on its side or roof (touching, no wheels down) gets no help;
	# VehicleRecovery handles that case instead of magically flipping it.
	var airborne := grounded_wheels == 0 and not touching
	var strength := 0.0
	if grounded_wheels > 0:
		strength = stats.ground_upright_strength
	elif airborne:
		strength = stats.air_upright_strength
	var tilt_axis := up.cross(Vector3.UP)
	angular += tilt_axis * strength * dt * 10.0
	if airborne:
		# Damp tumbling in the air, but keep yaw.
		var yaw := up * angular.dot(up)
		angular = yaw + (angular - yaw) * (1.0 - clampf(2.0 * dt, 0.0, 1.0))
	return angular


func _update_boost_timer(dt: float) -> void:
	if boost_time_left <= 0.0:
		return
	boost_time_left -= dt
	if boost_time_left <= 0.0:
		clear_boost()


func _update_wheel_visuals(delta: float) -> void:
	_wheel_spin = fmod(_wheel_spin - forward_speed / (stats.wheel_radius * visual_scale) * delta, TAU)
	var steer_angle := -steer_input * 0.45
	if drift.is_drifting():
		steer_angle = float(drift.direction) * -0.25 + -steer_input * 0.2
	for ray in _wheels:
		var pivot := ray.get_node_or_null("Pivot") as Node3D
		if pivot == null:
			continue
		var spring_length := stats.suspension_rest_length
		if ray.is_colliding():
			var dist := (ray.global_position - ray.get_collision_point()).dot(global_transform.basis.y)
			spring_length = clampf(dist - stats.wheel_radius, 0.0, stats.suspension_rest_length)
		pivot.position = Vector3(0.0, -spring_length, 0.0) + _wheel_visual_offset(ray)
		var yaw := (steer_angle if ray.name.begins_with("WheelF") else 0.0) + visual_yaw
		pivot.rotation = Vector3(_wheel_spin, yaw, 0.0)
