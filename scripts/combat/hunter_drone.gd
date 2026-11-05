class_name HunterDrone
extends Node3D
## Guided drone. Follows the track above the barriers toward its target and
## homes in when close. Without a target it hunts the nearest racer ahead.
## Never targets the racer who launched it.

var manager: WeaponManager
var shooter: VehicleController
var weapon: WeaponData
var target: VehicleController

const HOMING_RANGE := 30.0
const HIT_RANGE := 2.4
const CRUISE_HEIGHT := 2.5

var _age: float = 0.0
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"hunter_drones")
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	core.mesh = sphere
	core.material_override = WeaponManager.glow_material(weapon.color, 5.0)
	add_child(core)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	ring.mesh = torus
	ring.name = "Ring"
	ring.material_override = WeaponManager.glow_material(weapon.color, 3.0)
	add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = weapon.color
	light.light_energy = 2.5
	light.omni_range = 7.0
	add_child(light)
	_velocity = -shooter.global_transform.basis.z * maxf(shooter.forward_speed, 20.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > weapon.lifetime:
		manager.spawn_flash(global_position, weapon.color)
		queue_free()
		return
	if target == null or not manager.is_targetable(target):
		target = manager.find_target_ahead(global_position, shooter, 120.0)
	var track := manager.track
	var offset := track.get_offset_at(global_position)
	var goal := track.get_center_at(offset + 25.0) + Vector3.UP * CRUISE_HEIGHT
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() < HIT_RANGE:
			manager.apply_hit(target, weapon, shooter)
			manager.spawn_flash(global_position, weapon.color)
			queue_free()
			return
		if to_target.length() < HOMING_RANGE:
			goal = target.global_position + Vector3.UP * 0.6
	var desired := (goal - global_position).normalized() * weapon.speed
	_velocity = _velocity.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))
	global_position += _velocity * delta
	var ring := get_node("Ring") as Node3D
	ring.rotate_x(delta * 9.0)
