extends SceneTree
## Phase 2 headless checks: checkpoints, laps, grid, countdown, positions,
## AI racing and results. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_phase2.gd
## --fixed-fps makes physics run as fast as possible (full races are simulated).

const RACE_SCENE := "res://scenes/race/race.tscn"
const OVAL := [
	Vector3(0, 0, 120), Vector3(0, 0, -120), Vector3(40, 0, -160), Vector3(80, 0, -120),
	Vector3(80, 0, 120), Vector3(40, 0, 160),
]

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_progress_logic()
	_test_standings_order()
	await _run("grid", _test_grid, {"auto_start": false})
	await _run("countdown locks controls", _test_countdown, {"auto_start": false})
	await _run("skipped gates don't count", _test_no_gate_skipping, {"player_uses_autopilot": true})
	await _run("wrong-way warning", _test_wrong_way, {})
	await _run("full 3-lap race, 8 AI drivers", _test_full_race, {"player_uses_autopilot": true})
	await _run("AI drifts where corners allow", _test_ai_drifting,
			{"player_uses_autopilot": true, "total_laps": 1, "oval": true})
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _run(test_name: String, test: Callable, options: Dictionary) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.auto_start = options.get("auto_start", true)
	race.player_uses_autopilot = options.get("player_uses_autopilot", false)
	race.total_laps = options.get("total_laps", 3)
	if options.get("oval", false):
		(race.get_node("TestCircuit") as TrackCircuit).control_points = PackedVector3Array(OVAL)
	root.add_child(race)
	race.camera.save_preference = false
	await _frames(2)
	await test.call(race)
	for action in [&"accelerate", &"brake", &"steer_left", &"steer_right"]:
		Input.action_release(action)
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _wait_for_state(race: RaceManager, state: RaceManager.State, max_frames: int) -> void:
	var frames := 0
	while race.state != state and frames < max_frames:
		await physics_frame
		frames += 1


# --- pure logic --------------------------------------------------------------

func _test_progress_logic() -> void:
	_current = "lap/checkpoint logic"
	print("- lap/checkpoint logic (no scene)")
	var p := RaceProgress.new(null, "Test", Color.WHITE, false, 0, 4, 2)
	_check(p.on_checkpoint(1, 1.0) == &"", "gate 1 before the start line is ignored")
	_check(p.on_checkpoint(0, 2.0) == &"start", "first start-line crossing starts lap 1")
	_check(p.lap == 1, "lap 1 after the start")
	_check(p.on_checkpoint(2, 3.0) == &"", "skipping gate 1 is ignored")
	_check(p.on_checkpoint(0, 3.5) == &"", "re-crossing the line early does not count")
	_check(p.on_checkpoint(1, 4.0) == &"checkpoint", "gate 1 in order counts")
	_check(p.on_checkpoint(1, 4.5) == &"", "the same gate twice counts once")
	p.on_checkpoint(2, 5.0)
	p.on_checkpoint(3, 6.0)
	_check(p.on_checkpoint(0, 10.0) == &"lap", "all gates then the line completes a lap")
	_check(p.lap == 2 and is_equal_approx(p.lap_times[0], 10.0), "lap 1 timed from GO (10 s)")
	for gate in [1, 2, 3]:
		p.on_checkpoint(gate, 12.0 + gate)
	_check(p.on_checkpoint(0, 18.0) == &"finish", "final lap finishes the race")
	_check(p.finished and is_equal_approx(p.finish_time, 18.0), "finish time recorded")
	_check(is_equal_approx(p.best_lap, 8.0), "best lap is the faster lap (8 s)")
	_check(p.on_checkpoint(1, 19.0) == &"", "finished racers ignore gates")
	_check(p.checkpoints_passed == 9, "9 valid crossings for 2 laps of 4 gates (+start)")


