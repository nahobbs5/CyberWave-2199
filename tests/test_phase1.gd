extends SceneTree
## Phase 1 headless checks. Run from the project root:
##   godot --headless --import
##   godot --headless -s res://tests/test_phase1.gd
## Exit code 0 = all checks passed. These test logic and physics outcomes,
## not how the game looks or feels.

const MAIN_SCENE := "res://scenes/free_drive.tscn"
const DT := 1.0 / 60.0
const ACTIONS: Array[StringName] = [
	&"accelerate", &"brake", &"steer_left", &"steer_right",
	&"drift", &"drift_left", &"drift_right", &"cycle_camera", &"reset_vehicle",
]
## Keyboard-only and gamepad-only actions (everything else needs both).
const KEYBOARD_ONLY: Array[StringName] = [&"drift"]
const GAMEPAD_ONLY: Array[StringName] = [&"drift_left", &"drift_right"]

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_drift_logic()
	await _run("input actions", _test_input_actions)
	await _run("track queries", _test_track_queries)
	await _run("spawn and settle", _test_spawn_settle)
	await _run("accelerate, brake, reverse", _test_accel_brake_reverse)
	await _run("steering direction", _test_steering)
	await _run("drift charge and gold boost in sim", _test_drift_boost_sim)
	await _run("camera cycle and placement", _test_camera)
	await _run("manual reset and no shortcut", _test_manual_reset)
	await _run("auto recovery: overturned", _test_auto_overturned)
	await _run("auto recovery: stuck", _test_auto_stuck)
	await _run("auto recovery: out of bounds", _test_out_of_bounds)
	await _run("scripted driver completes a lap", _test_scripted_lap)
	await _run("shift + A/D keyboard drift", _test_shift_drift_keys)
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _run(test_name: String, test: Callable) -> void:
	_current = test_name
	print("- " + test_name)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	var camera := main.get_node("ChaseCamera") as ChaseCamera
	camera.save_preference = false
	await _frames(2)
	await test.call(main)
	_release_all()
	main.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _release_all() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _press_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _car(main: Node) -> VehicleController:
	return main.get_node("PlayerCar") as VehicleController


func _track(main: Node) -> TrackCircuit:
	return main.get_node("TestCircuit") as TrackCircuit


# --- tests -------------------------------------------------------------------

