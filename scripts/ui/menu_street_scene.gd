class_name MenuStreetScene
extends SubViewportContainer
## Live 3D backdrop for the start menus, laid out after "reference files/
## Cyberwave 2199 Racing Menu.png": a wet night street running into a neon
## skyline with a big magenta sun, an elevated highway curving off on the
## right, chevron signs, and the player's garage car (with its cosmetics and
## plate) parked on the right, seen from behind at three-quarters with its
## tail lights glowing. Built in code in its own small world; display only.

const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"
const WINDOW_SHADER := preload("res://assets/shaders/city_windows.gdshader")
const SUN_SHADER := preload("res://assets/shaders/menu_sun.gdshader")
## The car's origin sits this high above the road (its wheels hang below).
const RIDE_HEIGHT := 0.72
const CAMERA_POS := Vector3(1.0, 1.0, 8.0)
const CAMERA_TARGET := Vector3(-1.0, 1.5, -30.0)
## Number of moving light streaks on the highway.
const HIGHWAY_TRAFFIC := 10

var car: VehicleController
var camera: Camera3D

var _viewport: SubViewport
var _vehicle_id: String = ""
var _time: float = 0.0
## Highway curve control points (quadratic Bezier) and its traffic.
var _hw: Array[Vector3] = [Vector3(46, 8, 8), Vector3(12, 8, -26), Vector3(34, 8, -130)]
var _traffic: Array[MeshInstance3D] = []
var _traffic_t: Array[float] = []


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_build_environment()
	_build_sun()
	_build_skyline()
	_build_road()
	_build_highway()
	_build_signs()
	_build_car()
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 800.0
	_viewport.add_child(camera)
	_place_camera()
	refresh_car()


## The vehicle id the parked car is showing.
func vehicle_id() -> String:
	return _vehicle_id


## Puts the garage's selected car, its equipped cosmetics and the plate on
## the parked car.
func refresh_car() -> void:
	if car == null:
		return
	var profile := PlayerProfile.get_profile()
	var vehicle := VehicleCatalog.by_id(profile.selected_vehicle)
	if vehicle == null:
		return
	VehicleCosmetics.apply(car, vehicle, profile.loadout_for(vehicle.id), profile.plate_text)
	_vehicle_id = vehicle.id


func _process(delta: float) -> void:
	_time += delta
	_place_camera()
	for i in _traffic.size():
		_traffic_t[i] = fposmod(_traffic_t[i] + delta * (0.05 if i % 2 == 0 else -0.04), 1.0)
		var t := _traffic_t[i]
		var p := _bezier(t)
		var lane := 1.8 if i % 2 == 0 else -1.8
		var side := _bezier_tangent(t).cross(Vector3.UP).normalized()
		_traffic[i].position = p + side * lane + Vector3(0, 0.7, 0)
		_traffic[i].look_at(_traffic[i].position + _bezier_tangent(t), Vector3.UP)


## A slow drift so the shot doesn't look like a still.
func _place_camera() -> void:
	if camera == null:
		return
	var sway := Vector3(sin(_time * 0.21) * 0.25, sin(_time * 0.33) * 0.06, cos(_time * 0.17) * 0.2)
	camera.position = CAMERA_POS + sway
	camera.look_at(CAMERA_TARGET + Vector3(sway.x * 3.0, 0, 0), Vector3.UP)


# --- world -------------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.01, 0.1)
	sky_mat.sky_horizon_color = Color(0.4, 0.06, 0.38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.01, 0.0, 0.03)
	sky_mat.ground_horizon_color = Color(0.25, 0.04, 0.25)
	sky_mat.sun_angle_max = 0.0
	sky_mat.sun_curve = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.3, 0.6)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 0.85
	# Screen-space reflections only exist on Forward+ (desktop); the web's
	# Compatibility renderer gets painted streaks instead (see _build_car).
	if _forward_plus():
		e.ssr_enabled = true
		e.ssr_max_steps = 48
	e.fog_enabled = true
	e.fog_light_color = Color(0.3, 0.06, 0.32)
	e.fog_density = 0.0045
	e.fog_sky_affect = 0.0
	env.environment = e
	_viewport.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, -150, 0)
	moon.light_color = Color(0.6, 0.5, 1.0)
	moon.light_energy = 0.35
	_viewport.add_child(moon)
	var lights := [
		# position, colour, energy, range
		[Vector3(9, 5, -12), UIStyle.MAGENTA, 3.0, 22.0],
		[Vector3(-9, 4, -8), UIStyle.CYAN, 2.2, 18.0],
		[Vector3(-3, 3, 5), Color(0.75, 0.7, 1.0), 1.2, 9.0], # soft fill on the car from the camera side
	]
	for l in lights:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = l[3]
		_viewport.add_child(o)


