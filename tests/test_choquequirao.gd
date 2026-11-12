extends SceneTree
## Choquequirao checks (GDD 8.6f): the double-spiral layout (start outside,
## reach the plaza, inbound and outbound lanes alternating ring by ring), the
## Inca gateways the road drives through, the village houses (mostly roofless
## ruins, some thatched, none on a road), terraces, qolqas, the sunny sky, the
## South America Cup (race 3), a lap with everyone on the Qolqa shortcut and
## a full 8-car race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_choquequirao.gd

const TRACK := "res://scenes/tracks/choquequirao.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/south_america_circuit.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_choq_profile.json"
	GameSettings.path = "user://test_choq_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	var forced := _config()
	forced.total_laps = 1
	await _run("everyone takes the Qolqa storehouses (1 lap)", _test_forced_shortcut, forced)
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
	config.track_name = "Choquequirao"
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


## Which spiral arm a main-loop offset is on: "in", "out", "plaza" or "valley".
func _arm(scenery: ChoquequiraoScenery, offset: float) -> String:
	var o: Dictionary = scenery.section_offsets
	if offset >= o["in"] and offset < o.s_start:
		return "in"
	if offset >= o.s_start and offset < o.s_end:
		return "plaza"
	if offset >= o.s_end and offset < o.out:
		return "out"
	return "valley"