func _test_drift_logic() -> void:
	_current = "drift logic"
	print("- drift logic (no scene)")
	var stats := VehicleStats.new()
	var drift := DriftController.new()
	var ended: Array = []
	drift.drift_ended.connect(func(level: int, boosted: bool) -> void: ended.append([level, boosted]))

	# Holding both buttons, or driving too slowly, never starts a drift.
	drift.update(DT, true, true, true, 30.0, 5.0, stats)
	_check(not drift.is_drifting(), "both buttons should not start a drift")
	drift.update(DT, true, false, true, 5.0, 5.0, stats)
	_check(not drift.is_drifting(), "too slow should not start a drift")

	# Holding the button with no sideways motion gives no charge (GDD 4.1).
	drift.update(DT, true, false, true, 30.0, 0.0, stats)
	_check(drift.direction == -1, "left input should start a left drift")
	for i in 120:
		drift.update(DT, true, false, true, 30.0, 0.2, stats)
	_check(is_zero_approx(drift.charge_time), "straight-line drift must not charge")

	# Valid sliding reaches each level at its threshold.
	var level_at := {}
	var t := 0.0
	while t < 4.2:
		drift.update(DT, true, false, true, 30.0, 6.0, stats)
		t += DT
		if not level_at.has(drift.level):
			level_at[drift.level] = drift.charge_time
	_check(absf(level_at.get(1, -1.0) - 1.0) < DT * 1.5, "Cyan at 1.0s (got %s)" % level_at.get(1))
	_check(absf(level_at.get(2, -1.0) - 2.5) < DT * 1.5, "Magenta at 2.5s (got %s)" % level_at.get(2))
	_check(absf(level_at.get(3, -1.0) - 4.0) < DT * 1.5, "Gold at 4.0s (got %s)" % level_at.get(3))

	# Releasing fires the boost.
	var fired := drift.update(DT, false, false, true, 30.0, 6.0, stats)
	_check(fired == 3, "release after 4s should return Gold (got %d)" % fired)
	_check(ended.size() == 1 and ended[0] == [3, true], "drift_ended(3, true) emitted")
	_check(not drift.is_drifting(), "drift ends on release")

	# Releasing before Cyan gives nothing.
	drift.update(DT, false, true, true, 30.0, 6.0, stats)
	for i in 30:
		drift.update(DT, false, true, true, 30.0, 6.0, stats)
	fired = drift.update(DT, false, false, true, 30.0, 6.0, stats)
	_check(fired == 0, "early release gives no boost")

	# Airborne pauses charging, and a long airtime cancels the drift.
	drift.update(DT, false, true, true, 30.0, 6.0, stats)
	for i in 30:
		drift.update(DT, false, true, true, 30.0, 6.0, stats)
	var before_air := drift.charge_time
	for i in 30:
		drift.update(DT, false, true, false, 30.0, 6.0, stats)
	_check(is_equal_approx(drift.charge_time, before_air), "airborne pauses charge")
	for i in 70:
		drift.update(DT, false, true, false, 30.0, 6.0, stats)
	_check(not drift.is_drifting(), "long airtime cancels drift")

	# Losing speed cancels.
	drift.update(DT, true, false, true, 30.0, 6.0, stats)
	drift.update(DT, true, false, true, 3.0, 6.0, stats)
	_check(not drift.is_drifting(), "dropping far below drift speed cancels")
	drift.free()


func _test_input_actions(_main: Node) -> void:
	for action in ACTIONS:
		_check(InputMap.has_action(action), "action %s exists" % action)
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		if not GAMEPAD_ONLY.has(action):
			_check(has_key, "%s has a keyboard binding" % action)
		if not KEYBOARD_ONLY.has(action):
			_check(has_pad, "%s has a gamepad binding" % action)


func _test_track_queries(main: Node) -> void:
	var track := _track(main)
	_check(track.length > 1200.0 and track.length < 1500.0, "circuit length ~1.3 km (got %.0f)" % track.length)
	var spawn := track.get_spawn_transform()
	_check(track.is_on_road(spawn.origin), "spawn is on the road")
	_check(absf(track.get_offset_at(spawn.origin) - track.get_spawn_offset()) < 1.5, "offset lookup round-trips")
	_check(-spawn.basis.z.dot(track.get_tangent_at(track.get_spawn_offset())) > 0.99, "spawn faces driving direction")
	_check(is_equal_approx(track.wrapped_delta(track.length - 5.0, 5.0), 10.0), "wrapped delta crosses the seam")
	var barriers := track.get_node_or_null("_GenBarriers")
	_check(barriers != null and barriers.get_child_count() > 300, "barrier colliders generated")


func _test_spawn_settle(main: Node) -> void:
	var car := _car(main)
	await _frames(90)
	_check(car.grounded_wheels == 4, "all four wheels grounded (got %d)" % car.grounded_wheels)
	_check(car.global_transform.basis.y.dot(Vector3.UP) > 0.98, "car settles upright")
	_check(car.linear_velocity.length() < 0.5, "car comes to rest (%.2f m/s)" % car.linear_velocity.length())
	var height := car.global_position.y
	_check(height > 0.5 and height < 0.9, "ride height sensible (%.2f)" % height)


