extends SceneTree
## Gamepad in the single-player menus: A picks, B goes back, the D-pad and
## left stick move focus (Godot's ui_accept / ui_cancel have no pad buttons
## of their own; InputSetup adds A and B).
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_pad_menus.gd

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_pad_profile.json"
	GameSettings.path = "user://test_pad_settings.cfg"
	Championship.save_path = "user://test_pad_gp.json"
	PlayerProfile.delete_save()
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s" % message)


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _run() -> void:
	print("- gamepad in menus")
	InputSetup.ensure_actions()
	InputSetup.ensure_actions()
	_check(_has_button(&"ui_accept", JOY_BUTTON_A), "A picks (ui_accept)")
	_check(_has_button(&"ui_cancel", JOY_BUTTON_B), "B goes back (ui_cancel)")
	var a_count := 0
	for event in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventJoypadButton:
			a_count += 1
	_check(a_count == 1, "added once, however often actions are set up")
	_check(_has_button(&"ui_down", JOY_BUTTON_DPAD_DOWN), "the D-pad moves focus")

	change_scene_to_file(GameSession.MAIN_MENU_SCENE)
	for i in 10:
		await process_frame
	var menu := current_scene as MainMenu
	var first := root.gui_get_focus_owner()
	_check(menu != null and first != null, "the main menu has focus on a button")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var second := root.gui_get_focus_owner()
	_check(second != null and second != first, "D-pad down moves to the next button")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await process_frame
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await process_frame
	_check(root.gui_get_focus_owner() == first, "the left stick moves focus back up")
	var pressed := [false]
	(second as BaseButton).pressed.connect(func() -> void: pressed[0] = true, CONNECT_ONE_SHOT)
	(second as Control).grab_focus()
	await process_frame
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	press = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	_check(pressed[0], "A presses the focused button")
	# B on the main menu goes back to the title.
	change_scene_to_file(GameSession.MAIN_MENU_SCENE)
	for i in 10:
		await process_frame
	await _pad(JOY_BUTTON_B)
	for i in 30:
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == GameSession.TITLE_SCENE, "B goes back to the title")
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
