extends SceneTree
## Times a real race load through the loading screen, logging the bar.
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	await process_frame
	GameSession.scene_changes_enabled = true
	var name := OS.get_environment("TRACK") if OS.get_environment("TRACK") != "" else "Arashiyama Circuit"
	var config := RaceConfig.new()
	config.track_name = name
	config.track_scene = TrackCatalog.scene(name)
	GameSession.current = config
	var t0 := Time.get_ticks_msec()
	LoadingScreen.change_to(self, GameSession.RACE_SCENE)
	await process_frame
	var last := -1.0
	var last_t := t0
	while LoadingScreen.active != null:
		var p := LoadingScreen.active.get_progress()
		var now := Time.get_ticks_msec()
		if p != last:
			print("%6d ms (+%5d)  %3d%%" % [now - t0, now - last_t, int(p * 100)])
			last = p
		last_t = now
		await process_frame
	print("done in ", Time.get_ticks_msec() - t0, " ms; track=", (current_scene as RaceManager).track.scene_file_path,
		" kids=", (current_scene as RaceManager).track.get_child_count())
	quit()