func _test_standings_order() -> void:
	_current = "standings order"
	print("- standings order (no scene)")
	var a := RaceProgress.new(null, "A", Color.WHITE, false, 3, 8, 3)
	var b := RaceProgress.new(null, "B", Color.WHITE, false, 1, 8, 3)
	var c := RaceProgress.new(null, "C", Color.WHITE, false, 2, 8, 3)
	a.race_distance = 900.0
	b.race_distance = 1200.0
	c.finished = true
	c.finish_position = 1
	var list: Array[RaceProgress] = [a, b, c]
	list.sort_custom(RaceProgress.is_ahead)
	_check(list[0] == c and list[1] == b and list[2] == a, "finished first, then by distance")
	a.race_distance = 1200.0
	list.sort_custom(RaceProgress.is_ahead)
	_check(list[1] == b, "a tie keeps the better grid slot ahead")


# --- scene tests ---------------------------------------------------------------

func _test_grid(race: RaceManager) -> void:
	var track := race.track
	_check(race.racers.size() == 8, "8 racers spawned (got %d)" % race.racers.size())
	_check(race.player != null and race.player.grid_slot == 7, "player starts in the last slot")
	_check(race.player.position == 8, "player listed 8th on the grid")
	var gates := track.get_node("_GenCheckpoints").get_child_count()
	_check(gates == track.checkpoint_count, "%d checkpoint gates built" % gates)
	await _frames(60)
	var names := {}
	for racer in race.racers:
		var pos := racer.vehicle.global_position
		names[racer.display_name] = true
		_check(track.is_on_road(pos), "%s on the road" % racer.display_name)
		var behind := track.wrapped_delta(track.start_line_offset, track.get_offset_at(pos))
		_check(behind < -3.0, "%s behind the start line (%.1f m)" % [racer.display_name, behind])
		var facing := (-racer.vehicle.global_transform.basis.z).dot(track.get_tangent_at(track.get_offset_at(pos)))
		_check(facing > 0.98, "%s faces forward" % racer.display_name)
		for other in race.racers:
			if other != racer:
				var gap := pos.distance_to(other.vehicle.global_position)
				_check(gap > 4.0, "%s and %s not overlapping (%.1f m)" % [racer.display_name, other.display_name, gap])
	_check(names.size() == 8, "every racer has a distinct name")
	var player_offset := track.get_offset_at(race.player.vehicle.global_position)
	for racer in race.racers:
		if not racer.is_player:
			var ahead := track.wrapped_delta(player_offset, track.get_offset_at(racer.vehicle.global_position))
			_check(ahead > 0.0, "%s starts ahead of the player" % racer.display_name)


func _test_countdown(race: RaceManager) -> void:
	var words := []
	race.countdown_tick.connect(func(word: String) -> void: words.append(word))
	race.start_countdown()
	var start := race.player.vehicle.global_position
	Input.action_press(&"accelerate")
	await _frames(90)
	_check(race.state == RaceManager.State.COUNTDOWN, "still counting down at 1.5 s")
	_check(race.player.vehicle.global_position.distance_to(start) < 0.5, "throttle does nothing before GO")
	await _wait_for_state(race, RaceManager.State.RACING, 120)
	_check(words == ["READY", "SET", "GO"], "READY, SET, GO in order (%s)" % [words])
	_check(race.state == RaceManager.State.RACING, "race starts after GO")
	await _frames(60)
	_check(race.race_time > 0.9 and race.race_time < 1.1, "race clock runs from GO (%.2f s)" % race.race_time)
	_check(race.player.vehicle.global_position.distance_to(start) > 5.0, "player drives after GO")
	var ai_moved := 0
	for racer in race.racers:
		if not racer.is_player and racer.vehicle.forward_speed > 5.0:
			ai_moved += 1
	_check(ai_moved == 7, "all 7 AI pull away (%d moving)" % ai_moved)


func _test_no_gate_skipping(race: RaceManager) -> void:
	await _wait_for_state(race, RaceManager.State.RACING, 200)
	var p := race.player
	var frames := 0
	while p.lap == 0 and frames < 600:
		await physics_frame
		frames += 1
	_check(p.lap == 1 and p.next_checkpoint == 1, "crossing the line starts lap 1")
	# Teleport three gates ahead: the skipped gates must not count.
	var track := race.track
	var jump_to := track.get_checkpoint_offset(3) + 20.0
	p.vehicle.teleport(track.get_safe_transform(jump_to))
	await _frames(240)
	_check(p.next_checkpoint == 1, "still waiting for gate 1 after skipping ahead (next %d)" % p.next_checkpoint)
	_check(p.checkpoints_passed == 1, "no extra checkpoints counted (%d)" % p.checkpoints_passed)


