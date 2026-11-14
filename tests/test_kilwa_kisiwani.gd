extends SceneTree
## Kilwa Kisiwani Ruins checks (GDD 8.6g): the right-angle maze layout (wide
## road, many near-90-degree corners), the hypostyle hall's columns standing
## in the road (colliders, wide gaps, racing line and recovery steering
## clear of them), the two shortcuts, the village / ruins split, the Great
## Mosque, palace and fort dressing, the late-afternoon overcast light, the
## Africa Cup (race 1), a lap with everyone on both shortcuts and a full
## 8-car race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_kilwa_kisiwani.gd

const TRACK := "res://scenes/tracks/kilwa_kisiwani.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/africa_circuit.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_kilwa_profile.json"
	GameSettings.path = "user://test_kilwa_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	var forced := _config()
	forced.total_laps = 1
	await _run("everyone takes both shortcuts (1 lap)", _test_forced_shortcuts, forced)
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
	config.track_name = "Kilwa Kisiwani Ruins"
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


func _test_layout() -> void:
	_current = "layout"
	print("- layout, columns, ruins")
	# The first build in a run pays one-time texture and resource loads; time a second one.
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
	var scenery := track.get_node("Scenery") as KilwaScenery
	_check(build_ms < 8000, "builds in under 8 s headless (%d ms)" % build_ms)
	_check(track.length > 2900.0 and track.length < 3300.0, "about 3 km (%.0f m)" % track.length)
	_check(track.road_width == 22.0, "a wide 22 m road")

	# A maze of right angles: count the corners (heading turns 70-110 deg
	# within 45 m).
	var corners := 0
	var d := 0.0
	var last_corner := -100.0
	while d < track.length:
		var a := track.get_tangent_at(d)
		var b := track.get_tangent_at(d + 45.0)
		var turn := rad_to_deg(a.angle_to(b))
		if turn > 70.0 and turn < 110.0 and d - last_corner > 40.0:
			corners += 1
			last_corner = d
		d += 3.0
	_check(corners >= 18, "a maze of right-angle corners (%d)" % corners)

	# Columns in the road: colliders, wide gaps, nothing spawns on them.
	_check(track.road_columns.size() >= 15 and track.column_spots.size() == track.road_columns.size(),
			"%d columns stand in the road" % track.road_columns.size())
	var narrowest := INF
	for c in track.column_spots:
		narrowest = minf(narrowest, track.road_width * 0.5 - absf(c.y) - c.z)
		for other in track.column_spots:
			if other != c and absf(track.wrapped_delta(c.x, other.x)) < 1.0:
				narrowest = minf(narrowest, absf(c.y - other.y) - c.z - other.z)
	_check(narrowest >= 9.0, "every gap beside a column is 9 m+ (%.1f m)" % narrowest)
	var hall_rect := KilwaScenery.HALL
	var in_hall := track.road_columns.size() > 0
	for c in track.road_columns:
		in_hall = in_hall and hall_rect.has_point(Vector2(c.x, c.y))
	_check(in_hall, "the columns are all in the Great Mosque's hall")
	var space := track.get_world_3d().direct_space_state
	var c0 := track.road_columns[0]
	var probe := PhysicsRayQueryParameters3D.create(track.to_global(Vector3(c0.x - 3.0, 1.0, c0.y)),
			track.to_global(Vector3(c0.x + 3.0, 1.0, c0.y)), 1)
	var col_hit := space.intersect_ray(probe)
	_check(not col_hit.is_empty() and col_hit.collider.name.begins_with("_GenColumns"), "a column is solid")
	var line := RacingLine.new(track, VehicleStats.new())
	var clearance := INF
	for c in track.column_spots:
		for k in range(-2, 3):
			clearance = minf(clearance, absf(line.lateral_at(c.x + k) - c.y) - c.z)
	_check(clearance >= 2.0, "the AI racing line passes the columns with room (%.1f m)" % clearance)
	var spot_ok := true
	for c in track.column_spots:
		var lat := track.dodge_columns(c.x, c.y, 2.5)
		var p := track.to_local(track.get_safe_transform(c.x, lat).origin)
		spot_ok = spot_ok and track.column_near(p, 1.4) < 0
		var route := track.to_local(track.get_safe_transform(c.x, track.column_route_lateral(c.x)).origin)
		spot_ok = spot_ok and track.column_near(route, 1.4) < 0
	_check(spot_ok, "recovery spots and the Overdrive route steer round every column")
	var items_ok := true
	for row in track.crate_row_offsets:
		for lat in track.crate_lateral_positions:
			items_ok = items_ok and track.column_near(track.to_local(track.get_safe_transform(row, lat).origin), 2.0) < 0
	# Coins get a random layout every lap: try plenty of them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	for n in 200:
		for spot in TrackCoins.scatter_spots(track, track.coin_offsets.size(), rng):
			var p := track.to_local(track.get_safe_transform(spot.x, spot.y).origin)
			items_ok = items_ok and track.column_near(p, 2.0) < 0
	_check(items_ok, "no crate or coin sits on a column")

	# Two shortcuts.
	_check(track.shortcuts.size() == 2, "two shortcuts")
	var names := []
	for sc in track.shortcuts:
		names.append(sc.display_name)
		_check(sc.length < sc.span - 75.0, "%s saves 75+ m (%.0f vs %.0f)" % [sc.display_name, sc.length, sc.span])
	_check(names.has("Gereza fort yard") and names.has("Small Domed Mosque aisle"), "the fort yard and the domed aisle")

	# No barrier across either route (columns aside).
	var blocked := []
	for route in [null] + track.shortcuts:
		var sc := route as TrackShortcut
		var total := track.length if sc == null else sc.length
		d = 0.0
		while d < total:
			var a: Vector3
			var b: Vector3
			if sc == null:
				a = track.get_center_at(d) + Vector3.UP
				b = track.get_center_at(d + 8.0) + Vector3.UP
			else:
				a = track.to_global(sc.point_at(d)) + Vector3.UP
				b = track.to_global(sc.point_at(minf(d + 8.0, sc.length))) + Vector3.UP
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
			if not hit.is_empty() and hit.collider.name.begins_with("_GenBarriers"):
				blocked.append("%s@%.0f" % ["main" if sc == null else sc.display_name, d])
			d += 8.0
	_check(blocked.is_empty(), "no barrier blocks the main road or a shortcut (%s)" % [blocked])

	# A little village, mostly ruins; the hall and the palace gallery roofed.
	var metres := [0, 0, 0, 0, 0]
	var roofed := 0
	d = 0.0
	while d < track.length:
		metres[scenery.section_at(d)] += 1
		if scenery.is_roofed(track.curve.sample_baked(d)):
			roofed += 1
		d += 1.0
	var village := float(metres[KilwaScenery.Section.VILLAGE]) / track.length
	_check(village > 0.15 and village < 0.3, "a little of the lap in the village (%.0f%%)" % (village * 100.0))
	_check(float(roofed) / track.length > 0.18, "under the vaults for a fifth of the lap (%.0f%%)" % (100.0 * roofed / track.length))
	_check(scenery.section_at(track.start_line_offset) == KilwaScenery.Section.VILLAGE, "the start is in the village")
	_check(scenery.is_roofed(Vector3(c0.x, 0, c0.y)) or scenery.hall.contains(Vector3(c0.x, 0, c0.y)), "the columns stand under the hall")
	_check(track.flight_height_at(track.curve.get_closest_offset(Vector3(c0.x, 0, c0.y))) <= track.roofed_flight_height,
			"Overdrive flies low under the hall's ceiling")

	# The Great Mosque.
	var hall := scenery.hall
	_check(hall.road_piers == track.road_columns.size(), "every road column is drawn as a pier")
	_check(hall.free_piers >= 60 and hall.arches >= 150, "a forest of piers (%d) and pointed arches (%d)" % [hall.free_piers, hall.arches])
	_check(hall.domes >= 10, "domed bays (%d)" % hall.domes)
	_check(hall.collapsed.size() >= 3, "collapsed bays open to the sky (%d)" % hall.collapsed.size())
	_check(hall.collapsed.has(Vector2i(7, 5)), "the fallen dome with its tree")
	var dome_over_aisle := true
	for gx in range(6, 10):
		dome_over_aisle = dome_over_aisle and not hall.collapsed.has(Vector2i(gx, 9))
	_check(dome_over_aisle, "small domes over the side aisle")
	# Houses, towers, cannons, crenellations, niches.
	var houses := scenery.houses
	_check(houses.houses >= 120, "a village of houses (%d)" % houses.houses)
	_check(houses.thatched * 2 > houses.houses and houses.ruined >= 10, "mostly makuti-thatched, some ruined (%d / %d of %d)"
			% [houses.thatched, houses.ruined, houses.houses])
	_check(scenery.cannons >= 3, "cannons in the fort yard (%d)" % scenery.cannons)
	_check(scenery.towers >= 5, "towers and portals (%d)" % scenery.towers)
	_check(scenery.merlons >= 300, "stepped crenellations (%d merlons)" % scenery.merlons)
	_check(scenery.niches >= 60, "pointed niches in the walls (%d)" % scenery.niches)
	_check(scenery.baobabs >= 3 and scenery.flame_trees >= 2 and scenery.palms >= 200,
			"baobabs, flame trees and palms (%d, %d, %d)" % [scenery.baobabs, scenery.flame_trees, scenery.palms])
	_check(scenery.dhows >= 2, "dhows on the channel")
	_check(scenery.ground_y(0, -700) < -2.0 and scenery.ground_y(-300, 100) > -0.5, "the sea to the north, dry land in the village")

	# Late afternoon, mildly overcast.
	var env := (track.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as PanoramaSkyMaterial
	_check(sky != null and sky.panorama.resource_path.contains("overcast"), "an overcast sky")
	var sun := track.get_node("Sun") as DirectionalLight3D
	var elevation := rad_to_deg(asin(-(-sun.global_transform.basis.z).y))
	_check(sun.shadow_enabled and elevation > 12.0 and elevation < 32.0, "a low late-afternoon sun (%.0f deg up)" % elevation)
	_check(sun.light_color.r > sun.light_color.b + 0.25, "warm light")
	_check(track.get_node("_GenCornerSigns").get_child_count() > 0, "corner signs on the tight bends")
	_check(track.find_children("*", "TrackFeature", false, false).filter(func(f: TrackFeature) -> bool: return not f.pattern_copy).size() == 6, "6 track features")
	track.queue_free()
	await process_frame


func _test_cup() -> void:
	_current = "cup"
	print("- Africa Cup")
	var cup := load(CUP) as GrandPrixData
	_check(GrandPrixData.CUPS.has(CUP) and GrandPrixData.CUPS[-1] == CUP, "the Africa Cup is the last cup")
	_check(cup.display_name == "Africa Cup" and cup.emblem == "africa", "named Africa Cup, with a map of Africa")
	_check(cup.track_names[0] == "Kilwa Kisiwani Ruins" and cup.is_track_built(0), "race 1 is Kilwa Kisiwani Ruins")
	_check(cup.is_open(true) and cup.is_open(false), "open for Grand Prix and Versus (all three races built)")
	_check(TrackCatalog.scene_path("Kilwa Kisiwani Ruins") == TRACK
			and TrackCatalog.location("Kilwa Kisiwani Ruins").contains("Tanzania"), "in the track catalogue (Tanzania)")
	var shapes := TrophyIcon.africa_polygons(Rect2(0, 0, 100, 100))
	_check(shapes.size() == 2 and shapes[0].size() >= 30 and not Geometry2D.triangulate_polygon(shapes[0]).is_empty()
			and not Geometry2D.triangulate_polygon(shapes[1]).is_empty(), "the trophy map: Africa and Madagascar")
	_check(CupBadge.COLORS.has("africa"), "badge colours for the Africa Cup")


func _test_forced_shortcuts(race: RaceManager) -> void:
	for sc in race.track.shortcuts:
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
	print("    1 lap via both shortcuts: %.1f s simulated; %d taken" % [frames / 60.0, taken])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes via the shortcuts")
	_check(taken >= 14, "nearly every car took both (%d of 16)" % taken)


func _test_full_race(race: RaceManager) -> void:
	var recoveries := [0]
	var reasons := {}
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(r: String) -> void:
			recoveries[0] += 1
			reasons[r] = int(reasons.get(r, 0)) + 1)
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
	print("    race %.1f s simulated; times %s; shortcuts taken %d; recoveries %d %s" % [frames / 60.0, times, taken,
			recoveries[0], reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	_check(taken > 0, "the AI used the shortcuts (%d times)" % taken)
	_check(recoveries[0] <= 5, "few recoveries, so the AI threads the columns (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 330.0, "a 3-5 minute race: %s" % RaceProgress.format_time(winner.finish_time))
	await process_frame
