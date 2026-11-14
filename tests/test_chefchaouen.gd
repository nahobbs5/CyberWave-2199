extends SceneTree
## Chefchaouen checks (GDD 8.6i): Africa Cup race 3, a sloped medina circuit
## with two forks per lap. Main loop = the Outer Street and the Fountain
## Steps; branch routes (TrackShortcut.is_branch) = the Blue Stairway and
## the Market Lane. Either route's checkpoints count, lap progress maps both
## onto the same stretch, the Elimination gate is on the shared terrace, the
## AI race each branch on its own line, a recovery on a branch respawns on
## it, the minimap draws both, the routes are balanced, the fountain jump
## lands beside the market traffic, and a full race uses all four routes.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_chefchaouen.gd

const TRACK := "res://scenes/tracks/chefchaouen.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/africa_circuit.tres"
const NAME := "Chefchaouen"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_chefchaouen_profile.json"
	GameSettings.path = "user://test_chefchaouen_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	await _run("a recovery on a branch respawns on it", _test_branch_reset, _config(false))
	await _run("the fountain jump lands beside the market lane", _test_fountain_jump, _config(false))
	var timing := _config(false)
	timing.total_laps = 1
	await _run("route timing (each combination, 1 lap)", _test_route_timing, timing)
	await _run("full race (3 laps, weapons)", _test_full_race, _config(true))
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _config(weapons: bool) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.track_name = NAME
	config.track_scene = load(TRACK) as PackedScene
	config.weapons_enabled = weapons
	return config


func _run(test_name: String, test: Callable, config: RaceConfig) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = true
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	await test.call(race)
	race.queue_free()
	await process_frame


static func _branch(track: TrackCircuit, branch_name: String) -> TrackShortcut:
	for sc in track.shortcuts:
		if String(sc.name) == branch_name:
			return sc
	return null


## True if a main-loop offset is inside either branch's span.
static func _split(track: TrackCircuit, offset: float) -> bool:
	for sc in track.shortcuts:
		if sc.contains_main_offset(track, offset):
			return true
	return false


