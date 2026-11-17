class_name HoloDecoy
extends Node3D
## Holo Decoy (GDD 6.3): a hologram clone of its owner's car that rides
## behind and to one side of it for the weapon's lifetime. Targeted attacks
## aimed at the owner go for the clone instead (Hunter Drone and Swarm Bots
## home on it, Railguns aim at and hit it); the first one pops it. The
## Hunter-Killer isn't fooled. Child of the WeaponManager, so it can lag
## behind the car smoothly.

const SHADER := preload("res://assets/shaders/holo_decoy.gdshader")
const GROUP := &"holo_decoys"
## Where the clone rides relative to the car (car space: +z is behind).
const BEHIND := 5.5
const SIDE := 2.6
## Hits within this radius of the clone hit the clone (m).
const HIT_RADIUS := 1.9
const FADE_IN := 0.3
const FADE_OUT := 0.5

var manager: WeaponManager
var owner_car: VehicleController
var lifetime: float = 8.0
var color: Color = Color(0.2, 0.85, 1.0)

var _age: float = 0.0
var _popped: bool = false
var _side: float = 1.0
var _material: ShaderMaterial


func _ready() -> void:
	add_to_group(GROUP)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("color", color)
	_material.set_shader_parameter("alpha", 0.0)
	_material.set_shader_parameter("steady", 1.0 if GameSettings.reduced_flashing else 0.0)
	if owner_car != null:
		_build_clone()
		global_transform = _goal_transform()
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(0.0, 1.0, 0.0)
	add_child(light)


## Copies the car's drawn body and wheels as hologram geometry.
func _build_clone() -> void:
	var body := owner_car.get_node_or_null("Body") as Node3D
	if body != null:
		var copy := body.duplicate(0) as Node3D
		add_child(copy)
		copy.transform = body.transform
		_holo(copy)
	for child in owner_car.get_children():
		if child is RayCast3D:
			var pivot := child.get_node_or_null("Pivot") as Node3D
			if pivot == null:
				continue
			var wheel := pivot.duplicate(0) as Node3D
			add_child(wheel)
			wheel.transform = owner_car.global_transform.affine_inverse() * pivot.global_transform
			_holo(wheel)


## Strips lights, particles and sounds and gives every mesh the hologram look.
func _holo(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D or child is GPUParticles3D or child is CPUParticles3D \
				or child is AudioStreamPlayer3D or child is Label3D:
			child.free()
			continue
		_holo(child)
	if node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		geo.material_override = _material
		geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Which side of the car it rides on (+1 right, -1 left).
func set_side(side: float) -> void:
	_side = signf(side) if side != 0.0 else 1.0


func is_live() -> bool:
	return not _popped and not is_queued_for_deletion()


func _goal_transform() -> Transform3D:
	var car_xf := owner_car.global_transform
	var fwd := -car_xf.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var sway := sin(_age * 1.3) * 0.5
	var pos := car_xf.origin - fwd * BEHIND + right * (SIDE + sway) * _side
	return Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)


func _physics_process(delta: float) -> void:
	_age += delta
	if owner_car == null or not is_instance_valid(owner_car) or _age >= lifetime:
		_fade_away()
		return
	if _popped:
		return
	var goal := _goal_transform()
	var t := clampf(delta * 10.0, 0.0, 1.0)
	global_transform = Transform3D(global_transform.basis.orthonormalized().slerp(goal.basis, t),
			global_position.lerp(goal.origin, t))
	var fade := minf(_age / FADE_IN, 1.0) * clampf((lifetime - _age) / FADE_OUT, 0.0, 1.0)
	_material.set_shader_parameter("alpha", fade)


## Hit by an attack meant for its owner: bursts and vanishes.
func pop() -> void:
	if _popped:
		return
	_popped = true
	if manager != null:
		manager.spawn_arc_burst(global_position + Vector3.UP * 0.6, color)
		manager.spawn_flash(global_position + Vector3.UP * 0.6, color)
	queue_free()


func _fade_away() -> void:
	_popped = true
	queue_free()
