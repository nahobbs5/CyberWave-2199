class_name InputSetup
extends RefCounted
## Registers the game's input actions (GDD 3.2 / 3.3) at startup.
##
## Actions that already exist in Project Settings > Input Map are left alone,
## so editor-defined bindings always win. A future SettingsManager can replace
## this with saved, remappable bindings.

const STEER_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.1


static func ensure_actions() -> void:
	_add("accelerate", TRIGGER_DEADZONE, [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add("brake", TRIGGER_DEADZONE, [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add("steer_left", STEER_DEADZONE, [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add("steer_right", STEER_DEADZONE, [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	# Keyboard: hold Shift and steer (A/D) to drift that way.
	# Gamepad keeps dedicated left/right drift buttons (GDD 3.3).
	_add("drift", 0.5, [KEY_SHIFT], [], [])
	_add("drift_left", 0.5, [], [JOY_BUTTON_LEFT_SHOULDER], [])
	_add("drift_right", 0.5, [], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_add("cycle_camera", 0.5, [KEY_C], [JOY_BUTTON_BACK], [])
	_add("reset_vehicle", 0.5, [KEY_R], [JOY_BUTTON_Y], [])
	_add("use_weapon", 0.5, [KEY_SPACE], [JOY_BUTTON_A], [])
	_add("select_slot_1", 0.5, [KEY_1], [JOY_BUTTON_DPAD_LEFT], [])
	_add("select_slot_2", 0.5, [KEY_2], [JOY_BUTTON_DPAD_RIGHT], [])
	_add("pause", 0.5, [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_remove_space_from_ui_accept()


## Menus (pause, results) use ui_accept: Enter / gamepad A / mouse. Space is
## the weapon key, so it must not also press a focused menu button.
static func _remove_space_from_ui_accept() -> void:
	if not InputMap.has_action(&"ui_accept"):
		return
	for event in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventKey and ((event as InputEventKey).keycode == KEY_SPACE \
				or (event as InputEventKey).physical_keycode == KEY_SPACE):
			InputMap.action_erase_event(&"ui_accept", event)


static func _add(action: StringName, deadzone: float, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, deadzone)
	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	for button in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)
	for axis_pair in axes:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis_pair[0]
		motion.axis_value = axis_pair[1]
		InputMap.action_add_event(action, motion)
