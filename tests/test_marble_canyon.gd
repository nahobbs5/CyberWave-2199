extends SceneTree
## Marble Canyon checks (GDD 8.6j): the switchback layout (six hairpins,
## grades, the window as the high point, no two terraces close enough to
## confuse the lap position), the land kept under the road, the rock
## window's clearance and rock noses, the American Cup
## (race 1) and Vegas Overdrive moving to Practice, the terrace guard
## (dropping onto another terrace puts the car back, facing the right way),
## an 8-car opening lap and a full race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_marble_canyon.gd

const TRACK := "res://scenes/tracks/marble_canyon.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/american_circuit.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_marble_profile.json"
	GameSettings.path = "user://test_marble_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cups_and_practice()
	await _run("terrace guard", _test_terrace_guard, _config())
	var opening := _config()
	opening.total_laps = 1
	await _run("opening lap, 8 cars", _test_opening_lap, opening)
	if not OS.get_cmdline_user_args().has("quick"):
		await _run("full race (3 laps, weapons)", _test_full_race, _config())
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _config() -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.track_name = "Marble Canyon"
	config.track_scene = load(TRACK) as PackedScene
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


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_layout() -> void:
	_current = "layout"
	print("- layout, land, window")
	var track := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var sc := track.get_node("Scenery") as MarbleCanyonScenery
	var frames := 0
	while sc.arch == null and frames < 600:
		await process_frame
		frames += 1
	_check(sc.arch != null, "the scenery builds")
	_check(track.length > 2900.0 and track.length < 3300.0, "about 3.0-3.3 km (%.0f m)" % track.length)
	_check(track.road_width >= 18.0, "18 m road: two cars side by side through the hairpins (%.0f)" % track.road_width)
	_check(track.sloped and track.terrace_guard, "sloped, with the terrace guard on")
	_check(track.checkpoint_count == 12, "12 checkpoints")

	# Six hairpins: stretches turning more than 150 degrees within 140 m.
	var hairpins := 0
	var o := 0.0
	while o < track.length:
		var turn := _turn(track, o, o + 140.0)
		if absf(turn) > deg_to_rad(150.0):
			hairpins += 1
			o += 160.0
		else:
			o += 5.0
	_check(hairpins == 6, "six hairpins (%d)" % hairpins)
	for key in MarbleCanyonScenery.HAIRPINS:
		var h: Array = MarbleCanyonScenery.HAIRPINS[key]
		var turn := _turn(track, h[0], h[1])
		_check(absf(turn) > deg_to_rad(165.0) and signf(turn) == signf(h[2]),
				"%s turns %s (%.0f deg)" % [key, "left" if h[2] > 0 else "right", rad_to_deg(turn)])
		var grade: float = absf(track.curve.sample_baked(h[1]).y - track.curve.sample_baked(h[0]).y) / (h[1] - h[0])
		_check(grade < 0.045, "%s: grade eased at the apex (%.1f%%)" % [key, grade * 100.0])

	# Grades, high point, the descent steeper than the climb.
	var worst := 0.0
	var climb := 0.0
	var descent := 0.0
	var top_y := -INF
	var top_at := 0.0
	o = 0.0
	while o < track.length:
		var a := track.curve.sample_baked(o)
		var b := track.curve.sample_baked(track.wrap_offset(o + 10.0))
		var g := (b.y - a.y) / Vector2(b.x - a.x, b.z - a.z).length()
		worst = maxf(worst, absf(g))
		climb = maxf(climb, g)
		descent = maxf(descent, -g)
		if a.y > top_y:
			top_y = a.y
			top_at = o
		o += 5.0
	_check(worst < 0.115, "no grade over 11.5%% (%.1f%%)" % (worst * 100.0))
	_check(descent > climb, "the descent is steeper than the climb (%.1f%% vs %.1f%%)" % [descent * 100.0, climb * 100.0])
	_check(absf(top_at - MarbleCanyonScenery.WINDOW_OFFSET) < 60.0, "the window is the high point (%.0f m at %.0f)" % [top_y, top_at])
	var grid_y := track.curve.sample_baked(track.start_line_offset).y
	_check(absf(grid_y) < 1.0 and top_y - grid_y > 45.0, "grid on the canyon floor, %.0f m below the window" % (top_y - grid_y))

	# Terraces: every road point maps back to its own lap position, and every
	# other part of the lap is either 10 m clear of the road edge or 9 m
	# above / below it.
	var aliased := 0
	var close := 0
	var other := PackedVector3Array()
	o = 0.0
	while o < track.length:
		other.append(track.curve.sample_baked(o))
		o += 6.0
	o = 0.0
	while o < track.length:
		for lat in [-8.5, 0.0, 8.5]:
			var p := track.to_global(track.surface_point(o, lat) + Vector3.UP * 0.5)
			if absf(track.wrapped_delta(o, track.get_offset_at(p))) > 12.0:
				aliased += 1
		var c := track.curve.sample_baked(o)
		for i in other.size():
			var d := absf(track.wrapped_delta(o, float(i) * 6.0))
			if d < 90.0:
				continue
			var q := other[i]
			if Vector2(q.x - c.x, q.z - c.z).length() < track.road_width + 10.0 and absf(q.y - c.y) < 9.0:
				close += 1
		o += 8.0
	_check(aliased == 0, "every road point finds its own terrace (%d don't)" % aliased)
	_check(close == 0, "terraces are 10 m apart or 9 m above each other (%d too close)" % close)

	# Land under the road, a collider for falls.
	var above := -INF
	o = 0.0
	while o < track.length:
		for lat in [-9.0, 0.0, 9.0]:
			var p := track.surface_point(o, lat)
			above = maxf(above, sc.height_at(p.x, p.z) - p.y)
		o += 3.0
	_check(above < 0.0, "the land stays under the road (%.2f m)" % above)
	var land := sc.find_child("LandCollider", true, false)
	_check(land != null and land.get_child_count() > 0, "the land near the road has a collider")

	# The rock window.
	var half_clear := sc.arch.clear_half_width(8.0)
	var need := track.road_width * 0.5 + track.barrier_thickness + 3.0
	_check(half_clear >= need, "the window is %.1f m wide each side up to 8 m (needs %.1f)" % [half_clear, need])
	var headroom := sc.arch.clear_height(track.road_width * 0.5 + 2.0)
	_check(headroom >= 14.0, "and %.1f m high over the road (far chase camera ~3.6 m up)" % headroom)
	_check(sc.find_child("WindowCollider", true, false) != null, "the window fin has a collider")
	var throat := track.to_global(track.surface_point(MarbleCanyonScenery.WINDOW_OFFSET, 0.0))
	var space := root.get_world_3d().direct_space_state
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(throat + Vector3.UP * 1.0, throat + Vector3.UP * 12.0)
	_check(space.intersect_ray(ray).is_empty(), "nothing over the road in the throat for 12 m")
	var up := PhysicsRayQueryParameters3D.create(throat + Vector3.UP * 1.0, throat + Vector3.UP * 80.0)
	_check(not space.intersect_ray(up).is_empty(), "rock overhead in the throat (it's a window, not a gap)")
	_check(sc.noses.size() == 6, "a rock nose in every hairpin")
	track.queue_free()
	await process_frame