func _test_layout() -> void:
	_current = "layout"
	print("- layout, branches, slopes")
	var cold := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(cold)
	cold.queue_free()
	await process_frame
	var t0 := Time.get_ticks_msec()
	var track := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var build_ms := Time.get_ticks_msec() - t0
	await physics_frame
	await physics_frame
	print("    built in %d ms" % build_ms)
	_check(track.length > 3000.0 and track.length < 3300.0, "about 3.1 km (%.0f m)" % track.length)
	_check(track.road_width == 16.0 and track.sloped, "a sloped 16 m main road")
	var stair := _branch(track, "BlueStairway")
	var market := _branch(track, "MarketLane")
	_check(stair != null and market != null and track.shortcuts.size() == 2, "two forks: the Blue Stairway and the Market Lane")
	if stair == null or market == null:
		track.queue_free()
		return
	_check(stair.is_branch and market.is_branch and stair.road_width == 12.0 and market.road_width == 12.0,
			"both are 12 m branch routes")
	_check(stair.length < stair.span - 100.0 and market.length < market.span - 100.0,
			"each branch is shorter than the wide route it replaces (%.0f/%.0f, %.0f/%.0f)" % [stair.length, stair.span, market.length, market.span])
	# The forks don't overlap: each pair rejoins before the next split.
	_check(not market.contains_main_offset(track, stair.end_offset) and not stair.contains_main_offset(track, market.start_offset)
			and track.wrapped_delta(stair.end_offset, market.start_offset) > 150.0,
			"the two routes up rejoin on the terrace before the second fork (%.0f m of terrace)" % track.wrapped_delta(stair.end_offset, market.start_offset))
	# Merges and splits in their own lanes.
	_check(absf(stair.start_lateral) >= 2.5 and absf(stair.end_lateral) >= 2.5 and absf(market.end_lateral) >= 2.5,
			"branches join the main road in their own lanes")
	# Heights: lower square to the upper terrace, the stair crest above it.
	var lo := INF
	var hi := -INF
	var d := 0.0
	while d < track.length:
		var y := track.get_center_at(d).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		d += 5.0
	_check(lo > -1.0 and lo < 1.0 and hi > 26.0 and hi < 30.0, "main loop climbs from the square to the terrace (%.0f to %.0f m)" % [lo, hi])
	var crest := -INF
	var stair_steep := 0.0
	d = 0.0
	while d < stair.length - 10.0:
		crest = maxf(crest, stair.point_at(d).y)
		stair_steep = maxf(stair_steep, absf(stair.point_at(d + 10.0).y - stair.point_at(d).y) / 10.0)
		d += 5.0
	_check(crest > 30.0, "the stairway crests above the terrace (%.1f m)" % crest)
	_check(stair_steep > 0.09 and stair_steep < 0.16, "the stairway is steep but drivable (%.1f%%)" % (stair_steep * 100.0))
	# Never stacked: no road sample sits right over another route's.
	var stacked := 0
	var routes: Array = []
	for sc in [stair, market]:
		var pts := PackedVector3Array()
		d = 30.0
		while d < sc.length - 30.0:
			pts.append(sc.point_at(d))
			d += 6.0
		routes.append(pts)
	var main_pts := PackedVector3Array()
	d = 0.0
	while d < track.length:
		main_pts.append(track.to_local(track.get_center_at(d)))
		d += 6.0
	for pts: PackedVector3Array in routes:
		for p in pts:
			for q in main_pts:
				if Vector2(p.x - q.x, p.z - q.z).length() < 10.0 and absf(p.y - q.y) > 2.0:
					stacked += 1
	_check(stacked == 0, "the routes run side by side, never stacked (%d stacked samples)" % stacked)
	# Elimination on the shared terrace; every bypassed gate is copied.
	var gate := track.get_checkpoint_offset(track.elimination_gate_index())
	_check(not _split(track, gate), "the Elimination gate is on a shared section (offset %.0f)" % gate)
	var copies := track.find_children("Checkpoint*", "Area3D", true, false).size()
	_check(copies >= track.checkpoint_count + 6, "bypassed checkpoints are copied onto the branches (%d gates)" % copies)
	# Both branches on the minimap, at full strength.
	var map := Minimap.new()
	root.add_child(map)
	map.setup_track(track, null)
	_check(map.shortcut_count() == 2 and map.strong_route_count() == 2, "the minimap draws both branches like the main loop")
	map.queue_free()
	# Lap progress runs on across a branch.
	var prev := track.get_offset_at(track.to_global(stair.point_at(5.0)))
	var steady := true
	d = 10.0
	while d < stair.length - 5.0:
		var o := track.get_offset_at(track.to_global(stair.point_at(d)))
		steady = steady and track.wrapped_delta(prev, o) > 0.0
		prev = o
		d += 10.0
	_check(steady, "lap progress keeps moving forward along the stairway")
	await _scenery_checks(track, stair, market)
	track.queue_free()
	await process_frame


func _scenery_checks(track: TrackCircuit, stair: TrackShortcut, market: TrackShortcut) -> void:
	var scenery := track.get_node_or_null("Scenery") as ChefchaouenScenery
	_check(scenery != null, "the medina is built")
	if scenery == null:
		return
	# Signs well before each split, so a driver in traffic can pick a lane.
	for sc in [stair, market]:
		var lead: float = scenery.sign_lead.get(String(sc.name), 0.0)
		_check(lead >= 100.0, "%s is signposted %.0f m before the fork" % [sc.display_name, lead])
	_check(scenery.stair_steps > 150, "stone stairs drawn on the climbs and descents (%d steps)" % scenery.stair_steps)
	_check(scenery.houses > 150, "blue houses line the streets (%d)" % scenery.houses)
	_check(scenery.flowerpots > 60 and scenery.rugs > 30 and scenery.fountains >= 1 and scenery.doors > 40,
			"landmarks: flowerpots %d, rugs %d, fountains %d, doors %d" % [scenery.flowerpots, scenery.rugs, scenery.fountains, scenery.doors])
	_check(scenery.lowest_overhead >= 6.0, "nothing overhead lower than 6 m over a road (%.1f m)" % scenery.lowest_overhead)


func _test_cup() -> void:
	_current = "cup"
	print("- Africa Cup")
	var cup := load(CUP) as GrandPrixData
	_check(cup.race_count() == 3 and cup.track_names[2] == NAME and cup.is_track_built(2), "race 3 is Chefchaouen")
	_check(not cup.locked and cup.is_open(true) and cup.is_open(false), "the Africa Cup is open for Grand Prix and Versus")
	_check(TrackCatalog.scene_path(NAME) == TRACK and TrackCatalog.location(NAME).contains("Morocco"), "in the track catalogue (Morocco)")


