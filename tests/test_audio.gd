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
	print("- first launch")
	# The title opens mid scene change, before the music player is in the tree.
	change_scene_to_file("res://scenes/menu/title_menu.tscn")
	await _seconds(1.0)
	_check(Music.current_path() == Music.MENU and Music.get_player() != null and Music.get_player().playing,
			"the main theme plays when the app opens")
	current_scene.queue_free()
	await process_frame
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
	_check(Music.current_path() == TrackCatalog.music("Test Circuit") and Music.current_path() != Music.MENU,
			"a race swaps the menu music for its track's song")
	var beep := race.countdown_sound
	_check(beep != null and beep.bus == &"SFX", "countdown sound on the SFX bus")
	_check(race.state == RaceManager.State.COUNTDOWN and beep.playing, "it plays during the countdown")
	await _seconds(1.2)
	_check(player.playing and player.stream.resource_path == TrackCatalog.music("Test Circuit"), "the track's song is playing")
	race.queue_free()
	await process_frame

	print("- free drive")
	var drive := (load("res://scenes/free_drive.tscn") as PackedScene).instantiate()
	root.add_child(drive)
	await _seconds(1.0)
	_check(Music.current_path() == TrackCatalog.music("Test Circuit") and player.playing, "free drive plays the Test Circuit song")
	drive.queue_free()
	await process_frame

	await _test_final_lap_music()
	_test_track_music()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s" % message)


## Final lap: the race music plays 15% faster (pitch up); not in 1-lap races.
func _test_final_lap_music() -> void:
	print("- final-lap music")
	for laps in [3, 1]:
		var config := RaceConfig.new()
		config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
		config.track_name = "Vegas Overdrive"
		config.track_scene = TrackCatalog.scene(config.track_name)
		config.total_laps = laps
		var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
		race.config = config
		root.add_child(race)
		race.camera.save_preference = false
		await _seconds(1.0)
		var music := Music.current_path()
		_check(music == TrackCatalog.music("Vegas Overdrive") and Music.get_speed() == 1.0, "%d-lap race: track music at normal speed" % laps)
		# Drive the player through every gate by hand, lap by lap.
		race.state = RaceManager.State.RACING
		var car := race.player.vehicle
		var gates := race.track.checkpoint_count
		race._on_checkpoint_crossed(0, car) # start
		for lap in laps:
			for g in range(1, gates):
				race._on_checkpoint_crossed(g, car)
			race._on_checkpoint_crossed(0, car)
			await _seconds(0.6)
			var expected := Music.FINAL_LAP_SPEED if laps > 1 and lap == laps - 2 else 1.0
			if lap < laps - 1 or laps == 1:
				_check(is_equal_approx(Music.get_speed(), expected),
						"%d-lap race after lap %d: speed %.2f (want %.2f)" % [laps, lap + 1, Music.get_speed(), expected])
		# Finished: podium, then results, both to the victory theme.
		var waited := 0.0
		while Music.current_path() != Music.VICTORY and waited < 8.0:
			await _seconds(0.25)
			waited += 0.25
		_check(Music.current_path() == Music.VICTORY, "%d-lap race: victory music after the finish" % laps)
		var ceremony := race.find_child("PodiumCeremony", true, false) as PodiumCeremony
		if ceremony != null:
			ceremony.skip()
			ceremony.finish()
			await _seconds(0.5)
		_check(race.race_hud.is_results_visible() and Music.current_path() == Music.VICTORY and Music.get_player().playing,
				"%d-lap race: victory music carries on into the results" % laps)
		race.queue_free()
		await process_frame
	await _open(MAIN_MENU)
	_check(Music.current_path() == Music.MENU and Music.get_speed() == 1.0, "back in the menus the music is at normal speed")


func _test_track_music() -> void:
	print("- track music")
	var want := {
		"Crazy House": "res://music/sonican-spooky-halloween-strange-house-420678.mp3",
		"Vatnajökull Glacier": "res://music/ed-musicproductions-besieged-castle-397025.mp3",
		"Parque Quinta Normal": "res://music/theorienvibes-to-the-moon-and-back-232892.mp3",
		"Gardens by the Bay": "res://music/elisaveta_stoycheva-garden-fairytale-368607.mp3",
		"Vale da Lua": "res://music/restum-anoush-rise-of-the-phoenix-265090.mp3",
		"Choquequirao": "res://music/desifreemusic-epic-victory-march-for-heroes-triumph-amp-celebration-462007.mp3",
		"Test Circuit": "res://music/stageechoesmusic-the-garden-wakes-628640.mp3",
	}
	for track in want:
		_check(TrackCatalog.music(track) == want[track] and ResourceLoader.exists(want[track]), "%s has its music" % track)
	_check(ResourceLoader.exists(Music.VICTORY), "victory theme exists")
	# The web build drops the .mp3s and plays music/web/<name>.ogg copies.
	var songs: Array[String] = [Music.MENU, Music.GARAGE, Music.VICTORY]
	for track in TrackCatalog.names():
		if TrackCatalog.music(track) != "":
			songs.append(TrackCatalog.music(track))
	var missing: Array[String] = []
	for song in songs:
		var web := song.replace("res://music/", "res://music/web/").get_basename() + ".ogg"
		if not (load(web) is AudioStreamOggVorbis):
			missing.append(web.get_file())
	_check(missing.is_empty(), "every song has a web .ogg copy (missing: %s)" % [missing])


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
