extends SceneTree
## Vehicle physics (docs/Cyberwave_2199_Vehicle_Physics_Implementation_Guide.md):
## resting on a flat floor (all 8 cars), wheel contact data, axle pairing,
## anti-roll, a ramp jump and landing, and clean hand-offs to hold / flight /
## teleport. Built on a bare floor (no track), so it runs in a few seconds.
## Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_vehicle_physics.gd

const CAR := "res://scenes/vehicles/placeholder_car.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
var _world: Node3D


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_axles()
	await _test_rest_all_cars()
	await _test_contact_data()
	await _test_anti_roll()
	await _test_ramp()
	await _test_hand_offs()
	await _test_overlay()
	if _world != null:
		_world.queue_free()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _section(title: String) -> void:
	_current = title
	print("- " + title)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box(pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation = rot
	_world.add_child(body)


## A fresh flat world (plus `extra` geometry) with one car 1 m up.
func _car(stats: VehicleStats = null, extra: Callable = Callable()) -> VehicleController:
	if _world != null:
		_world.queue_free()
		await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	_box(Vector3(0, -0.5, 0), Vector3(3000, 1, 3000))
	if extra.is_valid():
		extra.call()
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.player_controlled = false
	car.is_player = false
	if stats != null:
		car.stats = stats
	car.position = Vector3(0, 1.0, 0)
	_world.add_child(car)
	return car


func _launch(car: VehicleController, speed: float) -> void:
	car.hold_here()
	await physics_frame
	car.release(speed)


func _pitch_roll_rate(car: VehicleController) -> float:
	var av := car.angular_velocity
	var up := car.global_transform.basis.y
	return (av - up * av.dot(up)).length()


# --- tests ---------------------------------------------------------------------

func _test_axles() -> void:
	_section("axles")
	var scene := (load(CAR) as PackedScene).instantiate() as VehicleController
	var positions := []
	var names := []
	for child in scene.get_children():
		if child is RayCast3D and child.name.begins_with("Wheel"):
			positions.append(child.position)
			names.append(str(child.name))
	scene.free()
	var axles := VehicleController.find_axles(positions)
	_check(axles.size() == 2, "the car's four wheels make two axles")
	if axles.size() == 2:
		_check(names[axles[0].x] == "WheelFL" and names[axles[0].y] == "WheelFR", "front axle FL / FR (%s)" % [axles])
		_check(names[axles[1].x] == "WheelRL" and names[axles[1].y] == "WheelRR", "rear axle RL / RR")
	_check(VehicleController.find_axles([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0, 1)]).is_empty(),
			"three wheels: no axles (anti-roll off)")


func _test_rest_all_cars() -> void:
	_section("rest, all 8 cars")
	for data in VehicleCatalog.all():
		var car := await _car(data.stats)
		var ys: Array[float] = []
		for f in 240:
			await physics_frame
			if f >= 180:
				ys.append(car.global_position.y)
		var name := data.stats.display_name
		_check(ys.max() - ys.min() < 0.01, "%s rests without bouncing (%.4f m)" % [name, ys.max() - ys.min()])
		_check(car.grounded_wheels == 4 and car.ray_hit_wheels == 4, "%s: four loaded wheels" % name)
		_check(car.traction_fraction > 0.99, "%s: full traction at rest (%.2f)" % [name, car.traction_fraction])
		var comp_ok := true
		for c in car.wheel_compression:
			comp_ok = comp_ok and absf(c - car.static_compression()) < 0.03
		_check(comp_ok, "%s: springs sit near the static compression (%.3f m)" % [name, car.static_compression()])
		_check(Vector2(car.linear_velocity.x, car.linear_velocity.z).length() < 0.05, "%s: stays put" % name)


func _test_contact_data() -> void:
	_section("contact data")
	var car := await _car()
	car.position = Vector3(0, 3.0, 0)
	car.rotation = Vector3(deg_to_rad(8), 0, deg_to_rad(10))
	var hits_ok := true
	var comp_ok := true
	var saw_partial := false
	for f in 180:
		await physics_frame
		hits_ok = hits_ok and car.ray_hit_wheels >= car.grounded_wheels
		for c in car.wheel_compression:
			comp_ok = comp_ok and c >= 0.0 and c <= car.stats.suspension_rest_length
		if car.grounded_wheels > 0 and car.grounded_wheels < 4:
			saw_partial = saw_partial or car.traction_fraction < 1.0
	_check(hits_ok, "ray hits >= loaded wheels, every step")
	_check(comp_ok, "recorded compression stays within 0..rest length")
	_check(saw_partial, "a tilted landing has steps with partial traction")
	# Dropped low (springs past full travel): no launch.
	car = await _car()
	car.position = Vector3(0, 0.35, 0)
	var peak := 0.0
	for f in 120:
		await physics_frame
		peak = maxf(peak, car.global_position.y)
	_check(peak < 1.2, "a car spawned with its springs bottomed out isn't launched (peak %.2f m)" % peak)