func _build_sun() -> void:
	var sun := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(230, 230)
	sun.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SUN_SHADER
	sun.material_override = mat
	sun.position = Vector3(30, 48, -400)
	_viewport.add_child(sun)


func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	var towers: Array[Array] = [] # [center, size]
	# Far skyline (crosses the road's end), mid blocks either side, and a
	# close wall of buildings down the left like the reference.
	for i in 70:
		var x := rng.randf_range(-220.0, 220.0)
		var size := Vector3(rng.randf_range(10, 24), rng.randf_range(24, 80), rng.randf_range(10, 24))
		towers.append([Vector3(x, 0, rng.randf_range(-300.0, -190.0)), size])
	for i in 44:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(30.0, 140.0)
		var size := Vector3(rng.randf_range(8, 18), rng.randf_range(16, 55), rng.randf_range(8, 18))
		towers.append([Vector3(x, 0, rng.randf_range(-170.0, -70.0)), size])
	var z := 12.0
	while z > -50.0:
		var depth := rng.randf_range(9, 16)
		var size := Vector3(rng.randf_range(10, 16), rng.randf_range(16, 34), depth)
		towers.append([Vector3(-16.0 - size.x * 0.5, 0, z - depth * 0.5), size])
		z -= depth + rng.randf_range(1.5, 5.0)
	z = -24.0
	while z > -90.0:
		var depth := rng.randf_range(10, 18)
		var size := Vector3(rng.randf_range(12, 20), rng.randf_range(14, 36), depth)
		towers.append([Vector3(rng.randf_range(52.0, 66.0), 0, z - depth * 0.5), size])
		z -= depth + rng.randf_range(3.0, 8.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = towers.size()
	for i in towers.size():
		var c: Vector3 = towers[i][0]
		var s: Vector3 = towers[i][1]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), c + Vector3(0, s.y * 0.5, 0)))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.2, 0.7), 0, 0))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = WINDOW_SHADER
	inst.material_override = mat
	_viewport.add_child(inst)

	# Neon trims: roof edges, corner strips and the odd vertical sign.
	var strips: Array[Array] = [] # [center, size, colour]
	for i in towers.size():
		var c: Vector3 = towers[i][0]
		var s: Vector3 = towers[i][1]
		var col := UIStyle.MAGENTA if rng.randf() < 0.55 else UIStyle.CYAN
		var roll := rng.randf()
		if roll < 0.35:
			strips.append([c + Vector3(0, s.y, s.z * 0.5), Vector3(s.x, 0.35, 0.3), col])
		elif roll < 0.55:
			strips.append([c + Vector3(s.x * 0.5, s.y * 0.5, s.z * 0.5), Vector3(0.3, s.y, 0.3), col])
		if rng.randf() < 0.3:
			strips.append([c + Vector3(rng.randf_range(-0.3, 0.3) * s.x, s.y + 6.0, 0), Vector3(0.4, 12.0, 0.4), Color(1, 0.3, 0.4)])
	# Tall vertical signs on the close left wall, facing the road.
	for i in 6:
		var sz := 8.0 - i * 9.0
		strips.append([Vector3(-15.8, 8.0 + rng.randf_range(-2, 3), sz), Vector3(0.3, rng.randf_range(6, 12), 1.6),
				UIStyle.MAGENTA if i % 2 == 0 else Color(1.0, 0.4, 0.75)])
	_add_glow_boxes(strips, 3.0)


