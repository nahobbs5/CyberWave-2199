class_name InputSetup
extends RefCounted
## Registers the game's input actions (GDD 3.2 / 3.3) at startup and applies
## the player's saved rebinds (GDD 11.9 remappable controls).
##
## Actions that already exist in Project Settings > Input Map are left alone,
## so editor-defined bindings always win over these defaults. A saved rebind
## replaces all of an action's keyboard events, or all of its gamepad events.

const STEER_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.1

## action: [deadzone, keys, gamepad buttons, gamepad axes [axis, direction]]
const DEFAULTS := {
	&"accelerate": [TRIGGER_DEADZONE, [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]],
	&"brake": [TRIGGER_DEADZONE, [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]]],
	&"steer_left": [STEER_DEADZONE, [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]]],
	&"steer_right": [STEER_DEADZONE, [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]]],
	# Hold Shift (keyboard) or RB (gamepad) and steer to drift that way (GDD 3.3).
	&"drift": [0.5, [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER], []],
	# Fixed-direction drift; unbound by default (kept for rebinding / code).
	&"drift_left": [0.5, [], [], []],
	&"drift_right": [0.5, [], [], []],
	&"cycle_camera": [0.5, [KEY_C], [JOY_BUTTON_DPAD_DOWN], []],
	# Hold to see behind you (the Rear View), release to go back.
	&"look_back": [0.5, [KEY_Q], [JOY_BUTTON_RIGHT_STICK], []],
	&"reset_vehicle": [0.5, [KEY_R], [JOY_BUTTON_DPAD_UP], []],
	&"use_weapon": [0.5, [KEY_SPACE], [JOY_BUTTON_LEFT_SHOULDER], []],
	# Ramp tricks: press in the air after a jump ramp.
	&"trick": [0.5, [KEY_E], [JOY_BUTTON_Y], []],
	&"select_slot_1": [0.5, [KEY_1], [JOY_BUTTON_DPAD_LEFT], []],
	&"select_slot_2": [0.5, [KEY_2], [JOY_BUTTON_DPAD_RIGHT], []],
	&"pause": [0.5, [KEY_ESCAPE], [JOY_BUTTON_START], []],
}

## Actions shown in Settings > Controls: [action, label, keyboard?, gamepad?]
const REMAPPABLE := [
	[&"accelerate", "Accelerate", true, true],
	[&"brake", "Brake / reverse", true, true],
	[&"steer_left", "Steer left", true, true],
	[&"steer_right", "Steer right", true, true],
	[&"drift", "Drift (hold + steer)", true, true],
	[&"use_weapon", "Use weapon", true, true],
	[&"trick", "Trick (off a ramp)", true, true],
	[&"select_slot_1", "Weapon slot 1", true, true],
	[&"select_slot_2", "Weapon slot 2", true, true],
	[&"cycle_camera", "Cycle camera", true, true],
	[&"look_back", "Look back (hold)", true, true],
	[&"reset_vehicle", "Reset vehicle", true, true],
	[&"pause", "Pause", true, true],
]

const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}
const JOY_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["Left stick left", "Left stick right"],
	JOY_AXIS_LEFT_Y: ["Left stick up", "Left stick down"],
	JOY_AXIS_RIGHT_X: ["Right stick left", "Right stick right"],
	JOY_AXIS_RIGHT_Y: ["Right stick up", "Right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}


static func ensure_actions() -> void:
	GameSettings.ensure_loaded()
	for action in DEFAULTS:
		if not InputMap.has_action(action):
			_add_defaults(action)
	_remove_space_from_ui_accept()
	_add_pad_to_ui_actions()
	apply_bindings(GameSettings.bindings)


## Builds this split-screen player's actions ("p2_accelerate", ...) from the
## current bindings, so rebinds carry over. device -1 = keyboard (key events
## only); otherwise that gamepad's events only, tied to its device id.
## Returns the action prefix ("p2_").
static func build_player_actions(slot: int, device: int) -> StringName:
	ensure_actions()
	var prefix := player_prefix(slot)
	for base in DEFAULTS:
		var action := StringName(prefix + str(base))
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, InputMap.action_get_deadzone(base))
		for event in InputMap.action_get_events(base):
			var is_key := event is InputEventKey
			var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
			if (device < 0 and is_key) or (device >= 0 and is_pad):
				var copy := event.duplicate() as InputEvent
				copy.device = device if device >= 0 else -1
				InputMap.action_add_event(action, copy)
	return StringName(prefix)


