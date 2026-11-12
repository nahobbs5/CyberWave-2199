class_name MultiplayerConnect
extends Control
## Split screen, step 1 of 3: connect controllers. Each player presses Enter
## (keyboard) or A (gamepad) once to take a slot (that device is theirs for
## the session; the keyboard can be one player) and again to confirm READY.
## Esc / B un-readies, then leaves; with nobody joined it goes back to the
## title. When two to four have joined and all are ready, an ALL READY banner
## asks for one more Enter / A / Start (any player) before car selection opens.
##
## Laid out after "reference files/Cyberwave 2199 Multiplayer Connect
## Screen.png" on NeonScreenLayout: four P1-P4 cards whose icon is the joined
## device (Xbox / PlayStation / Switch pad, other pad, or keyboard), a
## "Controllers found" count, a hint box and a gold Next button.

const MAX_PLAYERS := 4
const MIN_PLAYERS := 2
const HINT_JOIN := "Two to four players. Press Enter (keyboard) or A (gamepad) to join, then again to confirm %s."
const HINT_WAIT := "Waiting for everyone to be %s.   Esc / B: not ready, then leave."

## Joined devices by player slot (-1 = keyboard, else gamepad id).
var devices: Array[int] = []
## Ready flag per slot.
var ready_flags: Array[bool] = []

var layout: NeonScreenLayout
var cards: Array[SlotCard] = []
## The gold "Player Setup" button (enabled when everyone is ready).
var next_button: NeonMenuButton
## The ALL READY banner (shown while everyone is ready).
var confirm_banner: PanelContainer
var _found_icon: ControllerIcon
var _found_count: Label
var _hint_box: Control
var _hint: RichTextLabel
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


## Icon kind shown on a slot's card ("generic" for an empty slot).
func card_kind(slot: int) -> String:
	return cards[slot].icon.kind


## The "Controllers found" number as shown.
func controllers_found_text() -> String:
	return _found_count.text


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
		var card := cards[i]
		if i >= devices.size():
			card.show_empty()
			continue
		var kind := DeviceInput.controller_kind(devices[i])
		if ready_flags[i]:
			card.show_ready(kind)
		else:
			card.show_joined(kind, DeviceInput.kind_label(kind),
					"Press %s again\nto be READY" % ("Enter" if devices[i] < 0 else "A"))
	var pads := Input.get_connected_joypads()
	_found_count.text = str(pads.size())
	# One kind of pad plugged in: show it; none or a mix: the plain pad.
	var kinds := {}
	for p in pads:
		kinds[DeviceInput.controller_kind(p)] = true
	_found_icon.kind = kinds.keys()[0] if kinds.size() == 1 else "generic"
	var all_ready := can_continue()
	confirm_banner.visible = all_ready
	_hint_box.visible = not all_ready
	next_button.disabled = not all_ready
	var gold := "[color=#%s]READY[/color]" % UIStyle.GOLD.to_html(false)
	_hint.text = "[center]" + (HINT_JOIN if devices.size() < MIN_PLAYERS else HINT_WAIT) % gold + "[/center]"


