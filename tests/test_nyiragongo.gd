extends SceneTree
## Fires of Nyiragongo checks (GDD 8.6h): the first sloped track. The road
## drops about 60 m from the crater rim to the lava shelf by two switchback
## hairpins and climbs back out on a banked curve; cars drive on a collider
## that follows the sloped, banked road; the terrain hugs the road and falls
## away in cliffs; the lava lake and channel recover cars ("lava", items
## lost); the shortcut jumps the channel off a ramp; plumes stay clear of
## the roads; ash falls round the cameras; Africa Cup race 2; a lap with
## everyone on the jump and a full 8-car race.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_nyiragongo.gd

const TRACK := "res://scenes/tracks/nyiragongo.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"
const CUP := "res://resources/grand_prix/africa_circuit.tres"
const NAME := "Fires of Nyiragongo"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_nyiragongo_profile.json"
	GameSettings.path = "user://test_nyiragongo_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_layout()
	_test_cup()
	await _run("lava burns, and the jump clears the channel", _test_lava_and_jump, _config())
	var forced := _config()
	forced.total_laps = 1
	await _run("everyone takes the channel jump (1 lap)", _test_forced_shortcut, forced)
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


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _config() -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.track_name = NAME
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
	print("- layout, slopes, crater")
	# The first build in a run pays one-time loads; time a second one.
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
	var scenery := track.get_node("Scenery") as NyiragongoScenery
	_check(build_ms < 8000, "builds in under 8 s headless (%d ms)" % build_ms)
	_check(track.length > 3000.0 and track.length < 3400.0, "about 3.2 km (%.0f m)" % track.length)
	_check(track.sloped and track.road_width == 15.0, "a sloped track, 15 m road")

	# Heights: rim to shelf, a level start, gentle enough grades, a banked climb.
	var lo := INF
	var hi := -INF
	var steepest := 0.0
	var max_bank := 0.0
	var d := 0.0
	while d < track.length:
		var y := track.get_center_at(d).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		steepest = maxf(steepest, absf(track.get_center_at(d + 10.0).y - y) / 10.0)
		max_bank = maxf(max_bank, rad_to_deg(track.bank_at(d)))
		d += 5.0
	_check(hi - lo > 50.0, "the road drops %.0f m from the rim to the lava shelf" % (hi - lo))
	_check(steepest < 0.11, "no grade steeper than 11%% (%.1f%%)" % (steepest * 100.0))
	_check(max_bank >= 10.0 and max_bank <= 15.0, "the climb out is banked (%.1f deg)" % max_bank)
	var start_level := true
	for k in range(-60, 60, 10):
		start_level = start_level and absf(track.get_center_at(track.start_line_offset + k).y - track.get_center_at(track.start_line_offset).y) < 1.5
	_check(start_level and absf(track.get_center_at(track.start_line_offset).y) < 3.0, "the start straight is level, on the rim")
	_check(rad_to_deg(track.bank_at(track.start_line_offset)) < 0.5, "no banking at the start")

	# Shelves never overlap in plan (the minimap and scenery rely on it).
	var closest := INF
	var pts := PackedVector3Array()
	d = 0.0
	while d < track.length:
		pts.append(track.curve.sample_baked(d))
		d += 8.0
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var along := (j - i) * 8.0
			if along < 100.0 or track.length - along < 100.0:
				continue
			closest = minf(closest, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	_check(closest > 30.0, "separate stretches stay 30 m+ apart in plan (%.0f m)" % closest)
	# Two hairpins on the descent: heading turns ~180 degrees within 120 m.
	var hairpins := 0
	var last := -500.0
	d = 0.0
	while d < track.length:
		var turn := rad_to_deg(track.get_tangent_at(d).angle_to(track.get_tangent_at(d + 110.0)))
		if turn > 160.0 and d - last > 150.0:
			hairpins += 1
			last = d
		d += 5.0
	_check(hairpins == 2, "two switchback hairpins (%d)" % hairpins)

	# Cars drive on a collider that follows the sloped, banked road.
	var space := track.get_world_3d().direct_space_state
	var bad := 0
	var worst := 0.0
	var half := track.road_width * 0.5 - 1.0
	d = 0.0
	while d < track.length:
		for lat in [-half, 0.0, half]:
			var p := track.to_global(track.surface_point(d, lat))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 3.0, 1))
			if hit.is_empty() or not String(hit.collider.name).begins_with("_GenRoadSurface"):
				bad += 1
			else:
				worst = maxf(worst, absf((hit.position as Vector3).y - p.y))
		d += 6.0
	_check(bad <= 1 and worst < 0.35, "the road collider is under every point of the road (%d misses, %.2f m off)" % [bad, worst])

	# One shortcut: the channel jump, with a gap, a ramp before it and a speed floor.
	_check(track.shortcuts.size() == 1, "one shortcut")
	var sc := track.shortcuts[0]
	_check(sc.display_name == "Lava channel jump" and sc.length < sc.span - 90.0,
			"the channel jump saves 90+ m (%.0f vs %.0f)" % [sc.length, sc.span])
	_check(sc.gaps.size() == 1 and sc.gaps[0].y - sc.gaps[0].x >= 12.0 and sc.min_speed >= 25.0,
			"it has a 12 m+ gap and the AI commit to it")
	var gap_mid := track.to_global(sc.point_at((sc.gaps[0].x + sc.gaps[0].y) * 0.5))
	var gap_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(gap_mid + Vector3.UP * 2.0, gap_mid - Vector3.UP * 3.0, 1))
	_check(gap_hit.is_empty() and not track.is_on_road(gap_mid + Vector3.UP), "nothing to drive on in the gap")
	var ramp := track.get_node_or_null("ChannelRamp") as TrackFeature
	var lip := sc.local_offset(track.to_local(ramp.global_position)) + ramp.length * 0.5 if ramp != null else -1.0
	_check(ramp != null and ramp.kind == TrackFeature.Kind.JUMP_RAMP and ramp.on_shortcut == sc.name
			and absf(lip - sc.gaps[0].x) < 3.0, "a ramp's lip sits at the start of the gap")

	# No barrier across either route.
	var blocked := []
	for route in [null, sc]:
		var s := route as TrackShortcut
		var total := track.length if s == null else s.length
		d = 0.0
		while d < total - 8.0:
			if s != null and (s.in_gap(d) or s.in_gap(d + 8.0) or (d > s.gaps[0].x - 20.0 and d < s.gaps[0].y)):
				d += 8.0
				continue
			var a: Vector3
			var b: Vector3
			if s == null:
				a = track.get_center_at(d) + Vector3.UP
				b = track.get_center_at(d + 8.0) + Vector3.UP
			else:
				a = track.to_global(s.point_at(d)) + Vector3.UP
				b = track.to_global(s.point_at(d + 8.0)) + Vector3.UP
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
			if not hit.is_empty() and String(hit.collider.name).begins_with("_GenBarriers"):
				blocked.append("%s@%.0f" % ["main" if s == null else "jump", d])
			d += 8.0
	_check(blocked.is_empty(), "no barrier blocks the main road or the jump (%s)" % [blocked])

	# The crater: terrain hugs the road (never through it), cliffs between shelves.
	var poke := 0
	d = 0.0
	while d < track.length:
		for lat in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			var p := track.surface_point(d, lat)
			if scenery.ground_y(p.x, p.z) > p.y - 0.15:
				poke += 1
		d += 4.0
	_check(poke == 0, "the crater floor never pokes through the road (%d)" % poke)
	var between := Vector2(-302.0, 120.0) # between the first two descent shelves
	var upper := track.curve.get_closest_point(Vector3(-330.0, -10.0, 120.0)).y
	var lower := track.curve.get_closest_point(Vector3(-274.0, -30.0, 120.0)).y
	var g := scenery.ground_y(between.x, between.y)
	_check(upper - lower > 10.0 and g < upper and g > lower - 6.0, "a stepped wall between the shelves (%.0f, %.0f, %.0f)" % [upper, g, lower])
	_check(scenery.ground_y(0.0, -20.0) < NyiragongoScenery.LAKE_Y, "the lake floor is under the lava")
	var ledge := scenery.ground_y(NyiragongoScenery.LAKE_CENTRE.x + NyiragongoScenery.LAKE_RADIUS + 8.0, NyiragongoScenery.LAKE_CENTRE.y)
	_check(ledge > NyiragongoScenery.LAKE_Y + 4.0, "the lake lies in a pit below a black ledge (%.1f m down)" % (ledge - NyiragongoScenery.LAKE_Y))
	var north_rim := scenery.ground_y(0.0, -470.0)
	_check(north_rim > -10.0, "sheer walls up to a high rim: %.0f m above the lava shelf" % (north_rim + 60.0))
	_check(scenery.ground_y(0.0, 470.0) > 0.0 and scenery.ground_y(0.0, 470.0) < north_rim, "the start crosses the rim on a lower saddle")

	# Lava: lake and channel recover cars, never on a road; plumes clear of the roads.
	var zone := scenery.lava_zone
	_check(zone != null and zone.reason == "lava" and zone.get_child_count() > 20, "a lava zone over the lake and channel")
	var inside := 0
	d = 0.0
	while d < track.length:
		for lat in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if zone.has_point(track.get_safe_transform(d, lat, 0.6).origin):
				inside += 1
		d += 3.0
	var e := 0.0
	while e < sc.length:
		if not sc.in_gap(e) and zone.has_point(track.to_global(sc.point_at(e)) + Vector3.UP * 0.6):
			inside += 1
		e += 3.0
	_check(inside == 0, "no road point is in the lava (%d)" % inside)
	_check(zone.has_point(Vector3(gap_mid.x, NyiragongoScenery.CHANNEL_Y, gap_mid.z)), "lava under the jump")
	var plumes_clear := scenery.plumes.size() >= 3
	for plume in scenery.plumes:
		plumes_clear = plumes_clear and scenery.edge_distance(plume.position) > 100.0
	_check(plumes_clear, "%d plumes over the lake, 100 m+ from any road" % scenery.plumes.size())
	_check(scenery.ash != null and scenery.lake_mesh != null, "ash in the air and a lava lake")
	_check(scenery.spatter_cones >= 8 and scenery.pools >= 15 and scenery.boulders >= 300,
			"spatter cones, glowing pools and boulders (%d, %d, %d)" % [scenery.spatter_cones, scenery.pools, scenery.boulders])
	_check(scenery.scree >= 100 and scenery.columns >= 40, "scree under the walls and basalt columns (%d, %d)" % [scenery.scree, scenery.columns])
	_check(scenery.fountains.size() == NyiragongoScenery.VENTS.size(), "lava fountains at the vents")
	_check(track.find_children("Rocks_*", "MultiMeshInstance3D", true, false).size() > 0, "jagged rock meshes")
	_check(scenery.huts >= 3, "tin huts on the rim (%d)" % scenery.huts)

	# Dusk.
	var env := (track.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as PanoramaSkyMaterial
	_check(sky != null and sky.panorama.resource_path.contains("sunset") and sky.energy_multiplier < 0.6, "a dim dusk sky")
	var sun := track.get_node("Sun") as DirectionalLight3D
	var elevation := rad_to_deg(asin(-(-sun.global_transform.basis.z).y))
	_check(elevation > 5.0 and elevation < 25.0 and sun.light_color.r > sun.light_color.b + 0.4, "a low, warm sun (%.0f deg up)" % elevation)
	_check(env.fog_enabled and env.glow_enabled, "ash haze and lava glow")
	track.queue_free()
	await process_frame


func _test_cup() -> void:
	_current = "cup"
	print("- Africa Cup")
	var cup := load(CUP) as GrandPrixData
	_check(cup.race_count() == 2 and cup.track_names[1] == NAME and cup.is_track_built(1), "race 2 is Fires of Nyiragongo")
	_check(cup.track_scenes[1] == TRACK, "its scene")
	_check(TrackCatalog.scene_path(NAME) == TRACK and TrackCatalog.location(NAME).contains("Congo"), "in the track catalogue (D.R. Congo)")
	_check(not cup.is_open(true) and cup.is_open(false), "still locked for Grand Prix, open in Versus")


## The player's car into the lake: "lava", items gone. Then a straight run
## at the ramp at the jump's speed clears the channel and lands on the road.
func _test_lava_and_jump(race: RaceManager) -> void:
	var track := race.track
	var me := race.player.vehicle
	me.player_controlled = false
	# Drive it by hand: no autopilot steering or throttle.
	var autopilot := race.get_ai(race.player)
	if autopilot != null:
		autopilot.enabled = false
	await _frames(20)
	me.inventory.slots = [null, null]
	me.inventory.add(load("res://resources/weapons/nitro_overload.tres") as WeaponData)
	var had_item := not me.inventory.is_empty()
	var over := Vector3(NyiragongoScenery.LAKE_CENTRE.x + 40.0, NyiragongoScenery.LAKE_Y + 1.0, NyiragongoScenery.LAKE_CENTRE.y)
	me.teleport(Transform3D(Basis.IDENTITY, track.to_global(over)))
	await _frames(10)
	_check(me.recovery.last_reason == "lava", "driving into the lava recovers the car (%s)" % me.recovery.last_reason)
	_check(not had_item or me.inventory.is_empty(), "and burns its item")
	await _frames(90)
	_check(track.is_on_road(me.global_position) and me.global_position.y > track.road_floor_y(me.global_position) - 2.0,
			"and comes back on the road")

	# The jump: a straight run at the ramp at min_speed + a little.
	var sc := track.shortcuts[0]
	var ramp := track.get_node("ChannelRamp") as TrackFeature
	var xf: Transform3D = ramp.global_transform
	me.recovery.last_reason = ""
	me.teleport(Transform3D(xf.basis, xf.origin + xf.basis.z * 50.0 + xf.basis.y * 0.9))
	await _frames(3)
	me.linear_velocity = -xf.basis.z * (sc.min_speed + 2.0)
	var airborne := 0
	for i in 240:
		me.throttle_input = 1.0
		me.steer_input = 0.0
		await physics_frame
		if me.grounded_wheels == 0:
			airborne += 1
	var landed_d := sc.local_offset(track.to_local(me.global_position))
	print("    jump: %.2f s airborne, landed %.0f m along (gap ends %.0f)" % [airborne / 60.0, landed_d, sc.gaps[0].y])
	_check(airborne > 20, "the ramp launches the car (%.2f s)" % (airborne / 60.0))
	_check(me.recovery.last_reason == "" and landed_d > sc.gaps[0].y and track.is_on_road(me.global_position),
			"it clears the channel and lands on the road (%s)" % me.recovery.last_reason)


func _test_forced_shortcut(race: RaceManager) -> void:
	for sc in race.track.shortcuts:
		sc.ai_chance = 1.0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			ai.difficulty = ai.difficulty.duplicate()
			ai.difficulty.shortcut_chance = 2.0
	var reasons := {}
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(r: String) -> void: reasons[r] = int(reasons.get(r, 0)) + 1)
	var frames := 0
	while frames < 60 * 200 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var taken := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			taken += ai.shortcuts_taken
	print("    1 lap via the jump: %.1f s simulated; %d taken; recoveries %s" % [frames / 60.0, taken, reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes the lap")
	_check(taken >= 6, "the AI take the jump (%d of 7)" % taken)
	_check(int(reasons.get("lava", 0)) <= 1, "and clear the channel (%d fell in)" % int(reasons.get("lava", 0)))


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
	print("    race %.1f s simulated; times %s; jumps %d; recoveries %d %s" % [frames / 60.0, times, taken, recoveries[0], reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	_check(taken > 0, "the AI used the jump (%d times)" % taken)
	_check(recoveries[0] <= 4, "few recoveries on the slopes (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 330.0, "a 3-5 minute race: %s" % RaceProgress.format_time(winner.finish_time))
	await process_frame
