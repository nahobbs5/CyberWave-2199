extends SceneTree
## Slipstream ring checks: the neon arches around a drafting car. Run from
## the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_slipstream_ring.gd

const CAR := "res://scenes/vehicles/placeholder_car.tscn"
const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_ring_profile.json"
	GameSettings.path = "user://test_ring_settings.cfg"
	_run_all.call_deferred()


func _run_all() -> void:
	_test_mesh()
	await _test_on_car()
	await _test_in_race()
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


func _test_mesh() -> void:
	_current = "mesh"
	print("- arch mesh")
	var mesh := SlipstreamRing.arch_mesh(1.5, 0.3)
	var aabb := mesh.get_aabb()
	_check(absf(aabb.size.x - 3.3) < 0.01 and absf(aabb.end.y - 1.65) < 0.01, "a half circle 3.3 m wide, 1.65 m tall (%s)" % aabb)
	_check(aabb.position.y > -0.01, "nothing below the centre line")


func _test_on_car() -> void:
	_current = "car"
	print("- ring on a car")
	GameSettings.reduced_flashing = false
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.player_controlled = false
	root.add_child(car)
	car.freeze = true
	await _frames(2)
	var ring := (car.get_node("Feedback") as VehicleFeedback).ring
	_check(ring != null and ring.vehicle == car, "every car gets a ring")
	_check(not ring.is_shown(), "hidden before drafting")

	car.in_slipstream = true
	car.slipstream_charge = 0.1
	await _frames(30)
	var low := ring.strength
	_check(ring.is_shown() and low > 0.3, "shows while drafting (%.2f)" % low)
	car.slipstream_charge = 0.9
	await _frames(30)
	_check(ring.strength > low + 0.3, "brighter as the meter fills (%.2f -> %.2f)" % [low, ring.strength])

	car.in_slipstream = false
	car.slipstream_charge = 0.0
	car.slipstream_boost.emit()
	await _frames(2)
	_check(ring.burst > 0.8 and ring.is_shown(), "bursts when the boost fires (%.2f)" % ring.burst)
	await _frames(60)
	_check(ring.burst == 0.0 and not ring.is_shown(), "then fades out")

	GameSettings.reduced_flashing = true
	car.in_slipstream = true
	car.slipstream_charge = 0.5
	await _frames(30)
	var z := (ring.get_child(0) as Node3D).position.z
	await _frames(10)
	_check(ring.is_shown() and is_equal_approx((ring.get_child(0) as Node3D).position.z, z), "reduced flashing: steady, no ripple")
	car.slipstream_boost.emit()
	await _frames(1)
	_check(ring.burst == 0.0, "reduced flashing: no burst")
	GameSettings.reduced_flashing = false

	car.set_visual_scale(VehicleController.TRACK_VISUAL_SCALE)
	_check(is_equal_approx(ring.global_transform.basis.get_scale().x, VehicleController.TRACK_VISUAL_SCALE), "follows the car's visual scale")
	car.queue_free()
	await process_frame


func _test_in_race() -> void:
	_current = "race"
	print("- ring while drafting in a race")
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 3
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	var me := race.player.vehicle
	var ring := (me.get_node("Feedback") as VehicleFeedback).ring
	var leader: VehicleController = null
	for racer in race.racers:
		if not racer.is_player:
			leader = racer.vehicle
			break
	frames = 0
	while leader.forward_speed < 24.0 and frames < 60 * 20:
		await physics_frame
		frames += 1
	var shown := false
	var burst := false
	for i in 60 * 4:
		me.global_transform = leader.global_transform.translated_local(Vector3(0, 0, 7.0))
		me.linear_velocity = leader.linear_velocity
		await physics_frame
		shown = shown or ring.is_shown()
		if ring.burst > 0.0:
			burst = true
			break
	_check(shown, "the ring shows behind a car")
	_check(burst, "and bursts on the Slipstream boost")
	race.queue_free()
	await process_frame
