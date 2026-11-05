class_name ChaseCamera
extends Camera3D
## Shared chase camera controller for Far and Close Chase (GDD 10).
##
## Each view is a CameraProfile resource. C / gamepad View cycles views, and
## the choice is saved to user://settings.cfg so it persists between sessions
## (GameSettings keeps its own sections in the same file).
## Camera shake on impacts, stuns and boosts is scaled by the accessibility
## setting GameSettings.camera_shake (0 turns it off).

signal profile_changed(profile: CameraProfile)

const SETTINGS_PATH := "user://settings.cfg"

## Far Chase is the GDD default view; C cycles Far -> Close -> Far.
@export var far_chase: CameraProfile
@export var close_chase: CameraProfile
@export var save_preference: bool = true
## Collision layers the camera avoids clipping through (environment only).
@export_flags_3d_physics var collision_mask: int = 1

var target: VehicleController
var profiles: Array[CameraProfile] = []
var profile_index: int = 0

var _direction: Vector3 = Vector3.FORWARD
## Current shake (0..1), decays quickly.
var _shake: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	for profile in [far_chase, close_chase]:
		if profile != null:
			profiles.append(profile)
	if profiles.is_empty():
		push_warning("ChaseCamera: no profiles assigned; using defaults.")
		profiles.append(CameraProfile.new())
	if save_preference:
		profile_index = clampi(_load_preference(), 0, profiles.size() - 1)
	fov = get_profile().fov


func get_profile() -> CameraProfile:
	return profiles[profile_index]


func set_target(vehicle: VehicleController) -> void:
	if target != null and is_instance_valid(target):
		for pair in _shake_sources():
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	target = vehicle
	if target != null and not target.teleported.is_connected(snap):
		target.teleported.connect(snap)
	if target != null:
		for pair in _shake_sources():
			if not (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).connect(pair[1])
	snap()


## Adds camera shake (0..1), scaled by the accessibility setting.
func add_shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount * GameSettings.camera_shake), 0.0, 1.0)


func get_shake() -> float:
	return _shake


func _shake_sources() -> Array:
	var out := [
		[target.heavy_impact, _on_heavy_impact],
		[target.boost_started, _on_boost_shake],
	]
	if target.status != null:
		out.append([target.status.effect_started, _on_effect_shake])
	return out


func _on_heavy_impact(speed_lost: float) -> void:
	add_shake(clampf(speed_lost / 25.0, 0.2, 0.8))


func _on_boost_shake(level: int) -> void:
	add_shake(0.1 + 0.08 * level)


func _on_effect_shake(effect: StringName, _duration: float) -> void:
	if effect == &"stun" or effect == &"stagger":
		add_shake(0.6)
	elif effect == &"emp" or effect == &"traction":
		add_shake(0.3)


func cycle_profile() -> void:
	profile_index = (profile_index + 1) % profiles.size()
	if save_preference:
		_save_preference()
	profile_changed.emit(get_profile())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera"):
		cycle_profile()
		get_viewport().set_input_as_handled()


## Jumps straight to the desired position (after spawn/recovery).
func snap() -> void:
	if target == null:
		return
	_direction = _car_heading()
	global_position = _desired_position(get_profile(), 0.0)
	_look(get_profile())


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var p := get_profile()
	var heading := _car_heading()
	var planar_velocity := Vector3(target.linear_velocity.x, 0.0, target.linear_velocity.z)
	if planar_velocity.length() > 4.0 and target.forward_speed > 0.0:
		heading = heading.lerp(planar_velocity.normalized(), p.velocity_blend).normalized()
	_direction = _direction.slerp(heading, 1.0 - exp(-p.rotation_smoothing * delta)).normalized()

	var speed_ratio := clampf(absf(target.forward_speed) / target.stats.top_speed, 0.0, 1.2)
	var desired := _avoid_collision(_desired_position(p, speed_ratio), p)
	global_position = global_position.lerp(desired, 1.0 - exp(-p.position_smoothing * delta))
	_look(p)
	if _shake > 0.001:
		_shake_time += delta
		var t := _shake_time * 40.0
		rotate_object_local(Vector3.RIGHT, sin(t * 1.3) * 0.02 * _shake)
		rotate_object_local(Vector3.UP, sin(t * 0.9 + 1.7) * 0.025 * _shake)
		h_offset = sin(t * 1.1) * 0.25 * _shake
		v_offset = cos(t * 1.5) * 0.18 * _shake
		_shake = maxf(0.0, _shake - delta * 2.5)
	else:
		h_offset = 0.0
		v_offset = 0.0

	var target_fov := p.fov + p.speed_fov_gain * speed_ratio
	if target.is_boosting():
		target_fov += p.boost_fov_kick
	fov = lerpf(fov, target_fov, 1.0 - exp(-p.fov_smoothing * delta))


func _car_heading() -> Vector3:
	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return _direction
	return forward.normalized()


func _focus_point(p: CameraProfile) -> Vector3:
	return target.global_position + Vector3.UP * p.look_height


func _desired_position(p: CameraProfile, speed_ratio: float) -> Vector3:
	var dist := p.distance + p.speed_distance_gain * speed_ratio
	return target.global_position - _direction * dist + Vector3.UP * p.height


func _look(p: CameraProfile) -> void:
	var look_target := _focus_point(p) + _direction * p.look_ahead
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)


func _avoid_collision(desired: Vector3, p: CameraProfile) -> Vector3:
	var from := _focus_point(p)
	var query := PhysicsRayQueryParameters3D.create(from, desired, collision_mask, [target.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_pos: Vector3 = hit.position
	return hit_pos + (from - hit_pos).normalized() * p.collision_margin


func _load_preference() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return 0
	return int(config.get_value("camera", "profile_index", 0))


func _save_preference() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Keep any other sections; missing file is fine.
	config.set_value("camera", "profile_index", profile_index)
	config.save(SETTINGS_PATH)