## "p1_" .. "p4_" for split-screen slots 0-3.
static func player_prefix(slot: int) -> String:
	return "p%d_" % (slot + 1)


## A base action with a player's prefix ("" = single player, any device).
static func action(prefix: StringName, base: StringName) -> StringName:
	return base if prefix == &"" else StringName(str(prefix) + str(base))


## Which join device an event comes from: -1 keyboard, a gamepad id, or -2
## for anything else (mouse, touch).
static func event_device(event: InputEvent) -> int:
	if event is InputEventKey:
		return -1
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device
	return -2


## Restores the GDD defaults for one action (both devices).
static func reset_action(action: StringName) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	_add_defaults(action)


## Applies saved rebinds: { action: { "key": "k:87", "pad": "b:0" } }.
static func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings:
		var entry: Dictionary = bindings[action]
		if not InputMap.has_action(StringName(action)):
			continue
		for device in ["key", "pad"]:
			var event := event_from_string(str(entry.get(device, "")))
			if event != null:
				replace_device_events(StringName(action), event)


## Replaces every event of the new event's device type (keyboard or gamepad).
static func replace_device_events(action: StringName, event: InputEvent) -> void:
	var keyboard := event is InputEventKey
	for existing in InputMap.action_get_events(action):
		if (existing is InputEventKey) == keyboard:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)


## Other remappable actions already using this input (for conflict notes).
static func actions_using(event: InputEvent, except: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var wanted := event_to_string(event)
	for row in REMAPPABLE:
		var action: StringName = row[0]
		if action == except or not InputMap.has_action(action):
			continue
		for existing in InputMap.action_get_events(action):
			if event_to_string(existing) == wanted:
				out.append(action)
	return out


# --- serialising and naming events ------------------------------------------------

static func event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		return "k:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if event is InputEventJoypadButton:
		return "b:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		return "a:%d:%d" % [m.axis, 1 if m.axis_value > 0.0 else -1]
	return ""


static func event_from_string(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() < 2:
		return null
	match parts[0]:
		"k":
			var key := InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			return key
		"b":
			var button := InputEventJoypadButton.new()
			button.button_index = int(parts[1]) as JoyButton
			return button
		"a":
			if parts.size() < 3:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(parts[1]) as JoyAxis
			motion.axis_value = 1.0 if int(parts[2]) > 0 else -1.0
			return motion
	return null


static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if event is InputEventJoypadButton:
		var b := (event as InputEventJoypadButton).button_index
		return JOY_BUTTON_NAMES.get(b, "Button %d" % b)
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		var names: Array = JOY_AXIS_NAMES.get(m.axis, ["Axis %d-" % m.axis, "Axis %d+" % m.axis])
		return names[1 if m.axis_value > 0.0 else 0]
	return "?"


## "W, Up" for keyboard, "RT" for gamepad, "-" if unbound.
static func describe(action: StringName, keyboard: bool) -> String:
	if not InputMap.has_action(action):
		return "-"
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var is_key := event is InputEventKey
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if (keyboard and is_key) or (not keyboard and is_pad):
			names.append(event_name(event))
	return ", ".join(names) if not names.is_empty() else "-"


# --- internals ------------------------------------------------------------------

## Menus (pause, results) use ui_accept: Enter / gamepad A / mouse. Space is
## the weapon key, so it must not also press a focused menu button.
static func _remove_space_from_ui_accept() -> void:
	if not InputMap.has_action(&"ui_accept"):
		return
	for event in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventKey and ((event as InputEventKey).keycode == KEY_SPACE \
				or (event as InputEventKey).physical_keycode == KEY_SPACE):
			InputMap.action_erase_event(&"ui_accept", event)


## Godot's built-in ui_accept / ui_cancel have no gamepad buttons (the
## direction actions already have the D-pad and left stick), so a pad could
## move through menus but not pick or go back. Adds A and B, once.
static func _add_pad_to_ui_actions() -> void:
	for pair in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		if not InputMap.has_action(pair[0]):
			continue
		var present := false
		for event in InputMap.action_get_events(pair[0]):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == pair[1]:
				present = true
		if not present:
			var button := InputEventJoypadButton.new()
			button.button_index = pair[1]
			InputMap.action_add_event(pair[0], button)


static func _add_defaults(action: StringName) -> void:
	var d: Array = DEFAULTS[action]
	InputMap.add_action(action, d[0])
	for key in d[1]:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	for button in d[2]:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)
	for axis_pair in d[3]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis_pair[0]
		motion.axis_value = axis_pair[1]
		InputMap.action_add_event(action, motion)
