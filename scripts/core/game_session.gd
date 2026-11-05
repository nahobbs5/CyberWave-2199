class_name GameSession
extends RefCounted
## Carries the chosen race settings across scene changes (static, so no
## autoload is needed). The race scene reads `current` when it starts; when
## it's null (e.g. race.tscn run directly from the editor) the Race node's own
## exports are used instead.

const MODE_SELECT_SCENE := "res://scenes/menu/mode_select.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"

static var current: RaceConfig
## Headless tests turn this off so menu buttons don't change scene.
static var scene_changes_enabled: bool = true


static func start_race(tree: SceneTree, config: RaceConfig) -> void:
	current = config
	_change(tree, RACE_SCENE)


static func to_mode_select(tree: SceneTree) -> void:
	_change(tree, MODE_SELECT_SCENE)


static func _change(tree: SceneTree, path: String) -> void:
	tree.paused = false
	if scene_changes_enabled:
		tree.change_scene_to_file.call_deferred(path)
