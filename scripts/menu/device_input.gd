class_name DeviceInput
extends RefCounted
## Split-screen menus: turns raw events into "accept", "cancel", "left",
## "right", "up", "down", "start", "plate" (Y / Tab: edit the license plate)
## or "delete" (X) for the device that sent them, so each player drives
## their own card with their own keyboard or gamepad. A left-stick push
## counts once until the stick comes back to the middle.

const STICK_THRESHOLD := 0.6

## Gamepad left-stick position per [device, axis].
var _stick: Dictionary = {}


## -1 keyboard, a gamepad id, or -2 for anything else (mouse, touch).
static func device_of(event: InputEvent) -> int:
	return InputSetup.event_device(event)


## The menu press this event is ("" for none).
func press_of(event: InputEvent) -> String:
	var device := device_of(event)
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
			return ""
		var key := [device, m.axis]
		var before: float = _stick.get(key, 0.0)
		_stick[key] = m.axis_value
		var horizontal := m.axis == JOY_AXIS_LEFT_X
		if m.axis_value <= -STICK_THRESHOLD and before > -STICK_THRESHOLD:
			return "left" if horizontal else "up"
		if m.axis_value >= STICK_THRESHOLD and before < STICK_THRESHOLD:
			return "right" if horizontal else "down"
		return ""
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return ""
		match k.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				return "accept"
			KEY_ESCAPE, KEY_BACKSPACE:
				return "cancel"
			KEY_LEFT, KEY_A:
				return "left"
			KEY_RIGHT, KEY_D:
				return "right"
			KEY_UP, KEY_W:
				return "up"
			KEY_DOWN, KEY_S:
				return "down"
			KEY_TAB:
				return "plate"
		return ""
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		if not b.pressed:
			return ""
		match b.button_index:
			JOY_BUTTON_A:
				return "accept"
			JOY_BUTTON_START:
				return "start"
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				return "cancel"
			JOY_BUTTON_DPAD_LEFT:
				return "left"
			JOY_BUTTON_DPAD_RIGHT:
				return "right"
			JOY_BUTTON_DPAD_UP:
				return "up"
			JOY_BUTTON_DPAD_DOWN:
				return "down"
			JOY_BUTTON_Y:
				return "plate"
			JOY_BUTTON_X:
				return "delete"
	return ""


## "Keyboard" or "Gamepad 2  -  Xbox Controller".
static func device_name(device: int, with_model: bool = true) -> String:
	if device < 0:
		return "Keyboard"
	var text := "Gamepad %d" % (device + 1)
	var model := Input.get_joy_name(device)
	if with_model and model != "":
		text += "  -  " + model
	return text
