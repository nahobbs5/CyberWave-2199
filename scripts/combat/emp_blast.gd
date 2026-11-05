class_name EmpBlast
extends MeshInstance3D
## Visual only: an expanding, fading sphere showing an EMP Pulse's reach.

var radius: float = 20.0
var color: Color = Color(0.3, 0.6, 1.0)

const DURATION := 0.45

var _age: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	mesh = sphere
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color, 0.35)
	material_override = _material
	scale = Vector3.ONE * 0.1


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / DURATION, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.5, radius, t)
	_material.albedo_color = Color(color, 0.35 * (1.0 - t))
	if t >= 1.0:
		queue_free()
