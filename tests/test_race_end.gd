extends SceneTree
## The race ends when all but one car have finished: the last car is placed
## last without crossing the line (not in Elimination). Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_race_end.gd

const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_race_end_profile.json"
	GameSettings.path = "user://test_race_end_settings.cfg"
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_last_ai()
	await _test_last_player()
	await _test_split_screen()
	await _test_elimination()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _config(mode := RaceConfig.Mode.VERSUS) -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	return config


func _start(config: RaceConfig) -> RaceManager:
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	return race


func _end(race: RaceManager) -> void:
	paused = false
	race.queue_free()
	await process_frame
	await process_frame


## Puts `racer` on its last lap and drives it over the line.
func _finish(race: RaceManager, racer: RaceProgress) -> void:
	racer.lap = racer.total_laps
	racer.next_checkpoint = 0
	race._on_checkpoint_crossed(0, racer.vehicle)


func _ai(race: RaceManager) -> Array[RaceProgress]:
	var out: Array[RaceProgress] = []
	for r in race.racers:
		if not r.is_player:
			out.append(r)
	return out


func _test_last_ai() -> void:
	_current = "last AI"
	print("- the last AI car is placed last")
	var race := await _start(_config())
	var ai := _ai(race)
	_check(race.racers.size() == 8 and ai.size() == 7, "8 cars, 7 AI")
	_finish(race, race.player)
	_check(race.player.finish_position == 1 and race.state == RaceManager.State.FINISHED, "player wins, results open")
	for i in 5:
		_finish(race, ai[i])
	_check(not race.is_race_complete() and not ai[5].finished and not ai[6].finished, "two cars left: still racing")
	_finish(race, ai[4]) # already home: ignored
	_check(not ai[6].finished, "a car that's home doesn't count twice")
	_finish(race, ai[5])
	_check(race.is_race_complete() and ai[6].finished, "all but one home: the race is over")
	_check(ai[6].finish_position == 8 and ai[6].finish_time < 0.0, "the last car is 8th without crossing the line")
	var places := {}
	for r in race.racers:
		places[r.finish_position] = true
	_check(places.size() == 8, "8 distinct places")
	await _end(race)


func _test_last_player() -> void:
	_current = "last player"
	print("- the player is the last car")
	var race := await _start(_config())
	for r in _ai(race):
		_finish(race, r)
	_check(race.player.finished and race.player.finish_position == 8, "player placed 8th")
	_check(race.state == RaceManager.State.FINISHED and race.is_race_complete(), "the race is over")
	# The results open after the podium; open them straight away here.
	race.race_hud.results.open(race)
	await process_frame
	var time_text := race.race_hud.results.time_value.text
	_check(time_text == "DNF", "results show DNF for the time (%s)" % time_text)
	await _end(race)


func _test_split_screen() -> void:
	_current = "split screen"
	print("- two players, no AI")
	var config := _config()
	config.ai_rivals = false
	config.player_devices = PackedInt32Array([-1, 0])
	config.player_vehicle_ids = PackedStringArray([VehicleCatalog.all()[0].id, VehicleCatalog.all()[1].id])
	config.player_plates = PackedStringArray(["", "PL-2"])
	var race := await _start(config)
	_check(race.racers.size() == 2, "just the two players")
	_finish(race, race.players[0])
	_check(race.players[1].finished and race.players[1].finish_position == 2, "P1 home: P2 placed 2nd")
	_check(race.state == RaceManager.State.FINISHED, "the race is over")
	await _end(race)


func _test_elimination() -> void:
	_current = "elimination"
	print("- Elimination keeps its own rule")
	var race := await _start(_config(RaceConfig.Mode.ELIMINATION))
	_check(race.elimination != null, "an Elimination race")
	race._check_last_car()
	_check(not race.racers.any(func(r: RaceProgress) -> bool: return r.finished), "the last-car rule doesn't run")
	await _end(race)
