class_name SettingsMenu
extends Control
## Settings and accessibility (GDD 11.9): HUD scale, motion blur, camera
## shake, reduced flashing, separate audio sliders and remappable controls.
## Every change applies and saves straight away. Laid out after "reference
## files/Cyberwave 2199 Neon Settings Interface.png" (NeonScreenLayout): both
## panels are always shown; the DISPLAY & AUDIO / CONTROLS tabs (or LB / RB,
## Q / E) move focus between them and the focused side's tab is lit.
##
## Rebinding: press a binding button, then the new key / gamepad button /
## stick direction within 5 seconds. A rebind replaces that action's
## keyboard (or gamepad) inputs; if another action already used the input,
## a note says so.

const CAPTURE_SECONDS := 5.0
## Ignore input briefly so the press that opened the capture isn't captured.
const CAPTURE_ARM := 0.25

## Action -> icon kind for the controls table.
const ACTION_ICONS := {
	&"accelerate": "accelerate", &"brake": "brake", &"steer_left": "arrow_left",
	&"steer_right": "arrow_right", &"drift": "drift", &"use_weapon": "crosshair",
	&"trick": "ramp", &"select_slot_1": "slot1", &"select_slot_2": "slot2",
	&"cycle_camera": "camera", &"look_back": "look_back", &"reset_vehicle": "reset",
	&"pause": "pause",
}

var layout: NeonScreenLayout
var display_tab: NeonMenuButton
var controls_tab: NeonMenuButton
var _left_panel: NeonPanel
var _right_panel: NeonPanel
var _first_binding: Button
var _motion_blur: NeonToggle
var _message: Label
var _binding_buttons: Dictionary = {}
var _capture_action: StringName = &""
var _capture_keyboard: bool = true
var _capture_left: float = 0.0
var _capture_arm: float = 0.0
var _first: Control


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	UIStyle.fade_in(self)
	_refresh_bindings()
	_first.grab_focus.call_deferred()


func back() -> void:
	GameSession.back_from_options(get_tree())


## Focus the first control of the left (false) or right (true) panel.
func show_panel(controls: bool) -> void:
	if controls:
		_first_binding.grab_focus()
	else:
		_first.grab_focus()
	_light_tab(controls)


## True when the CONTROLS tab is lit (tests).
func controls_tab_lit() -> bool:
	return controls_tab.is_lit()


func _unhandled_input(event: InputEvent) -> void:
	if is_capturing():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()
		return
	var side := -1
	if event is InputEventJoypadButton and event.pressed:
		var button := (event as InputEventJoypadButton).button_index
		side = 0 if button == JOY_BUTTON_LEFT_SHOULDER else 1 if button == JOY_BUTTON_RIGHT_SHOULDER else -1
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		side = 0 if key == KEY_Q else 1 if key == KEY_E else -1
	if side >= 0:
		get_viewport().set_input_as_handled()
		show_panel(side == 1)


func _on_focus_changed(control: Control) -> void:
	if control == null:
		return
	if _right_panel.is_ancestor_of(control):
		_light_tab(true)
	elif _left_panel.is_ancestor_of(control):
		_light_tab(false)


func _light_tab(controls: bool) -> void:
	display_tab.set_lit(not controls)
	controls_tab.set_lit(controls)


func is_capturing() -> bool:
	return _capture_action != &""


func start_capture(action: StringName, keyboard: bool) -> void:
	_capture_action = action
	_capture_keyboard = keyboard
	_capture_left = CAPTURE_SECONDS
	_capture_arm = CAPTURE_ARM
	var button := _binding_buttons.get([action, keyboard]) as Button
	if button != null:
		button.text = "Press a key..." if keyboard else "Press a button..."
	_message.text = "Waiting for input (5 s)."


## Applies a captured input (tests call this directly).
func accept_capture(event: InputEvent) -> void:
	var action := _capture_action
	_capture_action = &""
	var clean := _normalise(event)
	var others := InputSetup.actions_using(clean, action)
	GameSettings.set_binding(action, clean)
	GameSettings.save_settings()
	var text := "%s: %s" % [_label_of(action), InputSetup.event_name(clean)]
	if not others.is_empty():
		var names: PackedStringArray = []
		for other in others:
			names.append(_label_of(other))
		text += "   (also used by %s)" % ", ".join(names)
	_message.text = text
	_refresh_bindings()


