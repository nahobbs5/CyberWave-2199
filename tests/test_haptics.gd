extends SceneTree
## Controller rumble (VehicleHaptics) and the Vibration setting. No real pad
## is needed: the haptics node counts and records every pulse it sends.
## Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_haptics.gd

const CAR := "res://scenes/vehicles/placeholder_car.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_haptics_profile.json"
	GameSettings.path = "user://test_haptics_settings.cfg"
	InputSetup.ensure_actions()
	_run_all.call_deferred()


func _run_all() -> void:
	GameSettings.reset_values()
	await _test_events()
	await _test_gating()
	_test_settings()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _make_car(is_player: bool) -> VehicleController:
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.is_player = is_player
	car.player_controlled = is_player
	root.add_child(car)
	return car


## Fires `action` and returns the pulse it caused (or null).
func _pulse_of(car: VehicleController, action: Callable) -> Variant:
	car.haptics.stop() # clear priority so every event can play
	var before := car.haptics.pulse_count
	action.call()
	if car.haptics.pulse_count == before:
		return null
	return car.haptics.last_pulse


func _same(p: Variant, spec: Array) -> bool:
	return p is Vector3 and (p as Vector3).is_equal_approx(Vector3(spec[0], spec[1], spec[2]))


func _test_events() -> void:
	_current = "events"
	print("- each event pulses")
	var car := _make_car(true)
	await process_frame
	_check(car.haptics != null, "every car has a VehicleHaptics node")
	_check(car.haptics.device == VehicleHaptics.ALL_PADS, "single player rumbles every pad")
	for level in [1, 2, 3]:
		var p: Variant = _pulse_of(car, func() -> void: car.start_boost(level))
		_check(_same(p, VehicleHaptics.DRIFT_BOOST[level - 1]), "drift boost level %d (%s)" % [level, p])
	var pad: Variant = _pulse_of(car, func() -> void: car.start_external_boost(5, 1, 2, "Boost pad", Color.WHITE))
	_check(_same(pad, VehicleHaptics.BOOST_PAD), "boost pad (%s)" % pad)
	var ring: Variant = _pulse_of(car, func() -> void: car.start_external_boost(5, 1, 2, "Boost ring", Color.WHITE))
	_check(_same(ring, VehicleHaptics.BOOST_RING), "boost ring (%s)" % ring)
	var trick: Variant = _pulse_of(car, func() -> void: car.start_external_boost(5, 1, 2, "Trick", Color.WHITE))
	_check(_same(trick, VehicleHaptics.TRICK_LANDED), "trick landing (%s)" % trick)
	var start: Variant = _pulse_of(car, func() -> void: car.trick.trick_started.emit())
	_check(_same(start, VehicleHaptics.TRICK_STARTED), "trick start tick (%s)" % start)
	var slip: Variant = _pulse_of(car, func() -> void: car.start_external_boost(5, 1, 2, Slipstream.BOOST_LABEL, Color.WHITE))
	_check(_same(slip, VehicleHaptics.OTHER_BOOST), "slipstream / other boosts (%s)" % slip)
	if car.status != null:
		var stun: Variant = _pulse_of(car, func() -> void: car.status.apply_attack(&"stun", 1.0))
		_check(_same(stun, VehicleHaptics.HIT_STUN), "stun hit (%s)" % stun)
		var emp: Variant = _pulse_of(car, func() -> void: car.status.apply_attack(&"emp", 1.0))
		_check(_same(emp, VehicleHaptics.HIT_EMP), "EMP hit (%s)" % emp)
		var spike: Variant = _pulse_of(car, func() -> void: car.status.apply_attack(&"traction", 1.0))
		_check(_same(spike, VehicleHaptics.HIT_LIGHT), "spike hit (%s)" % spike)
		car.status.apply_buff(&"shield", 5.0)
		var block: Variant = _pulse_of(car, func() -> void: car.status.apply_attack(&"override", 1.0))
		_check(_same(block, VehicleHaptics.SHIELD_BLOCK), "shield block (%s)" % block)
	else:
		_check(false, "placeholder car has StatusEffects")
	var small: Variant = _pulse_of(car, func() -> void: car.heavy_impact.emit(car.stats.major_impact_speed_loss))
	var big: Variant = _pulse_of(car, func() -> void: car.heavy_impact.emit(40.0))
	_check(small is Vector3 and is_equal_approx((small as Vector3).y, VehicleHaptics.CRASH_MIN), "light crash = softest pulse (%s)" % small)
	_check(big is Vector3 and is_equal_approx((big as Vector3).y, 1.0), "hard crash = full pulse (%s)" % big)
	# Priority: a weak pulse doesn't cut off a stronger one that's playing.
	car.haptics.stop()
	car.start_boost(3)
	var count := car.haptics.pulse_count
	car.trick.trick_started.emit()
	_check(car.haptics.pulse_count == count, "weak pulse doesn't cut off a stronger one")
	car.haptics.stop()
	car.queue_free()
	await process_frame


func _test_gating() -> void:
	_current = "gating"
	print("- who gets rumble")
	var ai := _make_car(false)
	var human := _make_car(true)
	await process_frame
	_check(_pulse_of(ai, func() -> void: ai.start_boost(2)) == null, "AI cars never rumble")
	GameSettings.vibration = false
	_check(_pulse_of(human, func() -> void: human.start_boost(2)) == null, "vibration off: no pulse")
	GameSettings.vibration = true
	human.player_controlled = false
	_check(_pulse_of(human, func() -> void: human.start_boost(2)) == null, "autopilot after the finish: no pulse")
	human.player_controlled = true
	human.haptics.device = -1
	_check(_pulse_of(human, func() -> void: human.start_boost(2)) == null, "keyboard player (split screen): no pulse")
	human.haptics.device = 1
	_check(human.haptics.target_pads() == [1], "split-screen pad targets only that device")
	_check(_pulse_of(human, func() -> void: human.start_boost(2)) != null, "pad player pulses")
	ai.queue_free()
	human.queue_free()
	await process_frame


func _test_settings() -> void:
	_current = "settings"
	print("- vibration setting")
	GameSettings.reset_values()
	_check(GameSettings.vibration, "on by default")
	GameSettings.vibration = false
	_check(GameSettings.save_settings(), "saves")
	GameSettings.vibration = true
	GameSettings.load_settings()
	_check(not GameSettings.vibration, "off survives save/load")
	GameSettings.reset_values()
	GameSettings.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
