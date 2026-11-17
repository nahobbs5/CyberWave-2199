extends SceneTree
## Half-pipes (GDD 8.7, the TrickEdge node): stretches of the road's outside
## edge that curve up into a 4 m quarter-pipe. Every race track has at least
## one, on the outside of a bend, clear of shortcut junctions, features and
## the start. On The Stacks, both are ridden: at speed the car is carried up
## the curve, launched above the lip, tricks, grabs an item box, drops back
## onto the wall and rides down onto the road facing down the road, with
## its trick boost; at 200cc too; slowly, or with no room left, it's just a
## bank. The same in a Mirror race. Also checks EMP puddles jam a car for 3 s.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_trick_edges.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const EDGE_SCRIPT := "res://scripts/track/trick_edge.gd"
const SCENE_EDGES := ["TrickEdgeA", "TrickEdgeB"]

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_trick_edges_profile.json"
	GameSettings.path = "user://test_trick_edges_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	_test_every_track()
	await _run("ride both half-pipes on The Stacks", _test_ride, _config(false, 100))
	await _run("200cc half-pipe ride", _test_fast, _config(false, 200))
	await _run("Mirror: half-pipes still work", _test_mirror, _config(true, 100))
	await _run("EMP puddle jams for 3 s", _test_emp_puddle, _config(false, 100))
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _config(mirrored: bool, cc: int) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.track_name = "The Stacks"
	config.track_scene = TrackCatalog.scene("The Stacks")
	config.mirrored = mirrored
	config.cc = cc
	return config


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _props(state: SceneState, i: int) -> Dictionary:
	var out := {}
	for k in state.get_node_property_count(i):
		out[state.get_node_property_name(i, k)] = state.get_node_property_value(i, k)
	return out


func _test_every_track() -> void:
	_current = "every race track"
	print("- " + _current)
	var total := 0
	for track_name in TrackCatalog.names():
		if TrackCatalog.PRACTICE_TRACKS.has(track_name) or not TrackCatalog.is_built(track_name):
			continue
		var state := (load(TrackCatalog.scene_path(track_name)) as PackedScene).get_state()
		var edges: Array[Dictionary] = []
		for i in state.get_node_count():
			var props := _props(state, i)
			var script := props.get("script") as Script
			if script != null and script.resource_path == EDGE_SCRIPT:
				props["name"] = str(state.get_node_name(i))
				edges.append(props)
		total += edges.size()
		var bad: Array[String] = []
		for e in edges:
			if absi(int(e.get("side", 1))) != 1 or (e.get("anchor_point", Vector3.ZERO) as Vector3) == Vector3.ZERO \
					or e.has("style") or (e.get("tint", Color(0, 0, 0, 0)) as Color).a <= 0.0:
				bad.append(e.name)
		_check(not edges.is_empty(), "%s has a half-pipe" % track_name)
		_check(bad.is_empty(), "%s half-pipes have a side, an anchor and a track tint, no old curb style (bad: %s)"
				% [track_name, bad])
	print("    %d half-pipes in all" % total)


func _run(test_name: String, test: Callable, config: RaceConfig) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = false
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	# Park the rivals so they can't get in the way.
	for r in race.racers:
		if r != race.player:
			r.vehicle.hold_here()
	await test.call(race)
	race.queue_free()
	await process_frame


## The pipe sits on the outside of its bend, at the road edge, solid, with
## a 4 m lip, item boxes over the lip, and its ends easing into the road.
func _check_build(track: TrackCircuit, edge: TrickEdge) -> void:
	var o := track.get_offset_at(edge.centre_global())
	var mid := (track.get_center_at(o - 25.0) + track.get_center_at(o + 25.0)) * 0.5
	var at := track.get_center_at(o)
	var inner := mid - at
	inner.y = 0.0
	var out := edge.centre_global() - at
	out.y = 0.0
	_check(inner.length() > 0.5 and out.dot(inner) < 0.0, "%s is on the outside of its bend" % edge.name)
	_check(is_equal_approx(edge.length, 70.0), "%s is 70 m long" % edge.name)
	var body := edge.get_node_or_null("Visual/Body") as StaticBody3D
	_check(body != null and body.get_child_count() >= 200, "%s is solid (%d collider slabs)" % [edge.name,
			body.get_child_count() if body != null else 0])
	var lip := track.to_global(edge.surface(edge.length * 0.5, PI * 0.5)[0])
	var foot := track.to_global(edge.surface(edge.length * 0.5, 0.0)[0])
	_check(absf(lip.y - foot.y - TrickEdge.RADIUS) < 0.3, "%s rises %.1f m to its lip" % [edge.name, lip.y - foot.y])
	var wall := track.to_global(edge.frame_at(edge.length * 0.5).origin)
	_check(lip.distance_to(Vector3(wall.x, lip.y, wall.z)) < 0.2, "%s's lip is at the wall" % edge.name)
	_check(edge.scale_at(0.0) < 0.05 and edge.scale_at(edge.length) < 0.05, "%s eases into the road at both ends" % edge.name)
	_check(edge.item_box_transforms().size() == 2 and edge.item_box_transforms().all(
			func(xf: Transform3D) -> bool: return xf.origin.y > lip.y), "%s has two item boxes over the lip" % edge.name)


