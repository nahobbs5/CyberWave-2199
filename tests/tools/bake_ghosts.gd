extends SceneTree
## Bakes the Time Trial rival and expert ghosts (GDD 2.5) for one track (or
## every one) into resources/ghosts/. The AI drives each run alone with the
## TT rules (3 laps, 150cc, one Triple Nitro, no crates) and GhostRecorder
## records it.
##   1. Calibrate: every starter car on Hard AI. Rival target = the slowest
##      clean starter time x RIVAL_MARGIN, so a clean run in any starter car
##      can win.
##   2. Rival ghost: the rival car on Normal AI, played back to finish on the
##      rival target.
##   3. Expert ghost: the rival car on EXPERT AI (tricks, drift boosts and
##      shortcuts every time), target = its own time x EXPERT_SQUEEZE.
## A run with a recovery isn't clean and is retried with another seed.
## Run from the project root (one track per process, so they can run in
## parallel):
##   godot --headless --fixed-fps 60 -s res://tests/tools/bake_ghosts.gd -- --track="Vegas Overdrive"
##   godot --headless --fixed-fps 60 -s res://tests/tools/bake_ghosts.gd -- --track=all
## Options: --tries=N (default 3), --dry (print only, don't save).

const RACE_SCENE := "res://scenes/race/race.tscn"
const RIVAL_MARGIN := 1.02
const EXPERT_SQUEEZE := 0.97
## Longest race (s) before a run counts as stuck.
const MAX_RACE_TIME := 900.0

var _tries: int = 3
var _dry: bool = false
var _table: PackedStringArray = []


func _initialize() -> void:
	PlayerProfile.save_path = "user://bake_ghosts_profile.json"
	GameSettings.path = "user://bake_ghosts_settings.cfg"
	PlayerProfile.unlock_all_for_tests()
	GameSession.scene_changes_enabled = false
	PodiumCeremony.instant = true
	CarUnlockScreen.instant = true
	_run.call_deferred()


func _run() -> void:
	var track := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		elif arg.begins_with("--tries="):
			_tries = maxi(1, int(arg.trim_prefix("--tries=")))
		elif arg == "--dry":
			_dry = true
	if track == "":
		track = OS.get_environment("TRACK")
	var tracks: Array[String] = []
	if track == "all":
		tracks = TimeTrialCatalog.tracks()
	elif TimeTrialCatalog.has_track(track):
		tracks = [track]
	else:
		for t in TimeTrialCatalog.tracks():
			if TimeTrialCatalog.slug(t) == track:
				tracks = [t]
	if tracks.is_empty():
		printerr("Unknown track '%s'. Use --track=\"Vegas Overdrive\", a slug, or all." % track)
		quit(1)
		return
	var ok := true
	for t in tracks:
		ok = await _bake(t) and ok
	print("\ntrack | slowest starter | rival target (car, rec, scale) | expert target (rec, scale)")
	for line in _table:
		print(line)
	quit(0 if ok else 1)