func _test_accel_brake_reverse(main: Node) -> void:
	var car := _car(main)
	await _frames(30)
	var start := car.global_position
	Input.action_press(&"accelerate")
	await _frames(180)
	var speed := car.forward_speed
	_check(speed > 25.0, "3s of throttle reaches >25 m/s (got %.1f)" % speed)
	_check(speed <= car.stats.top_speed + 0.5, "speed stays under top speed")
	_check(car.recovery.total_progress > 40.0, "car moved forward along track (%.1f m)" % car.recovery.total_progress)
	_check(car.global_position.distance_to(start) > 40.0, "car moved in world")
	Input.action_release(&"accelerate")
	Input.action_press(&"brake")
	await _frames(80)
	_check(car.forward_speed < 5.0, "braking slows the car (%.1f m/s)" % car.forward_speed)
	await _frames(120)
	_check(car.forward_speed < -2.0, "holding brake reverses (%.1f m/s)" % car.forward_speed)


func _test_steering(main: Node) -> void:
	var car := _car(main)
	await _frames(30)
	var right0 := car.global_transform.basis.x
	Input.action_press(&"accelerate")
	await _frames(60)
	Input.action_press(&"steer_right")
	await _frames(30)
	var forward := -car.global_transform.basis.z
	_check(forward.dot(right0) > 0.1, "steer right turns right (dot %.2f)" % forward.dot(right0))
	Input.action_release(&"steer_right")
	Input.action_press(&"steer_left")
	await _frames(60)
	forward = -car.global_transform.basis.z
	_check(forward.dot(right0) < 0.0, "steer left turns back left (dot %.2f)" % forward.dot(right0))
	Input.action_release(&"steer_left")

	# Handling floor: at ~126 km/h, one second of full lock turns >= 1.5 rad
	# (the pre-tightening handling managed ~1.2).
	# Done on open ground so barriers can't interfere.
	car.recovery.auto_recovery_enabled = false
	car.player_controlled = false
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(-400.0, 0.9, 400.0)))
	await _frames(30)
	var guard := 0
	while car.forward_speed < 35.0 and guard < 600:
		car.throttle_input = 1.0
		await physics_frame
		guard += 1
	var start_forward := -car.global_transform.basis.z
	car.steer_input = 1.0
	for i in 60:
		car.throttle_input = 1.0 if car.forward_speed < 35.0 else 0.0
		await physics_frame
	var turned := start_forward.angle_to(-car.global_transform.basis.z)
	_check(turned >= 1.5, "1 s full lock at 126 km/h turns >= 1.5 rad (got %.2f)" % turned)


func _test_drift_boost_sim(main: Node) -> void:
	var car := _car(main)
	car.recovery.auto_recovery_enabled = false
	# Open ground outside the circuit, so the drift can circle freely.
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(-400.0, 0.9, 0.0)))
	await _frames(40)
	Input.action_press(&"accelerate")
	await _frames(150)
	var entry_speed := car.forward_speed
	_check(entry_speed > car.stats.drift_min_speed, "fast enough to drift (%.1f)" % entry_speed)

	var levels_seen := []
	car.drift.charge_level_changed.connect(func(level: int) -> void: levels_seen.append(level))
	var boosts := []
	car.boost_started.connect(func(level: int) -> void: boosts.append(level))

	Input.action_press(&"drift_right")
	Input.action_press(&"steer_right")
	var max_lateral := 0.0
	var drifting_frames := 0
	for i in 290:
		await physics_frame
		max_lateral = maxf(max_lateral, absf(car.lateral_speed))
		if car.drift.is_drifting():
			drifting_frames += 1
	_check(drifting_frames > 270, "drift stayed active (%d/290 frames)" % drifting_frames)
	_check(max_lateral > car.stats.drift_min_lateral_speed, "car slides sideways (%.1f m/s)" % max_lateral)
	_check(levels_seen == [1, 2, 3], "reached Cyan, Magenta, Gold in order (%s)" % [levels_seen])
	var release_speed := car.forward_speed
	Input.action_release(&"drift_right")
	Input.action_release(&"steer_right")
	await _frames(2)
	_check(boosts == [3], "Gold boost fired on release (%s)" % [boosts])
	_check(car.is_boosting(), "boost active after release")
	await _frames(30)
	_check(car.forward_speed > release_speed + 5.0,
			"boost adds speed (%.1f -> %.1f)" % [release_speed, car.forward_speed])