func _build() -> void:
	layout = MultiplayerWidgets.frame(self, "CONNECT CONTROLLERS", 1)
	layout.back_button.pressed.connect(back)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.content.add_child(page)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 46)
	row_margin.add_theme_constant_override("margin_right", 46)
	row_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(row_margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_margin.add_child(row)
	for i in MAX_PLAYERS:
		var card := SlotCard.new(i, SplitScreen.PLAYER_COLORS[i])
		row.add_child(card)
		cards.append(card)

	# "Controllers found: N" between two fading lines.
	var found := HBoxContainer.new()
	found.add_theme_constant_override("separation", 14)
	found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(found)
	found.add_child(MultiplayerWidgets.FadeLine.new(true))
	_found_icon = ControllerIcon.new("generic", Vector2(52, 34), false)
	_found_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	found.add_child(_found_icon)
	var found_text := UIStyle.label("Controllers found:", 24)
	found_text.add_theme_font_override("font", UIStyle.slanted_font(false))
	found.add_child(found_text)
	_found_count = UIStyle.label("0", 28, UIStyle.CYAN)
	_found_count.add_theme_font_override("font", UIStyle.slanted_font(true))
	found.add_child(_found_count)
	found.add_child(MultiplayerWidgets.FadeLine.new(false))

	# The hint box; the ALL READY banner takes its place.
	var hint_holder := Control.new()
	hint_holder.custom_minimum_size = Vector2(0, 66)
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(hint_holder)
	var hint_center := CenterContainer.new()
	hint_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_holder.add_child(hint_center)
	var info := MultiplayerWidgets.InfoBox.new()
	hint_center.add_child(info)
	_hint_box = info
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 18)
	info.add_child(info_row)
	info_row.add_child(MultiplayerWidgets.InfoGlyph.new())
	_hint = RichTextLabel.new()
	_hint.bbcode_enabled = true
	_hint.fit_content = true
	_hint.scroll_active = false
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.custom_minimum_size = Vector2(960, 0)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("normal_font", UIStyle.bold_font())
	_hint.add_theme_font_size_override("normal_font_size", 23)
	info_row.add_child(_hint)
	var banner_center := CenterContainer.new()
	banner_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_holder.add_child(banner_center)
	confirm_banner = MultiplayerConnect.ready_banner("Press Enter / A / Start to choose cars")
	banner_center.add_child(confirm_banner)

	next_button = MultiplayerWidgets.next_button("Player Setup", continue_to_cars)
	add_child(next_button)


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


# --- pieces ------------------------------------------------------------------

