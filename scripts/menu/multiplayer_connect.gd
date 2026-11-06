class_name MultiplayerConnect
extends Control
## Split screen, step 1 of 3: connect controllers. Each player presses Enter
## (keyboard) or A (gamepad) once to take a slot (that device is theirs for
## the session; the keyboard can be one player) and again to confirm READY.
## Esc / B un-readies, then leaves; with nobody joined it goes back to the
## title. When two to four have joined and all are ready, an ALL READY banner
## asks for one more Enter / A / Start (any player) before car selection opens.

const MAX_PLAYERS := 4
const MIN_PLAYERS := 2

## Joined devices by player slot (-1 = keyboard, else gamepad id).
var devices: Array[int] = []
## Ready flag per slot.
var ready_flags: Array[bool] = []

var cards: Array[PanelContainer] = []
var _device_labels: Array[Label] = []
var _status: Array[Label] = []
var _pads_label: Label
var _hint: Label
## The ALL READY banner (shown while everyone is ready).
var confirm_banner: PanelContainer
var _presses := DeviceInput.new()


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = true
	GameSession.series = null
	Music.play(get_tree(), Music.MENU)
	_build()
	# Back from car select: the same players are still here.
	for d in GameSession.mp_devices:
		join(d)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	UIStyle.fade_in(self)
	_refresh()


func slot_of(device: int) -> int:
	return devices.find(device)


## Adds a player on this device. Returns their slot (or -1 when full).
func join(device: int) -> int:
	if slot_of(device) != -1:
		return slot_of(device)
	if devices.size() >= MAX_PLAYERS:
		return -1
	devices.append(device)
	ready_flags.append(false)
	_refresh()
	return devices.size() - 1


func leave(device: int) -> void:
	var i := slot_of(device)
	if i == -1:
		return
	devices.remove_at(i)
	ready_flags.remove_at(i)
	_refresh()


## Confirms (or takes back) a joined player's READY. When everyone who
## joined (two or more) is ready, the ALL READY banner waits for a final press.
func set_ready(device: int, value: bool) -> void:
	var i := slot_of(device)
	if i == -1:
		return
	ready_flags[i] = value
	_refresh()


func is_ready(device: int) -> bool:
	var i := slot_of(device)
	return i != -1 and ready_flags[i]


func can_continue() -> bool:
	return devices.size() >= MIN_PLAYERS and not ready_flags.has(false)


## Stores the players (keeping each slot's car) and opens car selection.
func continue_to_cars() -> void:
	if not can_continue():
		return
	var old_devices := GameSession.mp_devices
	var old_cars := GameSession.mp_vehicles
	var cars := PackedStringArray()
	for d in devices:
		var before := old_devices.find(d)
		cars.append(old_cars[before] if before >= 0 and before < old_cars.size() else "")
	GameSession.mp_devices = PackedInt32Array(devices)
	GameSession.mp_vehicles = cars
	GameSession.to_mp_cars(get_tree())


func back() -> void:
	GameSession.mp_devices = PackedInt32Array()
	GameSession.to_title(get_tree())


func _input(event: InputEvent) -> void:
	var device := DeviceInput.device_of(event)
	if device == -2:
		return
	var press := _presses.press_of(event)
	if press == "":
		return
	get_viewport().set_input_as_handled()
	var slot := slot_of(device)
	match press:
		"accept", "start":
			if slot == -1:
				join(device)
			elif not ready_flags[slot]:
				set_ready(device, true)
			elif can_continue():
				continue_to_cars()
		"cancel":
			if slot != -1 and ready_flags[slot]:
				set_ready(device, false)
			elif slot != -1:
				leave(device)
			elif devices.is_empty():
				back()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		leave(device)
	_refresh()