func cancel_capture() -> void:
	_capture_action = &""
	_message.text = "Rebind cancelled."
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not is_capturing():
		return
	# Swallow everything while waiting, so menu navigation doesn't react.
	get_viewport().set_input_as_handled()
	if _capture_arm > 0.0:
		return
	if _capture_keyboard and event is InputEventKey and event.pressed and not event.echo:
		accept_capture(event)
	elif not _capture_keyboard and event is InputEventJoypadButton and event.pressed:
		accept_capture(event)
	elif not _capture_keyboard and event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		accept_capture(event)


func _process(delta: float) -> void:
	if not is_capturing():
		return
	_capture_arm -= delta
	_capture_left -= delta
	if _capture_left <= 0.0:
		cancel_capture()


func _normalise(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var k := InputEventKey.new()
		var src := event as InputEventKey
		k.physical_keycode = src.physical_keycode if src.physical_keycode != KEY_NONE else src.keycode
		return k
	if event is InputEventJoypadButton:
		var b := InputEventJoypadButton.new()
		b.button_index = (event as InputEventJoypadButton).button_index
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = (event as InputEventJoypadMotion).axis
	m.axis_value = 1.0 if (event as InputEventJoypadMotion).axis_value > 0.0 else -1.0
	return m


func _label_of(action: StringName) -> String:
	for row in InputSetup.REMAPPABLE:
		if row[0] == action:
			return row[1]
	return String(action)


func _refresh_bindings() -> void:
	for key in _binding_buttons:
		var button := _binding_buttons[key] as Button
		button.text = InputSetup.describe(key[0], key[1])


# --- layout --------------------------------------------------------------------

func _build() -> void:
	UIStyle.background(self)
	layout = NeonScreenLayout.new("SETTINGS", "gear")
	add_child(layout)
	layout.back_button.pressed.connect(back)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	layout.content.add_child(page)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 22)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(tabs)
	display_tab = _tab(tabs, "Display & Audio", "monitor", "speaker", false)
	controls_tab = _tab(tabs, "Controls", "gamepad", "", true)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	_left_panel = NeonPanel.new(14, UIStyle.CYAN, UIStyle.MAGENTA)
	_left_panel.custom_minimum_size = Vector2(540, 0)
	columns.add_child(_left_panel)
	_right_panel = NeonPanel.new(14, UIStyle.CYAN, UIStyle.MAGENTA)
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_right_panel)
	_build_display(_left_panel)
	_build_controls(_right_panel)
	_light_tab(false)


func _tab(parent: Container, text: String, icon_kind: String, extra_icon: String, controls: bool) -> NeonMenuButton:
	var tab := NeonMenuButton.new(text, icon_kind)
	tab.extra_icon_kind = extra_icon
	tab.chevrons = false
	tab.focus_mode = Control.FOCUS_NONE
	tab.font_size = 28
	tab.custom_minimum_size = Vector2(500, 44)
	tab.pressed.connect(show_panel.bind(controls))
	parent.add_child(tab)
	return tab


