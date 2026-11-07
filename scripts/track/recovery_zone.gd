@tool
class_name RecoveryZone
extends Area3D
## A hazard volume (docs/Recovery System.md §7 B): any car inside starts a
## recovery straight away, with `reason` ("water" splashes first). Add box
## shapes as CollisionShape3D children, in the editor or with add_box().
## SceneryTerrain makes one over a track's deep water by itself.
##
## Cars are found by polling the overlap every physics step, so a car that
## arrives while its recovery is refused (cooldown) is still caught.

@export var reason: String = "water"


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not monitoring:
		return
	for body in get_overlapping_bodies():
		var car := body as VehicleController
		if car != null and car.recovery != null and not car.recovery.is_busy():
			car.recovery.request_recovery(reason)


## Adds a box (local centre and size) to the zone.
func add_box(center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
	return shape


## True if a world point is inside any of the zone's boxes (tests, tools).
func has_point(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	for child in get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var half := (shape.shape as BoxShape3D).size * 0.5
		var p := shape.transform.affine_inverse() * local
		if absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z:
			return true
	return false