func _refresh() -> void:
	if cards.is_empty():
		return
	for i in MAX_PLAYERS:
		var color: Color = SplitScreen.PLAYER_COLORS[i]
		var style := cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i < devices.size():
			_device_labels[i].text = DeviceInput.device_name(devices[i], false).to_upper()
			_device_labels[i].add_theme_color_override("font_color", Color.WHITE)
			var model := Input.get_joy_name(devices[i]) if devices[i] >= 0 else "Arrows / WASD, Enter, Esc"
			if ready_flags[i]:
				_status[i].text = "READY!\n" + model
				_status[i].add_theme_color_override("font_color", color)
				style.set_border_width_all(5)
				style.bg_color = Color(color, 0.14)
			else:
				_status[i].text = "Press %s again: READY\n%s" % ["Enter" if devices[i] < 0 else "A", model]
				_status[i].add_theme_color_override("font_color", Color.WHITE)
				style.set_border_width_all(3)
				style.bg_color = Color(0.04, 0.02, 0.08, 0.92)
			style.border_color = color
		else:
			_device_labels[i].text = "- - -"
			_device_labels[i].add_theme_color_override("font_color", UIStyle.FAINT)
			_status[i].text = "Press Enter / A\nto join"
			_status[i].add_theme_color_override("font_color", UIStyle.MUTED)
			style.border_color = Color(color, 0.25)
			style.set_border_width_all(2)
			style.bg_color = Color(0.04, 0.02, 0.08, 0.92)
	var pads := Input.get_connected_joypads()
	var names: PackedStringArray = []
	for p in pads:
		names.append(DeviceInput.device_name(p))
	_pads_label.text = "Controllers found:  " + ("  |  ".join(names) if not names.is_empty() else "none (keyboard only)")
	confirm_banner.visible = can_continue()
	_hint.visible = not confirm_banner.visible
	if devices.size() < MIN_PLAYERS:
		_hint.text = "Two to four players. Press Enter (keyboard) or A (gamepad) to join, then again to confirm READY."
	else:
		_hint.text = "Waiting for everyone to be READY.   Esc / B: not ready, then leave."


func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	MultiplayerConnect.title_row(page, "CONNECT CONTROLLERS", 1)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)
	for i in MAX_PLAYERS:
		var color: Color = SplitScreen.PLAYER_COLORS[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIStyle.box_style(Color(0.04, 0.02, 0.08, 0.92), Color(color, 0.25), 14, 2))
		card.custom_minimum_size = Vector2(280, 300)
		row.add_child(card)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 14)
		card.add_child(box)
		var who := UIStyle.heading("P%d" % (i + 1), 64, color)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(who)
		var device := UIStyle.heading("", 24, Color.WHITE)
		device.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(device)
		var status := UIStyle.stat("", 16, UIStyle.MUTED)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(status)
		cards.append(card)
		_device_labels.append(device)
		_status.append(status)

	_pads_label = UIStyle.stat("", 15, UIStyle.MUTED)
	_pads_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_pads_label)
	_hint = UIStyle.stat("", 16, Color.WHITE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_hint)
	confirm_banner = MultiplayerConnect.ready_banner("Press Enter / A / Start to choose cars")
	page.add_child(confirm_banner)
	var back_button := UIStyle.secondary_button("Back", back)
	back_button.focus_mode = Control.FOCUS_NONE # driven per device, not by focus
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(back_button)


## The ALL READY banner shared by the connect and car screens: a glowing
## panel with the final-confirm prompt. Starts hidden.
static func ready_banner(prompt: String) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.name = "AllReady"
	banner.visible = false
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := UIStyle.box_style(Color(UIStyle.MAGENTA, 0.16), UIStyle.MAGENTA, 12, 3)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	style.shadow_color = Color(UIStyle.MAGENTA, 0.45)
	style.shadow_size = 14
	banner.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	banner.add_child(box)
	var title := UIStyle.heading("ALL READY!", 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UIStyle.stat(prompt + "      Esc / B: not ready", 17, UIStyle.CYAN)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	return banner


## The shared heading for the three split-screen screens ("STEP 1 OF 3").
static func title_row(page: Container, text: String, step: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)
	row.add_child(UIStyle.logo(Vector2(170, 56)))
	var title := UIStyle.heading("MULTIPLAYER  -  " + text, 30, UIStyle.MAGENTA)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var steps := UIStyle.stat("STEP %d OF 3" % step, 18, UIStyle.CYAN)
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(steps)
