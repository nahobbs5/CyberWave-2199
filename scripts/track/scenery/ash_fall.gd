class_name AshFall
extends Node3D
## Falling volcanic ash (Nyiragongo, GDD 8.6h): grey flakes drifting down
## round every chase camera, so each split-screen view has its own. One
## CPUParticles3D per camera (Compatibility and web friendly), emitting in a
## box around the camera with world-space particles, so flakes stay put as
## the camera moves through them. Purely visual.

## Flakes alive per camera at once.
@export var amount: int = 700
## Size of the box round the camera that flakes appear in (m).
@export var box: Vector3 = Vector3(70, 30, 70)
@export var color: Color = Color(0.62, 0.6, 0.58, 0.85)
@export var fall_speed: float = 1.6
## Sideways drift (wind), m/s.
@export var wind: Vector3 = Vector3(0.9, 0.0, 0.4)

## Camera -> its emitter.
var _emitters: Dictionary = {}
var _mesh: QuadMesh
var _scan: float = 0.0


func _ready() -> void:
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _flake_texture()
	_mesh.material = mat


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_sync_cameras()
	for cam: Node3D in _emitters:
		if is_instance_valid(cam):
			(_emitters[cam] as CPUParticles3D).global_position = cam.global_position


## Emitters currently following cameras (tests).
func emitter_count() -> int:
	return _emitters.size()


func _sync_cameras() -> void:
	for cam in _emitters.keys():
		if not is_instance_valid(cam) or not (cam as Node).is_inside_tree():
			var old := _emitters[cam] as CPUParticles3D
			if is_instance_valid(old):
				old.queue_free()
			_emitters.erase(cam)
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"chase_cameras"):
		var cam := node as Node3D
		if cam != null and not _emitters.has(cam):
			var p := _make_emitter()
			add_child(p)
			p.global_position = cam.global_position
			p.emitting = true
			_emitters[cam] = p


func _make_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = box.y / fall_speed
	p.preprocess = p.lifetime
	p.local_coords = false
	p.mesh = _mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.direction = Vector3(wind.x, -fall_speed, wind.z).normalized()
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = fall_speed * 0.7
	p.initial_velocity_max = fall_speed * 1.3
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color = color
	# Flakes fade in and out at the ends of their lives.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.15, color)
	ramp.add_point(0.85, color)
	p.color_ramp = ramp
	return p


## A soft, slightly ragged grey flake.
static func _flake_texture() -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a := clampf(1.0 - d * d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
