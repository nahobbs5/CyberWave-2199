class_name VehiclePreview
extends SubViewportContainer
## Rotating 3D vehicle preview for the garage, race setup and split-screen
## car select (GDD 11.3, 11.4). Shows the placeholder car with a vehicle's
## proportions, a cosmetic loadout and the license plate on a glowing
## turntable inside a neon garage ("reference files/Cyberwave 2199 Neon
## Garage New.png"): a paneled garage door with a neon world map on it
## (WorldMapBuilder: a pin on every track), a framed plate above, angled corner struts, a checkered floor, ceiling lights and (detail
## FULL) lockers, crates and a magenta / cyan glow in the back corners. The car spins slowly by itself; drag it with the mouse
## (or the right stick) to turn it by hand, and the spin resumes shortly after.

const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"
## Radians of turn per pixel dragged.
const DRAG_SPEED := 0.012
## Radians per second at full right-stick tilt.
const STICK_SPEED := 2.6
const STICK_DEADZONE := 0.2
## Seconds after a manual turn before the auto-spin picks up again.
const RESUME_DELAY := 1.5
## Top of the turntable, where the tyres sit.
const FLOOR_Y := -0.72
## The garage floor, below the turntable.
const ROOM_FLOOR := FLOOR_Y - 0.24
const TABLE_RADIUS := 3.0
## Camera spot (before zoom) and the point it looks at.
const CAMERA_POS := Vector3(5.6, 1.7, 5.6)
const LOOK_AT := Vector3(0.0, -0.2, 0.0)
## Height of the garage door (to the lip under the header band), from the room floor.
const DOOR_TOP := 3.2
## World map on the door: width (m) and centre height above the room floor;
## LITE (split-screen cards) gets a smaller one.
const MAP_WIDTH := 6.5
const MAP_Y := 1.55
const MAP_WIDTH_LITE := 5.0
const MAP_Y_LITE := 2.05

## FULL: the whole garage. LITE (small split-screen cards): no props, a
## smaller world map without its grid, no neon dashes on the sign plate,
## and fewer lights.
enum Detail { FULL, LITE }
## Opening angle: a front three-quarter view, like the reference art.
const START_YAW := 4.45

## Radians per second while nobody is turning it.
@export var spin_speed: float = 0.5
@export var detail: Detail = Detail.FULL
## Camera h_offset / v_offset in metres: +x moves the car left on screen,
## -y moves it up. The full-screen garage pushes the car to the left.
@export var view_offset: Vector2 = Vector2.ZERO
## Camera distance scale (>1 shows more of the room).
@export var zoom: float = 1.0
## Opening turn of the car (set before adding to the tree). The CAR UNLOCKED
## screen uses a rear three-quarter view.
@export var start_yaw: float = START_YAW
## Colour of the turntable's inner glow ring (set before adding to the tree).
@export var ring_color: Color = UIStyle.CYAN

var car: VehicleController
## Locked car look (set_mystery).
var mystery: bool = false

static var _silhouette: StandardMaterial3D
var _mark: Node3D