## Signed heading change (left positive) between two lap offsets.
func _turn(track: TrackCircuit, from: float, to: float) -> float:
	var total := 0.0
	var o := from
	var prev := track.get_tangent_at(track.wrap_offset(o))
	while o < to:
		o += 2.0
		var t := track.get_tangent_at(track.wrap_offset(o))
		total += atan2(prev.cross(t).y, prev.dot(t))
		prev = t
	return total


func _test_cups_and_practice() -> void:
	_current = "cups"
	print("- American Cup and Practice")
	var cup := load(CUP) as GrandPrixData
	_check(cup.track_names[0] == "Marble Canyon" and cup.is_track_built(0), "American Cup race 1 is Marble Canyon")
	_check(cup.track_scenes[0] == TRACK and cup.locations[0] == "Marble Canyon, Arizona", "its scene and location")
	_check(TrackCatalog.scene_path("Marble Canyon") == TRACK, "in the track catalogue")
	_check(TrackCatalog.music("Marble Canyon") != "" and ResourceLoader.exists(TrackCatalog.music("Marble Canyon")),
			"it has race music")
	var in_cup := false
	for c in GrandPrixData.all_cups():
		in_cup = in_cup or c.track_names.has("Vegas Overdrive")
	_check(not in_cup, "Vegas Overdrive is in no cup (so not in Versus)")
	_check(TrackCatalog.PRACTICE_TRACKS.has("Vegas Overdrive") and TrackCatalog.PRACTICE_TRACKS.has("Test Circuit"),
			"Practice offers Vegas Overdrive and the Test Circuit")
	_check(TrackCatalog.is_built("Vegas Overdrive"), "Vegas keeps its scene")


