class_name GameSession
extends RefCounted
## Carries the chosen race settings across scene changes (static, so no
## autoload is needed) and moves between the menus and the race. The race scene reads `current` when it starts; when
## it's null (e.g. race.tscn run directly from the editor) the Race node's own
## exports are used instead.

const TITLE_SCENE := "res://scenes/menu/title_menu.tscn"
const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
## Split screen, step 1 of 3: connect controllers.
const MULTIPLAYER_SCENE := "res://scenes/menu/multiplayer_connect.tscn"
## Step 2: each player picks a car (with its stats).
const MP_CARS_SCENE := "res://scenes/menu/multiplayer_cars.tscn"
## Step 3: mode and race settings.
const MP_SETUP_SCENE := "res://scenes/menu/multiplayer_setup.tscn"
const RACE_SETUP_SCENE := "res://scenes/menu/race_setup.tscn"
const GARAGE_SCENE := "res://scenes/menu/garage.tscn"
const SETTINGS_SCENE := "res://scenes/menu/settings_menu.tscn"
const CREDITS_SCENE := "res://scenes/menu/credits.tscn"
const CUP_SELECT_SCENE := "res://scenes/menu/cup_select.tscn"
const TRACK_SELECT_SCENE := "res://scenes/menu/track_select.tscn"
const FREE_DRIVE_SCENE := "res://scenes/free_drive.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
## Scenes that build a track on load; they open behind a LoadingScreen.
const SLOW_SCENES: Array[String] = [RACE_SCENE, FREE_DRIVE_SCENE]

static var current: RaceConfig
## Mode the race setup screen opens with.
static var setup_mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
## The cup picked on the cup screen (a GrandPrixData path), and in Versus the
## track picked from it. Empty = the race setup screen uses the remembered one.
static var cup_path: String = ""
static var track_name: String = ""
## Split screen: the lobby's players and settings. Cup / track select start
## the race themselves while this is on, and leaving a race returns to the
## lobby. Off = single player.
static var split_screen: bool = false
## Split screen: one input device per player (-1 = keyboard, else gamepad id)
## and each player's vehicle id.
static var mp_devices: PackedInt32Array = PackedInt32Array()
static var mp_vehicles: PackedStringArray = PackedStringArray()
## Split screen: each player's license plate (set on the car screen).
static var mp_plates: PackedStringArray = PackedStringArray()
## Split screen settings chosen in the lobby.
static var mp_settings: Dictionary = {"ai": true, "difficulty": 1, "laps": 2, "weapons": true}
## Versus: every setting but the track (set on the race setup screen, or
## the split-screen setup screen). The track screen adds the track.
static var versus_template: RaceConfig
## Versus series of more than one race (Mario Kart style), null otherwise.
## The track screen picks each race's track for it.
static var series: Championship
## Where Settings / Credits go back to (the title or the single-player menu).
static var menu_return: String = TITLE_SCENE
## Headless tests turn this off so menu buttons don't change scene.
static var scene_changes_enabled: bool = true


static func start_race(tree: SceneTree, config: RaceConfig) -> void:
	current = config
	_change(tree, RACE_SCENE)


## The single-player menu.
static func to_main_menu(tree: SceneTree) -> void:
	split_screen = false
	menu_return = MAIN_MENU_SCENE
	_change(tree, MAIN_MENU_SCENE)


## The first menu: Single Player / Multiplayer / Settings.
static func to_title(tree: SceneTree) -> void:
	split_screen = false
	menu_return = TITLE_SCENE
	_change(tree, TITLE_SCENE)


## Split screen step 1: connect controllers.
static func to_multiplayer(tree: SceneTree) -> void:
	split_screen = true
	series = null
	_change(tree, MULTIPLAYER_SCENE)


## Split screen step 2: car selection.
static func to_mp_cars(tree: SceneTree) -> void:
	split_screen = true
	series = null
	_change(tree, MP_CARS_SCENE)


## Split screen step 3: race settings.
static func to_mp_setup(tree: SceneTree) -> void:
	split_screen = true
	series = null
	_change(tree, MP_SETUP_SCENE)


## Leaving a race or finishing a series: car selection in split screen (the
## players stay joined), else the single-player menu.
static func to_menu(tree: SceneTree) -> void:
	series = null
	if split_screen:
		to_mp_cars(tree)
	else:
		to_main_menu(tree)