var _viewport: SubViewport
var _camera: Camera3D
var _room: Node3D
var _pivot: Node3D
var _dragging: bool = false
## Counts down after a manual turn; auto-spin waits until it reaches 0.
var _idle_timer: float = 0.0
## Eases the auto-spin back in instead of jumping to full speed.
var _spin_blend: float = 1.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = ""
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(460, 300)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_build_environment()
	_build_showroom()
	_camera = Camera3D.new()
	_camera.fov = 34.0
	_viewport.add_child(_camera)
	place_camera()
	_pivot = Node3D.new()
	_pivot.rotation.y = start_yaw
	_viewport.add_child(_pivot)
	car = (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
	# Display only: no physics, input, AI or effects.
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.player_controlled = false
	car.is_player = false
	_pivot.add_child(car)
	for child in car.get_children():
		if child.name.begins_with("Wheel"):
			var pivot := child.get_node_or_null("Pivot") as Node3D
			if pivot != null:
				pivot.position.y = -0.38


func show_vehicle(vehicle: VehicleData, loadout: Dictionary, plate_text: String) -> void:
	if car == null:
		return
	VehicleCosmetics.apply(car, vehicle, loadout, plate_text)
	if mystery:
		_apply_mystery()


## Locked car (GDD 9.1a, "reference files/Neon locked mystery car.png"): the
## car turns into a black silhouette (labels, lights and effects hidden) and a
## big glowing gold "?" stands over it, facing the camera. Stays on across
## show_vehicle until switched off.
func set_mystery(on: bool) -> void:
	mystery = on
	if car == null:
		return
	if on:
		_apply_mystery()
	else:
		_clear_mystery()


func is_mystery_shown() -> bool:
	return mystery and _mark != null and _mark.visible


func _apply_mystery() -> void:
	if _mark == null:
		_build_mystery_mark()
	_mark.visible = true
	for node in car.find_children("*", "Node3D", true, false):
		if node is Label3D or node is Light3D or node is GPUParticles3D or node is CPUParticles3D:
			if not node.has_meta(&"mystery_visible"):
				node.set_meta(&"mystery_visible", node.visible)
			node.visible = false
		elif node is GeometryInstance3D:
			var g := node as GeometryInstance3D
			if g.material_override != _silhouette_material():
				g.set_meta(&"mystery_material", g.material_override)
			g.material_override = _silhouette_material()


func _clear_mystery() -> void:
	if _mark != null:
		_mark.visible = false
	for node in car.find_children("*", "Node3D", true, false):
		if node.has_meta(&"mystery_visible"):
			node.visible = bool(node.get_meta(&"mystery_visible"))
			node.remove_meta(&"mystery_visible")
		if node.has_meta(&"mystery_material"):
			(node as GeometryInstance3D).material_override = node.get_meta(&"mystery_material") as Material
			node.remove_meta(&"mystery_material")


static func _silhouette_material() -> StandardMaterial3D:
	if _silhouette == null:
		# Unlit near-black: a flat shape with no reflections giving it away.
		_silhouette = StandardMaterial3D.new()
		_silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_silhouette.albedo_color = Color(0.02, 0.015, 0.035)
	return _silhouette


## The "?": an extruded Oxanium glyph in emissive gold with a warm light.
func _build_mystery_mark() -> void:
	_mark = Node3D.new()
	_mark.name = "MysteryMark"
	_viewport.add_child(_mark)
	var text := TextMesh.new()
	text.text = "?"
	text.font = UIStyle.heading_font()
	text.font_size = 64
	text.pixel_size = 0.026
	text.depth = 0.24
	text.curve_step = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.05)
	mat.emission_energy_multiplier = 1.4
	mat.roughness = 0.3
	mat.metallic = 0.4
	# In front of the silhouette, never hidden inside it.
	mat.no_depth_test = true
	mat.render_priority = 10
	text.material = mat
	var glyph := MeshInstance3D.new()
	glyph.name = "Glyph"
	glyph.mesh = text
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(glyph)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.75, 0.2)
	glow.light_energy = 2.5
	glow.omni_range = 4.5
	glow.position = Vector3(0.0, 0.0, 1.0)
	_mark.add_child(glow)
	_place_mystery_mark()


## Stands the "?" over the turntable centre, square to the camera.
func _place_mystery_mark() -> void:
	if _mark == null or _camera == null:
		return
	_mark.position = Vector3(0.0, FLOOR_Y + 1.15, 0.0)
	var to_cam := _camera.global_position - _mark.position if _camera.is_inside_tree() else _camera.position - _mark.position
	to_cam.y = 0.0
	if to_cam.length() > 0.01:
		_mark.basis = Basis.looking_at(-to_cam.normalized(), Vector3.UP)


## Re-aims the camera after changing view_offset or zoom.
func place_camera() -> void:
	if _camera == null:
		return
	var flat := Vector3(CAMERA_POS.x, 0.0, CAMERA_POS.z) * zoom
	_camera.position = Vector3(flat.x, CAMERA_POS.y + 0.35 * (zoom - 1.0), flat.z)
	_camera.look_at(LOOK_AT)
	_camera.h_offset = view_offset.x
	_camera.v_offset = view_offset.y
	_place_mystery_mark()


## Where the front edge of the turntable (the side facing the camera) is on
## screen, in this control's local coordinates. The LOCKED plate sits there.
func turntable_front() -> Vector2:
	if _camera == null or _viewport == null:
		return size * Vector2(0.5, 0.8)
	var to_cam := Vector3(_camera.position.x, 0.0, _camera.position.z).normalized()
	var p := _camera.unproject_position(to_cam * TABLE_RADIUS * 0.72 + Vector3(0.0, FLOOR_Y, 0.0))
	var vp := Vector2(_viewport.size)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return size * Vector2(0.5, 0.8)
	return p * size / vp


