extends SceneTree
## Air attitude control (GDD 5.4): in the air a car turns to land on its
## wheels (lined up with the ground it comes down on), facing down the road
## (the ramp's way, else its take-off heading), so ramps and tricks always
## land clean, even at 200cc. It only changes the spin: the flight path is
## the same with or without it. (Half-pipe rides are guided: see
## test_trick_edges.gd.)
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_air_attitude.gd

const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_air_attitude_profile.json"
	GameSettings.path = "user://test_air_attitude_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	await _run("spun take-off on the Test Circuit", _test_spun_launch, _config("", 200))
	await _run("200cc ramps on The Stacks", _test_stacks, _config("The Stacks", 200))
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _config(track_name: String, cc: int) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.weapons_enabled = true
	config.cc = cc
	if track_name != "":
		config.track_name = track_name
		config.track_scene = TrackCatalog.scene(track_name)
	return config


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _run(test_name: String, test: Callable, config: RaceConfig) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = false
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 900:
		await physics_frame
		frames += 1
	# Park the rivals out of the way so they can't bump the test car.
	for r in race.racers:
		if r != race.player:
			r.vehicle.hold_here()
	await test.call(race)
	race.queue_free()
	await process_frame


## Heading error (degrees) between the car's nose and a direction, both
## flattened onto the ground.
func _heading_error(car: VehicleController, direction: Vector3) -> float:
	var nose := -car.global_transform.basis.z
	nose.y = 0.0
	direction.y = 0.0
	if nose.length() < 0.01 or direction.length() < 0.01:
		return 180.0
	return rad_to_deg(nose.normalized().angle_to(direction.normalized()))


## Launches the car from `xf` with `velocity` and `spin`, runs until it has
## landed (3+ wheels down for 15 steps after real air), and reports.
## `probe_time`: also records where it is that long into the flight.
func _fly(car: VehicleController, xf: Transform3D, velocity: Vector3, spin: Vector3,
		probe_time: float = 0.4) -> Dictionary:
	car.player_controlled = false
	car.teleport(xf)
	await physics_frame
	await physics_frame
	car.linear_velocity = velocity
	car.angular_velocity = spin
	var air := 0
	var probe := Vector3.ZERO
	var landed := false
	var heading := 180.0
	var up_dot := -1.0
	var spin_rate := 99.0
	for i in 400:
		car.throttle_input = 0.0
		car.brake_input = 0.0
		car.steer_input = 0.0
		await physics_frame
		if car.grounded_wheels == 0:
			air += 1
			if air == int(probe_time * 60.0):
				probe = car.global_position
		elif air > 10 and car.grounded_wheels >= 2:
			# Touchdown: how it meets the road.
			landed = true
			up_dot = car.global_transform.basis.y.dot(car.road_up)
			var v := car.linear_velocity
			heading = _heading_error(car, v if car.forward_speed >= 0.0 else -v)
			spin_rate = car.angular_velocity.length()
			for k in 20:
				await physics_frame
			break
	return {"air": air / 60.0, "landed": landed, "up": up_dot, "heading": heading, "spin": spin_rate,
			"probe": probe, "recovered": car.recovery.last_reason != "",
			"upright_after": car.global_transform.basis.y.dot(car.road_up) > 0.95 and car.grounded_wheels >= 3}


func _test_spun_launch(race: RaceManager) -> void:
	var car := race.player.vehicle
	var track := race.track
	var o := track.start_line_offset + 40.0
	var xf := track.get_safe_transform(o, 0.0, 3.0)
	var fwd := -xf.basis.z
	var launch := fwd * 30.0 + Vector3.UP * 7.0
	# The target pose: wheels down, nose the way it pointed at take-off,
	# laid flat (the launch heading points up a bit).
	var tilted := xf.basis.rotated(Vector3.UP, 1.2).rotated(fwd, 0.8)
	var target := car.air_target_basis(tilted, launch)
	_check(target.y.dot(car.air_ground_up) > 0.999 and (-target.z).dot(fwd) > 0.99,
			"the landing pose is wheels down, nose along the take-off heading")
	var spin := Vector3.UP * 8.0 + fwd * 4.0 + fwd.cross(Vector3.UP) * 4.0
	var r: Dictionary = await _fly(car, xf, launch, spin)
	print("    spun launch: %.2f s air, up %.3f, heading %.1f deg, spin %.2f" % [r.air, r.up, r.heading, r.spin])
	_check(r.landed and r.up > 0.97 and r.upright_after, "a car spun hard at take-off lands on its wheels (up %.3f)" % r.up)
	_check(r.heading < 10.0 and r.spin < 1.0, "facing its direction of travel, not spinning (%.1f deg off, %.2f rad/s)" % [r.heading, r.spin])
	_check(not r.recovered, "no recovery")
	var calm: Dictionary = await _fly(car, xf, launch, Vector3.ZERO)
	_check((r.probe as Vector3).distance_to(calm.probe) < 0.5,
			"the flight path is the same with or without the spin (%.2f m apart)" % (r.probe as Vector3).distance_to(calm.probe))
	# Flung round past 90 degrees: still comes back to its take-off heading.
	var flung: Dictionary = await _fly(car, xf, launch, Vector3.UP * 14.0)
	print("    flung: up %.3f, heading %.1f deg, spin %.2f" % [flung.up, flung.heading, flung.spin])
	_check(flung.landed and flung.up > 0.97 and flung.heading < 10.0 and flung.spin < 1.0,
			"flung round past 90 degrees, it comes back round nose first (%.1f deg)" % flung.heading)
	# Backwards through the air (spun round): lands facing backwards.
	var rev_xf := Transform3D(xf.basis.rotated(Vector3.UP, PI), xf.origin)
	var rev: Dictionary = await _fly(car, rev_xf, launch, Vector3.UP * 2.0)
	print("    backwards: up %.3f, heading %.1f deg" % [rev.up, rev.heading])
	_check(rev.landed and rev.up > 0.97 and rev.heading < 10.0 and (-car.global_transform.basis.z).dot(fwd) < 0.0,
			"flying backwards it lands on its wheels, still facing backwards")
	# Turned off in the stats: the old behaviour (yaw spin kept).
	var plain := car.stats.duplicate() as VehicleStats
	plain.air_attitude_gain = 0.0
	var tuned := car.stats
	car.stats = plain
	var old: Dictionary = await _fly(car, xf, launch, spin)
	car.stats = tuned
	print("    without air control: up %.3f, heading %.1f deg, spin %.2f" % [old.up, old.heading, old.spin])
	_check(old.heading > r.heading + 10.0 or old.spin > r.spin + 1.0, "without it the same launch lands spinning or off line")