func _test_camera(main: Node) -> void:
	var car := _car(main)
	var camera := main.get_node("ChaseCamera") as ChaseCamera
	camera.profile_index = 0
	await _frames(60)
	_check(camera.get_profile().display_name == "Far Chase", "Far Chase is the default")
	var car_forward := -car.global_transform.basis.z
	var to_camera := camera.global_position - car.global_position
	_check(to_camera.dot(car_forward) < -3.0, "camera sits behind the car")
	_check(to_camera.y > 1.0, "camera sits above the car")
	var far_distance := to_camera.length()

	await _press_key(KEY_C)
	_check(camera.get_profile().display_name == "Close Chase", "C switches to Close Chase")
	await _frames(90)
	var close_distance := (camera.global_position - car.global_position).length()
	_check(close_distance < far_distance - 1.0, "Close Chase is closer (%.1f vs %.1f)" % [close_distance, far_distance])
	await _press_key(KEY_C)
	_check(camera.get_profile().display_name == "Far Chase", "C cycles back to Far Chase")


func _test_manual_reset(main: Node) -> void:
	var car := _car(main)
	var track := _track(main)
	var reasons := []
	car.recovery.recovered.connect(func(reason: String) -> void: reasons.append(reason))
	Input.action_press(&"accelerate")
	await _frames(120)
	Input.action_release(&"accelerate")
	var safe := car.recovery.last_safe_offset
	await _press_key(KEY_R)
	await _frames(5)
	_check(reasons == ["manual"], "R triggers a manual recovery (%s)" % [reasons])
	var offset := track.get_offset_at(car.global_position)
	var delta := track.wrapped_delta(safe, offset)
	_check(delta < 0.0 and delta > -20.0, "reset lands just behind the last safe point (%.1f m)" % delta)
	_check(track.get_lateral_distance(car.global_position) < 1.0, "reset lands on the centre line")
	_check(car.global_transform.basis.y.dot(Vector3.UP) > 0.99, "reset is upright")
	_check(car.linear_velocity.length() < 2.0, "reset clears momentum")

	# Teleporting far ahead must not count as progress, so a reset goes back.
	await _frames(70)
	var before := car.recovery.last_safe_offset
	car.teleport(track.get_safe_transform(before + 300.0))
	await _frames(40)
	_check(absf(track.wrapped_delta(before, car.recovery.last_safe_offset)) < 10.0,
			"a 300 m jump is not accepted as progress")
	car.recovery.request_recovery("manual")
	await _frames(5)
	var back := track.wrapped_delta(before, track.get_offset_at(car.global_position))
	_check(back < 0.0 and back > -20.0, "reset after a jump returns to the real position (%.1f m)" % back)


func _test_auto_overturned(main: Node) -> void:
	var car := _car(main)
	var track := _track(main)
	var reasons := []
	car.recovery.recovered.connect(func(reason: String) -> void: reasons.append(reason))
	await _frames(30)
	var xf := track.get_safe_transform(track.get_spawn_offset() + 30.0, 0.0, 1.5)
	xf.basis = xf.basis * Basis(Vector3.BACK, PI)
	car.teleport(xf)
	await _frames(200)
	_check(reasons.has("overturned"), "upside-down car is recovered (%s)" % [reasons])
	_check(car.global_transform.basis.y.dot(Vector3.UP) > 0.9, "car upright after recovery")


func _test_auto_stuck(main: Node) -> void:
	var car := _car(main)
	var track := _track(main)
	var reasons := []
	car.recovery.recovered.connect(func(reason: String) -> void: reasons.append(reason))
	await _frames(30)
	# Face straight into the right-hand barrier, 3 m away, and floor it.
	var offset := track.get_spawn_offset() + 20.0
	var tangent := track.get_tangent_at(offset)
	var right := tangent.cross(Vector3.UP).normalized()
	var pos := track.get_center_at(offset) + right * (track.road_width * 0.5 - 3.0) + Vector3.UP * 0.9
	car.teleport(Transform3D(Basis.looking_at(right, Vector3.UP), pos))
	await _frames(20)
	Input.action_press(&"accelerate")
	await _frames(300)
	_check(reasons.has("stuck"), "car pinned against a wall is recovered (%s)" % [reasons])


