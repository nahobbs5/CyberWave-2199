extends SceneTree
## Vale da Lua checks (GDD 8.6e): layout and the Behind the Falls shortcut,
## the elevated road with two open rock shelves, the rivers (crossing under
## the road well below it, waterfalls, one water recovery zone kept off the
## roads), boulders off the roads, the South America Cup (race 2), falling
## off a shelf into the creek, a lap with everyone on the shortcut and a full
## 8-car race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_vale_da_lua.gd

const TRACK := "res://scenes/tracks/vale_da_lua.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/south_america_circuit.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_vale_profile.json"
	GameSettings.path = "user://test_vale_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	await _run("falling off a shelf into the creek", _test_shelf_fall, _config())
	var forced := _config()
	forced.total_laps = 1
	await _run("everyone goes Behind the Falls (1 lap)", _test_forced_shortcut, forced)
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
	config.track_name = "Vale da Lua"
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
	print("- layout, rivers, rock")
	var t0 := Time.get_ticks_msec()
	var track := (load(TRACK) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var build_ms := Time.get_ticks_msec() - t0
	await physics_frame
	await physics_frame
	print("    built in %d ms" % build_ms)
	_check(build_ms < 8000, "builds in under 8 s headless (%d ms)" % build_ms)
	_check(track.length > 2900.0 and track.length < 3200.0, "about 3.1 km (%.0f m)" % track.length)
	_check(track.road_width == 13.0, "13 m road")
	_check(track.shortcuts.size() == 1, "one shortcut")
	var sc := track.shortcuts[0]
	_check(sc.display_name == "Behind the falls" and sc.road_width == 9.0, "Behind the Falls, 9 m wide")
	_check(sc.length < sc.span - 100.0, "the shortcut saves 100+ m (%.0f vs %.0f)" % [sc.length, sc.span])
	_check(track.elevated and track.open_edges.size() == 2, "an elevated road with two open rock shelves")
	# No barrier across either route.
	var space := track.get_world_3d().direct_space_state
	var blocked := []
	for route in ["main", "shortcut"]:
		var total := track.length if route == "main" else sc.length
		var d := 0.0
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
	_check(track.get_node("_GenCornerSigns").get_child_count() >= 18, "corner signs on the bends")
	var scenery := track.get_node("Scenery") as ValeDaLuaScenery
	_check(scenery.river_crossings >= 3, "rivers pass under the road (%d crossings)" % scenery.river_crossings)
	var shallowest := -INF
	for y in scenery.crossing_depths:
		shallowest = maxf(shallowest, y)
	_check(shallowest <= -4.0, "the water is at least 4 m below every bridge (%.1f m)" % shallowest)
	_check(scenery.waterfalls >= 3, "waterfalls (%d)" % scenery.waterfalls)
	_check(track.find_children("Water_*", "MeshInstance3D", true, false).size() >= 4, "moving water in every river")
	var on_road := 0
	for i in scenery.boulder_origins.size():
		if scenery.edge_distance(scenery.boulder_origins[i]) < scenery.boulder_radii[i] * 0.5:
			on_road += 1
	_check(scenery.boulder_count() > 300 and on_road == 0, "sculpted boulders (%d), none on a road (%d)" % [scenery.boulder_count(), on_road])
	# One water zone, never over a road.
	var zones := track.find_children("*", "RecoveryZone", true, false)
	_check(zones.size() == 1 and zones[0].get_child_count() > 5, "one water recovery zone along the rivers")
	var wet_road := 0
	if zones.size() == 1:
		var zone := zones[0] as RecoveryZone
		var d := 0.0
		while d < track.length:
			for lateral: float in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
				if zone.has_point(track.get_safe_transform(d, lateral, 0.6).origin):
					wet_road += 1
			d += 2.0
		d = 0.0
		while d < sc.length:
			if zone.has_point(track.to_global(sc.point_at(d)) + Vector3.UP * 0.6):
				wet_road += 1
			d += 2.0
	_check(wet_road == 0, "the water zone never reaches a road (%d samples)" % wet_road)
	_check(scenery.is_roofed(track.to_local(track.to_global(sc.point_at(sc.length * 0.4)))) or scenery.is_roofed(ValeDaLuaScenery.OVERHANG_CENTRE),
			"the shortcut ledge runs under the overhang")
	var features := track.find_children("*", "TrackFeature", false, false)
	_check(features.size() == 7, "7 track features (%d)" % features.size())
	track.queue_free()
	await process_frame


func _test_cup() -> void:
	_current = "cup"
	print("- South America Cup")
	var cup := load(CUP) as GrandPrixData
	_check(cup.track_names[1] == "Vale da Lua" and cup.is_track_built(1), "race 2 is Vale da Lua")
	_check(cup.track_names[2] == "Choquequirao" and cup.is_track_built(2), "race 3 is Choquequirao")
	_check(not cup.is_open(true) and cup.is_open(false), "locked for Grand Prix, open in Versus")
	_check(TrackCatalog.scene_path("Vale da Lua") == TRACK and TrackCatalog.location("Vale da Lua").contains("Brazil"),
			"in the track catalogue (Brazil)")


## Off the open edge of a shelf: down into the creek, a splash, back on the road.
func _test_shelf_fall(race: RaceManager) -> void:
	var track := race.track
	var me := race.player.vehicle
	await _frames(30)
	var e := track.open_edges[0]
	var mid := (e.x + e.y) * 0.5
	me.teleport(track.get_safe_transform(mid, signf(e.z) * (track.road_width * 0.5 + 5.0), 1.0))
	var fell := false
	var frames := 0
	while frames < 300 and me.recovery.last_reason == "":
		fell = fell or me.global_position.y < -2.0
		await physics_frame
		frames += 1
	_check(fell, "the car drops off the shelf")
	_check(me.recovery.last_reason == "water", "and splashes into the creek (%s)" % me.recovery.last_reason)
	await _frames(150)
	_check(track.is_on_road(me.global_position) and me.global_position.y > -0.5 and me.global_position.y < 3.0,
			"back on the road (y %.1f)" % me.global_position.y)


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
	print("    1 lap Behind the Falls: %.1f s simulated" % (frames / 60.0))
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