## Versus: the setup is done; store it (and start a series when there's
## more than one race) and go and pick a track.
static func begin_versus(tree: SceneTree, template: RaceConfig, races: int, p_difficulty_id: String) -> void:
	versus_template = template
	series = null
	if races > 1:
		series = Championship.create_series(races, template, p_difficulty_id,
				load("res://resources/racers/rival_roster.tres") as RivalRoster)
	to_track_select(tree)


## The track screen picked `track`: the series' next race, or one race.
static func start_versus_race(tree: SceneTree, track: String) -> void:
	if series != null:
		series.add_track(track)
		start_race(tree, series.make_race_config())
		return
	var config := versus_template.duplicate() as RaceConfig if versus_template != null else RaceConfig.new()
	config.track_name = track
	config.track_scene = TrackCatalog.scene(track)
	start_race(tree, config)


## Back from the track screen: the setup it came from.
static func back_from_tracks(tree: SceneTree) -> void:
	series = null
	if split_screen:
		to_mp_setup(tree)
	else:
		to_race_setup(tree, setup_mode)


## Back from Settings / Credits.
static func back_from_options(tree: SceneTree) -> void:
	if menu_return == MAIN_MENU_SCENE:
		to_main_menu(tree)
	else:
		to_title(tree)


## Split screen: a race config from the lobby's players and settings.
static func make_multiplayer_config(mode: RaceConfig.Mode, track: String) -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.player_devices = mp_devices.duplicate()
	config.player_vehicle_ids = mp_vehicles.duplicate()
	config.player_plates = mp_plates.duplicate()
	config.ai_rivals = bool(mp_settings.get("ai", true))
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = int(mp_settings.get("laps", 2)) + 1
	config.weapons_enabled = bool(mp_settings.get("weapons", true))
	if track != "":
		config.track_name = track
		config.track_scene = TrackCatalog.scene(track)
	config.vehicle_id = mp_vehicles[0] if not mp_vehicles.is_empty() else ""
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	config.rival_vehicles = RaceConfig.random_vehicles(7)
	return config


## Split screen: a new in-memory Grand Prix (never saved to disk, so the
## single-player save stays as it is).
static func start_multiplayer_grand_prix(tree: SceneTree, cup: GrandPrixData) -> void:
	var c := Championship.create(cup, difficulty_id(), bool(mp_settings.get("weapons", true)),
			load("res://resources/racers/rival_roster.tres") as RivalRoster,
			mp_vehicles[0] if not mp_vehicles.is_empty() else PlayerProfile.DEFAULT_VEHICLE,
			mp_devices, mp_vehicles, bool(mp_settings.get("ai", true)))
	c.player_plates = mp_plates.duplicate()
	start_race(tree, c.make_race_config())


static func difficulty_id() -> String:
	return ["easy", "normal", "hard"][clampi(int(mp_settings.get("difficulty", 1)), 0, 2)]


static func to_race_setup(tree: SceneTree, mode: RaceConfig.Mode) -> void:
	setup_mode = mode
	_change(tree, RACE_SETUP_SCENE)


## Grand Prix starts here: pick a cup (Mario Kart style).
static func to_cup_select(tree: SceneTree, mode: RaceConfig.Mode) -> void:
	setup_mode = mode
	_change(tree, CUP_SELECT_SCENE)


## Versus: pick a track from every cup.
static func to_track_select(tree: SceneTree) -> void:
	_change(tree, TRACK_SELECT_SCENE)


static func to_garage(tree: SceneTree) -> void:
	_change(tree, GARAGE_SCENE)


static func to_settings(tree: SceneTree) -> void:
	_change(tree, SETTINGS_SCENE)


static func to_credits(tree: SceneTree) -> void:
	_change(tree, CREDITS_SCENE)


## Versus setup opens on the race type (Standard / Elimination) used last.
static func last_versus_mode() -> RaceConfig.Mode:
	var setup := PlayerProfile.get_profile().last_setup
	return RaceConfig.Mode.ELIMINATION if int(setup.get("race_type", 0)) == 1 else RaceConfig.Mode.VERSUS


static func to_free_drive(tree: SceneTree) -> void:
	_change(tree, FREE_DRIVE_SCENE)


static func _change(tree: SceneTree, path: String) -> void:
	tree.paused = false
	if not scene_changes_enabled:
		return
	if path in SLOW_SCENES:
		# Tracks take seconds to build: show a loading card over the wait.
		LoadingScreen.change_to(tree, path)
	else:
		tree.change_scene_to_file.call_deferred(path)