func _build_road() -> void:
	var road := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 340)
	road.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.02, 0.06)
	mat.metallic = 0.65
	mat.roughness = 0.12
	road.material_override = mat
	road.position = Vector3(0, 0, -150)
	_viewport.add_child(road)
	# Pavements either side.
	var walk_mat := StandardMaterial3D.new()
	walk_mat.albedo_color = Color(0.05, 0.035, 0.09)
	walk_mat.roughness = 0.35
	walk_mat.metallic = 0.4
	for side in [-1.0, 1.0]:
		var walk := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(40, 0.25, 340)
		walk.mesh = box
		walk.material_override = walk_mat
		walk.position = Vector3(side * (8.5 + 20.0), 0.12, -150)
		_viewport.add_child(walk)
	var strips: Array[Array] = []
	# Curbs: cyan on the left, magenta on the right.
	strips.append([Vector3(-8.5, 0.27, -150), Vector3(0.18, 0.06, 340), UIStyle.CYAN])
	strips.append([Vector3(8.5, 0.27, -150), Vector3(0.18, 0.06, 340), UIStyle.MAGENTA])
	# Centre dashes.
	var dz := 14.0
	while dz > -320.0:
		strips.append([Vector3(-2.2, 0.01, dz), Vector3(0.14, 0.02, 3.0), Color(0.75, 0.7, 1.0)])
		dz -= 9.0
	_add_glow_boxes(strips, 1.8)


func _build_highway() -> void:
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.05, 0.03, 0.09)
	deck_mat.roughness = 0.5
	var segments := 40
	var strips: Array[Array] = []
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a := _bezier(t0)
		var b := _bezier(t1)
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + 0.2
		var deck := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(10.0, 0.9, length)
		deck.mesh = box
		deck.material_override = deck_mat
		_viewport.add_child(deck)
		deck.look_at_from_position(mid, mid + (b - a), Vector3.UP)
		var side := (b - a).cross(Vector3.UP).normalized()
		for s in [-1.0, 1.0]:
			var rail: Vector3 = mid + side * s * 5.0 + Vector3(0, 0.75, 0)
			strips.append([rail, Vector3(0.25, 0.25, length), UIStyle.MAGENTA if s > 0 else Color(1.0, 0.45, 0.85), (b - a)])
		if i % 4 == 0:
			var pillar := MeshInstance3D.new()
			var col := BoxMesh.new()
			col.size = Vector3(1.6, mid.y, 1.6)
			pillar.mesh = col
			pillar.material_override = deck_mat
			pillar.position = Vector3(mid.x, mid.y * 0.5 - 0.4, mid.z)
			_viewport.add_child(pillar)
	_add_glow_boxes(strips, 3.2)
	var light_mat := WeaponManager.glow_material(Color(1.0, 0.85, 0.95), 1.6)
	var tail_mat := WeaponManager.glow_material(Color(1.0, 0.15, 0.4), 1.8)
	for i in HIGHWAY_TRAFFIC:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.25, 1.6)
		m.mesh = box
		m.material_override = light_mat if i % 2 == 0 else tail_mat
		_viewport.add_child(m)
		_traffic.append(m)
		_traffic_t.append(float(i) / HIGHWAY_TRAFFIC)


func _build_signs() -> void:
	var left := _chevron_texture(-1)
	var right := _chevron_texture(1)
	# [texture, position, size, yaw degrees]
	var signs := [
		[left, Vector3(13.0, 3.0, -26.0), Vector2(5.5, 1.6), -20.0],
		[left, Vector3(19.0, 3.4, -40.0), Vector2(5.0, 1.45), -30.0],
		[right, Vector3(-4.0, 1.2, -34.0), Vector2(4.4, 1.3), 0.0],
		[left, Vector3(5.5, 1.1, -48.0), Vector2(4.4, 1.3), 0.0],
	]
	for s in signs:
		var board := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = s[2]
		board.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.01, 0.06)
		mat.emission_enabled = true
		mat.emission_texture = s[0]
		mat.emission = Color.WHITE
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = 2.4
		board.material_override = mat
		board.position = s[1]
		board.rotation_degrees.y = s[3]
		_viewport.add_child(board)
	# A glowing billboard on the left block, part-way down the street.
	var billboard := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(9.0, 5.5)
	billboard.mesh = bq
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color.BLACK
	bmat.emission_enabled = true
	bmat.emission_texture = _billboard_texture()
	bmat.emission = Color.WHITE
	bmat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	bmat.emission_energy_multiplier = 2.0
	billboard.material_override = bmat
	billboard.position = Vector3(-15.6, 10.0, -40.0)
	billboard.rotation_degrees.y = 70.0
	_viewport.add_child(billboard)