## Lights in the scene (tests: LITE uses fewer).
func light_count() -> int:
	return _viewport.find_children("*", "Light3D", true, false).size() if _viewport != null else 0


## Meshes in the room (tests: LITE uses fewer).
func room_mesh_count() -> int:
	return _room.find_children("*", "MeshInstance3D", true, false).size() if _room != null else 0


## The car's current turn on the platform (radians).
func yaw() -> float:
	return _pivot.rotation.y if _pivot != null else 0.0


## Turns the car by hand and holds the auto-spin off for a moment.
func turn(radians: float) -> void:
	if _pivot == null:
		return
	_pivot.rotate_y(radians)
	_idle_timer = RESUME_DELAY
	_spin_blend = 0.0


func is_auto_spinning() -> bool:
	return not _dragging and _idle_timer <= 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if not _dragging:
			_idle_timer = RESUME_DELAY
		accept_event()
	elif event is InputEventScreenTouch:
		_dragging = (event as InputEventScreenTouch).pressed
		if not _dragging:
			_idle_timer = RESUME_DELAY
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		turn((event as InputEventMouseMotion).relative.x * DRAG_SPEED)
		accept_event()
	elif event is InputEventScreenDrag:
		turn((event as InputEventScreenDrag).relative.x * DRAG_SPEED)
		accept_event()


func _process(delta: float) -> void:
	if _pivot == null:
		return
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) if is_visible_in_tree() else 0.0
	if absf(stick) > STICK_DEADZONE:
		turn(stick * STICK_SPEED * delta)
		return
	if _dragging:
		return
	if _idle_timer > 0.0:
		_idle_timer -= delta
		return
	_spin_blend = minf(_spin_blend + delta, 1.0)
	_pivot.rotate_y(delta * spin_speed * _spin_blend)


# --- showroom ----------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.01, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.34, 0.6)
	environment.ambient_light_energy = 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.9
	environment.ssr_enabled = detail == Detail.FULL
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.14, 0.05, 0.24)
	environment.fog_density = 0.018
	env.environment = environment
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 35, 0)
	key.light_energy = 1.1
	key.light_color = Color(0.85, 0.85, 1.0)
	_viewport.add_child(key)
	# Soft fill from the camera side so dark paints still read.
	var fill := OmniLight3D.new()
	fill.position = Vector3(4.5, 2.5, 4.5)
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 1.6
	fill.omni_range = 12.0
	_viewport.add_child(fill)
	if detail == Detail.LITE:
		return
	for side in [-1.0, 1.0]:
		var rim := OmniLight3D.new()
		rim.position = Vector3(side * 4.0, 2.2, -2.0 * side)
		rim.light_color = UIStyle.CYAN if side < 0.0 else UIStyle.MAGENTA
		rim.light_energy = 2.4
		rim.omni_range = 9.0
		_viewport.add_child(rim)
	# Magenta glow spilling up from the turntable.
	var ring_light := OmniLight3D.new()
	ring_light.position = Vector3(0.0, FLOOR_Y + 0.2, 0.0)
	ring_light.light_color = UIStyle.MAGENTA
	ring_light.light_energy = 1.2
	ring_light.omni_range = 5.0
	_viewport.add_child(ring_light)