## Drives the car at the pipe from the road, `speed` m/s angled 12 degrees
## toward the wall (as a player steers in), starting `into` metres into the
## span (in the driving direction). Reports the ride.
func _ride(race: RaceManager, edge: TrickEdge, speed: float, into: float = 10.0, throttle: float = 1.0,
		frames: int = 420) -> Dictionary:
	var me := race.player.vehicle
	var track := race.track
	me.player_controlled = false
	me.trick._pending_boost = false
	me.trick._window = 0.0
	me.clear_boost() # the last ride's trick boost
	edge._cooldowns.clear()
	var dir := -1.0 if track.reversed else 1.0
	var at := into if dir > 0.0 else edge.length - into
	var f := edge.frame_at(at)
	var fwd := track.global_transform.basis * (-f.basis.z.normalized() * dir)
	var inward := track.global_transform.basis * f.basis.x.normalized()
	var start := track.to_global(f.origin + f.basis.x.normalized() * (TrickEdge.RADIUS + 1.0) + f.basis.y.normalized() * 0.7)
	var lip_y := track.to_global(edge.surface(at, PI * 0.5)[0]).y
	var up := track.global_transform.basis * f.basis.y.normalized()
	var aim := (fwd * cos(deg_to_rad(12.0)) - inward * sin(deg_to_rad(12.0))).normalized()
	me.teleport(Transform3D(Basis(up.cross(-aim).normalized(), up, -aim), start))
	await physics_frame
	await physics_frame
	me.linear_velocity = aim * speed
	var before := edge.triggered
	var landed_before := me.trick.tricks_landed
	var flew := 0
	var top := -INF
	var tricked := false
	var released := false
	var result := {}
	for i in frames:
		me.throttle_input = throttle
		me.steer_input = 0.0
		await physics_frame
		if me.is_flying():
			flew += 1
			top = maxf(top, me.global_position.y - lip_y)
			if not tricked and me.trick.window_open():
				tricked = await _press_trick(me)
		elif flew > 0 and not released:
			released = true
			var o := track.get_offset_at(me.global_position)
			var tangent := track.get_tangent_at(o) # already the driving way in Mirror
			var nose := -me.global_transform.basis.z
			result["heading"] = rad_to_deg(Vector2(nose.x, nose.z).normalized().angle_to(Vector2(tangent.x, tangent.z).normalized()))
			result["exit_speed"] = me.forward_speed
			# Judged just after: with no steering, the bend soon brings the
			# car back to the pipe's foot (a player steers away).
			for k in 10:
				await physics_frame
			break
	result["started"] = edge.triggered > before
	result["flew"] = flew / 60.0
	result["top"] = top
	result["tricked"] = tricked
	result["landed"] = me.trick.tricks_landed > landed_before
	result["upright"] = me.global_transform.basis.y.dot(me.road_up) > 0.95 and me.grounded_wheels >= 3
	result["on_road"] = me.recovery.last_reason == "" and track.is_on_road(me.global_position)
	result["item"] = not me.inventory.is_empty()
	return result


## Presses the player's Trick button (a real input event, as from the pad
## or keyboard) while the ride flies the car. True if a trick started.
func _press_trick(me: VehicleController) -> bool:
	me.player_controlled = true
	var press := InputEventAction.new()
	press.action = me.action(&"trick")
	press.pressed = true
	me.get_viewport().push_input(press)
	await process_frame
	var started := me.trick.is_tricking()
	var release := InputEventAction.new()
	release.action = press.action
	release.pressed = false
	me.get_viewport().push_input(release)
	me.player_controlled = false
	return started


