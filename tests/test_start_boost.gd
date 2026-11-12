extends SceneTree
## Rocket start headless checks (StartLaunch, RaceManager, VehicleFeedback).
## Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_start_boost.gd

const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
## Player speed 0.5 s after START, by start kind.
var _speeds: Dictionary = {}


func _initialize() -> void:
	PodiumCeremony.instant = true
	PlayerProfile.save_path = "user://test_start_boost_profile.json"
	GameSettings.path = "user://test_start_boost_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	_test_rules()
	_test_ai_odds()
	# Press frames at 60 fps: the "2" fades at about 1.7 s.
	await _run("normal start (pressed late)", _launch.bind(160, &""))
	await _run("rocket start (pressed as the 2 fades)", _launch.bind(102, StartLaunch.ROCKET))
	await _run("burnout (pressed too early)", _launch.bind(30, StartLaunch.BURNOUT))
	await _run("AI rocket starts on Hard", _ai_race.bind("res://resources/ai/hard.tres"))
	_current = "compare"
	_check(_speeds.get(StartLaunch.ROCKET, 0.0) > _speeds.get(&"", 0.0) + 3.0,
			"rocket start is faster off the line (%.1f vs %.1f m/s)" % [_speeds.get(StartLaunch.ROCKET, 0.0), _speeds.get(&"", 0.0)])
	_check(_speeds.get(StartLaunch.BURNOUT, 99.0) < _speeds.get(&"", 0.0) - 3.0,
			"burnout is slower off the line (%.1f vs %.1f m/s)" % [_speeds.get(StartLaunch.BURNOUT, 99.0), _speeds.get(&"", 0.0)])
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_rules() -> void:
	_current = "rules"
	print("- StartLaunch rules (no scene)")
	_check(_hold_from(0.5) == StartLaunch.BURNOUT, "pressed during the 3: burnout")
	_check(_hold_from(1.2) == StartLaunch.BURNOUT, "pressed while the 2 is still solid: burnout")
	_check(_hold_from(1.7) == StartLaunch.ROCKET, "pressed as the 2 fades: rocket start")
	_check(_hold_from(2.1) == StartLaunch.ROCKET, "just after the 2 is gone: still rocket")
	_check(_hold_from(2.5) == &"", "pressed during the 1: nothing")
	_check(_hold_from(-1.0) == &"", "never pressed: nothing")
	# Let go and press again in the window: the new press counts.
	var l := StartLaunch.new()
	var t := 0.0
	while t < 3.0:
		l.update(t, (t >= 0.5 and t < 1.0) or t >= 1.8)
		t += 1.0 / 60.0
	_check(l.result() == StartLaunch.ROCKET, "early press released, re-pressed in the window: rocket")
	_check(l.rev() > 0.9, "rev builds up while held (%.2f)" % l.rev())
	l.update(3.2, false)
	_check(l.rev() < 0.9 and not l.is_holding(), "letting go drops the rev")


## AI press times, rolled 2000 times per difficulty: harder = more rocket
## starts and fewer burnouts.
func _test_ai_odds() -> void:
	_current = "AI odds"
	print("- AI start odds by difficulty (no scene)")
	var rockets := {}
	var burnouts := {}
	for name in ["easy", "normal", "hard"]:
		var ai := AIController.new()
		ai.difficulty = load("res://resources/ai/%s.tres" % name) as AIDifficulty
		ai._rng.seed = 42
		var r := 0
		var b := 0
		for i in 2000:
			var press := ai.start_press_time()
			var kind := _hold_from(press)
			r += 1 if kind == StartLaunch.ROCKET else 0
			b += 1 if kind == StartLaunch.BURNOUT else 0
		rockets[name] = r / 2000.0
		burnouts[name] = b / 2000.0
		ai.free()
	print("    rockets %s, burnouts %s" % [rockets, burnouts])
	_check(rockets.easy < rockets.normal and rockets.normal < rockets.hard, "harder AI rocket-start more often")
	_check(burnouts.easy > burnouts.normal and burnouts.normal > burnouts.hard, "harder AI burn out less often")
	_check(absf(rockets.hard - 0.8) < 0.05 and absf(burnouts.easy - 0.2) < 0.05, "odds match the difficulty settings")