## The garage, built in a frame turned to face the camera: local +Z points
## at the camera, the back wall is at z = -6.
func _build_showroom() -> void:
	_room = Node3D.new()
	_room.rotation_degrees.y = 45.0
	_viewport.add_child(_room)
	var full := detail == Detail.FULL

	# Glossy checkered floor so the neon catches on it.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = _checker_texture()
	floor_mat.uv1_scale = Vector3(16, 16, 1)
	floor_mat.metallic = 0.35
	floor_mat.roughness = 0.32
	floor_mesh.material_override = floor_mat
	floor_mesh.position.y = ROOM_FLOOR
	_room.add_child(floor_mesh)

	# Paneled back wall with a header band, angled side walls and a ceiling.
	var wall_mat := WeaponManager.glow_material(Color(0.13, 0.09, 0.24), 0.0)
	var seam_mat := WeaponManager.glow_material(Color(0.07, 0.05, 0.14), 0.0)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.2, 0.15, 0.34)
	trim_mat.metallic = 0.55
	trim_mat.roughness = 0.4
	_box(Vector3(0, ROOM_FLOOR + 5.0, -6.1), Vector3(30, 10, 0.1), wall_mat)
	for side in [-1.0, 1.0]:
		var wall := _box(Vector3(side * 9.0, ROOM_FLOOR + 5.0, -1.0), Vector3(0.1, 10, 14), wall_mat)
		wall.rotation_degrees.y = side * 25.0
	_box(Vector3(0, ROOM_FLOOR + 5.6, -1.0), Vector3(30, 0.1, 14), WeaponManager.glow_material(Color(0.03, 0.02, 0.06), 0.0))
	for x in ([-3.2, 3.2] if full else [0.0]):
		_box(Vector3(x, ROOM_FLOOR + 5.5, -2.6), Vector3(2.2, 0.06, 0.7), WeaponManager.glow_material(Color(0.85, 0.82, 1.0), 2.5))
	# The garage door: horizontal panel seams and vertical joints.
	var y := 0.6
	while y < DOOR_TOP:
		_box(Vector3(0, ROOM_FLOOR + y, -6.02), Vector3(11.0, 0.05, 0.04), seam_mat)
		y += 0.6
	for x in [-3.7, 3.7]:
		_box(Vector3(x, ROOM_FLOOR + DOOR_TOP * 0.5, -6.02), Vector3(0.05, DOOR_TOP, 0.04), seam_mat)
	# The world map across the door, with a pin on every track.
	var world := WorldMapBuilder.build(MAP_WIDTH if full else MAP_WIDTH_LITE, not full)
	world.position = Vector3(0, ROOM_FLOOR + (MAP_Y if full else MAP_Y_LITE), -5.97)
	_room.add_child(world)
	# Header band across the top, with a lip under it.
	_box(Vector3(0, ROOM_FLOOR + DOOR_TOP + 0.6, -5.95), Vector3(12.0, 1.1, 0.2), trim_mat)
	_box(Vector3(0, ROOM_FLOOR + DOOR_TOP, -5.85), Vector3(12.0, 0.1, 0.35), seam_mat)
	_sign_plate(Vector3(0, ROOM_FLOOR + DOOR_TOP + 0.55, -5.82))

	# Corner pillars with struts angled up into the ceiling.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 6.1, ROOM_FLOOR + 2.6, -5.8), Vector3(0.5, 5.2, 0.5), trim_mat)
		var strut := _box(Vector3(side * 5.2, ROOM_FLOOR + 4.6, -5.7), Vector3(0.35, 2.6, 0.35), trim_mat)
		strut.rotation_degrees.z = side * 40.0

	if full:
		_locker(Vector3(-7.1, 0, -5.2), UIStyle.MAGENTA)
		_locker(Vector3(7.1, 0, -5.2), UIStyle.CYAN)
		_crates(Vector3(-5.0, 0, -5.0), UIStyle.MAGENTA)
		_crates(Vector3(5.0, 0, -5.0), UIStyle.CYAN)
		# Coloured glow washing each back corner.
		for side in [-1.0, 1.0]:
			var glow := OmniLight3D.new()
			glow.position = Vector3(side * 6.4, ROOM_FLOOR + 3.6, -4.8)
			glow.light_color = UIStyle.MAGENTA if side < 0.0 else UIStyle.CYAN
			glow.light_energy = 2.2
			glow.omni_range = 5.5
			_room.add_child(glow)

	# Turntable: a glowing magenta foot, a thick magenta band and a dark top
	# with a white rim ring and an inner glow ring; a magenta ring on the floor.
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.06, 0.04, 0.1)
	base_mat.metallic = 0.5
	base_mat.roughness = 0.3
	_disc(TABLE_RADIUS + 0.3, 0.05, ROOM_FLOOR + 0.025, WeaponManager.glow_material(UIStyle.MAGENTA.darkened(0.15), 2.0))
	_disc(TABLE_RADIUS + 0.06, 0.15, ROOM_FLOOR + 0.125, WeaponManager.glow_material(UIStyle.MAGENTA, 3.4))
	_disc(TABLE_RADIUS, 0.05, FLOOR_Y - 0.025, base_mat)
	_ring(TABLE_RADIUS - 0.14, 0.045, Color(0.95, 0.92, 1.0), 2.2, FLOOR_Y + 0.005)
	_ring(TABLE_RADIUS - 0.75, 0.05, ring_color, 2.4, FLOOR_Y + 0.005)
	_ring(TABLE_RADIUS + 1.0, 0.035, UIStyle.MAGENTA, 2.0, ROOM_FLOOR + 0.01)


