class_name HunterDrone
extends Node3D
## Guided drone. Follows the track above the barriers toward its target and
## homes in when close. Without a target it hunts the nearest racer ahead.
## Never targets the racer who launched it. A target with a Holo Decoy out
## draws the drone onto the decoy instead (it pops the decoy).
## SwarmBots reuses the chase with its own look and strike.

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
	_build_visuals()
	_velocity = -shooter.global_transform.basis.z * maxf(shooter.forward_speed, 20.0)


func _build_visuals() -> void:
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


## True while chasing a live target (the HUD's INCOMING warning).
func is_chasing(vehicle: VehicleController) -> bool:
	return target == vehicle and not is_queued_for_deletion()


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
		# A decoy out draws the drone onto it.
		var decoy := manager.decoy_of(target)
		var aim: Vector3 = decoy.global_position if decoy != null else target.global_position
		var to_target := aim - global_position
		if to_target.length() < HIT_RANGE:
			if decoy != null:
				manager.absorb_with_decoy(decoy, weapon, shooter)
			else:
				_strike(target)
			manager.spawn_flash(global_position, weapon.color)
			queue_free()
			return
		if to_target.length() < HOMING_RANGE:
			goal = aim + Vector3.UP * 0.6
	var desired := (goal - global_position).normalized() * weapon.speed
	_velocity = _velocity.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))
	global_position += _velocity * delta
	_animate(delta)


func _strike(victim: VehicleController) -> void:
	manager.apply_hit(victim, weapon, shooter)


func _animate(delta: float) -> void:
	var ring := get_node_or_null("Ring") as Node3D
	if ring != null:
		ring.rotate_x(delta * 9.0)
