extends Node3D
## Free-drive sandbox (Practice): one car, no race rules.
## Wires the track, car, camera and HUD, using the selected vehicle and its
## cosmetics. The track is GameSession.practice_track (picked on the
## Practice screen); the scene's own TestCircuit is swapped out for any other.
## Esc returns to the main menu. A full lap of the developer track
## (UnlockCatalog.PRACTICE_LAP_TRACK) unlocks its car: the game pauses on the
## CAR UNLOCKED screen and Continue drives on.

@onready var track: TrackCircuit = $TestCircuit
@onready var car: VehicleController = $PlayerCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: PrototypeHUD = $PrototypeHUD
var minimap: Minimap


func _ready() -> void:
	InputSetup.ensure_actions()
	_use_practice_track()
	Music.play(get_tree(), TrackCatalog.music("Test Circuit"))
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
	hud.lap_completed.connect(_on_lap_completed)
	_add_minimap()
	HudScaler.apply(hud, GameSettings.hud_scale)
	if GameSettings.motion_blur:
		var blur := SpeedBlur.new()
		blur.vehicle = car
		add_child(blur)


## The Practice-lap car unlock (GDD 9.1a).
func _on_lap_completed(_lap: int, lap_time: float) -> void:
	if GameSession.practice_track != UnlockCatalog.PRACTICE_LAP_TRACK:
		return
	var profile := PlayerProfile.get_profile()
	if not profile.unlock_vehicle(UnlockCatalog.PRACTICE_LAP_UNLOCK):
		return
	profile.save()
	get_tree().paused = true
	CarUnlockScreen.show_cards(self, [{
		"vehicle": UnlockCatalog.PRACTICE_LAP_UNLOCK,
		"line1": "%s · Practice" % UnlockCatalog.PRACTICE_LAP_TRACK,
		"line2": "Lap completed in %s" % RaceProgress.format_time(lap_time),
	}], _resume)


## Back to driving after the CAR UNLOCKED screen.
func _resume() -> void:
	get_tree().paused = false
	ResultsScreen.set_race_sfx_muted(false)
	Music.play(get_tree(), TrackCatalog.music("Test Circuit"))


## Replaces the built-in Test Circuit with the chosen practice track.
func _use_practice_track() -> void:
	var path := TrackCatalog.scene_path(GameSession.practice_track)
	if path == track.scene_file_path:
		return
	var old := track
	# The loading screen may have built it already, in steps.
	track = LoadingScreen.take_track(path)
	if track == null:
		track = (load(path) as PackedScene).instantiate() as TrackCircuit
	remove_child(old)
	old.free()
	add_child(track)
	move_child(track, 0)


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
