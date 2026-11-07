extends Node3D
## Free-drive sandbox (Phase 1 prototype): one car, no race rules.
## Wires the track, car, camera and HUD, using the selected vehicle and its
## cosmetics. Esc returns to the main menu.

@onready var track: TrackCircuit = $TestCircuit
@onready var car: VehicleController = $PlayerCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: PrototypeHUD = $PrototypeHUD
var minimap: Minimap


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.stop(get_tree())
	var profile := PlayerProfile.get_profile()
	var vehicle := VehicleCatalog.by_id(profile.selected_vehicle)
	car.set_stats(vehicle.stats)
	VehicleCosmetics.apply(car, vehicle, profile.loadout_for(vehicle.id), profile.plate_text)
	car.set_visual_scale(VehicleController.TRACK_VISUAL_SCALE)
	var spawn := track.get_spawn_transform()
	car.global_transform = spawn
	car.recovery.set_track(track, track.get_spawn_offset())
	camera.set_target(car)
	hud.setup(car, camera, track)
	_add_minimap()
	HudScaler.apply(hud, GameSettings.hud_scale)
	if GameSettings.motion_blur:
		var blur := SpeedBlur.new()
		blur.vehicle = car
		add_child(blur)


## Practice minimap, bottom right like in races: the track and your car.
func _add_minimap() -> void:
	var anchor := Control.new()
	anchor.name = "MinimapAnchor"
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(anchor)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.position = -Minimap.MAP_SIZE - Vector2(20, 20)
	anchor.add_child(minimap)
	minimap.setup_track(track, car)


func _unhandled_input(event: InputEvent) -> void:
	# No pause menu in the sandbox: Esc / Start goes back to the main menu.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameSession.to_main_menu(get_tree())