func _build_display(panel: Container) -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	panel.add_child(left)
	left.add_child(NeonWidgets.section_header("monitor", "DISPLAY & ACCESSIBILITY"))
	_first = NeonWidgets.slider_row(left, "hud", "HUD Scale", 75, 150, 5, GameSettings.hud_scale * 100.0, "%d%%",
			func(v: float) -> void: GameSettings.hud_scale = v / 100.0)
	_motion_blur = NeonWidgets.toggle_row(left, "blur", "Motion Blur", GameSettings.motion_blur,
			func(on: bool) -> void: GameSettings.motion_blur = on)
	NeonWidgets.slider_row(left, "camera", "Camera Shake", 0, 100, 5, GameSettings.camera_shake * 100.0, "%d%%",
			func(v: float) -> void: GameSettings.camera_shake = v / 100.0)
	NeonWidgets.toggle_row(left, "bolt", "Reduced Flashing", GameSettings.reduced_flashing,
			func(on: bool) -> void: GameSettings.reduced_flashing = on)
	NeonWidgets.toggle_row(left, "gamepad", "Controller Vibration", GameSettings.vibration,
			func(on: bool) -> void:
				GameSettings.vibration = on
				VehicleHaptics.preview())
	left.add_child(NeonWidgets.note("HUD scale and motion blur apply from the next race.", Color.WHITE, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(gap)
	left.add_child(NeonWidgets.section_header("speaker", "AUDIO", true))
	NeonWidgets.slider_row(left, "speaker", "Master Volume", 0, 100, 5, GameSettings.master_volume * 100.0, "%d%%",
			_set_volume.bind("master"))
	NeonWidgets.slider_row(left, "note", "Music Volume", 0, 100, 5, GameSettings.music_volume * 100.0, "%d%%",
			_set_volume.bind("music"))
	var sfx := NeonWidgets.slider_row(left, "wave", "Sound Effects", 0, 100, 5, GameSettings.sfx_volume * 100.0, "%d%%",
			_set_volume.bind("sfx"))
	sfx.focus_neighbor_bottom = sfx.get_path_to(layout.back_button)
	layout.back_button.focus_neighbor_top = layout.back_button.get_path_to(sfx)


func _build_controls(panel: Container) -> void:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	panel.add_child(right)
	right.add_child(NeonWidgets.section_header("gamepad", "CONTROLS"))
	var heads := _ControlsRow.new()
	for spec in [["", 30.0, false], ["ACTION", 0.0, true], ["KEYBOARD", 170.0, false], ["GAMEPAD", 170.0, false]]:
		var l := UIStyle.stat(spec[0], 16, Color(1, 1, 1, 0.8))
		l.custom_minimum_size = Vector2(spec[1], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if spec[2] else HORIZONTAL_ALIGNMENT_CENTER
		if spec[2]:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heads.add_child(l)
	right.add_child(_inset(heads, 0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the focused row's outline inside the scroll area's clip.
	scroll.add_child(_inset(rows, 2))
	for row in InputSetup.REMAPPABLE:
		var action: StringName = row[0]
		var line := _ControlsRow.new()
		rows.add_child(line)
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(30, 0)
		holder.add_child(NeonWidgets.icon(ACTION_ICONS.get(action, "play"), 22))
		line.add_child(holder)
		var name_label := UIStyle.label(_title_case(row[1]), 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		for keyboard in [true, false]:
			var enabled: bool = row[2] if keyboard else row[3]
			var b := NeonWidgets.binding_button(start_capture.bind(action, keyboard))
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.disabled = not enabled
			b.focus_entered.connect(line.queue_redraw)
			b.focus_exited.connect(line.queue_redraw)
			line.add_child(b)
			if enabled:
				_binding_buttons[[action, keyboard]] = b
				if _first_binding == null:
					_first_binding = b
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	right.add_child(footer)
	var hint := NeonWidgets.note("Pick a binding, then press the new input.", UIStyle.GOLD, false)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	_message = hint.find_child("Text", true, false) as Label
	footer.add_child(NeonWidgets.outline_button("Reset to Defaults", "reset", func() -> void:
			GameSettings.reset_bindings()
			GameSettings.save_settings()
			_message.text = "Controls reset."
			_refresh_bindings()))


func _inset(control: Control, vertical: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 6)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, vertical)
	m.add_child(control)
	return m


## "Brake / reverse" -> "Brake / Reverse"; "a" stays lower case.
static func _title_case(text: String) -> String:
	var words := text.split(" ")
	for i in words.size():
		var w := words[i]
		var at := 1 if w.begins_with("(") else 0
		if w.length() > at and (i == 0 or w.substr(at) != "a"):
			words[i] = w.substr(0, at) + w.substr(at, 1).to_upper() + w.substr(at + 1)
	return " ".join(words)


func _set_volume(v: float, bus: String) -> void:
	GameSettings.set_volume(bus, v / 100.0)


## A controls-table row: outlined in magenta while one of its bindings has focus.
class _ControlsRow extends HBoxContainer:
	func _init() -> void:
		add_theme_constant_override("separation", 12)
		custom_minimum_size = Vector2(0, 26)

	func _draw() -> void:
		var focused := get_viewport() != null and get_viewport().gui_get_focus_owner() != null \
				and get_viewport().gui_get_focus_owner().get_parent() == self
		if not focused:
			return
		var rect := Rect2(Vector2(-5, -2), size + Vector2(10, 4))
		var pts := NeonPanel.rounded_rect(rect, 6.0, 3)
		pts.append(pts[0])
		draw_colored_polygon(NeonPanel.rounded_rect(rect, 6.0, 3), Color(0.35, 0.05, 0.4, 0.45))
		draw_polyline(pts, Color(UIStyle.MAGENTA, 0.25), 7.0, true)
		draw_polyline(pts, UIStyle.MAGENTA.lightened(0.15), 2.0, true)