func _test_out_of_bounds(main: Node) -> void:
	var car := _car(main)
	var reasons := []
	car.recovery.recovered.connect(func(reason: String) -> void: reasons.append(reason))
	await _frames(30)
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(-400.0, -30.0, 0.0)))
	await _frames(10)
	_check(reasons.has("out of bounds"), "falling below the world is recovered (%s)" % [reasons])
	_check(car.global_position.y > 0.0, "car is back above the ground")


## A crude follow-the-centre-line driver proves the circuit is drivable end to
## end with this handling and that the HUD lap counter ticks over.
func _test_scripted_lap(main: Node) -> void:
	var car := _car(main)
	var track := _track(main)
	var hud := main.get_node("PrototypeHUD") as PrototypeHUD
	var reasons := []
	car.recovery.recovered.connect(func(reason: String) -> void: reasons.append(reason))
	car.player_controlled = false
	var max_frames := 60 * 90
	var frames := 0
	while hud.get_lap_count() < 1 and frames < max_frames:
		await physics_frame
		frames += 1
		var offset := track.get_offset_at(car.global_position)
		var aim := track.get_center_at(offset + 18.0) - car.global_position
		var forward := -car.global_transform.basis.z
		var angle := forward.signed_angle_to(Vector3(aim.x, 0.0, aim.z), Vector3.UP)
		car.steer_input = clampf(-angle * 2.5, -1.0, 1.0)
		var target_speed := 26.0
		car.throttle_input = 1.0 if car.forward_speed < target_speed else 0.0
		car.brake_input = 0.5 if car.forward_speed > target_speed + 4.0 else 0.0
	_check(hud.get_lap_count() >= 1, "lap completed within 90 s (%.1f s)" % (frames / 60.0))
	_check(reasons.is_empty(), "no recoveries needed during the lap (%s)" % [reasons])
	print("    scripted lap took %.1f s of simulated time" % (frames / 60.0))


func _key_event(key: Key, pressed: bool, shift: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.shift_pressed = shift
	Input.parse_input_event(event)


## Real key events: Shift + D starts a right drift, Shift alone keeps it,
## releasing Shift ends it, and Shift without steering never drifts.
func _test_shift_drift_keys(main: Node) -> void:
	var car := _car(main)
	car.recovery.auto_recovery_enabled = false
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(-400.0, 0.9, 0.0)))
	await _frames(40)
	Input.action_press(&"accelerate")
	await _frames(120)

	_key_event(KEY_SHIFT, true, true)
	await _frames(30)
	_check(not car.drift.is_drifting(), "Shift without steering does not drift")

	_key_event(KEY_D, true, true)
	await _frames(10)
	_check(Input.is_action_pressed(&"steer_right"), "D still steers while Shift is held")
	_check(car.drift.direction == 1, "Shift + D starts a right drift (dir %d)" % car.drift.direction)

	_key_event(KEY_D, false, true)
	_key_event(KEY_A, true, true)
	await _frames(20)
	_check(car.drift.direction == 1, "counter-steering with A keeps the right drift")
	_key_event(KEY_A, false, true)
	await _frames(20)
	_check(car.drift.direction == 1, "Shift alone keeps the drift going")

	_key_event(KEY_SHIFT, false, false)
	await _frames(3)
	_check(not car.drift.is_drifting(), "releasing Shift ends the drift")

	_key_event(KEY_A, true, false)
	_key_event(KEY_SHIFT, true, true)
	await _frames(10)
	_check(car.drift.direction == -1, "Shift pressed while holding A starts a left drift")
	_key_event(KEY_SHIFT, false, false)
	_key_event(KEY_A, false, false)