func _box(pos: Vector3, box_size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	m.mesh = box
	m.material_override = mat
	m.position = pos
	_room.add_child(m)
	return m


func _disc(radius: float, height: float, y: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = height
	disc.radial_segments = 64
	m.mesh = disc
	m.material_override = mat
	m.position.y = y
	_room.add_child(m)


## A glowing flat ring at height y.
func _ring(radius: float, thickness: float, color: Color, energy: float, y: float = FLOOR_Y + 0.035) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = WeaponManager.glow_material(color, energy)
	ring.scale.y = 0.5
	ring.position.y = y
	_room.add_child(ring)


## A framed plate with pointed ends above the door, a magenta dash on the
## left and a cyan one on the right (dashes in the full garage only).
func _sign_plate(pos: Vector3) -> void:
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.17, 0.12, 0.3)
	frame.metallic = 0.6
	frame.roughness = 0.35
	var face := WeaponManager.glow_material(Color(0.08, 0.06, 0.15), 0.0)
	_box(pos, Vector3(6.6, 0.62, 0.08), frame)
	for side in [-1.0, 1.0]:
		var tip := _box(pos + Vector3(side * 3.3, 0, 0), Vector3(0.44, 0.44, 0.08), frame)
		tip.rotation_degrees.z = 45.0
		if detail == Detail.LITE:
			continue
		_box(pos + Vector3(side * 2.75, 0, 0.06), Vector3(0.55, 0.05, 0.02),
				WeaponManager.glow_material(UIStyle.MAGENTA if side < 0.0 else UIStyle.CYAN, 4.0))
	_box(pos + Vector3(0, 0, 0.05), Vector3(4.2, 0.78, 0.08), frame)
	_box(pos + Vector3(0, 0, 0.1), Vector3(4.0, 0.64, 0.02), face)


## A double locker with vents and handles (pos.y is ignored).
func _locker(pos: Vector3, accent: Color) -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.09, 0.07, 0.15)
	body.metallic = 0.5
	body.roughness = 0.45
	var dark := WeaponManager.glow_material(Color(0.03, 0.02, 0.06), 0.0)
	_box(Vector3(pos.x, ROOM_FLOOR + 1.15, pos.z), Vector3(1.7, 2.3, 0.7), body)
	_box(Vector3(pos.x, ROOM_FLOOR + 1.15, pos.z + 0.36), Vector3(0.03, 2.2, 0.02), dark)
	for door in [-1.0, 1.0]:
		var x: float = pos.x + door * 0.42
		for i in 3:
			_box(Vector3(x, ROOM_FLOOR + 2.0 + i * 0.09, pos.z + 0.36), Vector3(0.55, 0.035, 0.02), dark)
		_box(Vector3(pos.x + door * 0.1, ROOM_FLOOR + 1.2, pos.z + 0.37), Vector3(0.04, 0.22, 0.03), dark)
	_box(Vector3(pos.x, ROOM_FLOOR + 2.32, pos.z + 0.36), Vector3(1.5, 0.03, 0.02), WeaponManager.glow_material(accent, 2.0))


## Two stacked crates, the lower one with a neon dash (pos.y is ignored).
func _crates(pos: Vector3, accent: Color) -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.11, 0.08, 0.18)
	body.metallic = 0.4
	body.roughness = 0.5
	_box(Vector3(pos.x, ROOM_FLOOR + 0.3, pos.z), Vector3(1.1, 0.6, 0.8), body)
	_box(Vector3(pos.x - 0.1, ROOM_FLOOR + 0.82, pos.z - 0.05), Vector3(0.9, 0.44, 0.7), body)
	_box(Vector3(pos.x, ROOM_FLOOR + 0.3, pos.z + 0.41), Vector3(0.45, 0.04, 0.02), WeaponManager.glow_material(accent, 4.0))


static var _checker: Texture2D


## Dark purple 2x2 checks for the floor.
static func _checker_texture() -> Texture2D:
	if _checker == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for y in n:
			for x in n:
				var a := (x < n / 2) == (y < n / 2)
				img.set_pixel(x, y, Color(0.07, 0.05, 0.13) if a else Color(0.16, 0.12, 0.27))
		img.generate_mipmaps()
		_checker = ImageTexture.create_from_image(img)
	return _checker
