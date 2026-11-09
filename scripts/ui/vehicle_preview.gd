class_name VehiclePreview
extends SubViewportContainer
## Rotating 3D vehicle preview for the garage, race setup and split-screen
## car select (GDD 11.3, 11.4). Shows the placeholder car with a vehicle's
## proportions, a cosmetic loadout and the license plate on a glowing
## turntable inside a neon garage ("reference files/Cyberwave 2199 Neon
## Garage.png"): a roll-up door with a big CW-2199 stencil, neon tubes, a
## checkered floor, ceiling lights and (detail FULL) tool chests, tyre stacks
## and a flags banner. The car spins slowly by itself; drag it with the mouse
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

## FULL: the whole garage. LITE (small split-screen cards): no props or
## banner and fewer lights.
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

var car: VehicleController

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
	_pivot.rotation.y = START_YAW
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


## Re-aims the camera after changing view_offset or zoom.
func place_camera() -> void:
	if _camera == null:
		return
	var flat := Vector3(CAMERA_POS.x, 0.0, CAMERA_POS.z) * zoom
	_camera.position = Vector3(flat.x, CAMERA_POS.y + 0.35 * (zoom - 1.0), flat.z)
	_camera.look_at(LOOK_AT)
	_camera.h_offset = view_offset.x
	_camera.v_offset = view_offset.y


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

	var wall_mat := WeaponManager.glow_material(Color(0.15, 0.1, 0.27), 0.0)
	_box(Vector3(0, ROOM_FLOOR + 5.0, -6.1), Vector3(30, 10, 0.1), wall_mat)
	for side in [-1.0, 1.0]:
		var wall := _box(Vector3(side * 9.0, ROOM_FLOOR + 5.0, -1.0), Vector3(0.1, 10, 14), wall_mat)
		wall.rotation_degrees.y = side * 25.0
	_box(Vector3(0, ROOM_FLOOR + 5.6, -1.0), Vector3(30, 0.1, 14), WeaponManager.glow_material(Color(0.03, 0.02, 0.06), 0.0))
	# Ceiling light panels.
	for x in ([-3.2, 3.2] if full else [0.0]):
		_box(Vector3(x, ROOM_FLOOR + 5.5, -2.6), Vector3(2.2, 0.06, 0.7), WeaponManager.glow_material(Color(0.85, 0.82, 1.0), 2.5))

	# Roll-up door: ribs, a glowing frame and the CW-2199 stencil.
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.2, 0.15, 0.32)
	rib_mat.metallic = 0.6
	rib_mat.roughness = 0.45
	for i in 11:
		_box(Vector3(0, ROOM_FLOOR + 0.22 + i * 0.4, -5.98), Vector3(7.0, 0.34, 0.08), rib_mat)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 3.65, ROOM_FLOOR + 2.3, -5.95), Vector3(0.1, 4.6, 0.1), WeaponManager.glow_material(UIStyle.MAGENTA, 3.0))
	_box(Vector3(0, ROOM_FLOOR + 4.65, -5.95), Vector3(7.4, 0.1, 0.1), WeaponManager.glow_material(Color(0.6, 0.3, 1.0), 3.0))
	var stencil := Label3D.new()
	stencil.text = "CW-2199"
	stencil.font = UIStyle.heading_font()
	stencil.font_size = 240
	stencil.pixel_size = 0.011
	stencil.modulate = Color(0.62, 0.58, 0.85, 0.32)
	stencil.outline_size = 0
	stencil.shaded = false
	stencil.position = Vector3(0, ROOM_FLOOR + 2.7, -5.9)
	_room.add_child(stencil)

	# Neon tubes and strips on the back and side walls.
	for spec in [[-5.2, UIStyle.MAGENTA], [5.2, UIStyle.CYAN], [-7.4, UIStyle.CYAN], [7.4, UIStyle.MAGENTA]]:
		_box(Vector3(spec[0], ROOM_FLOOR + 2.6, -6.0), Vector3(0.12, 3.4, 0.12), WeaponManager.glow_material(spec[1], 3.0))
	for spec in [[-6.3, 4.4, UIStyle.MAGENTA], [6.3, 4.1, UIStyle.CYAN]]:
		_box(Vector3(spec[0], ROOM_FLOOR + spec[1], -6.0), Vector3(1.6, 0.08, 0.08), WeaponManager.glow_material(spec[2], 4.0))

	if full:
		_tool_chest(Vector3(-6.2, 0, -4.9), UIStyle.MAGENTA)
		_tool_chest(Vector3(6.3, 0, -4.8), UIStyle.CYAN)
		_tyres(Vector3(-4.6, 0, -4.9), 4)
		_tyres(Vector3(4.5, 0, -5.0), 3)
		_tyres(Vector3(5.3, 0, -4.4), 2)
		_banner(Vector3(-2.3, ROOM_FLOOR + 3.4, -5.85))

	# Turntable: dark base, glowing magenta side band, dark top with rings.
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.06, 0.04, 0.1)
	base_mat.metallic = 0.5
	base_mat.roughness = 0.3
	_disc(TABLE_RADIUS + 0.12, 0.08, ROOM_FLOOR + 0.04, base_mat)
	_disc(TABLE_RADIUS + 0.03, 0.1, ROOM_FLOOR + 0.13, WeaponManager.glow_material(UIStyle.MAGENTA, 3.2))
	_disc(TABLE_RADIUS, 0.06, FLOOR_Y - 0.03, base_mat)
	_ring(TABLE_RADIUS - 0.12, 0.025, Color(0.9, 0.85, 1.0), 1.6, FLOOR_Y + 0.005)
	_ring(TABLE_RADIUS - 0.55, 0.035, UIStyle.CYAN, 2.0, FLOOR_Y + 0.005)
	_ring(TABLE_RADIUS + 0.55, 0.02, UIStyle.MAGENTA.darkened(0.2), 1.2, ROOM_FLOOR + 0.01)


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


