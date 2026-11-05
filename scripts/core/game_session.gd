class_name GameSession
extends RefCounted
## Carries the chosen race settings across scene changes (static, so no
## autoload is needed) and moves between the menus and the race. The race scene reads `current` when it starts; when
## it's null (e.g. race.tscn run directly from the editor) the Race node's own
## exports are used instead.

const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const RACE_SETUP_SCENE := "res://scenes/menu/race_setup.tscn"
const GARAGE_SCENE := "res://scenes/menu/garage.tscn"
const SETTINGS_SCENE := "res://scenes/menu/settings_menu.tscn"
const FREE_DRIVE_SCENE := "res://scenes/free_drive.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"

static var current: RaceConfig
## Mode the race setup screen opens with.
static var setup_mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
## Headless tests turn this off so menu buttons don't change scene.
static var scene_changes_enabled: bool = true


static func start_race(tree: SceneTree, config: RaceConfig) -> void:
	current = config
	_change(tree, RACE_SCENE)


static func to_main_menu(tree: SceneTree) -> void:
	_change(tree, MAIN_MENU_SCENE)


static func to_race_setup(tree: SceneTree, mode: RaceConfig.Mode) -> void:
	setup_mode = mode
	_change(tree, RACE_SETUP_SCENE)


static func to_garage(tree: SceneTree) -> void:
	_change(tree, GARAGE_SCENE)


static func to_settings(tree: SceneTree) -> void:
	_change(tree, SETTINGS_SCENE)


static func to_free_drive(tree: SceneTree) -> void:
	_change(tree, FREE_DRIVE_SCENE)


static func _change(tree: SceneTree, path: String) -> void:
	tree.paused = false
	if scene_changes_enabled:
		tree.change_scene_to_file.call_deferred(path)