## Recovered on the Blue Stairway, a car comes back on the stairway.
func _test_branch_reset(race: RaceManager) -> void:
	var track := race.track
	var stair := _branch(track, "BlueStairway")
	var me := race.player.vehicle
	await _frames(30)
	# Drive it up the stairway from the bottom so its safe point follows.
	var ai := race.get_ai(race.player)
	if ai != null:
		ai.forced_branches = {"BlueStairway": true, "MarketLane": true}
	me.teleport(track.global_transform * stair.safe_transform(150.0, 0.0, 0.9))
	# A teleport never moves the safe point (it isn't driven), so set it here.
	await _frames(2)
	me.recovery.last_safe_offset = track.get_offset_at(me.global_position)
	var frames := 0
	while frames < 60 * 25 and stair.local_offset(track.to_local(me.global_position)) < 450.0:
		await physics_frame
		frames += 1
	var reached := stair.local_offset(track.to_local(me.global_position))
	_check(track.get_shortcut_at(me.global_position) == stair and reached >= 400.0,
			"the car drives up the stairway (%.0f m along)" % reached)
	_check(me.recovery.safe_branch == stair, "its safe point is on the stairway")
	me.recovery.request_recovery("manual")
	frames = 0
	while me.recovery.is_busy() and frames < 600:
		await physics_frame
		frames += 1
	await _frames(20)
	var on := track.get_shortcut_at(me.global_position)
	var at := stair.local_offset(track.to_local(me.global_position))
	_check(on == stair and at > reached - 40.0, "it respawns on the stairway (%.0f m along)" % at)


## Off the final landing at speed: airborne, then down on the road beside
## (not on top of) the Market Lane's merging lane.
func _test_fountain_jump(race: RaceManager) -> void:
	var track := race.track
	var market := _branch(track, "MarketLane")
	var me := race.player.vehicle
	var ai := race.get_ai(race.player)
	if ai != null:
		ai.forced_branches = {"BlueStairway": false, "MarketLane": false}
	var ramp: TrackFeature = null
	for f in track.find_children("*", "TrackFeature", false, false):
		if (f as TrackFeature).kind == TrackFeature.Kind.JUMP_RAMP and (f as TrackFeature).on_shortcut == "":
			ramp = f
	_check(ramp != null, "a jump ramp on the final landing")
	if ramp == null:
		return
	await _frames(20)
	# Straight down the ramp's lane at full throttle (no steering): the AI
	# is paused so it doesn't overwrite the inputs.
	if ai != null:
		ai.set_physics_process(false)
	me.teleport(track.get_safe_transform(ramp.offset - 120.0, ramp.lateral, 0.9))
	var flew := false
	var landed_lateral := INF
	var frames := 0
	while frames < 60 * 14:
		me.throttle_input = 1.0
		me.brake_input = 0.0
		me.steer_input = 0.0
		await physics_frame
		frames += 1
		var off := track.get_offset_at(me.global_position)
		var past := track.wrapped_delta(ramp.offset, off)
		if past > 0.0 and past < 60.0 and me.grounded_wheels == 0:
			flew = true
		if flew and me.grounded_wheels >= 3 and past > 0.0:
			var right := track.get_tangent_at(off).cross(Vector3.UP).normalized()
			landed_lateral = (me.global_position - track.get_center_at(off)).dot(right)
			break
	_check(flew, "the car flies off the final landing")
	_check(landed_lateral != INF and track.is_on_road(me.global_position), "and lands on the road")
	_check(signf(landed_lateral) != signf(market.end_lateral) and absf(landed_lateral) > 1.0,
			"on the side away from the Market Lane's lane (landed %.1f m, market lane %.1f m)" % [landed_lateral, market.end_lateral])


