class_name PodiumStage
extends MenuStreetScene
## The podium ceremony's 3D world, after "reference files/Neon Grand Prix
## Victory Podium.png": the start menus' night street (sun, skyline,
## highway) with three neon platforms on the road: gold 1st in the middle,
## silver 2nd on the left, magenta 3rd on the right. The top three's cars
## drive in, their platforms rise, a crown drops over the winner and
## spotlights sweep. Everything is posed from one number (set_progress), so
## skipping to the end is exact. Display only.

## Platform centres by place (index 0 = 1st).
const SPOTS: Array[Vector3] = [Vector3(0.0, 0.0, -7.0), Vector3(-5.0, 0.0, -6.0), Vector3(5.0, 0.0, -6.0)]
const HEIGHTS: Array[float] = [1.7, 1.25, 1.0]
const RADIUS := 2.35
## Platform top while the cars drive on (just above the road).
const LOW := 0.14
## Final car headings: noses towards the camera, angled in a little.
const YAWS: Array[float] = [PI + 0.18, PI - 0.3, PI + 0.3]
const PLACE_COLORS: Array[Color] = [Color(1.0, 0.78, 0.18), Color(0.72, 0.8, 1.0), Color(1.0, 0.25, 0.85)]
## How far down the street the cars start.
const RUN_IN := 34.0

const WIDE_POS := Vector3(0.0, 3.7, 13.5)
const WIDE_TARGET := Vector3(0.0, 1.4, -6.5)
const CLOSE_POS := Vector3(0.5, 3.2, 6.8)
const CLOSE_TARGET := Vector3(0.0, 2.3, -6.8)

## Racers on the podium, best first: {name, look (RaceManager.racer_look)}.
var entries: Array = []
## Grand Prix: the longer, bigger ceremony.
var grand: bool = false
## Seconds into the ceremony (see set_progress).
var progress: float = 0.0

var cars: Array[VehicleController] = []
## The rising part of each platform, by place.
var platforms: Array[Node3D] = []
var crown: Node3D
var spotlights: Array[SpotLight3D] = []
var beams: Array[MeshInstance3D] = []

var _podium_root: Node3D


## Phase ends in seconds: [cars parked, platforms up, celebration over, total].
static func timeline(p_grand: bool) -> Array[float]:
	if p_grand:
		return [3.5, 8.5, 11.5, 13.5]
	return [3.5, 7.5, 9.5, 11.0]


func setup(p_entries: Array, p_grand: bool) -> void:
	entries = p_entries
	grand = p_grand
	if _viewport != null:
		_build_podium()
		set_progress(progress)


func duration() -> float:
	return timeline(grand)[3]


## World point at the front of place `i`'s platform, just under its top
## edge (where its name tag goes).
func tag_anchor(i: int) -> Vector3:
	var top := platforms[i].position.y if i < platforms.size() else 0.0
	return SPOTS[i] + Vector3(0.0, top - 0.02, RADIUS)


## Screen position (in this control's pixels) of a world point.
func screen_point(world: Vector3) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	var p := camera.unproject_position(world)
	var vp := Vector2(_viewport.size)
	return p * (size / vp) if vp.x > 0.0 and vp.y > 0.0 else p


## Height of place `i`'s platform top at time t.
func platform_top(i: int, t: float) -> float:
	var tl := timeline(grand)
	# 3rd rises first, then 2nd, then 1st.
	var order := 2 - i
	var span := (tl[1] - tl[0]) / 3.0
	var start := tl[0] + order * span * 0.85
	var k := clampf((t - start) / (span * 1.3), 0.0, 1.0)
	return lerpf(LOW, HEIGHTS[i], _ease_out_back(k) if k < 1.0 else 1.0)


## Has place `i`'s platform finished rising?
func is_risen(i: int, t: float = progress) -> bool:
	return is_equal_approx(platform_top(i, t), HEIGHTS[i])