func _bake(track: String) -> bool:
	var t0 := Time.get_ticks_msec()
	print("\n== %s" % track)
	var hard := load("res://resources/ai/hard.tres") as AIDifficulty
	var normal := load("res://resources/ai/normal.tres") as AIDifficulty
	var slowest := 0.0
	for id in UnlockCatalog.STARTERS:
		var run := await _clean_run(track, id, hard, 0)
		if run == null:
			printerr("  %s: no clean run" % id)
			return false
		print("  starter %-12s %s" % [id, RaceProgress.format_time(run.recorded_time)])
		slowest = maxf(slowest, run.recorded_time)
	var rival_id := TimeTrialCatalog.rival_vehicle(track)
	var rival_target := slowest * RIVAL_MARGIN
	var rival := await _clean_run(track, rival_id, normal, 1)
	if rival == null:
		printerr("  rival %s: no clean run" % rival_id)
		return false
	rival.target_time = rival_target
	var expert := await _clean_run(track, rival_id, _expert_difficulty(), 1)
	if expert == null:
		printerr("  expert %s: no clean run" % rival_id)
		return false
	expert.target_time = expert.recorded_time * EXPERT_SQUEEZE
	if expert.target_time >= rival.target_time:
		expert.target_time = rival.target_time * EXPERT_SQUEEZE
	for g in [rival, expert]:
		var scale := (g as GhostData).time_scale()
		if scale < 0.9 or scale > 1.1:
			printerr("  WARNING: %s ghost plays at %.3fx (outside 0.9-1.1; may look unnatural)" % [
					"rival" if g == rival else "expert", scale])
	_table.append("%s | %s | %s (%s, %s, %.3fx) | %s (%s, %.3fx)" % [track, RaceProgress.format_time(slowest),
			RaceProgress.format_time(rival.target_time), rival_id, RaceProgress.format_time(rival.recorded_time),
			rival.time_scale(), RaceProgress.format_time(expert.target_time),
			RaceProgress.format_time(expert.recorded_time), expert.time_scale()])
	if not _dry:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TimeTrialCatalog.ghost_dir))
		for pair in [[rival, TimeTrialCatalog.Ghost.RIVAL], [expert, TimeTrialCatalog.Ghost.EXPERT]]:
			var path := TimeTrialCatalog.ghost_path(track, pair[1])
			var err := ResourceSaver.save(pair[0], path, ResourceSaver.FLAG_COMPRESS)
			print("  saved %s (%s)" % [path, "ok" if err == OK else "error %d" % err])
	print("  %s done in %.0f s" % [track, (Time.get_ticks_msec() - t0) / 1000.0])
	return true


## Hard, plus tricks, drift boosts and shortcuts every time, and a tight line.
func _expert_difficulty() -> AIDifficulty:
	var d := (load("res://resources/ai/hard.tres") as AIDifficulty).duplicate() as AIDifficulty
	d.display_name = "Expert"
	d.drift_chance = 1.0
	d.trick_chance = 1.0
	d.shortcut_chance = 2.0
	d.line_wander = 0.15
	d.reaction_time = 0.05
	d.rocket_start_chance = 1.0
	d.burnout_chance = 0.0
	return d


## The first run without a recovery (up to _tries seeds), or null.
func _clean_run(track: String, vehicle_id: String, difficulty: AIDifficulty, slot: int) -> GhostData:
	for attempt in _tries:
		var result := await _drive(track, vehicle_id, difficulty, slot, 2199 + attempt * 7717)
		if result.data != null and int(result.recoveries) == 0:
			return result.data
		print("    %s try %d: %s" % [vehicle_id, attempt + 1, "%d recoveries" % result.recoveries if result.data != null else "didn't finish"])
	return null


func _drive(track: String, vehicle_id: String, difficulty: AIDifficulty, slot: int, seed: int) -> Dictionary:
	var config := RaceConfig.time_trial(track, TimeTrialCatalog.Ghost.NONE, vehicle_id)
	config.difficulty = difficulty
	config.start_slot = slot
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = true
	race.random_seed = seed
	root.add_child(race)
	race.camera.save_preference = false
	var recoveries := [0]
	race.player.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	while not race.player.finished and race.race_time < MAX_RACE_TIME:
		await physics_frame
	# One more step so the recorder logs the finish.
	await physics_frame
	await physics_frame
	var data: GhostData = null
	var nitros := int(race.weapon_manager.uses.get(&"triple_nitro", 0)) if race.weapon_manager != null else 0
	print("    %s: %s, %d Nitro use(s)" % [vehicle_id, RaceProgress.format_time(race.player.finish_time) if race.player.finished else "DNF", nitros])
	if race.player.finished and race.ghost_recorder.is_done():
		data = race.ghost_recorder.to_data()
		data.vehicle_id = vehicle_id
		data.color = VehicleCatalog.by_id(vehicle_id).factory_color
		data.track_name = track
	race.queue_free()
	await process_frame
	await process_frame
	return {"data": data, "recoveries": recoveries[0]}