## Teleport (= a fall) onto another terrace: ahead on the descent and
## behind on the climb. Each time the car is put back at its last safe
## point, facing along the road.
func _test_terrace_guard(race: RaceManager) -> void:
	var track := race.track
	var me := race.player.vehicle
	await _frames(30)
	for case in [[1800.0, 2010.0, "dropped ahead onto a lower terrace"], [1100.0, 880.0, "dropped back onto a lower terrace"]]:
		var from: float = case[0]
		var to: float = case[1]
		me.teleport(track.get_safe_transform(from))
		await _frames(2)
		me.recovery.set_track(track, from)
		me.recovery.last_reason = ""
		await _frames(40)
		var safe := me.recovery.last_safe_offset
		me.teleport(track.get_safe_transform(to))
		var frames := 0
		while frames < 120 and me.recovery.last_reason == "":
			await physics_frame
			frames += 1
		_check(me.recovery.last_reason == "off route", "%s: recovered (%s)" % [case[2], me.recovery.last_reason])
		await _frames(150)
		var here := track.get_offset_at(me.global_position)
		var back := track.wrapped_delta(safe, here)
		_check(back > -20.0 and back < 60.0, "%s: back by the safe point (%.0f m from it)" % [case[2], back])
		var fwd := -me.global_transform.basis.z
		var road := track.get_direction_at(me.global_position)
		_check(fwd.dot(road) > 0.8, "%s: facing the right way (%.2f)" % [case[2], fwd.dot(road)])


## The full field through the opening lap: everyone gets round, through the
## window, without piling up at the first hairpin or the window.
func _test_opening_lap(race: RaceManager) -> void:
	var track := race.track
	var at_h1 := [0]
	var at_window := [0]
	var other := [0]
	var reasons := {}
	for racer in race.racers:
		var car := racer.vehicle
		car.recovery.recovered.connect(func(reason: String) -> void:
			var o := track.get_offset_at(car.global_position)
			var h1: Array = MarbleCanyonScenery.HAIRPINS["H1"]
			if o > h1[0] - 120.0 and o < h1[1] + 40.0:
				at_h1[0] += 1
			elif absf(o - MarbleCanyonScenery.WINDOW_OFFSET) < 120.0:
				at_window[0] += 1
			else:
				other[0] += 1
			reasons[reason] = int(reasons.get(reason, 0)) + 1)
	var through := {}
	var frames := 0
	while frames < 60 * 160 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
		if frames % 10 == 0:
			for racer in race.racers:
				var o := track.get_offset_at(racer.vehicle.global_position)
				if absf(o - MarbleCanyonScenery.WINDOW_OFFSET) < 10.0:
					through[racer.display_name] = true
	var times: Array[String] = []
	for racer in race.get_standings():
		times.append(RaceProgress.format_time(racer.finish_time))
	print("    1 lap: %.1f s; times %s; recoveries H1 %d, window %d, elsewhere %d %s" % [
			frames / 60.0, times, at_h1[0], at_window[0], other[0], reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish the lap")
	_check(through.size() == 8, "all 8 drove through the window (%d)" % through.size())
	_check(at_h1[0] <= 1, "no pile-up at the first hairpin (%d recoveries)" % at_h1[0])
	_check(at_window[0] == 0, "no pile-up at the window (%d recoveries)" % at_window[0])


func _test_full_race(race: RaceManager) -> void:
	var recoveries := [0]
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var frames := 0
	while frames < 60 * 400 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var times: Array[String] = []
	for racer in race.get_standings():
		times.append(RaceProgress.format_time(racer.finish_time))
	print("    race %.1f s simulated; times %s; recoveries %d" % [frames / 60.0, times, recoveries[0]])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	# The last car is classified when the rest are home; everyone who
	# crossed the line passed every gate.
	var finishers := race.racers.filter(func(r: RaceProgress) -> bool: return r.finish_time > 0.0)
	_check(finishers.size() >= 7 and finishers.all(func(r: RaceProgress) -> bool:
			return r.checkpoints_passed == 3 * race.track.checkpoint_count + 1), "every gate counted (%d finishers)" % finishers.size())
	_check(recoveries[0] <= 6, "few recoveries (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 285.0, "a 3-4.5 minute race: %s" % RaceProgress.format_time(winner.finish_time))
