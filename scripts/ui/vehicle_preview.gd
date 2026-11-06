class_name VehiclePreview
extends SubViewportContainer
## Rotating 3D vehicle preview for the garage and race setup (GDD 11.3,
## 11.4). Shows the placeholder car with a vehicle's proportions, a cosmetic
## loadout and the license plate on a neon showroom platform, in its own
## small lit world. The car spins slowly by itself; drag it with the mouse
## (or the right stick) to turn it by hand, and the spin resumes shortly after.

const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"
## Radians of turn per pixel dragged.
const DRAG_SPEED := 0.012
## Radians per second at full right-stick tilt.
const STICK_SPEED := 2.6
const STICK_DEADZONE := 0.2
## Seconds after a manual turn before the auto-spin picks up again.
const RESUME_DELAY := 1.5
const FLOOR_Y := -0.72
## Opening angle: a front three-quarter view, like the reference art.
const START_YAW := 4.45

## Radians per second while nobody is turning it.
@export var spin_speed: float = 0.5

var car: VehicleController

var _viewport: SubViewport
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
	var camera := Camera3D.new()
	camera.position = Vector3(6.0, 1.9, 6.0)
	camera.fov = 36.0
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, -0.3, 0.0))
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
	environment.ambient_light_color = Color(0.35, 0.3, 0.5)
	environment.ambient_light_energy = 0.55
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.9
	environment.ssr_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.04, 0.2)
	environment.fog_density = 0.035
	env.environment = environment
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 35, 0)
	key.light_energy = 1.2
	key.light_color = Color(0.85, 0.85, 1.0)
	_viewport.add_child(key)
	for side in [-1.0, 1.0]:
		var rim := OmniLight3D.new()
		rim.position = Vector3(side * 4.0, 2.2, -2.0 * side)
		rim.light_color = UIStyle.CYAN if side < 0.0 else UIStyle.MAGENTA
		rim.light_energy = 2.6
		rim.omni_range = 9.0
		_viewport.add_child(rim)
	# Soft fill from the camera side so dark paints still read.
	var fill := OmniLight3D.new()
	fill.position = Vector3(4.5, 2.5, 4.5)
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 1.6
	fill.omni_range = 12.0
	_viewport.add_child(fill)
	# Magenta glow spilling up from the platform ring.
	var ring_light := OmniLight3D.new()
	ring_light.position = Vector3(0.0, FLOOR_Y + 0.3, 0.0)
	ring_light.light_color = UIStyle.MAGENTA
	ring_light.light_energy = 1.2
	ring_light.omni_range = 5.0
	_viewport.add_child(ring_light)


func _build_showroom() -> void:
	# Wet-look floor so the neon catches on it.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.03, 0.02, 0.06)
	floor_mat.metallic = 0.3
	floor_mat.roughness = 0.38
	floor_mesh.material_override = floor_mat
	floor_mesh.position.y = FLOOR_Y - 0.03
	_viewport.add_child(floor_mesh)

	# Turntable platform with a glowing magenta rim and a thin cyan inner ring.
	var platform := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.3
	disc.bottom_radius = 3.4
	disc.height = 0.06
	disc.radial_segments = 64
	platform.mesh = disc
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.06, 0.03, 0.1)
	platform_mat.metallic = 0.5
	platform_mat.roughness = 0.25
	platform.material_override = platform_mat
	platform.position.y = FLOOR_Y
	_viewport.add_child(platform)
	_ring(3.38, 0.06, UIStyle.MAGENTA, 2.2)
	_ring(2.85, 0.02, UIStyle.CYAN, 1.4)
	_ring(3.75, 0.015, UIStyle.MAGENTA.darkened(0.2), 1.0)

	# Back wall behind the car (the camera sits at +X +Z looking at the
	# origin), with neon strips and a faint stencilled "CW-2199".
	var backdrop := Node3D.new()
	backdrop.position = Vector3(-7.5, FLOOR_Y, -7.5)
	backdrop.rotation_degrees.y = 45.0
	_viewport.add_child(backdrop)
	var wall := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 16)
	wall.mesh = quad
	wall.material_override = WeaponManager.glow_material(Color(0.05, 0.025, 0.09), 0.0)
	wall.position.y = 8.0
	backdrop.add_child(wall)
	var bars := [
		# x, y, width, height, colour
		[-7.0, 4.6, 3.2, 0.12, UIStyle.MAGENTA],
		[-2.0, 5.3, 2.4, 0.10, UIStyle.CYAN],
		[3.5, 4.8, 3.6, 0.12, UIStyle.MAGENTA],
		[8.0, 5.6, 2.0, 0.10, UIStyle.CYAN],
		[-4.5, 1.4, 0.10, 1.6, UIStyle.MAGENTA],
		[6.0, 1.6, 0.10, 1.8, UIStyle.CYAN],
	]
	for b in bars:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(b[2], b[3], 0.05)
		bar.mesh = box
		bar.material_override = WeaponManager.glow_material(b[4], 4.0)
		bar.position = Vector3(b[0], b[1], 0.05)
		backdrop.add_child(bar)
	var stencil := Label3D.new()
	stencil.text = "CW-2199"
	stencil.font = UIStyle.heading_font()
	stencil.font_size = 220
	stencil.pixel_size = 0.012
	stencil.modulate = Color(0.55, 0.5, 0.75, 0.16)
	stencil.outline_size = 0
	stencil.shaded = false
	stencil.position = Vector3(2.5, 3.0, 0.06)
	backdrop.add_child(stencil)


## A glowing flat ring on the floor.
func _ring(radius: float, thickness: float, color: Color, energy: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = WeaponManager.glow_material(color, energy)
	ring.scale.y = 0.5
	ring.position.y = FLOOR_Y + 0.035
	_viewport.add_child(ring)
