class_name RailgunShot
extends Node3D
## Fast projectile. Sweeps a ray each frame so it can't tunnel through cars
## or barriers. Never hits the car that fired it.

var manager: WeaponManager
var shooter: VehicleController
var weapon: WeaponData
var direction: Vector3 = Vector3.FORWARD

var _travelled: float = 0.0


func _ready() -> void:
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 4.0)
	bolt.mesh = box
	bolt.material_override = WeaponManager.glow_material(weapon.color, 6.0)
	add_child(bolt)
	var light := OmniLight3D.new()
	light.light_color = weapon.color
	light.light_energy = 3.0
	light.omni_range = 6.0
	add_child(light)
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step := weapon.speed * delta
	var from := global_position
	var to := from + direction * step
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [shooter.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider is VehicleController:
			manager.apply_hit(hit.collider, weapon, shooter)
		manager.spawn_flash(hit.position, weapon.color)
		queue_free()
		return
	global_position = to
	_travelled += step
	if _travelled > weapon.radius:
		queue_free()
