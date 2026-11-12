extends SceneTree
## Parque Quinta Normal Greenhouse checks (GDD 8.10): layout and shortcut,
## the Rotunda roundabout (about 310 degrees round the plinth), the glass
## roofs, scenery off the roads, the South America Cup (open for Grand
## Prix, Greenhouse raceable in Versus), a lap with everyone on the Fern
## Wing shortcut and a full 8-car race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_quinta_normal.gd

const TRACK := "res://scenes/tracks/quinta_normal.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/south_america_circuit.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_quinta_profile.json"
	GameSettings.path = "user://test_quinta_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	var forced := _config()
	forced.total_laps = 1
	await _run("everyone takes the Fern Wing (1 lap)", _test_forced_shortcut, forced)
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
	config.track_name = "Parque Quinta Normal"
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
	print("- layout, roundabout, glasshouses")
	var t0 := Time.get_ticks_msec()
	var track := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var build_ms := Time.get_ticks_msec() - t0
	await physics_frame
	await physics_frame
	print("    built in %d ms" % build_ms)
	_check(build_ms < 8000, "builds in under 8 s headless (%d ms)" % build_ms)
	_check(track.length > 2950.0 and track.length < 3300.0, "about 3.1 km (%.0f m)" % track.length)
	_check(track.road_width == 13.0, "13 m road")
	_check(track.shortcuts.size() == 1, "one shortcut")
	var sc := track.shortcuts[0]
	_check(sc.display_name == "Fern Wing" and sc.road_width == 9.0, "the Fern Wing, 9 m wide")
	_check(sc.length < sc.span - 90.0 and sc.length > sc.span - 150.0, "the shortcut saves 90-150 m (%.0f vs %.0f)" % [sc.length, sc.span])
	# The Rotunda roundabout: unwrap the angle round the plinth along the road.
	var c := QuintaNormalScenery.ROTUNDA
	var swept := 0.0
	var best := 0.0
	var min_r := INF
	var prev := NAN
	var d := 0.0
	while d < track.length:
		var p := track.get_center_at(d)
		var r := Vector2(p.x - c.x, p.z - c.z).length()
		if r < 55.0:
			var ang := atan2(p.z - c.z, p.x - c.x)
			if not is_nan(prev):
				swept += wrapf(ang - prev, -PI, PI)
				best = maxf(best, absf(swept))
			prev = ang
			min_r = minf(min_r, r)
		else:
			prev = NAN
			swept = 0.0
		d += 2.0
	_check(rad_to_deg(best) > 280.0, "the roundabout sweeps most of the way round the plinth (%.0f deg)" % rad_to_deg(best))
	_check(min_r > QuintaNormalScenery.PLINTH_R + 18.0, "the road keeps well clear of the plinth (%.1f m)" % min_r)
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
	# Glass roofs: the start, the Rotunda and the Fern Wing are covered; the park isn't.
	var scenery := track.get_node("Scenery") as QuintaNormalScenery
	var whole_grid := true
	for slot in 8:
		whole_grid = whole_grid and scenery.is_roofed(track.to_local(track.get_grid_transform(slot).origin))
	_check(whole_grid and scenery.is_roofed(track.get_center_at(track.start_line_offset)), "the grid and the start line are under the main wing")
	_check(scenery.is_roofed(Vector3(-100, 0, -40)) and scenery.is_roofed(Vector3(200, 0, -40)), "both main wing spans are roofed")
	_check(not scenery.is_roofed(Vector3(57, 0, -40)), "the courtyard between them is open")
	_check(scenery.is_roofed(c + Vector3(0, 0, 44)), "the Rotunda is roofed")
	_check(scenery.is_roofed(track.to_global(sc.point_at(sc.length * 0.5))), "the Fern Wing is roofed")
	_check(not scenery.is_roofed(Vector3(380, 0, 100)), "the avenue is open")
	var flight_wing := track.flight_height_at(track.start_line_offset + 20.0)
	_check(flight_wing <= track.roofed_flight_height + 0.01, "Overdrive flies low under the glass (%.1f m)" % flight_wing)
	# The vault clears the start gantry: ribs at the road's edge are high enough.
	var arc_at_edge := QuintaNormalScenery.WING_WALL + QuintaNormalScenery.WING_HALF * 0.85 \
			* sqrt(1.0 - pow((track.road_width * 0.5 + 1.0) / QuintaNormalScenery.WING_HALF, 2.0))
	_check(arc_at_edge > 11.0, "the wing's vault clears the gantry (%.1f m over the barrier)" % arc_at_edge)
	# Trees and the wire mesh keep off the roads.
	var on_road := 0
	var trees := 0
	for mm in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		var m := (mm as MultiMeshInstance3D).multimesh
		for i in m.instance_count:
			var o := (mm as Node3D).transform * m.get_instance_transform(i).origin
			trees += 1
			if scenery.edge_distance(o) < 3.0:
				on_road += 1
	_check(trees > 1000 and on_road == 0, "a park of trees (%d), none on a road (%d)" % [trees, on_road])
	var meshes := scenery.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool:
		return (n as MeshInstance3D).material_override == GlasshouseBuilder.mesh_material())
	_check(meshes.size() >= 8, "wire mesh everywhere (%d chunks)" % meshes.size())
	var features := track.find_children("*", "TrackFeature", false, false).filter(func(f: TrackFeature) -> bool: return not f.pattern_copy) # authored (not boost-pad pattern copies)
	_check(features.size() == 5, "5 track features (%d)" % features.size())
	track.queue_free()
	await process_frame


func _test_cup() -> void:
	_current = "cup"
	print("- South America Cup")
	var cup := load(CUP) as GrandPrixData
	_check(cup != null and cup.display_name == "South America Cup" and cup.emblem == "south_america", "the South America Cup")
	_check(GrandPrixData.CUPS.has(CUP), "listed with the other cups")
	_check(cup.track_names[0] == "Parque Quinta Normal" and cup.is_track_built(0), "race 1 is the Greenhouse")
	_check(cup.is_track_built(1) and cup.is_track_built(2), "races 2 (Vale da Lua) and 3 (Choquequirao) are built")
	_check(cup.is_open(true) and cup.is_open(false), "open for Grand Prix and Versus")
	_check(TrackCatalog.scene_path("Parque Quinta Normal") == TRACK and TrackCatalog.location("Parque Quinta Normal") == "Santiago, Chile",
			"in the track catalogue")
	var poly := TrophyIcon.south_america_polygon(Rect2(0, 0, 100, 60))
	_check(poly.size() > 40 and not Geometry2D.triangulate_polygon(poly).is_empty(), "the trophy's South America is a valid shape")


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
	print("    1 lap via the Fern Wing: %.1f s simulated" % (frames / 60.0))
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes via the shortcut")
	_check(taken >= 8, "all eight took it (%d)" % taken)


func _test_full_race(race: RaceManager) -> void:
	var recoveries := [0]
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var frames := 0
	while frames < 60 * 400 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
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
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.checkpoints_passed == 3 * race.track.checkpoint_count + 1),
			"every gate counted")
	_check(taken > 0, "the AI used the shortcut (%d times)" % taken)
	_check(recoveries[0] <= 4, "few recoveries (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 285.0, "a 3-4 minute race: %s" % RaceProgress.format_time(winner.finish_time))
