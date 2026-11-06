class_name SettingsMenu
extends Control
## Settings and accessibility (GDD 11.9): HUD scale, motion blur, camera
## shake, reduced flashing, separate audio sliders and remappable controls.
## Every change applies and saves straight away.
##
## Rebinding: press a binding button, then the new key / gamepad button /
## stick direction within 5 seconds. A rebind replaces that action's
## keyboard (or gamepad) inputs; if another action already used the input,
## a note says so.

const CAPTURE_SECONDS := 5.0
## Ignore input briefly so the press that opened the capture isn't captured.
const CAPTURE_ARM := 0.25

var _controls: GridContainer
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
	UIStyle.fade_in(self)
	_refresh_bindings()
	_first.grab_focus.call_deferred()


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
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var coins := UIStyle.header(page, "SETTINGS")
	coins.text = ""
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UIStyle.label("DISPLAY & ACCESSIBILITY", 18, UIStyle.CYAN))
	var hud := _slider(left, "HUD scale", 75, 150, 5, GameSettings.hud_scale * 100.0, "%d%%",
			func(v: float) -> void: GameSettings.hud_scale = v / 100.0)
	_first = hud
	_check(left, "Motion blur", GameSettings.motion_blur,
			func(on: bool) -> void: GameSettings.motion_blur = on)
	_slider(left, "Camera shake", 0, 100, 5, GameSettings.camera_shake * 100.0, "%d%%",
			func(v: float) -> void: GameSettings.camera_shake = v / 100.0)
	_check(left, "Reduced flashing", GameSettings.reduced_flashing,
			func(on: bool) -> void: GameSettings.reduced_flashing = on)
	left.add_child(UIStyle.label("HUD scale and motion blur apply from the next race.", 13, Color(1, 1, 1, 0.5)))
	left.add_child(Control.new())
	left.add_child(UIStyle.label("AUDIO", 18, UIStyle.CYAN))
	_slider(left, "Master", 0, 100, 5, GameSettings.master_volume * 100.0, "%d%%",
			_set_volume.bind("master"))
	_slider(left, "Music", 0, 100, 5, GameSettings.music_volume * 100.0, "%d%%",
			_set_volume.bind("music"))
	_slider(left, "Sound effects", 0, 100, 5, GameSettings.sfx_volume * 100.0, "%d%%",
			_set_volume.bind("sfx"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(UIStyle.button("Back", func() -> void: GameSession.back_from_options(get_tree())))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UIStyle.label("CONTROLS", 18, UIStyle.CYAN))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_controls = GridContainer.new()
	_controls.columns = 3
	_controls.add_theme_constant_override("h_separation", 12)
	_controls.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_controls)
	for header in ["ACTION", "KEYBOARD", "GAMEPAD"]:
		_controls.add_child(UIStyle.label(header, 14, Color(1, 1, 1, 0.5)))
	for row in InputSetup.REMAPPABLE:
		var action: StringName = row[0]
		_controls.add_child(UIStyle.label(row[1], 15))
		for keyboard in [true, false]:
			var enabled: bool = row[2] if keyboard else row[3]
			var b := UIStyle.button("-", start_capture.bind(action, keyboard))
			b.custom_minimum_size = Vector2(200, 32)
			b.add_theme_font_size_override("font_size", 15)
			b.disabled = not enabled
			_controls.add_child(b)
			if enabled:
				_binding_buttons[[action, keyboard]] = b
	_message = UIStyle.label("Pick a binding, then press the new input.", 15, Color(1.0, 0.82, 0.3))
	right.add_child(_message)
	right.add_child(UIStyle.button("Reset controls to defaults", func() -> void:
			GameSettings.reset_bindings()
			GameSettings.save_settings()
			_message.text = "Controls reset."
			_refresh_bindings()))


func _set_volume(v: float, bus: String) -> void:
	GameSettings.set_volume(bus, v / 100.0)


func _slider(parent: Container, text: String, lo: float, hi: float, step: float, value: float,
		fmt: String, on_change: Callable) -> HSlider:
	return UIStyle.slider_row(parent, text, lo, hi, step, value, fmt, on_change)


func _check(parent: Container, text: String, value: bool, on_change: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	var l := UIStyle.label(text, 16)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		GameSettings.save_settings())
	row.add_child(check)
	parent.add_child(row)
	return check