func _judge(label: String, r: Dictionary, speed: float) -> void:
	print("    %s: ride %.2f s, %.1f m over the lip, exit %.1f m/s, %.1f deg off the road" % [label, r.flew, r.top,
			r.get("exit_speed", 0.0), r.get("heading", 180.0)])
	_check(r.started and r.flew > 1.0, "%s: carries the car up and over (%.2f s)" % [label, r.flew])
	_check(r.top > 1.0, "%s: launches it above the lip (centre %.1f m over it)" % [label, r.top])
	_check(r.tricked and r.landed, "%s: a trick in the air, and its boost on the way out" % label)
	_check(r.upright and r.on_road, "%s: back on the road on its wheels, no recovery" % label)
	_check(r.get("heading", 180.0) < 12.0, "%s: facing down the road (%.1f deg)" % [label, r.get("heading", 180.0)])
	_check(r.get("exit_speed", 0.0) > speed * 0.75, "%s: keeps its speed (%.1f of %.1f m/s)" % [label, r.get("exit_speed", 0.0), speed])


func _edges(track: TrackCircuit) -> Array[TrickEdge]:
	var edges: Array[TrickEdge] = []
	for n in SCENE_EDGES:
		var e := track.get_node_or_null(n) as TrickEdge
		_check(e != null, "The Stacks has %s" % n)
		if e != null:
			edges.append(e)
	return edges


func _test_ride(race: RaceManager) -> void:
	var track := race.track
	var crates := race.weapon_manager.crates.size()
	_check(crates >= 4, "item boxes spawned (%d crates)" % crates)
	var items := 0
	for edge in _edges(track):
		_check_build(track, edge)
		race.player.vehicle.inventory.clear()
		var r: Dictionary = await _ride(race, edge, 30.0)
		_judge(edge.name, r, 30.0)
		items += 1 if r.item else 0
		var slow: Dictionary = await _ride(race, edge, 10.0, 10.0, 0.0)
		_check(not slow.started, "%s is just a bank at 10 m/s" % edge.name)
		# Past the pipe's end in 1.5 s.
		var late: Dictionary = await _ride(race, edge, 30.0, edge.length - TrickEdge.TAPER - 8.0, 1.0, 90)
		_check(not late.started, "%s: no ride without room left to finish it" % edge.name)
	_check(items >= 1, "the item boxes over the lip give a weapon (%d of 2 rides)" % items)


func _test_fast(race: RaceManager) -> void:
	var edge := _edges(race.track)[0]
	var speed := 34.0 * RaceConfig.cc_scale(200)
	var r: Dictionary = await _ride(race, edge, speed)
	_judge("200cc " + edge.name, r, speed)


func _test_mirror(race: RaceManager) -> void:
	var track := race.track
	_check(track.reversed, "the track is reversed")
	for edge in _edges(track):
		_check(edge.reversed, "%s knows it's Mirror" % edge.name)
		var chev := edge.get_node_or_null("Visual/Chevron1") as Node3D
		var o := track.get_offset_at(chev.global_position) if chev != null else 0.0
		_check(chev != null and (-chev.global_transform.basis.z).dot(track.get_tangent_at(o)) > 0.6,
				"%s's chevrons point the Mirror way" % edge.name)
		var r: Dictionary = await _ride(race, edge, 30.0)
		_judge("Mirror " + edge.name, r, 30.0)


func _test_emp_puddle(race: RaceManager) -> void:
	var me := race.player.vehicle
	me.player_controlled = false
	var puddle := TrackFeature.new()
	puddle.name = "TestPuddle"
	puddle.kind = TrackFeature.Kind.EMP_PUDDLE
	puddle.width = 5.0
	puddle.offset = race.track.wrap_offset(race.track.start_line_offset + 200.0)
	race.track.add_child(puddle)
	puddle.place_on_track(race.track)
	await physics_frame
	me.status.remove(&"shield")
	me.teleport(Transform3D(puddle.global_transform.basis, puddle.global_position + Vector3.UP * 0.9))
	var frames := 0
	while not me.status.has(&"emp") and frames < 60:
		await physics_frame
		frames += 1
	_check(me.status.has(&"emp"), "the puddle zaps the car")
	var left := me.status.time_left(&"emp")
	_check(left > 2.8 and left <= TrackFeature.EMP_PUDDLE_DURATION + 0.01, "the EMP lasts 3 s (%.2f s left)" % left)
	me.teleport(Transform3D(puddle.global_transform.basis, puddle.global_position + puddle.global_transform.basis.z * 30.0 + Vector3.UP * 0.9))
	for i in 120:
		await physics_frame
	_check(me.status.has(&"emp"), "still jammed 2 s later")
	for i in 72:
		await physics_frame
	_check(not me.status.has(&"emp"), "and it wears off by 3.2 s")