## Each slot is forced onto one of the four route combinations; sector times
## from the shared approach before each fork to the shared exit after it.
func _test_route_timing(race: RaceManager) -> void:
	var track := race.track
	var stair := _branch(track, "BlueStairway")
	var market := _branch(track, "MarketLane")
	var combos := [[true, true], [true, false], [false, true], [false, false]]
	var i := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			var c: Array = combos[i % 4]
			ai.forced_branches = {"BlueStairway": c[0], "MarketLane": c[1]}
		i += 1
	# Sector gates: 40 m before each split, 40 m after each merge.
	var sectors := [[track.wrap_offset(stair.start_offset - 40.0), track.wrap_offset(stair.end_offset + 40.0), stair],
			[track.wrap_offset(market.start_offset - 40.0), track.wrap_offset(market.end_offset + 40.0), market]]
	var entered := {}
	var times := {} # "branch|main" -> [seconds...]
	var used := {} # racer -> [took stair, took market]
	var elapsed := 0.0
	var frames := 0
	var last_off := {}
	while frames < 60 * 200 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
		elapsed += 1.0 / 60.0
		for racer in race.racers:
			var pos := racer.vehicle.global_position
			var off := track.get_offset_at(pos)
			var on := track.get_shortcut_at(pos)
			if not used.has(racer):
				used[racer] = [false, false]
			if on == stair:
				used[racer][0] = true
			elif on == market:
				used[racer][1] = true
			var prev: float = last_off.get(racer, off)
			last_off[racer] = off
			for k in sectors.size():
				var s: Array = sectors[k]
				var key := "%s/%d" % [racer.vehicle.name, k]
				if _crossed(track, prev, off, s[0]) and not entered.has(key):
					entered[key] = elapsed
				elif _crossed(track, prev, off, s[1]) and entered.has(key) and entered[key] >= 0.0:
					var took: bool = used[racer][k]
					var route := ("%s|branch" if took else "%s|main") % (s[2] as TrackShortcut).name
					if not times.has(route):
						times[route] = []
					times[route].append(elapsed - float(entered[key]))
					entered[key] = -1.0
	var avg := {}
	for route in times:
		var sum := 0.0
		for t in times[route]:
			sum += t
		avg[route] = sum / (times[route] as Array).size()
	print("    sector averages: %s" % [avg])
	for k in ["BlueStairway", "MarketLane"]:
		var b: float = avg.get("%s|branch" % k, -1.0)
		var m: float = avg.get("%s|main" % k, -1.0)
		_check(b > 0.0 and m > 0.0, "%s: both routes timed" % k)
		if b > 0.0 and m > 0.0:
			_check(absf(b - m) / m < 0.08, "%s: the two routes are within 8%% (branch %.1f s, wide route %.1f s)" % [k, b, m])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes the lap on their route")


static func _crossed(track: TrackCircuit, prev: float, now: float, at: float) -> bool:
	var a := track.wrapped_delta(at, prev)
	var b := track.wrapped_delta(at, now)
	return a < 0.0 and b >= 0.0 and b < 50.0


func _test_full_race(race: RaceManager) -> void:
	var track := race.track
	var stair := _branch(track, "BlueStairway")
	var market := _branch(track, "MarketLane")
	var recoveries := [0]
	var reasons := {}
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(r: String) -> void:
			recoveries[0] += 1
			reasons[r] = int(reasons.get(r, 0)) + 1)
	var lap_routes := {} # "racer:lap" -> [stair, market]
	var combos := {}
	var frames := 0
	while frames < 60 * 420 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
		if frames % 6 != 0:
			continue
		for racer in race.racers:
			if racer.finished:
				continue
			var key := "%s:%d" % [racer.vehicle.name, racer.lap]
			if not lap_routes.has(key):
				lap_routes[key] = [false, false]
			var on := track.get_shortcut_at(racer.vehicle.global_position)
			if on == stair:
				lap_routes[key][0] = true
			elif on == market:
				lap_routes[key][1] = true
	for key in lap_routes:
		combos[str(lap_routes[key])] = true
	var times: Array[String] = []
	for racer in race.get_standings():
		times.append(RaceProgress.format_time(racer.finish_time))
	print("    race %.1f s simulated; times %s; route combos %s; recoveries %d %s" % [frames / 60.0, times, combos.keys(), recoveries[0], reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	_check(combos.size() == 4, "the field uses all four routes through the lap (%d)" % combos.size())
	_check(recoveries[0] <= 4, "few recoveries on the stairs and slopes (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 330.0, "a 3-5 minute race: %s" % RaceProgress.format_time(winner.finish_time))
	await process_frame
