extends SceneTree
## Controller disconnected checks (ControllerDisconnect). Run from the
## project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_controller_disconnect.gd

const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_disconnect_profile.json"
	GameSettings.path = "user://test_disconnect_settings.cfg"
	_run_all.call_deferred()


func _run_all() -> void:
	await _test_solo()
	await _test_solo_keyboard_and_menu()
	await _test_split()
	await _test_split_keyboard_taken()
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


func _config(devices: PackedInt32Array) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	if devices.size() > 1:
		config.mode = RaceConfig.Mode.VERSUS
		config.player_devices = devices
		var cars := PackedStringArray()
		for i in devices.size():
			cars.append(VehicleCatalog.all()[i].id)
		config.player_vehicle_ids = cars
		config.player_plates = PackedStringArray(["", "PL-2", "PL-3", "PL-4"]).slice(0, devices.size())
	return config


func _start(config: RaceConfig) -> RaceManager:
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	return race


func _end(race: RaceManager) -> void:
	paused = false
	race.queue_free()
	await _frames(2)


func _button(device: int, button: JoyButton = JOY_BUTTON_A) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
	await _frames(2)


func _enter() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ENTER
		e.physical_keycode = KEY_ENTER
		e.pressed = pressed
		Input.parse_input_event(e)
	await _frames(2)


func _unplug(device: int) -> void:
	Input.joy_connection_changed.emit(device, false)
	await _frames(1)


func _test_solo() -> void:
	_current = "solo"
	print("- solo")
	var race := await _start(_config(PackedInt32Array()))
	var overlay := race.controller_disconnect
	_check(race.state == RaceManager.State.RACING, "the race is running")
	await _unplug(2)
	_check(not overlay.is_open() and not paused, "an idle pad unplugged: nothing happens")
	await _button(0)
	await _unplug(0)
	_check(overlay.is_open() and paused, "the pad you drive with unplugged: paused")
	_check(overlay.title_text() == "CONTROLLER DISCONNECTED", "titled CONTROLLER DISCONNECTED (%s)" % overlay.title_text())
	_check(overlay.keyboard_offered(), "offers the keyboard")
	# Start must not unpause underneath.
	await _button(1, JOY_BUTTON_START)
	_check(overlay.is_counting() and paused and not race.pause_menu.is_open(), "any pad button: 3-2-1, still paused")
	await _frames(60)
	_check(paused and overlay.is_counting(), "still counting at 1 s")
	await _frames(60)
	_check(not paused and not overlay.is_open(), "the race resumes after the 3-2-1")
	await _end(race)


func _test_solo_keyboard_and_menu() -> void:
	_current = "solo keyboard"
	print("- solo: keyboard, and the pause menu")
	var race := await _start(_config(PackedInt32Array()))
	var overlay := race.controller_disconnect
	await _button(0)
	await _unplug(0)
	await _enter()
	_check(overlay.is_counting(), "Enter: continue with keyboard")
	await _frames(120)
	_check(not paused, "resumed")

	await _button(0)
	race.pause_menu.open()
	await _frames(1)
	await _unplug(0)
	_check(overlay.is_open() and not race.pause_menu.is_open() and paused, "over the pause menu: the menu hides")
	await _button(0)
	_check(not overlay.is_open() and race.pause_menu.is_open() and paused, "then the pause menu comes back, no 3-2-1")
	race.pause_menu.close()
	await _end(race)


func _test_split() -> void:
	_current = "split"
	print("- split screen")
	var race := await _start(_config(PackedInt32Array([0, 1])))
	var overlay := race.controller_disconnect
	await _unplug(1)
	_check(overlay.is_open() and paused, "P2's pad unplugged: everyone paused")
	_check(overlay.title_text() == "PLAYER 2 CONTROLLER DISCONNECTED", "titled for player 2 (%s)" % overlay.title_text())
	_check(overlay.keyboard_offered(), "keyboard free: offered")
	await _button(0)
	_check(overlay.is_open() and not overlay.is_counting(), "P1's pad can't claim it")
	await _button(3)
	_check(overlay.is_counting() and race.config.player_devices[1] == 3, "a free pad claims it (%s)" % race.config.player_devices)
	var events := InputMap.action_get_events(&"p2_accelerate")
	_check(not events.is_empty() and events.all(func(e: InputEvent) -> bool: return e.device == 3), "P2's actions now read pad 3")
	_check(race.players[1].vehicle.haptics.device == 3, "and it rumbles pad 3")
	await _frames(120)
	_check(not paused, "resumed")

	# Two at once: one after the other.
	await _unplug(0)
	await _unplug(3)
	_check(overlay.slot == 0, "P1 first")
	await _button(5)
	_check(overlay.is_open() and not overlay.is_counting() and overlay.slot == 1, "then P2")
	await _enter()
	_check(overlay.is_counting() and race.config.player_devices[1] == -1, "P2 takes the keyboard")
	await _frames(120)
	await _end(race)


func _test_split_keyboard_taken() -> void:
	_current = "split keyboard"
	print("- split screen: keyboard taken")
	var race := await _start(_config(PackedInt32Array([-1, 1])))
	var overlay := race.controller_disconnect
	await _unplug(1)
	_check(overlay.is_open() and not overlay.keyboard_offered(), "P1 on the keyboard: no keyboard option")
	await _enter()
	_check(overlay.is_open() and not overlay.is_counting(), "Enter does nothing")
	await _button(1)
	_check(overlay.is_counting() and race.config.player_devices[1] == 1, "the same pad, reconnected, claims it back")
	await _frames(120)
	await _end(race)