## Poses every part for `t` seconds into the ceremony.
func set_progress(t: float) -> void:
	progress = t
	var tl := timeline(grand)
	for i in platforms.size():
		var top := platform_top(i, t)
		platforms[i].position.y = top
		if i >= cars.size():
			continue
		# Drive in down the street, staggered, easing to a stop on the platform.
		var start := 0.15 * (2 - i)
		var k := clampf((t - start) / maxf(tl[0] - start, 0.01), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var car := cars[i]
		car.position = SPOTS[i] + Vector3(0.0, top + RIDE_HEIGHT, -RUN_IN * (1.0 - e))
		car.rotation.y = lerp_angle(PI, YAWS[i], smoothstep(0.6, 1.0, k))
	if crown != null:
		var drop := clampf((t - tl[1]) / 0.8, 0.0, 1.0)
		crown.visible = t >= tl[1] and not cars.is_empty()
		var rest := crown_rest()
		crown.position = rest + Vector3(0.0, 7.0 * (1.0 - _ease_out_bounce(drop)), 0.0)
	var lit := t >= tl[1]
	for s in spotlights:
		s.visible = lit
	for b in beams:
		b.visible = lit
	_aim_spotlights()
	_place_camera()


## Where the crown floats over the winner's car.
func crown_rest() -> Vector3:
	return SPOTS[0] + Vector3(0.0, HEIGHTS[0] + RIDE_HEIGHT + 1.75, 0.0)


func _process(delta: float) -> void:
	super(delta)
	if crown != null and crown.visible:
		crown.rotation.y += delta * 0.8
		var tl := timeline(grand)
		if progress >= tl[1] + 0.8:
			crown.position.y = crown_rest().y + sin(_time * 2.0) * 0.08
	_aim_spotlights()


func _place_camera() -> void:
	if camera == null:
		return
	# Wide shot, then a slow push in towards the winner.
	var k := smoothstep(0.1, 1.0, progress / duration()) if duration() > 0.0 else 1.0
	var sway := Vector3(sin(_time * 0.21) * 0.15, sin(_time * 0.33) * 0.05, 0.0)
	camera.position = WIDE_POS.lerp(CLOSE_POS, k) + sway
	camera.look_at(WIDE_TARGET.lerp(CLOSE_TARGET, k), Vector3.UP)


# --- building -----------------------------------------------------------------

## The menu street's parked car is replaced by the podium.
func _build_car() -> void:
	_build_podium()


func _build_podium() -> void:
	if _podium_root != null:
		_podium_root.queue_free()
	cars.clear()
	platforms.clear()
	spotlights.clear()
	beams.clear()
	crown = null
	_podium_root = Node3D.new()
	_podium_root.name = "Podium"
	_viewport.add_child(_podium_root)
	# Key light on the cars from the camera side.
	var key := OmniLight3D.new()
	key.light_color = Color(0.85, 0.8, 1.0)
	key.light_energy = 1.6
	key.omni_range = 16.0
	key.position = Vector3(0.0, 6.0, 1.0)
	_podium_root.add_child(key)
	for i in 3:
		_build_platform(i)
	for i in mini(entries.size(), 3):
		_build_podium_car(i, entries[i])
	_build_crown()
	_build_spotlights()


func _build_platform(i: int) -> void:
	var color := PLACE_COLORS[i]
	var h := HEIGHTS[i]
	# A glowing ring on the road around the platform's foot (fixed).
	var foot := MeshInstance3D.new()
	var foot_mesh := CylinderMesh.new()
	foot_mesh.top_radius = RADIUS + 0.22
	foot_mesh.bottom_radius = RADIUS + 0.22
	foot_mesh.height = 0.06
	foot_mesh.cap_top = false
	foot_mesh.cap_bottom = false
	foot.mesh = foot_mesh
	foot.material_override = WeaponManager.glow_material(color, 1.4)
	foot.position = SPOTS[i] + Vector3(0, 0.03, 0)
	_podium_root.add_child(foot)
	# The rising part: its origin is the platform top, the body hangs below
	# it (through the road while it's lowered).
	var top := Node3D.new()
	top.name = "Platform%d" % (i + 1)
	top.position = SPOTS[i] + Vector3(0, LOW, 0)
	_podium_root.add_child(top)
	platforms.append(top)
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = RADIUS
	body_mesh.bottom_radius = RADIUS
	body_mesh.height = h
	body_mesh.radial_segments = 48
	body.mesh = body_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.55)
	mat.metallic = 0.7
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.12
	body.material_override = mat
	body.position.y = -h * 0.5
	top.add_child(body)
	for y in [-0.04, -h + 0.18]:
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = RADIUS + 0.05
		rim_mesh.bottom_radius = RADIUS + 0.05
		rim_mesh.height = 0.08
		rim_mesh.cap_top = false
		rim_mesh.cap_bottom = false
		rim_mesh.radial_segments = 48
		rim.mesh = rim_mesh
		rim.material_override = WeaponManager.glow_material(color.lightened(0.15), 1.6)
		rim.position.y = y
		top.add_child(rim)
	# Big place number on the front face.
	var number := Label3D.new()
	number.text = str(i + 1)
	number.font = UIStyle.slanted_font(true)
	number.font_size = 160
	number.pixel_size = 0.0032
	number.modulate = color.lightened(0.25)
	number.outline_modulate = color.darkened(0.5)
	number.outline_size = 18
	number.shaded = false
	number.position = Vector3(0, -(h * 0.5 + 0.2), RADIUS + 0.02)
	top.add_child(number)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 0.5
	glow.omni_range = 4.0
	glow.position = Vector3(0, 0.6, RADIUS * 0.6)
	top.add_child(glow)