func _ai_race(race: RaceManager, difficulty_path: String) -> void:
	# Difficulty is read at setup; swap it and re-plan before the countdown.
	race.difficulty = load(difficulty_path) as AIDifficulty
	for r in race.racers:
		var ai := race.get_ai(r)
		if ai != null:
			ai.difficulty = race.difficulty
	var results := {}
	race.start_launched.connect(func(r: RaceProgress, result: StringName) -> void:
		if not r.is_player:
			results[r] = result)
	race.start_countdown()
	var revved := {}
	while race.state == RaceManager.State.COUNTDOWN:
		await physics_frame
		for r in race.racers:
			if not r.is_player and r.vehicle.start_rev > 0.0:
				revved[r] = true
	var rockets := results.values().count(StartLaunch.ROCKET)
	_check(results.size() == 7, "every AI gets a launch result (%d)" % results.size())
	_check(revved.size() == 7, "every AI revs before START (%d)" % revved.size())
	_check(rockets >= 3, "most Hard AI rocket-start (%d of 7)" % rockets)
	var boosting := race.racers.filter(func(r: RaceProgress) -> bool:
		return not r.is_player and r.vehicle.is_boosting() and r.vehicle.boost_label == RaceManager.ROCKET_START_LABEL).size()
	_check(boosting == rockets, "each rocket-starting AI boosts (%d)" % boosting)


func _hold_from(press: float) -> StringName:
	var l := StartLaunch.new()
	var t := 0.0
	while t < 3.0:
		l.update(t, press >= 0.0 and t >= press)
		t += 1.0 / 60.0
	return l.result()


func _launch(race: RaceManager, press_frame: int, expected: StringName) -> void:
	var results: Array = []
	race.start_launched.connect(func(r: RaceProgress, result: StringName) -> void:
		if r == race.player:
			results.append(result))
	var car := race.player.vehicle
	var start := car.global_position
	race.start_countdown()
	await _frames(press_frame)
	Input.action_press(&"accelerate")
	var fb := car.get_node("Feedback") as VehicleFeedback
	var max_rev := 0.0
	var squatted := false
	while race.state == RaceManager.State.COUNTDOWN:
		await physics_frame
		max_rev = maxf(max_rev, car.start_rev)
		squatted = squatted or fb.rev_pitch > 0.0
	_check(squatted, "the rear squats while revving")
	_check(car.global_position.distance_to(start) < 0.5, "car holds still before START")
	_check(max_rev > 0.0, "revving shows before START (%.2f)" % max_rev)
	_check(car.start_rev == 0.0, "rev cleared at START")
	_check(results == [expected], "launch result %s (got %s)" % [expected, results])
	if expected == StartLaunch.ROCKET:
		_check(car.is_boosting() and car.boost_label == RaceManager.ROCKET_START_LABEL, "rocket start boosts")
	if expected == StartLaunch.BURNOUT:
		_check(car.status.has(&"burnout") and not car.status.can_drive(), "burnout: no control for a moment")
	else:
		_check(car.status == null or not car.status.has(&"burnout"), "no burnout")
	await _frames(30)
	_speeds[expected] = car.forward_speed
	await _frames(60)
	if expected == StartLaunch.BURNOUT:
		_check(not car.status.has(&"burnout") and car.status.can_drive(), "control back after the burnout")
		_check(not car.status.is_protected(), "a burnout isn't a hard stun (no protection)")


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _run(test_name: String, test: Callable) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.auto_start = false
	race.weapons_enabled = false
	root.add_child(race)
	race.camera.save_preference = false
	await _frames(2)
	await test.call(race)
	Input.action_release(&"accelerate")
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
