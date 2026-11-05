extends Node3D
## Free-drive sandbox (Phase 1 prototype): one car, no race rules.
## Wires the track, car, camera and HUD, using the selected vehicle and its
## cosmetics. Esc returns to the main menu.

@onready var track: TrackCircuit = $TestCircuit
@onready var car: VehicleController = $PlayerCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: PrototypeHUD = $PrototypeHUD


func _ready() -> void:
	InputSetup.ensure_actions()
	var profile := PlayerProfile.get_profile()
	var vehicle := VehicleCatalog.by_id(profile.selected_vehicle)
	car.set_stats(vehicle.stats)
	VehicleCosmetics.apply(car, vehicle, profile.loadout_for(vehicle.id), profile.plate_text)
	var spawn := track.get_spawn_transform()
	car.global_transform = spawn
	car.recovery.set_track(track, track.get_spawn_offset())
	camera.set_target(car)
	hud.setup(car, camera, track)
	HudScaler.apply(hud, GameSettings.hud_scale)
	if GameSettings.motion_blur:
		var blur := SpeedBlur.new()
		blur.vehicle = car
		add_child(blur)


func _unhandled_input(event: InputEvent) -> void:
	# No pause menu in the sandbox: Esc / Start goes back to the main menu.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameSession.to_main_menu(get_tree())
