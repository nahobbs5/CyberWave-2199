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

## Drift boost fired (level 1-3).
signal boost_started(level: int)
## Non-drift boost fired (e.g. Nitro Overload).
signal external_boost_started(label: String)
signal boost_ended
## Emitted on a sudden large loss of forward speed (barrier hit, etc.).
signal heavy_impact(speed_lost: float)
## Emitted after a teleport/recovery has been applied.
signal teleported

## Steering needed to pick a direction when starting a Shift drift.
const SHIFT_DRIFT_STEER_THRESHOLD := 0.3

@export var stats: VehicleStats
## When true, inputs are read from the InputMap each physics frame.
## AI (Phase 2) sets this to false and writes the *_input fields directly.
@export var player_controlled: bool = true
## The human racer's car (gets audio cues and the camera). Stays true after the
## player finishes and the autopilot takes over.
@export var is_player: bool = true

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0
var drift_left_held: bool = false
var drift_right_held: bool = false
var input_enabled: bool = true

var grounded_wheels: int = 0
var forward_speed: float = 0.0
var lateral_speed: float = 0.0
var ground_normal: Vector3 = Vector3.UP

var boost_level: int = 0
var boost_time_left: float = 0.0
## What the current boost is called and its colour (for HUD and effects).
var boost_label: String = ""
var boost_color: Color = Color.WHITE

var _boost_extra_speed: float = 0.0
var _pending_kick: float = 0.0
var _pending_speed_scale: float = 1.0
var _has_pending_teleport: bool = false
var _pending_teleport: Transform3D
var _prev_forward_speed: float = 0.0
var _wheel_spin: float = 0.0
var _wheels: Array[RayCast3D] = []

@onready var drift: DriftController = $DriftController
@onready var recovery: VehicleRecovery = $VehicleRecovery
## Optional combat nodes (absent cars just ignore weapons).
@onready var status: StatusEffects = get_node_or_null("StatusEffects")
@onready var inventory: ItemInventory = get_node_or_null("ItemInventory")
@onready var targeting: TargetingSystem = get_node_or_null("TargetingSystem")


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


func _physics_process(delta: float) -> void:
	if player_controlled:
		_read_player_input()
	_update_wheel_visuals(delta)


func _read_player_input() -> void:
	if not input_enabled:
		throttle_input = 0.0
		brake_input = 0.0
		steer_input = 0.0
		drift_left_held = false
		drift_right_held = false
		return
	throttle_input = Input.get_action_strength("accelerate")
	brake_input = Input.get_action_strength("brake")
	steer_input = Input.get_axis("steer_left", "steer_right")
	drift_left_held = Input.is_action_pressed("drift_left")
	drift_right_held = Input.is_action_pressed("drift_right")
	if Input.is_action_pressed("drift"):
		# Shift drift: steering picks the direction when the drift starts;
		# after that, Shift alone keeps it going (steering just shapes it).
		if drift.is_drifting():
			drift_left_held = drift_left_held or drift.direction < 0
			drift_right_held = drift_right_held or drift.direction > 0
		elif steer_input <= -SHIFT_DRIFT_STEER_THRESHOLD:
			drift_left_held = true
		elif steer_input >= SHIFT_DRIFT_STEER_THRESHOLD:
			drift_right_held = true


## Moves the car on the next physics step and clears all motion.
func teleport(target: Transform3D) -> void:
	_pending_teleport = target
	_has_pending_teleport = true


## Placeholder paint so racers are distinguishable (not a cosmetic system).
## Swaps the driving stats after the car is in the tree (re-aims the wheel rays).
func set_stats(new_stats: VehicleStats) -> void:
	stats = new_stats if new_stats != null else VehicleStats.new()
	for ray in _wheels:
		ray.target_position = Vector3(0.0, -(stats.suspension_rest_length + stats.wheel_radius), 0.0)


func set_body_color(color: Color) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.8
	paint.roughness = 0.25
	for path in ["Body/Chassis", "Body/Nose"]:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh != null:
			mesh.material_override = paint


func is_boosting() -> bool:
	return boost_time_left > 0.0


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
		teleported.emit.call_deferred()
		return

	var dt := state.step
	var body_basis := state.transform.basis
	var up := body_basis.y
	var fwd := -body_basis.z
	var right := body_basis.x

	_apply_suspension(state, up)
	var traction := float(grounded_wheels) / maxf(1.0, float(_wheels.size()))

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
			grounded_wheels >= 2, forward_speed, lateral_speed, stats)

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
	var normal_sum := Vector3.ZERO
	for ray in _wheels:
		if not ray.is_colliding():
			continue
		var hit := ray.get_collision_point()
		var origin := ray.global_position
		# Measure along the car's up axis. The ray hit comes from the previous
		# physics step, so a straight-line distance grows with speed and makes
		# the springs read as uncompressed (the car then sinks onto its belly).
		var spring_length := (origin - hit).dot(up) - stats.wheel_radius
		var compression := stats.suspension_rest_length - spring_length
		if compression <= 0.0:
			continue
		grounded_wheels += 1
		normal_sum += ray.get_collision_normal()
		var offset := origin - state.transform.origin
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset)
		var force := stats.suspension_stiffness * compression - stats.suspension_damping * point_velocity.dot(up)
		if force > 0.0:
			# An impulse changes velocity immediately, so the drive/grip code
			# below reads (and writes back) a velocity that already includes it.
			state.apply_impulse(up * force * state.step, offset)
	ground_normal = normal_sum.normalized() if grounded_wheels > 0 else Vector3.UP


func _apply_drive(velocity: Vector3, fwd: Vector3, dt: float, traction: float) -> Vector3:
	var drive_dir := (fwd - ground_normal * fwd.dot(ground_normal)).normalized()
	var cap := get_speed_cap()
	var accel := 0.0

	if throttle_input > 0.0 and forward_speed < cap:
		var ratio := clampf(forward_speed / cap, 0.0, 1.0)
		accel += throttle_input * stats.acceleration * (1.0 - ratio * ratio)
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
	if status != null:
		grip_rate *= status.grip_multiplier()
	var retention := stats.drift_speed_retention if drifting else stats.grip_speed_retention

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
	_wheel_spin = fmod(_wheel_spin - forward_speed / stats.wheel_radius * delta, TAU)
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
		pivot.position = Vector3(0.0, -spring_length, 0.0)
		var yaw := steer_angle if ray.name.begins_with("WheelF") else 0.0
		pivot.rotation = Vector3(_wheel_spin, yaw, 0.0)
