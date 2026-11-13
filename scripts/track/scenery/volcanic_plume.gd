class_name VolcanicPlume
extends CPUParticles3D
## A towering column of gas and steam off a lava lake (Nyiragongo, GDD 8.6h):
## big soft billboard puffs that rise, swell and lean downwind, glowing
## orange where the lava lights them from below and turning grey-white
## higher up. Visual only. Place it on a vent; set height and wind before
## adding it to the tree.

## How high the column climbs before it fades (m).
@export var height: float = 220.0
## Downwind drift at the top of the column (m/s, horizontal).
@export var wind: Vector3 = Vector3(2.5, 0.0, 1.0)
@export var rise_speed: float = 6.0
@export var puff_size: float = 26.0

static var _puff_material: StandardMaterial3D


func _ready() -> void:
	if _puff_material == null:
		_puff_material = StandardMaterial3D.new()
		_puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff_material.vertex_color_use_as_albedo = true
		_puff_material.albedo_texture = _puff_texture()
		_puff_material.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * puff_size
	quad.material = _puff_material
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = 70
	lifetime = height / rise_speed
	preprocess = lifetime
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = puff_size * 0.6
	direction = Vector3.UP
	spread = 8.0
	initial_velocity_min = rise_speed * 0.8
	initial_velocity_max = rise_speed * 1.2
	# The wind bends the column over as it climbs.
	gravity = wind / maxf(lifetime * 0.5, 1.0)
	damping_min = 0.0
	damping_max = 0.2
	angular_velocity_min = -6.0
	angular_velocity_max = 6.0
	scale_amount_min = 0.7
	scale_amount_max = 1.2
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.5))
	swell.add_point(Vector2(1.0, 3.2))
	scale_amount_curve = swell
	# Lava-lit orange at the vent, grey-white above, fading out at the top.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.45, 0.18, 0.0))
	ramp.set_color(1, Color(0.5, 0.48, 0.48, 0.0))
	ramp.add_point(0.05, Color(1.0, 0.52, 0.25, 0.55))
	ramp.add_point(0.25, Color(0.85, 0.62, 0.5, 0.45))
	ramp.add_point(0.6, Color(0.66, 0.63, 0.62, 0.32))
	color_ramp = ramp
	emitting = true


## Soft, lumpy puff (radial falloff broken up by noise).
static func _puff_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.09
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var n := noise.get_noise_2d(x, y) * 0.35
			var a := clampf(1.0 - smoothstep(0.35, 1.0, d + n), 0.0, 1.0)
			var shade := 0.85 + noise.get_noise_2d(x + 40, y) * 0.15
			img.set_pixel(x, y, Color(shade, shade, shade, a * 0.9))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
