extends SceneTree
## Audio headless checks: menu music carries across the main menu, race
## setup and settings without restarting, the garage switches to its own
## theme and back, races stop the music, and the countdown beep plays on the
## SFX bus. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_audio.gd

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const RACE_SETUP := "res://scenes/menu/race_setup.tscn"
const GARAGE := "res://scenes/menu/garage.tscn"
const SETTINGS := "res://scenes/menu/settings_menu.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_audio_profile.json"
	GameSettings.path = "user://test_audio_settings.cfg"
	Championship.save_path = "user://test_audio_gp.json"
	_run_all.call_deferred()


func _run_all() -> void:
	GameSession.scene_changes_enabled = false
	print("- menu music")
	await _open(MAIN_MENU)
	var player := Music.get_player()
	_check(Music.current_path() == Music.MENU and player != null, "main menu plays the main theme")
	_check(player != null and player.is_inside_tree() and player.bus == &"Music", "one music player on the Music bus")
	_check(player != null and player.playing, "it's playing")
	var stream := player.stream if player != null else null
	_check(stream is AudioStreamMP3 and (stream as AudioStreamMP3).loop, "the main theme loops")
	await _open(RACE_SETUP)
	_check(Music.get_player() == player and player.stream == stream and player.playing, "race setup keeps the same song going")
	await _open(SETTINGS)
	_check(player.stream == stream and player.playing, "settings keeps it going too")
	await _open(GARAGE)
	_check(Music.current_path() == Music.GARAGE, "garage switches to Wings of Hope")
	_check(player.stream is AudioStreamMP3 and player.stream.resource_path == Music.GARAGE and player.playing
			and (player.stream as AudioStreamMP3).loop, "garage theme playing and looping")
	await _open(MAIN_MENU)
	_check(Music.current_path() == Music.MENU and player.stream == stream, "back to the main theme")

	print("- race")
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	root.add_child(race)
	race.camera.save_preference = false
	await process_frame
	_check(Music.current_path() == "", "a race stops the menu music")
	var beep := race.countdown_sound
	_check(beep != null and beep.bus == &"SFX", "countdown sound on the SFX bus")
	_check(race.state == RaceManager.State.COUNTDOWN and beep.playing, "it plays during the countdown")
	await _seconds(1.2)
	_check(not player.playing, "the music has faded out")
	race.queue_free()
	await process_frame

	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s" % message)


## Opens a menu scene the way a scene change would, then lets fades finish.
func _open(path: String) -> void:
	for child in root.get_children():
		if child is Control:
			child.queue_free()
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await _seconds(1.0)


func _seconds(s: float) -> void:
	await create_timer(s).timeout
