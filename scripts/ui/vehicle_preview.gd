class_name VehiclePreview
extends SubViewportContainer
## Rotating 3D vehicle preview for the garage and race setup (GDD 11.3,
## 11.4). Shows the placeholder car with a vehicle's proportions, a cosmetic
## loadout and the license plate, in its own small lit world.

const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"

## Radians per second; the player can't drag it yet.
@export var spin_speed: float = 0.5

var car: VehicleController

var _viewport: SubViewport
var _pivot: Node3D


func _ready() -> void:
	stretch = true
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(460, 300)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.015, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.3, 0.45)
	environment.ambient_light_energy = 0.6
	environment.glow_enabled = true
	env.environment = environment
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.4
	_viewport.add_child(key)
	for side in [-1.0, 1.0]:
		var rim := OmniLight3D.new()
		rim.position = Vector3(side * 4.0, 2.0, -2.0 * side)
		rim.light_color = UIStyle.CYAN if side < 0.0 else UIStyle.MAGENTA
		rim.light_energy = 2.5
		rim.omni_range = 9.0
		_viewport.add_child(rim)
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.4
	disc.bottom_radius = 3.4
	disc.height = 0.05
	disc.radial_segments = 48
	floor.mesh = disc
	floor.material_override = WeaponManager.glow_material(Color(0.08, 0.04, 0.14), 0.0)
	floor.position.y = -0.72
	_viewport.add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(4.6, 1.9, 4.6)
	camera.fov = 42.0
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, -0.1, 0.0))
	_pivot = Node3D.new()
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


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(delta * spin_speed)
