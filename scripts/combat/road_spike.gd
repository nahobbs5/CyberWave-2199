class_name RoadSpike
extends Area3D
## Electrified spike strip dropped behind its owner (GDD 6.3, 6.4).
## Affects any racer who drives over it, including its owner once the
## deployment grace period has passed. Single use; expires after its lifetime.

var manager: WeaponManager
var shooter: VehicleController
var weapon: WeaponData

## Strip width across the road (m).
const WIDTH := 2.0
## Spikes on the strip, spread evenly across WIDTH.
const SPIKES := 3

var _age: float = 0.0
var _owner_checked: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # vehicles
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 1.6, 1.8)
	shape.shape = box
	shape.position = Vector3(0.0, 0.8, 0.0)
	add_child(shape)
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(WIDTH, 0.06, 1.2)
	strip.mesh = strip_mesh
	strip.material_override = WeaponManager.glow_material(Color(0.15, 0.15, 0.18), 0.0)
	strip.position = Vector3(0.0, 0.04, 0.0)
	add_child(strip)
	var spike_mat := WeaponManager.glow_material(weapon.color, 4.0)
	var spacing := (WIDTH - 0.3) / (SPIKES - 1)
	for i in SPIKES:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.12
		cone.height = 0.35
		cone.radial_segments = 6
		spike.mesh = cone
		spike.material_override = spike_mat
		spike.position = Vector3(-(WIDTH - 0.3) / 2.0 + i * spacing, 0.2, 0.0)
		add_child(spike)
	body_entered.connect(_on_body_entered)


func is_armed_for(vehicle: VehicleController) -> bool:
	if vehicle != shooter:
		return true
	return weapon.can_affect_owner and _age >= weapon.owner_grace


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > weapon.lifetime:
		queue_free()
		return
	# An owner still sitting on the strip when the grace period ends is hit too.
	if not _owner_checked and is_armed_for(shooter):
		_owner_checked = true
		if overlaps_body(shooter):
			_trigger(shooter)


func _on_body_entered(body: Node3D) -> void:
	var vehicle := body as VehicleController
	if vehicle != null and is_armed_for(vehicle):
		_trigger(vehicle)


func _trigger(vehicle: VehicleController) -> void:
	if is_queued_for_deletion():
		return
	manager.apply_hit(vehicle, weapon, shooter)
	manager.spawn_flash(global_position + Vector3.UP * 0.5, weapon.color)
	queue_free()