func _build_car() -> void:
	car = (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
	# Display only: no physics, input, AI or effects.
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.player_controlled = false
	car.is_player = false
	car.position = Vector3(3.0, RIDE_HEIGHT, -1.5)
	# Nose angled off to the left, so the camera sees the rear and left side.
	car.rotation.y = 0.42
	_viewport.add_child(car)
	for child in car.get_children():
		if child.name.begins_with("Wheel"):
			var pivot := child.get_node_or_null("Pivot") as Node3D
			if pivot != null:
				pivot.position.y = -0.38
	# Red spill from the tail lights onto the wet road behind the car.
	var tail := OmniLight3D.new()
	tail.light_color = Color(1.0, 0.1, 0.3)
	tail.light_energy = 2.5
	tail.omni_range = 6.0
	tail.position = Vector3(0, -0.2, 2.9)
	car.add_child(tail)
	# Reflections drawn in by hand where there's no screen-space reflection
	# (the Compatibility renderer used on the web).
	if not _forward_plus():
		for x in [-0.6, 0.6]:
			var streak := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.5, 2.8)
			streak.mesh = q
			var smat := StandardMaterial3D.new()
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smat.albedo_color = Color(1.0, 0.1, 0.35, 0.35)
			streak.material_override = smat
			streak.rotation_degrees.x = -90.0
			streak.position = Vector3(x, -RIDE_HEIGHT + 0.02, 3.8)
			car.add_child(streak)


# --- helpers -----------------------------------------------------------------

static func _forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


## Glowing boxes in one MultiMesh. Each entry: [centre, size, colour] and an
## optional forward direction to turn the box along.
func _add_glow_boxes(boxes: Array[Array], energy: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = boxes.size()
	for i in boxes.size():
		var b: Array = boxes[i]
		var basis := Basis.from_scale(b[1])
		if b.size() > 3:
			var fwd: Vector3 = (b[3] as Vector3).normalized()
			basis = Basis.looking_at(fwd, Vector3.UP) * Basis.from_scale(b[1])
		mm.set_instance_transform(i, Transform3D(basis, b[0]))
		mm.set_instance_color(i, b[2])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
uniform float energy = 3.0;
void fragment() { ALBEDO = COLOR.rgb * energy; }
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("energy", energy)
	inst.material_override = mat
	_viewport.add_child(inst)


func _bezier(t: float) -> Vector3:
	var u := 1.0 - t
	return _hw[0] * u * u + _hw[1] * 2.0 * u * t + _hw[2] * t * t


func _bezier_tangent(t: float) -> Vector3:
	return ((_hw[1] - _hw[0]) * (1.0 - t) + (_hw[2] - _hw[1]) * t).normalized()


## A road sign of three neon chevrons pointing left (-1) or right (1).
static func _chevron_texture(direction: int) -> Texture2D:
	var w := 256
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var col := Color(1.0, 0.3, 0.85)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := INF
			for k in 3:
				var cx := 70.0 + k * 58.0
				var tip := Vector2(cx + 22.0 * direction, h * 0.5)
				var top := Vector2(cx - 14.0 * direction, 10.0)
				var bottom := Vector2(cx - 14.0 * direction, h - 10.0)
				d = minf(d, minf(UIStyle._segment_distance(p, top, tip), UIStyle._segment_distance(p, tip, bottom)))
			var line := clampf(7.0 - d, 0.0, 1.0)
			var glow := clampf(1.0 - d / 16.0, 0.0, 1.0) * 0.35
			var frame := 1.0 if x < 3 or x >= w - 3 or y < 3 or y >= h - 3 else 0.0
			var c := col * maxf(line, glow)
			c = c.lerp(col, frame * 0.8)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return ImageTexture.create_from_image(img)


## The billboard: a cyan-to-magenta gradient screen with a bright frame and
## a few horizontal scan bars.
static func _billboard_texture() -> Texture2D:
	var w := 160
	var h := 100
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := float(x) / w
			var c := UIStyle.CYAN.lerp(UIStyle.MAGENTA, t) * (0.35 + 0.25 * float(y) / h)
			if y % 12 < 2:
				c = c * 1.6
			if x < 3 or x >= w - 3 or y < 3 or y >= h - 3:
				c = Color(1.0, 0.6, 0.95)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return ImageTexture.create_from_image(img)