## Two stacked roller chests with glowing drawer lines (pos.y is ignored).
func _tool_chest(pos: Vector3, accent: Color) -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.1, 0.07, 0.16)
	body.metallic = 0.5
	body.roughness = 0.4
	var line := WeaponManager.glow_material(accent, 3.5)
	_box(Vector3(pos.x, ROOM_FLOOR + 0.6, pos.z), Vector3(1.8, 1.2, 0.8), body)
	_box(Vector3(pos.x, ROOM_FLOOR + 1.55, pos.z - 0.05), Vector3(1.6, 0.7, 0.65), body)
	for i in 4:
		var y := ROOM_FLOOR + 0.25 + i * 0.3 + (0.25 if i == 3 else 0.0)
		_box(Vector3(pos.x, y, pos.z + 0.41), Vector3(1.5, 0.04, 0.02), line)


## A stack of tyres (pos.y is ignored).
func _tyres(pos: Vector3, count: int) -> void:
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.045, 0.06)
	rubber.roughness = 0.75
	for i in count:
		var m := MeshInstance3D.new()
		var tyre := CylinderMesh.new()
		tyre.top_radius = 0.42
		tyre.bottom_radius = 0.42
		tyre.height = 0.3
		tyre.radial_segments = 20
		m.mesh = tyre
		m.material_override = rubber
		m.position = Vector3(pos.x + (0.04 if i % 2 == 1 else 0.0), ROOM_FLOOR + 0.15 + i * 0.31, pos.z)
		_room.add_child(m)


## A purple hanging banner with crossed checkered flags.
func _banner(pos: Vector3) -> void:
	var cloth := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 2.2)
	cloth.mesh = quad
	cloth.material_override = WeaponManager.glow_material(Color(0.32, 0.12, 0.5), 0.6)
	cloth.position = pos
	_room.add_child(cloth)
	var flags := MeshInstance3D.new()
	var face := QuadMesh.new()
	face.size = Vector2(1.2, 1.2)
	flags.mesh = face
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = UIStyle.icon_texture("flags", 128, Color(0.85, 0.8, 1.0))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flags.material_override = mat
	flags.position = pos + Vector3(0, 0.25, 0.02)
	_room.add_child(flags)
	_box(pos + Vector3(0, 1.12, 0.02), Vector3(1.8, 0.05, 0.05), WeaponManager.glow_material(UIStyle.MAGENTA, 3.0))


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