## Rides a ramp at 200cc speed, with a trick in the air, and reports the
## touchdown: wheels-down (up), nose vs the road's direction there, spin.
func _ride(race: RaceManager, start: Transform3D, speed: float, trigger: Callable) -> Dictionary:
	var car := race.player.vehicle
	var track := race.track
	car.player_controlled = false
	car.teleport(start)
	# A trick left pending by the run before (a bad landing never pays its
	# boost) would keep the window shut: start each run fresh.
	car.trick._pending_boost = false
	car.trick._window = 0.0
	await physics_frame
	await physics_frame
	car.linear_velocity = -start.basis.z * speed
	var air := 0
	var tricked := false
	var result := {"landed": false, "up": -1.0, "heading": 180.0, "spin": 99.0, "air": 0.0, "tricked": false,
			"on_road": false}
	for i in 360:
		car.throttle_input = 1.0
		car.steer_input = 0.0
		await physics_frame
		if not trigger.call():
			continue
		if car.grounded_wheels == 0:
			air += 1
			if not tricked and air >= 4:
				tricked = car.trick.try_trick()
		elif air > 10 and car.grounded_wheels >= 2:
			# Touchdown.
			result = {"landed": true, "up": car.global_transform.basis.y.dot(car.road_up),
					"heading": _heading_error(car, track.get_tangent_at(track.get_offset_at(car.global_position))),
					"spin": car.angular_velocity.length(),
					"air": air / 60.0, "tricked": tricked}
			for k in 20:
				await physics_frame
			result["on_road"] = car.recovery.last_reason == "" and track.is_on_road(car.global_position)
			result["upright_after"] = car.global_transform.basis.y.dot(car.road_up) > 0.95 and car.grounded_wheels >= 3
			break
	return result


## Both runs of a ramp: with the air control, and (for the log) without it.
## `reset` runs before each ride (a feature's cooldown would block the
## back-to-back second run).
func _ride_both(race: RaceManager, label: String, start: Transform3D, speed: float, counter: Callable,
		reset: Callable = Callable()) -> void:
	var car := race.player.vehicle
	var tuned := car.stats
	var plain := tuned.duplicate() as VehicleStats
	plain.air_attitude_gain = 0.0
	car.stats = plain
	if reset.is_valid():
		reset.call()
	var before: int = counter.call()
	var old: Dictionary = await _ride(race, start, speed, func() -> bool: return counter.call() > before)
	car.stats = tuned
	if reset.is_valid():
		reset.call()
	before = counter.call()
	var r: Dictionary = await _ride(race, start, speed, func() -> bool: return counter.call() > before)
	print("    %s: %.2f s air | with: up %.3f, %.1f deg off the road, spin %.2f | without: up %.3f, %.1f deg, spin %.2f"
			% [label, r.air, r.up, r.heading, r.spin, old.up, old.heading, old.spin])
	_check(r.landed and r.tricked, "%s at 200cc: trick in the air, then lands" % label)
	# 15 degrees: the bend turns under a car flying straight.
	_check(r.up > 0.97 and r.heading < 15.0 and r.spin < 1.0,
			"%s at 200cc: touches down level, facing down the road, not spinning (up %.3f, %.1f deg, %.2f rad/s)"
			% [label, r.up, r.heading, r.spin])
	_check(r.get("on_road", false) and r.get("upright_after", false), "%s at 200cc: stays on its wheels on the road" % label)


func _test_stacks(race: RaceManager) -> void:
	var track := race.track
	var speed := 34.0 * RaceConfig.cc_scale(200)
	for ramp_name in ["SmallRampLoadingDock", "JumpCourtyard"]:
		var ramp := track.get_node_or_null(ramp_name) as TrackFeature
		_check(ramp != null, "The Stacks has %s" % ramp_name)
		if ramp == null:
			continue
		var xf: Transform3D = ramp.global_transform
		var start := Transform3D(xf.basis, xf.origin + xf.basis.z * 60.0 + Vector3.UP * 0.9)
		await _ride_both(race, ramp_name, start, speed, func() -> int: return ramp.triggered)
