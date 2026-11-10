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

	# Charging behind a car: no rings yet.
	car.in_slipstream = true
	car.slipstream_charge = 0.9
	await _frames(30)
	_check(not ring.is_shown(), "hidden while the meter is still filling")

	# The meter filled: the boost runs, the rings snap in.
	car.in_slipstream = false
	car.slipstream_charge = 0.0
	_fire_boost(car)
	await _frames(2)
	_check(ring.is_shown() and ring.burst > 0.5, "snaps in when the boost fires (%.2f)" % ring.burst)
	await _frames(20)
	_check(ring.is_shown() and ring.strength > 0.95 and car.is_slipstream_boosting(), "stays while the boost runs (%.2f)" % ring.strength)
	car.boost_time_left = 0.0
	await _frames(40)
	_check(not ring.is_shown(), "fades out when the boost ends")

	GameSettings.reduced_flashing = true
	_fire_boost(car)
	await _frames(1)
	_check(ring.burst == 0.0, "reduced flashing: no snap")
	await _frames(15)
	var z := (ring.get_child(0) as Node3D).position.z
	await _frames(10)
	_check(ring.is_shown() and is_equal_approx((ring.get_child(0) as Node3D).position.z, z), "reduced flashing: steady, no ripple")
	car.boost_time_left = 0.0
	await _frames(40)
	GameSettings.reduced_flashing = false

	car.set_visual_scale(VehicleController.TRACK_VISUAL_SCALE)
	_check(is_equal_approx(ring.global_transform.basis.get_scale().x, VehicleController.TRACK_VISUAL_SCALE), "follows the car's visual scale")
	car.queue_free()
	await process_frame


## What Slipstream does when the meter fills.
func _fire_boost(car: VehicleController) -> void:
	car.start_external_boost(Slipstream.BOOST_EXTRA, Slipstream.BOOST_TIME, Slipstream.BOOST_KICK,
			Slipstream.BOOST_LABEL, Slipstream.BOOST_COLOR)
	car.slipstream_boost.emit()


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
	var shown_early := false
	var charged := 0.0
	var boosted := false
	for i in 60 * 4:
		me.global_transform = leader.global_transform.translated_local(Vector3(0, 0, 7.0))
		me.linear_velocity = leader.linear_velocity
		await physics_frame
		if me.is_slipstream_boosting():
			boosted = true
			break
		charged = maxf(charged, me.slipstream_charge)
		shown_early = shown_early or ring.is_shown()
	_check(charged > 0.3 and not shown_early, "no ring while the meter fills (%.2f)" % charged)
	await process_frame
	await process_frame
	_check(boosted and ring.is_shown(), "the ring shows once the Slipstream boost fires")
	race.queue_free()
	await process_frame