func _test_anti_roll() -> void:
	_section("anti-roll")
	var curb := func() -> void: _box(Vector3(-0.85, 0.03, -80), Vector3(0.6, 0.06, 120))
	var off := VehicleStats.new()
	var on := VehicleStats.new()
	on.anti_roll_stiffness = 8000.0
	var results := {}
	for stats in [off, on]:
		var car := await _car(stats, curb)
		await _frames(30)
		await _launch(car, 25.0)
		var max_force := 0.0
		for f in 120:
			car.throttle_input = 1.0 if car.forward_speed < 25.0 else 0.0
			await physics_frame
			max_force = maxf(max_force, absf(car.anti_roll_force.x) + absf(car.anti_roll_force.y))
		results[stats] = [max_force, car.global_position.y]
	_check(results[off][0] == 0.0, "off by default (no force)")
	_check(results[on][0] > 50.0, "a one-side curb loads the bars (%.0f N)" % results[on][0])
	# Equal and opposite at each axle: no net lift once past the curb.
	var rest_off := await _rest_height(off)
	var rest_on := await _rest_height(on)
	_check(absf(rest_off - rest_on) < 0.002, "no net lift (rest height %.3f vs %.3f)" % [rest_off, rest_on])


func _rest_height(stats: VehicleStats) -> float:
	var car := await _car(stats)
	await _frames(180)
	return car.global_position.y


func _test_ramp() -> void:
	_section("ramp jump and landing")
	var ramp := func() -> void:
		var a := deg_to_rad(14.0)
		_box(Vector3(0, sin(a) * 7.0 - 0.5 * cos(a), -60), Vector3(8, 1, 14), Vector3(a, 0, 0))
	var car := await _car(null, ramp)
	await _frames(30)
	await _launch(car, 38.0)
	var air := 0
	var max_air := 0
	var landed_at := -1
	var reairborne := 0
	var was_air := false
	var post_rate := 0.0
	var max_up := 0.0
	var traction_in_air := 0.0
	var stabilizing := false
	for f in 360:
		car.throttle_input = 1.0
		await physics_frame
		var airborne := car.grounded_wheels == 0
		air = air + 1 if airborne else 0
		max_air = maxi(max_air, air)
		if airborne and air > car.stats.contact_grace_ticks:
			traction_in_air = maxf(traction_in_air, car.traction_fraction)
		if was_air and not airborne and max_air > 20 and landed_at < 0:
			landed_at = f
			stabilizing = car._stabilize_left > 0.0
		elif landed_at >= 0 and airborne and not was_air:
			reairborne += 1
		was_air = airborne
		if landed_at >= 0 and f - landed_at < 90:
			post_rate = maxf(post_rate, _pitch_roll_rate(car))
			if f - landed_at > 3:
				max_up = maxf(max_up, car.linear_velocity.y)
	_check(max_air > 120, "real airtime off the ramp (%.2f s)" % (max_air / 60.0))
	_check(traction_in_air == 0.0, "no traction in the air past the grace steps")
	_check(landed_at >= 0, "lands with 2+ loaded wheels (what trick boosts need)")
	_check(stabilizing, "the landing stabiliser starts on touchdown")
	_check(reairborne == 0, "no bounce back into the air")
	_check(post_rate < 1.0, "pitch/roll settles after landing (peak %.2f rad/s)" % post_rate)
	_check(max_up < 2.3, "landing rebound kept down (%.2f m/s up)" % max_up)


func _test_hand_offs() -> void:
	_section("hold, flight, teleport")
	var car := await _car()
	await _frames(90)
	car.hold_here()
	await _frames(2)
	_check(car.ray_hit_wheels == 0 and car.traction_fraction == 0.0 and car.wheel_load[0] == 0.0,
			"holding clears the wheel data")
	car.release(0.0)
	var spike := 0.0
	for f in 20:
		await physics_frame
		spike = maxf(spike, absf(car.linear_velocity.y))
	_check(spike < 1.0 and car.grounded_wheels == 4, "release: no spring kick (%.2f m/s)" % spike)
	car.fly_to(car.global_transform.translated(Vector3(0, 3, 0)), Vector3.ZERO)
	await _frames(2)
	_check(car.ray_hit_wheels == 0 and car.wheel_load[1] == 0.0, "flight clears the wheel data")
	car.end_flight(0.0)
	var bounced := false
	for f in 120:
		await physics_frame
		bounced = bounced or car.linear_velocity.y > 2.0
	_check(not bounced and car.grounded_wheels == 4, "back from flight: lands without a launch")
	car.teleport(Transform3D(Basis(), Vector3(20, 0.8, 0)))
	await _frames(1)
	_check(car.ray_hit_wheels == 0 and car.wheel_load[2] == 0.0, "teleport clears the wheel data")
	await _frames(60)
	_check(car.grounded_wheels == 4, "and the car settles where it was put")


func _test_overlay() -> void:
	_section("debug overlay")
	var car := await _car()
	await _frames(30)
	var overlay := PhysicsDebugOverlay.new(car)
	_world.add_child(overlay)
	await process_frame
	_check(not overlay.visible, "hidden by default")
	VehicleController.debug_physics = true
	await process_frame
	_check(overlay.visible and overlay.text.contains("loaded 4") and overlay.text.contains("mass 1200"),
			"F3 flag shows wheel contact and mass")
	VehicleController.debug_physics = false