func _test_wrong_way(race: RaceManager) -> void:
	await _wait_for_state(race, RaceManager.State.RACING, 200)
	var track := race.track
	var car := race.player.vehicle
	# Well clear of the pack, which is still near the grid.
	var offset := track.get_offset_at(car.global_position) + 400.0
	var tangent := track.get_tangent_at(offset)
	car.teleport(Transform3D(Basis.looking_at(-tangent, Vector3.UP), track.get_center_at(offset) + Vector3.UP * 0.9))
	await _frames(20)
	_check(not race.wrong_way, "no warning while stopped")
	Input.action_press(&"accelerate")
	await _frames(120)
	_check(race.wrong_way, "driving against the track shows WRONG WAY (speed %.1f)" % car.forward_speed)


func _test_full_race(race: RaceManager) -> void:
	var recoveries := {}
	for racer in race.racers:
		var key := racer.display_name
		recoveries[key] = 0
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[key] += 1)
	var order_errors := 0
	var samples := 0
	var frames := 0
	var limit := 60 * 240
	while frames < limit and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
		if frames % 300 == 0 and race.state == RaceManager.State.RACING:
			# Cross-check positions against an independent measure: distance
			# legitimately driven (from VehicleRecovery) plus grid setback.
			var standings := race.get_standings()
			for i in standings.size() - 1:
				var a := standings[i]
				var b := standings[i + 1]
				if a.finished or b.finished:
					continue
				samples += 1
				if _reference_distance(race, a) + 8.0 < _reference_distance(race, b):
					order_errors += 1
	print("    race took %.1f s simulated" % (frames / 60.0))
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 racers finished")
	var positions := {}
	var standings := race.get_standings()
	for i in standings.size():
		var racer := standings[i]
		positions[racer.finish_position] = true
		_check(racer.lap_times.size() == 3, "%s logged 3 laps" % racer.display_name)
		_check(racer.checkpoints_passed == 3 * race.track.checkpoint_count + 1,
				"%s crossed every gate (%d)" % [racer.display_name, racer.checkpoints_passed])
		_check(racer.position == i + 1 and racer.finish_position == i + 1, "%s standings match finish order" % racer.display_name)
		if i > 0:
			_check(racer.finish_time >= standings[i - 1].finish_time, "finish times ascend with position")
	_check(positions.size() == 8, "8 distinct finishing positions")
	var total_recoveries := 0
	for key in recoveries:
		total_recoveries += recoveries[key]
	_check(total_recoveries <= 2, "AI rarely needs recovery (%d total: %s)" % [total_recoveries, recoveries])
	_check(samples > 50 and order_errors == 0, "live positions agree with distance driven (%d/%d off)" % [order_errors, samples])
	_check(race.state == RaceManager.State.FINISHED, "race marked finished for the player")
	_check(race.race_hud.is_results_visible(), "results screen shown")


func _reference_distance(race: RaceManager, racer: RaceProgress) -> float:
	var track := race.track
	var setback := track.wrapped_delta(track.start_line_offset, track.get_grid_offset(racer.grid_slot))
	return racer.vehicle.recovery.total_progress + setback


func _test_ai_drifting(race: RaceManager) -> void:
	_check(race.line.drift_zones.size() >= 2, "oval has drift zones (%d)" % race.line.drift_zones.size())
	var frames := 0
	while not race.player.finished and frames < 60 * 90:
		await physics_frame
		frames += 1
	var boosts := 0
	var drifters := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null and ai.drift_boosts > 0:
			drifters += 1
			boosts += ai.drift_boosts
	_check(drifters >= 6, "most AI earn drift boosts on the oval (%d racers, %d boosts)" % [drifters, boosts])
