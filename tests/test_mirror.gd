extends SceneTree
## Mirror races (GDD 2.1): TrackCircuit.set_reversed() turns every built track
## round. The road stays put (distance d becomes length - d), the start line,
## crates and coins keep their spots, gates run in reverse order, the grid
## and gantry face the new way, shortcuts swap ends (a jump gap gets a
## take-off ramp on its far side, the old ramp becomes the landing), ramps
## turn round, and turning it back restores everything. Then short Mirror
## races with AI drivers, a reversed jump over Nyiragongo's lava channel and
## a Mirror lap with every AI sent over it.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_mirror.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
## Seconds of racing in each Mirror race.
const RACE_SECONDS := 30.0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_mirror_profile.json"
	GameSettings.path = "user://test_mirror_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	for track_name in TrackCatalog.names():
		if TrackCatalog.is_built(track_name) or TrackCatalog.PRACTICE_TRACKS.has(track_name):
			await _test_track(track_name)
	_test_config()
	for track_name in ["Marble Canyon", "Fires of Nyiragongo"]:
		var config := RaceConfig.new()
		config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
		config.total_laps = 1
		config.weapons_enabled = false
		config.mirrored = true
		config.track_name = track_name
		config.track_scene = TrackCatalog.scene(track_name)
		await _run("Mirror race: " + track_name, _test_race, config)
	var jump := _mirror_config("Fires of Nyiragongo")
	await _run("Mirror jump: Fires of Nyiragongo", _test_jump, jump, false)
	await _run("Mirror lap over the jump", _test_forced_jump, _mirror_config("Fires of Nyiragongo"))
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# --- every track -------------------------------------------------------------

func _snapshot(track: TrackCircuit) -> Dictionary:
	var snap := {}
	snap.length = track.length
	snap.start = track.get_center_at(track.start_line_offset)
	snap.start_tangent = track.get_tangent_at(track.start_line_offset)
	var gates: Array[Vector3] = []
	for i in track.checkpoint_count:
		gates.append(track.get_center_at(track.get_checkpoint_offset(i)))
	snap.gates = gates
	var crates: Array[Vector3] = []
	for row in track.crate_row_offsets:
		for lat in track.crate_lateral_positions:
			crates.append(track.get_safe_transform(row, lat, 1.1).origin)
	snap.crates = crates
	var coins: Array[Vector3] = []
	for i in track.coin_offsets.size():
		var lat := track.coin_laterals[i] if i < track.coin_laterals.size() else 0.0
		coins.append(track.get_safe_transform(track.coin_offsets[i], lat, 1.0).origin)
	snap.coins = coins
	var samples: Array[Vector3] = []
	var surface: Array[Vector3] = []
	for i in 40:
		var s := track.length * i / 40.0
		samples.append(track.get_center_at(s))
		surface.append(track.to_global(track.surface_point(s, 4.0)))
	snap.samples = samples
	snap.surface = surface
	var ends: Array = []
	for sc in track.shortcuts:
		ends.append([sc.name, track.to_global(sc.point_at(0.0)), track.to_global(sc.point_at(sc.length))])
	snap.shortcuts = ends
	var features := {}
	for child in track.get_children():
		if child is TrackFeature:
			features[child.name] = (child as TrackFeature).global_transform
	snap.features = features
	snap.control_points = track.control_points
	snap.start_line_offset = track.start_line_offset
	snap.crate_offsets = track.crate_row_offsets
	snap.gate_count = track.get_node("%sCheckpoints" % TrackCircuit.GENERATED_PREFIX).get_child_count()
	return snap


func _all_near(a: Array, b: Array, _tolerance: float) -> float:
	var worst := 0.0
	if a.size() != b.size():
		return INF
	for i in a.size():
		worst = maxf(worst, (a[i] as Vector3).distance_to(b[i]))
	return worst