func _test_layout() -> void:
	_current = "layout"
	print("- layout, gateways, village")
	# The first build in a run pays one-time texture and resource loads
	# (seconds, and much slower on a busy machine); time a second one.
	var t0 := Time.get_ticks_msec()
	var cold := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(cold)
	var cold_ms := Time.get_ticks_msec() - t0
	cold.queue_free()
	await process_frame
	t0 = Time.get_ticks_msec()
	var track := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var build_ms := Time.get_ticks_msec() - t0
	await physics_frame
	await physics_frame
	print("    built in %d ms (first build %d ms)" % [build_ms, cold_ms])
	_check(build_ms < 8000, "builds in under 8 s headless (%d ms)" % build_ms)
	_check(track.length > 3000.0 and track.length < 3350.0, "about 3.2 km (%.0f m)" % track.length)
	_check(track.road_width == 12.0, "12 m road")
	var flat := true
	for p in track.control_points:
		flat = flat and p.y == 0.0
	_check(flat, "flat, like every track")
	_check(track.shortcuts.size() == 1, "one shortcut")
	var sc := track.shortcuts[0]
	_check(sc.display_name == "Qolqa storehouses" and sc.road_width == 9.0, "the Qolqa storehouses lane, 9 m wide")
	_check(sc.length < sc.span - 100.0, "the shortcut saves 100+ m (%.0f vs %.0f)" % [sc.length, sc.span])
	var scenery := track.get_node("Scenery") as ChoquequiraoScenery
	var o: Dictionary = scenery.section_offsets
	_check(o["in"] < o.s_start and o.s_start < o.plaza and o.plaza < o.s_end and o.s_end < o.out,
			"in through the gate, spiral in, the plaza S, spiral out, out through the gate")

	# Start outside the village, reach the middle of the plaza.
	var start := track.curve.sample_baked(track.start_line_offset)
	_check(_arm(scenery, track.start_line_offset) == "valley" and Vector2(start.x, start.z).length() > 150.0,
			"the start line is outside the village (%.0f m from the plaza)" % Vector2(start.x, start.z).length())
	var centre := track.curve.get_closest_point(Vector3.ZERO)
	_check(Vector2(centre.x, centre.z).length() < 3.0, "the road crosses the centre of the plaza")

	# Labyrinth rings: beside an inbound lane is an outbound one (or the
	# plaza / the valley), never another inbound lane, and vice versa.
	var same_arm := 0
	var neighbours := 0
	var d: float = o["in"] + 30.0
	while d < o.out - 30.0:
		var arm := _arm(scenery, d)
		if arm == "in" or arm == "out":
			var c := track.curve.sample_baked(d)
			var tangent := track.get_tangent_at(d)
			var right := tangent.cross(Vector3.UP).normalized()
			for side in [-1.0, 1.0]:
				var t := 8.0
				while t < 45.0:
					var p: Vector3 = c + right * side * t
					var q := track.curve.get_closest_point(p)
					if Vector2(q.x - c.x, q.z - c.z).length() > 18.0:
						var other := _arm(scenery, track.curve.get_closest_offset(q))
						neighbours += 1
						if other == arm:
							same_arm += 1
						break
					t += 1.0
		d += 15.0
	_check(neighbours > 150 and same_arm == 0, "inbound and outbound lanes alternate ring by ring (%d of %d beside their own arm)" % [same_arm, neighbours])

	# Lanes never closer than 24 m (centre to centre) except where they meet.
	var pts: Array[Vector3] = []
	d = 0.0
	while d < track.length:
		pts.append(track.curve.sample_baked(d))
		d += 4.0
	var closest := INF
	for i in pts.size():
		for j in range(i + 30, pts.size()):
			if pts.size() - (j - i) < 30:
				continue
			closest = minf(closest, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	_check(closest >= 24.0, "lanes stay 24 m+ apart (%.1f m)" % closest)

	# No barrier across either route.
	var space := track.get_world_3d().direct_space_state
	var blocked := []
	for route in ["main", "shortcut"]:
		var total := track.length if route == "main" else sc.length
		d = 0.0
		while d < total:
			var a: Vector3
			var b: Vector3
			if route == "main":
				a = track.get_center_at(d) + Vector3.UP
				b = track.get_center_at(d + 8.0) + Vector3.UP
			else:
				a = track.to_global(sc.point_at(d)) + Vector3.UP
				b = track.to_global(sc.point_at(minf(d + 8.0, sc.length))) + Vector3.UP
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
			if not hit.is_empty() and hit.collider.name.begins_with("_GenBarriers"):
				blocked.append("%s@%.0f" % [route, d])
			d += 8.0
	_check(blocked.is_empty(), "no barrier blocks the main road or the shortcut (%s)" % [blocked])

	# Gateways the road drives through.
	_check(scenery.gates.size() >= 6, "the road drives through %d gateways" % scenery.gates.size())
	var plaza_gates := 0
	var clear_ok := true
	for g in scenery.gates:
		var opening: Vector3 = g[1]
		clear_ok = clear_ok and opening.x > track.road_width * 0.5 + track.barrier_thickness + 0.5 \
				and opening.y > track.road_width * 0.5 and opening.z > track.flight_height + 3.0
		if absf(track.wrap_offset(g[0]) - o.plaza) < (o.s_end - o.s_start) * 0.5 + 25.0:
			plaza_gates += 1
		if _arm(scenery, track.wrap_offset(g[0])) == "valley":
			clear_ok = false
	_check(clear_ok, "every gateway is inside the village and clears the road, barriers and Overdrive flight")
	_check(plaza_gates >= 4, "a run of gateways in, across and out of the plaza (%d)" % plaza_gates)

	# The village: houses on the terraces, mostly roofless, never on a road.
	var b := scenery.buildings
	print("    %d buildings (%d thatched, %d ruined), %d qolqas, %d terrace risers" % [b.houses, b.roofed, b.ruined, scenery.qolqas, scenery.terrace_risers])
	_check(b.houses >= 60, "a village of houses (%d)" % b.houses)
	_check(b.roofed >= 5 and b.roofed * 3 < b.houses, "mostly roofless, some thatched (%d of %d)" % [b.roofed, b.houses])
	_check(b.ruined >= 5, "some partly collapsed (%d)" % b.ruined)
	var on_road := 0
	for f in b.footprints:
		var xf: Transform3D = f[0]
		var size: Vector2 = f[1]
		for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5), Vector3.ZERO]:
			var p: Vector3 = xf * Vector3(corner.x * size.x, 0, corner.z * size.y)
			if scenery.edge_distance(Vector3(p.x, 0, p.z)) < 1.0:
				on_road += 1
	_check(on_road == 0, "no building stands on a road or barrier (%d corners)" % on_road)
	_check(scenery.plaza_buildings == 2, "the great hall and the usnu on the plaza")
	_check(scenery.qolqas >= 8, "a row of qolqa storehouses by the shortcut (%d)" % scenery.qolqas)
	_check(scenery.terrace_risers > 1000, "stone terraces along the lanes and up the valley")
	_check(scenery.terrace_height(ChoquequiraoScenery.Section.VILLAGE, 5.0) == ChoquequiraoScenery.STEP_H
			and scenery.terrace_height(ChoquequiraoScenery.Section.LOBE, 5.0) == 0.0,
			"the village lanes run between terraces, the valley floor is open")
	var low_banks := true
	d = 0.0
	while d < track.length:
		var p := track.curve.sample_baked(d)
		low_banks = low_banks and scenery.ground_y(p.x, p.z) < 0.05
		d += 25.0
	_check(low_banks, "the ground never rises over the road")
	_check(scenery.ground_y(600, -600) > 150.0, "the valley walls climb to mountains")

	# A bright sunny day.
	var env := (track.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as PanoramaSkyMaterial
	_check(sky != null and sky.panorama.resource_path.contains("partly_cloudy"), "a blue sky with fair-weather clouds")
	var sun := track.get_node("Sun") as DirectionalLight3D
	_check(sun.shadow_enabled and sun.light_energy >= 1.8 and -sun.global_transform.basis.z.y < -0.6, "a high, strong sun")
	_check(track.get_node("_GenCornerSigns").get_child_count() > 0, "corner signs on the tight bends")
	_check(track.find_children("*", "TrackFeature", false, false).filter(func(f: TrackFeature) -> bool: return not f.pattern_copy).size() == 5, "5 track features")
	track.queue_free()
	await process_frame


func _test_cup() -> void:
	_current = "cup"
	print("- South America Cup")
	var cup := load(CUP) as GrandPrixData
	_check(cup.race_count() == 3 and cup.track_names[2] == "Choquequirao" and cup.is_track_built(2), "race 3 is Choquequirao")
	_check(cup.is_open(true) and cup.is_open(false), "open for Grand Prix and Versus")
	_check(TrackCatalog.scene_path("Choquequirao") == TRACK and TrackCatalog.location("Choquequirao").contains("Peru"),
			"in the track catalogue (Peru)")


func _test_forced_shortcut(race: RaceManager) -> void:
	var sc := race.track.shortcuts[0]
	sc.ai_chance = 1.0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			ai.difficulty = ai.difficulty.duplicate()
			ai.difficulty.shortcut_chance = 2.0
	var frames := 0
	while frames < 60 * 220 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var taken := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			taken += ai.shortcuts_taken
	print("    1 lap via the qolqas: %.1f s simulated" % (frames / 60.0))
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes via the shortcut")
	_check(taken >= 8, "all eight took it (%d)" % taken)


func _test_full_race(race: RaceManager) -> void:
	var recoveries := [0]
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var frames := 0
	while frames < 60 * 420 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var taken := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			taken += ai.shortcuts_taken
	var times: Array[String] = []
	for racer in race.get_standings():
		times.append(RaceProgress.format_time(racer.finish_time))
	print("    race %.1f s simulated; times %s; shortcuts taken %d; recoveries %d" % [frames / 60.0, times, taken, recoveries[0]])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	_check(taken > 0, "the AI used the shortcut (%d times)" % taken)
	_check(recoveries[0] <= 4, "few recoveries (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 330.0, "a 3-5 minute race: %s" % RaceProgress.format_time(winner.finish_time))
	await process_frame
