class_name ControlsCard
extends VBoxContainer
## The pause menu's controls table (after "reference files/Cyberwave 2199
## Neon Pause Menu.png"): ACTION / KEYBOARD / GAMEPAD columns, one row per
## action on a faint stripe with its icon, keys as magenta keycaps and pad
## inputs as cyan ones. Read from the current bindings (refresh() after a
## rebind), so it always shows what the player actually uses.

## [label, icon kind, actions]. Several actions in one row (Steer, item
## slots) get a keycap per action, and their pad inputs are merged.
const ROWS := [
	["Accelerate", "accelerate", [&"accelerate"]],
	["Brake / Reverse", "brake", [&"brake"]],
	["Steer", "arrow_right", [&"steer_left", &"steer_right"]],
	["Drift (hold) + Steer", "drift", [&"drift"]],
	["Use Item", "crosshair", [&"use_weapon"]],
	["Switch Item Slot (1 / 2)", "slot1", [&"select_slot_1", &"select_slot_2"]],
	["Trick (in the air)", "bolt", [&"trick"]],
	["Camera", "camera", [&"cycle_camera"]],
	["Look Back (hold)", "look_back", [&"look_back"]],
	["Reset Car", "reset", [&"reset_vehicle"]],
	["Pause", "pause", [&"pause"]],
]
const KEY_COLOR := Color(1.0, 0.25, 0.75)
const PAD_COLOR := Color(0.2, 0.9, 1.0)
const COLUMN := 200.0
const ROW_HEIGHT := 34.0

## Per row, for tests: {"label", "keyboard": PackedStringArray of keycap
## texts, "gamepad": PackedStringArray of pad keycap texts}.
var rows: Array = []
var _rows_box: VBoxContainer


func _init() -> void:
	name = "Controls"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 10)
	heads.custom_minimum_size = Vector2(0, 34)
	add_child(_inset(heads))
	var action := UIStyle.stat("ACTION", 22, UIStyle.CYAN)
	action.add_theme_font_override("font", UIStyle.slanted_font(true))
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_child(action)
	heads.add_child(_head("keyboard", "KEYBOARD"))
	heads.add_child(_head("gamepad", "GAMEPAD"))
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 3)
	add_child(_rows_box)
	refresh()


## Rebuilds the rows from the current bindings.
func refresh() -> void:
	for c in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.queue_free()
	rows.clear()
	for spec in ROWS:
		var actions: Array = spec[2]
		var keys := _keyboard_caps(actions)
		var pad := _pad_caps(actions)
		rows.append({"label": spec[0], "keyboard": keys, "gamepad": pad[0]})
		var line := _Stripe.new()
		line.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		line.add_theme_constant_override("separation", 10)
		_rows_box.add_child(line)
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(44, 0)
		holder.add_child(NeonWidgets.icon(spec[1], 24))
		line.add_child(holder)
		var l := UIStyle.label(spec[0], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Never wider than the panel leaves it (the keycap columns come first).
		l.clip_text = true
		l.custom_minimum_size.x = 120
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(l)
		line.add_child(_cell(keys, KEY_COLOR, " / ", ""))
		line.add_child(_cell(pad[0], PAD_COLOR, "", pad[1]))


func _head(icon_kind: String, text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(COLUMN, 0)
	box.add_theme_constant_override("separation", 8)
	box.add_child(NeonWidgets.icon(icon_kind, 26))
	var l := UIStyle.stat(text, 18, UIStyle.CYAN)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	return box


## Keycaps (with `between` text between them) and a trailing note.
func _cell(caps: PackedStringArray, color: Color, between: String, note: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(COLUMN, 0)
	box.add_theme_constant_override("separation", 6)
	for i in caps.size():
		if i > 0 and between != "":
			box.add_child(UIStyle.stat(between.strip_edges(), 16, Color(1, 1, 1, 0.6)))
		box.add_child(NeonWidgets.key_cap(caps[i], color))
	if note != "":
		var n := UIStyle.stat(note, 15, Color(1, 1, 1, 0.85))
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(n)
	return box


## One action: a cap per key ("W", "Up"). Several actions: a cap per
## action with its keys joined ("A / Left", "D / Right").
static func _keyboard_caps(actions: Array) -> PackedStringArray:
	var caps: PackedStringArray = []
	for action in actions:
		var names := _names(action, true)
		if actions.size() == 1:
			caps.append_array(names)
		elif not names.is_empty():
			caps.append(" / ".join(names))
	if caps.is_empty():
		caps.append("-")
	return caps


## [caps, note]: "Left stick left" -> cap "LS", note "left"; "D-pad Up" ->
## cap "D-pad", note "Up". Inputs sharing a cap are merged ("LS", "left /
## right").
static func _pad_caps(actions: Array) -> Array:
	var caps: PackedStringArray = []
	var notes: PackedStringArray = []
	for action in actions:
		for n in _names(action, false):
			var cap := n
			var note := ""
			var lower := n.to_lower()
			if lower.contains(" stick "):
				cap = "LS" if lower.begins_with("left") else "RS"
				note = n.substr(lower.find(" stick ") + 7)
			elif lower.begins_with("d-pad "):
				cap = "D-pad"
				note = n.substr(6)
			if not caps.has(cap):
				caps.append(cap)
			if note != "" and not notes.has(note):
				notes.append(note)
	if caps.is_empty():
		caps.append("-")
	return [caps, " / ".join(notes)]


static func _names(action: StringName, keyboard: bool) -> PackedStringArray:
	var names: PackedStringArray = []
	if not InputMap.has_action(action):
		return names
	for event in InputMap.action_get_events(action):
		var is_key := event is InputEventKey
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if (keyboard and is_key) or (not keyboard and is_pad):
			names.append(InputSetup.event_name(event))
	return names


func _inset(control: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 54)
	m.add_theme_constant_override("margin_right", 0)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(control)
	return m


## A row on a faint rounded stripe.
class _Stripe extends HBoxContainer:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(NeonPanel.rounded_rect(rect, 8.0, 3), Color(0.35, 0.3, 0.6, 0.14))