func _build_podium_car(i: int, entry: Dictionary) -> void:
	var car := (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
	# Display only: no physics, input, AI or effects.
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.player_controlled = false
	car.is_player = false
	car.name = "PodiumCar%d" % (i + 1)
	_podium_root.add_child(car)
	for child in car.get_children():
		if child.name.begins_with("Wheel"):
			var pivot := child.get_node_or_null("Pivot") as Node3D
			if pivot != null:
				pivot.position.y = -0.38
	var look: Dictionary = entry.get("look", {})
	if not look.is_empty():
		RaceManager.apply_look(car, look)
	cars.append(car)


## A gold crown: band, five spikes with gems, and a soft halo of rays.
func _build_crown() -> void:
	crown = Node3D.new()
	crown.name = "Crown"
	crown.visible = false
	crown.scale = Vector3.ONE * 1.3
	_podium_root.add_child(crown)
	var gold := WeaponManager.glow_material(Color(1.0, 0.75, 0.2), 1.6)
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.52
	band_mesh.bottom_radius = 0.46
	band_mesh.height = 0.32
	band_mesh.cap_top = false
	band_mesh.cap_bottom = false
	band.mesh = band_mesh
	band.material_override = gold
	crown.add_child(band)
	var gem_colors := [UIStyle.CYAN, UIStyle.MAGENTA]
	for k in 5:
		var a := TAU * k / 5.0
		var dir := Vector3(sin(a), 0, cos(a))
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.15
		cone.height = 0.5
		cone.radial_segments = 8
		spike.mesh = cone
		spike.material_override = gold
		spike.position = dir * 0.48 + Vector3(0, 0.38, 0)
		crown.add_child(spike)
		var tip := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		tip.mesh = ball
		tip.material_override = WeaponManager.glow_material(Color(1.0, 0.95, 0.7), 2.5)
		tip.position = dir * 0.48 + Vector3(0, 0.66, 0)
		crown.add_child(tip)
		var gem := MeshInstance3D.new()
		var gem_ball := SphereMesh.new()
		gem_ball.radius = 0.08
		gem_ball.height = 0.16
		gem.mesh = gem_ball
		gem.material_override = WeaponManager.glow_material(gem_colors[k % 2], 3.0)
		gem.position = dir * 0.53
		crown.add_child(gem)
	var halo := Sprite3D.new()
	halo.texture = _halo_texture()
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.pixel_size = 0.018
	halo.modulate = Color(1.0, 0.8, 0.3, 0.8)
	halo.shaded = false
	halo.position = Vector3(0, 0.2, -0.3)
	halo.render_priority = -1
	crown.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 2.0
	light.omni_range = 5.0
	crown.add_child(light)


## Spotlights on poles behind and beside the podium, with visible beams.
func _build_spotlights() -> void:
	var count := 4 if grand else 2
	var spots: Array[Vector3] = [Vector3(-9.0, 10.0, -12.0), Vector3(9.0, 10.0, -12.0),
			Vector3(-6.0, 9.0, 4.0), Vector3(6.0, 9.0, 4.0)]
	var colors: Array[Color] = [UIStyle.CYAN, UIStyle.MAGENTA, Color(1.0, 0.85, 0.5), Color(0.75, 0.6, 1.0)]
	for k in count:
		var s := SpotLight3D.new()
		s.position = spots[k]
		s.light_color = colors[k]
		s.light_energy = 6.0
		s.spot_range = 30.0
		s.spot_angle = 14.0
		s.visible = false
		_podium_root.add_child(s)
		spotlights.append(s)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.12
		cone.bottom_radius = 2.2
		cone.height = 1.0
		cone.cap_top = false
		cone.cap_bottom = false
		cone.radial_segments = 20
		beam.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(colors[k], 0.07)
		beam.material_override = mat
		beam.visible = false
		_podium_root.add_child(beam)
		beams.append(beam)


## Sweeps the spotlights over the winner (still with reduced flashing).
func _aim_spotlights() -> void:
	var calm := GameSettings.reduced_flashing
	for k in spotlights.size():
		var s := spotlights[k]
		var target := SPOTS[0] + Vector3(0.0, HEIGHTS[0] + 0.6, 0.0)
		if not calm:
			var phase := _time * (0.9 + 0.25 * k) + k * 1.7
			target += Vector3(sin(phase) * 3.0, 0.0, cos(phase * 0.7) * 1.5)
		s.basis = Basis.looking_at(target - s.position, Vector3.UP)
		var beam := beams[k]
		var along := s.position - target
		var length := along.length()
		var up := along / length
		var side := up.cross(Vector3.FORWARD)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var basis := Basis(side, up, side.cross(up)).orthonormalized()
		beam.transform = Transform3D(basis.scaled(Vector3(1.0, length, 1.0)), (s.position + target) * 0.5)


# --- helpers ------------------------------------------------------------------

static var _halo: Texture2D


## Soft gold glow with rays, for behind the crown.
static func _halo_texture() -> Texture2D:
	if _halo != null:
		return _halo
	var side := 128
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var c := Vector2(side, side) * 0.5
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length() / (side * 0.5)
			var glow := clampf(1.0 - r, 0.0, 1.0)
			var rays := pow(absf(cos(d.angle() * 6.0)), 6.0) * clampf(1.0 - r, 0.0, 1.0)
			var a := clampf(glow * glow * 0.8 + rays * 0.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_halo = ImageTexture.create_from_image(img)
	return _halo


static func _ease_out_back(k: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)


static func _ease_out_bounce(k: float) -> float:
	var n := 7.5625
	var d := 2.75
	if k < 1.0 / d:
		return n * k * k
	if k < 2.0 / d:
		k -= 1.5 / d
		return n * k * k + 0.75
	if k < 2.5 / d:
		k -= 2.25 / d
		return n * k * k + 0.9375
	k -= 2.625 / d
	return n * k * k + 0.984375