## One player's slot: a tall neon card with a slanted "P1" tag on its top
## edge, the device icon, and the join / READY prompt, over a checker fade.
class SlotCard extends Control:
	const TAG_H := 50.0
	const EMPTY_INK := Color(0.72, 0.72, 0.8, 0.9)

	var slot: int
	var color: Color
	var icon: ControllerIcon
	## 0 empty, 1 joined, 2 ready.
	var state: int = 0
	var _dots: Dots
	var _device: Label
	var _prompt: Label
	var _ready_banner: ReadyBanner
	var _time: float = 0.0

	func _init(index: int, player_color: Color) -> void:
		slot = index
		color = player_color
		custom_minimum_size = Vector2(230, 330)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_top = TAG_H + 4
		box.offset_bottom = -34
		box.offset_left = 12
		box.offset_right = -12
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		icon = ControllerIcon.new("generic", Vector2(200, 110))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		_dots = Dots.new()
		_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(_dots)
		_device = UIStyle.label("", 22, Color.WHITE)
		_device.add_theme_font_override("font", UIStyle.slanted_font(true))
		_device.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_device)
		_prompt = UIStyle.label("", 24, Color.WHITE)
		_prompt.add_theme_font_override("font", UIStyle.bold_font())
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt.add_theme_constant_override("line_spacing", -4)
		box.add_child(_prompt)
		_ready_banner = ReadyBanner.new()
		_ready_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(_ready_banner)
		show_empty()

	func show_empty() -> void:
		state = 0
		icon.kind = "generic"
		icon.color = EMPTY_INK
		icon.muted = true
		icon.excited = false
		_dots.visible = true
		_device.visible = false
		_prompt.visible = true
		_prompt.text = "Press Enter / A\nto join"
		_ready_banner.visible = false
		queue_redraw()

	func show_joined(kind: String, device_text: String, prompt: String) -> void:
		state = 1
		icon.kind = kind
		icon.color = Color.WHITE
		icon.muted = false
		icon.excited = false
		_dots.visible = false
		_device.visible = true
		_device.text = device_text
		_device.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
		_prompt.visible = true
		_prompt.text = prompt
		_ready_banner.visible = false
		queue_redraw()

	func show_ready(kind: String) -> void:
		state = 2
		icon.kind = kind
		icon.color = Color.WHITE
		icon.muted = false
		icon.excited = true
		_dots.visible = false
		_device.visible = false
		_prompt.visible = false
		_ready_banner.visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if state == 2:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, TAG_H * 0.5), size - Vector2(0, TAG_H * 0.5))
		var pts := NeonPanel.rounded_rect(r, 22.0)
		# Fill: dark, tinted by the player's colour towards the bottom.
		var fills := PackedColorArray()
		for p in pts:
			var t := (p.y - r.position.y) / r.size.y
			fills.append(Color(0.05, 0.03, 0.12, 0.88).lerp(Color(color.darkened(0.7), 0.88), t * t * (0.5 if state == 0 else 0.8)))
		draw_polygon(pts, fills)
		_draw_checker(r)
		var edge := color
		var glow := 0.18
		var width := 3.0
		if state == 0:
			edge = Color(color, 0.75)
			glow = 0.1
		elif state == 2:
			edge = SetupWidgets.GOLD_TOP
			glow = 0.3 + 0.1 * sin(_time * 4.0)
			width = 4.0
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(edge, glow * 0.6), 22.0, true)
		draw_polyline(outline, Color(edge, glow * 1.6), 9.0, true)
		draw_polyline(outline, edge, width, true)
		if state == 2:
			draw_polyline(outline, Color(1, 1, 0.9, 0.7), 1.2, true)
		_draw_tag()

	## Slanted checker squares along the bottom, fading upwards.
	func _draw_checker(r: Rect2) -> void:
		var cell := 18.0
		var rows := 3
		var y_bottom := r.end.y - 10.0
		var inset := 12.0
		var cols := int((r.size.x - inset * 2.0) / cell)
		var x0 := r.position.x + (r.size.x - cols * cell) * 0.5
		for row in rows:
			var y := y_bottom - (row + 1) * cell
			var a := (0.34 if state > 0 else 0.2) * (1.0 - float(row) / rows)
			for c in cols:
				if (c + row) % 2 != 0:
					continue
				var x := x0 + c * cell
				draw_rect(Rect2(x, y, cell, cell), Color(color, a))

	## "P1" on a slanted bar in the player's colour, across the top edge.
	func _draw_tag() -> void:
		var w := 128.0
		var h := TAG_H
		var s := h * 0.32
		var x := (size.x - w) * 0.5
		var pts := PackedVector2Array([Vector2(x + s, 0), Vector2(x + w, 0), Vector2(x + w - s, h), Vector2(x, h)])
		var cols := PackedColorArray()
		for p in pts:
			cols.append(color.lightened(0.25).lerp(color.darkened(0.15), p.y / h))
		draw_polygon(pts, cols)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(color, 0.3), 8.0, true)
		var font := UIStyle.slanted_font(true)
		var text := "P%d" % (slot + 1)
		var fs := 40
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var base := Vector2(x + (w - ts.x) * 0.5, (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
		draw_string(font, base + Vector2(2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## "• • •" under an empty slot's icon (drawn: the fonts lack the glyph).
class Dots extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(60, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 3:
			draw_circle(Vector2(size.x * 0.5 + (i - 1) * 18.0, size.y * 0.5), 3.5, Color(1, 1, 1, 0.75))


## Gold "READY!" plate with checker flags either side.
class ReadyBanner extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(250, 58)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var cx := size.x * 0.5
		# Checker flags.
		var cell := h * 0.22
		for side in [-1.0, 1.0]:
			for c in 3:
				for r in 2:
					if (c + r) % 2 != 0:
						continue
					var x: float = cx + side * (h * 1.3 + c * cell) - (cell if side < 0 else 0.0)
					var y := h * 0.5 - cell + r * cell
					var sk := cell * 0.35
					draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + cell + sk, y),
							Vector2(x + cell, y + cell), Vector2(x, y + cell)]), Color(SetupWidgets.GOLD_TOP, 0.9 - 0.25 * c))
		# The plate.
		var w := h * 2.6
		var s := h * 0.3
		var x0 := cx - w * 0.5
		var pts := PackedVector2Array([Vector2(x0 + s, 4), Vector2(x0 + w, 4), Vector2(x0 + w - s, h - 4), Vector2(x0, h - 4)])
		var cols := PackedColorArray()
		for p in pts:
			cols.append(SetupWidgets.GOLD_TOP.lerp(SetupWidgets.GOLD_BOTTOM, p.y / h))
		var glow := pts.duplicate()
		glow.append(pts[0])
		draw_polyline(glow, Color(SetupWidgets.GOLD_TOP, 0.3), 12.0, true)
		draw_polygon(pts, cols)
		var font := UIStyle.slanted_font(true)
		var fs := int(h * 0.56)
		var ts := font.get_string_size("READY!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(cx - ts.x * 0.5, (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5), "READY!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SetupWidgets.DARK_TEXT)