func _test_track(track_name: String) -> void:
	_current = track_name
	print("- " + track_name)
	var track := (load(TrackCatalog.scene_path(track_name)) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	await _frames(2)
	var before := _snapshot(track)
	_check_start_clear(track, "forward")
	track.set_reversed(true)
	track.set_reversed(true) # twice = once
	await _frames(1)
	var length: float = track.length
	_check(absf(length - before.length) < 1.0, "same length (%.1f vs %.1f)" % [length, before.length])
	var worst := 0.0
	for i in 40:
		var s: float = before.length * i / 40.0
		worst = maxf(worst, track.get_center_at(fposmod(length - s, length)).distance_to(before.samples[i]))
	_check(worst < 0.6, "same road, driven backwards (worst %.2f m)" % worst)
	var worst_surface := 0.0
	for i in 40:
		var s: float = before.length * i / 40.0
		var p := track.to_global(track.surface_point(fposmod(length - s, length), -4.0))
		worst_surface = maxf(worst_surface, p.distance_to(before.surface[i]))
	_check(worst_surface < 0.8, "the road surface (banking) matches, sides swapped (worst %.2f m)" % worst_surface)
	_check(track.get_center_at(track.start_line_offset).distance_to(before.start) < 0.6, "the start line stays put")
	_check(track.get_tangent_at(track.start_line_offset).dot(before.start_tangent) < -0.95, "and points the other way")
	var pole := track.get_grid_transform(0)
	_check((-pole.basis.z).dot(before.start_tangent) < -0.8, "pole position faces the new way")
	_check(track.wrapped_delta(track.get_grid_offset(0), track.start_line_offset) > 0.0, "the grid sits behind the line")
	_check_start_clear(track, "Mirror")
	var gantry := track.get_node("%sStartGantry" % TrackCircuit.GENERATED_PREFIX) as Node3D
	var gantry_fwd := -(track.global_transform.basis * gantry.transform.basis).z
	_check(gantry_fwd.dot(before.start_tangent) < -0.95, "the start gantry faces the new way")
	var board := gantry.find_child("StartLights", true, false) as MeshInstance3D
	_check(board != null and bool((board.material_override as ShaderMaterial).get_shader_parameter("right_to_left")),
			"the start lights count down right to left")
	var gates: Array[Vector3] = []
	var n := track.checkpoint_count
	for j in n:
		gates.append(before.gates[(n - j) % n])
	var now_gates: Array[Vector3] = []
	for j in n:
		now_gates.append(track.get_center_at(track.get_checkpoint_offset(j)))
	_check(_all_near(now_gates, gates, 0.6) < 0.8, "gates run in reverse order")
	var gate_holder := track.get_node("%sCheckpoints" % TrackCircuit.GENERATED_PREFIX)
	_check(gate_holder.get_child_count() == before.gate_count, "same number of gates (%d)" % gate_holder.get_child_count())
	var crates: Array[Vector3] = []
	for row in track.crate_row_offsets:
		for lat in track.crate_lateral_positions:
			crates.append(track.get_safe_transform(row, lat, 1.1).origin)
	var kept := 0
	for c: Vector3 in crates:
		if before.crates.any(func(o: Vector3) -> bool: return o.distance_to(c) < 0.9):
			kept += 1
		elif track.start_distance(c) >= TrackCircuit.START_CLEAR - 0.5:
			kept += 1 # moved past the line, out of the start area
	_check(crates.size() == before.crates.size() and kept == crates.size(), "item crates keep their spots (or move off the grid)")
	var coins: Array[Vector3] = []
	for i in track.coin_offsets.size():
		var lat := track.coin_laterals[i] if i < track.coin_laterals.size() else 0.0
		coins.append(track.get_safe_transform(track.coin_offsets[i], lat, 1.0).origin)
	var coins_kept := 0
	for c: Vector3 in coins:
		if before.coins.any(func(o: Vector3) -> bool: return o.distance_to(c) < 0.9) 				or track.start_distance(c) >= TrackCircuit.START_CLEAR - 0.5:
			coins_kept += 1
	_check(coins.size() == before.coins.size() and coins_kept == coins.size(), "coins keep their spots (or move off the grid)")
	var swapped := true
	var ramps_ok := true
	for i in track.shortcuts.size():
		var sc := track.shortcuts[i]
		var old: Array = before.shortcuts[i]
		swapped = swapped and track.to_global(sc.point_at(0.0)).distance_to(old[2]) < 1.5 \
				and track.to_global(sc.point_at(sc.length)).distance_to(old[1]) < 1.5
		for g in sc.gaps.size():
			var ramp := track.get_node_or_null("%sMirrorRamp_%s_%d" % [TrackCircuit.GENERATED_PREFIX, sc.name, g]) as TrackFeature
			if ramp == null:
				ramps_ok = false
				continue
			var lip := ramp.global_transform * Vector3(0.0, 0.0, -ramp.length * 0.5)
			ramps_ok = ramps_ok and lip.distance_to(track.to_global(sc.point_at(sc.gaps[g].x))) < 1.5 \
					and (-ramp.global_transform.basis.z).dot(track.global_transform.basis * sc.tangent_at(sc.gaps[g].x)) > 0.9 \
					and ramp.item_box_transforms().size() >= 2
		for child in track.get_children():
			var f := child as TrackFeature
			if f != null and f.mirror_landing:
				ramps_ok = ramps_ok and f.on_shortcut == String(sc.name) and f.item_box_transforms().is_empty()
	_check(swapped, "shortcuts swap ends (%d)" % track.shortcuts.size())
	_check(ramps_ok, "every jump gap gets a take-off ramp facing the new way, at the gap's edge")
	var turned := true
	for f_name: StringName in before.features:
		var f := track.get_node(NodePath(f_name)) as TrackFeature
		var was: Transform3D = before.features[f_name]
		if f == null:
			turned = false
			continue
		var moved := f.global_position.distance_to(was.origin) > 0.01
		# Start pads move past the line; everything else turns where it stands.
		turned = turned and (not moved or track.start_distance(f.global_position) >= TrackCircuit.START_CLEAR - 0.5) \
				and f.global_transform.basis.z.dot(was.basis.z) < -0.9
	_check(turned, "features turn round in place (%d)" % before.features.size())

	track.set_reversed(false)
	await _frames(1)
	var restored: bool = track.control_points == before.control_points \
			and absf(track.start_line_offset - before.start_line_offset) < 0.01 \
			and _all_near([track.get_center_at(0.0)], [before.samples[0]], 0.01) < 0.01
	for i in track.crate_row_offsets.size():
		restored = restored and absf(track.crate_row_offsets[i] - before.crate_offsets[i]) < 0.01
	for f_name: StringName in before.features:
		var f := track.get_node(NodePath(f_name)) as TrackFeature
		restored = restored and f.global_transform.basis.z.dot((before.features[f_name] as Transform3D).basis.z) > 0.99 \
				and f.global_position.distance_to((before.features[f_name] as Transform3D).origin) < 0.01
	var forward_board := track.get_node("%sStartGantry" % TrackCircuit.GENERATED_PREFIX).find_child("StartLights", true, false) as MeshInstance3D
	restored = restored and not bool((forward_board.material_override as ShaderMaterial).get_shader_parameter("right_to_left"))
	restored = restored and not track.get_children().any(func(c: Node) -> bool:
		return c.name.begins_with(TrackCircuit.GENERATED_PREFIX + "MirrorRamp_") or (c is TrackFeature and (c as TrackFeature).mirror_landing))
	_check(restored, "turning it back restores the track")
	track.queue_free()
	await _frames(1)


## Nothing on the grid or around the line: no feature, item crate or coin
## from START_CLEAR behind the back of the grid to START_CLEAR past the line.
func _check_start_clear(track: TrackCircuit, direction: String) -> void:
	var area := track.start_area()
	var inside := func(p: Vector3) -> bool:
		var d := track.start_distance(p)
		return d > area.x and d < area.y and track.get_shortcut_at(p) == null
	var found: Array[String] = []
	for child in track.get_children():
		var f := child as TrackFeature
		if f != null and f.on_shortcut == "" and inside.call(f.global_position):
			found.append("%s (%.0f m)" % [f.name, track.start_distance(f.global_position)])
	for row in track.crate_row_offsets:
		if inside.call(track.get_center_at(row)):
			found.append("crate row (%.0f m)" % track.start_distance(track.get_center_at(row)))
	for o in track.coin_offsets:
		if inside.call(track.get_center_at(o)):
			found.append("coin (%.0f m)" % track.start_distance(track.get_center_at(o)))
	_check(found.is_empty(), "%s: the grid and start line are clear (%s)" % [direction, ", ".join(found)])


# --- config ------------------------------------------------------------------

func _test_config() -> void:
	_current = "config"
	print("- " + _current)
	var template := RaceConfig.new()
	template.mirrored = true
	template.track_name = "Marble Canyon"
	_check(template.record_name() == "Marble Canyon (Mirror)", "Mirror keeps its own records")
	var series := Championship.create_series(3, template, "normal",
			load("res://resources/racers/rival_roster.tres") as RivalRoster)
	series.add_track("Marble Canyon")
	_check(series.make_race_config().mirrored, "every race of a Mirror series is Mirror")
	template.mirrored = false
	var plain := Championship.create_series(3, template, "normal",
			load("res://resources/racers/rival_roster.tres") as RivalRoster)
	plain.add_track("Marble Canyon")
	_check(not plain.make_race_config().mirrored, "a Standard series isn't")
	_check(RaceSetup.describe(RaceConfig.Mode.VERSUS, 1, true, true).begins_with("MIRROR: Track direction is reversed."),
			"the setup note explains Mirror")


# --- races -------------------------------------------------------------------

func _mirror_config(track_name: String) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.weapons_enabled = false
	config.mirrored = true
	config.track_name = track_name
	config.track_scene = TrackCatalog.scene(track_name)
	return config


func _run(test_name: String, test: Callable, config: RaceConfig, autopilot: bool = true) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = autopilot
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 900:
		await physics_frame
		frames += 1
	await test.call(race)
	race.queue_free()
	await process_frame


func _test_race(race: RaceManager) -> void:
	var track := race.track
	_check(track.reversed, "the track is reversed")
	var start_tangent := track.get_tangent_at(track.start_line_offset)
	var facing := race.racers.all(func(r: RaceProgress) -> bool:
		return (-r.vehicle.global_transform.basis.z).dot(start_tangent) > 0.8)
	_check(facing, "every car on the grid faces the reversed direction")
	var wrong_frames := 0
	for i in int(RACE_SECONDS * 60.0):
		await physics_frame
		if race.wrong_way:
			wrong_frames += 1
	var moving := race.racers.filter(func(r: RaceProgress) -> bool: return r.checkpoints_passed >= 3)
	print("    %d / %d cars past 3+ gates, best %d" % [moving.size(), race.racers.size(),
			race.racers.map(func(r: RaceProgress) -> int: return r.checkpoints_passed).max()])
	_check(moving.size() >= race.racers.size() - 1,
			"the field races the reversed way through the gates (%d / %d)" % [moving.size(), race.racers.size()])
	_check(wrong_frames < 30, "the autopilot car is never driving the wrong way (%d frames)" % wrong_frames)


## The reversed lava-channel jump: a straight run at the Mirror take-off ramp.
func _test_jump(race: RaceManager) -> void:
	var track := race.track
	var me := race.player.vehicle
	me.player_controlled = false
	var sc := track.shortcuts[0]
	var ramp := track.get_node("%sMirrorRamp_%s_0" % [TrackCircuit.GENERATED_PREFIX, sc.name]) as TrackFeature
	# A run-up on the shortcut itself, straight at the ramp.
	var start := track.global_transform * sc.safe_transform(ramp.offset - 35.0, 0.0, 0.9)
	_check(ramp.global_position.distance_to(track.to_global(sc.point_at(ramp.offset))) < 0.5, "the Mirror ramp sits on the shortcut")
	me.recovery.last_reason = ""
	me.teleport(start)
	await _frames(3)
	me.linear_velocity = -start.basis.z * (sc.min_speed + 2.0)
	var airborne := 0
	for i in 240:
		me.throttle_input = 1.0
		me.steer_input = 0.0
		await physics_frame
		if me.grounded_wheels == 0:
			airborne += 1
		elif airborne > 20 and me.grounded_wheels >= 3:
			break # touched down: judge the landing here
	await _frames(10)
	var landed_d := sc.local_offset(track.to_local(me.global_position))
	print("    reversed jump: %.2f s airborne, landed %.0f m along (gap ends %.0f)" % [airborne / 60.0, landed_d, sc.gaps[0].y])
	_check(airborne > 20, "the Mirror ramp launches the car (%.2f s)" % (airborne / 60.0))
	_check(me.recovery.last_reason == "" and landed_d > sc.gaps[0].y and track.is_on_road(me.global_position),
			"it clears the channel backwards and lands on the road (%s)" % me.recovery.last_reason)
	_check(me.global_transform.basis.y.dot(Vector3.UP) > 0.85, "on its wheels")


## Every AI sent over the reversed jump for a Mirror lap.
func _test_forced_jump(race: RaceManager) -> void:
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
	print("    Mirror lap via the jump: %.1f s simulated; %d taken; recoveries %s" % [frames / 60.0, taken, reasons])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes the Mirror lap")
	_check(taken >= 6, "the AI take the reversed jump (%d of 7)" % taken)
	_check(int(reasons.get("lava", 0)) <= 1, "and clear the channel (%d fell in)" % int(reasons.get("lava", 0)))
