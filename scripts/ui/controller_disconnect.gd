class_name ControllerDisconnect
extends CanvasLayer
## Pauses the race when a player's gamepad disconnects, after "reference
## files/Cyberwave Race Controller Disconnected.png": a cut-corner dark plate
## with an amber edge, a pad and broken-link icon, CONTROLLER DISCONNECTED,
## and an [Enter] Continue with keyboard row.
##
## Solo: only a pad that has driven this race counts (unplugging an idle pad
## while you play on keyboard does nothing). Any gamepad button, or Enter for
## the keyboard, carries on.
## Split screen: pauses everyone, titled PLAYER n. That player claims any pad
## no other player owns by pressing a button on it (their pN_ actions are
## rebuilt for it), or the keyboard with Enter when nobody else is on it.
## Then a 3-2-1 and the race resumes; if the pause menu was open, it comes
## back instead. Runs while the tree is paused.

const AMBER := Color(1.0, 0.68, 0.12)
const PURPLE := Color(0.5, 0.22, 0.95)
## Seconds per number of the 3-2-1 resume.
const COUNT_STEP := 0.6
const PLATE_SIZE := Vector2(820, 360)
## Title size solo, and with the longer PLAYER n title.
const TITLE_SIZE := 50
const TITLE_SIZE_LONG := 40

var race: RaceManager
## Split-screen slot being resolved (0 solo).
var slot: int = 0

## Pads that have driven this race (solo).
var _used_pads: Dictionary = {}
## Slots still waiting for a controller, in order.
var _queue: Array[int] = []
var _was_menu_open: bool = false
var _counting: bool = false
var _count_time: float = 0.0

var _screen: Control
var _plate: Control
var _title_lead: Label
var _title_tail: Label
var _subtitle: Label
var _keyboard_row: Control
var _rule: Control
var _count_label: Label


func _init() -> void:
	name = "ControllerDisconnect"
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(manager: RaceManager) -> void:
	race = manager
	_build()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


## Waiting for a controller, or counting back in.
func is_open() -> bool:
	return _screen != null and _screen.visible


func is_counting() -> bool:
	return _counting


## The whole title ("PLAYER 2 CONTROLLER DISCONNECTED"; tests).
func title_text() -> String:
	return "%s %s" % [_title_lead.text, _title_tail.text]


## Whether the [Enter] Continue with keyboard row shows.
func keyboard_offered() -> bool:
	return _keyboard_row.visible


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or race == null:
		return
	var affected := _slot_for(device)
	if affected < 0 or affected in _queue:
		return
	_queue.append(affected)
	if not is_open() or _counting:
		_open()


## Which player's controller this was: a slot, or -1 when it doesn't matter.
func _slot_for(device: int) -> int:
	if race.state != RaceManager.State.COUNTDOWN and race.state != RaceManager.State.RACING:
		return -1
	if race.is_multiplayer():
		var devices := race.config.player_devices
		for i in devices.size():
			if devices[i] == device and i < race.players.size() and not race.players[i].finished:
				return i
		return -1
	if not _used_pads.has(device) or race.player == null or race.player.finished:
		return -1
	return 0


func _open() -> void:
	if not is_open():
		var menu := race.pause_menu
		_was_menu_open = menu != null and menu.is_open()
		if _was_menu_open:
			menu.hide_panel()
	_counting = false
	get_tree().paused = true
	slot = _queue[0]
	var multi := race.is_multiplayer()
	_title_lead.text = "PLAYER %d CONTROLLER" % (slot + 1) if multi else "CONTROLLER"
	for l in [_title_lead, _title_tail]:
		(l as Label).add_theme_font_size_override("font_size", TITLE_SIZE_LONG if multi else TITLE_SIZE)
	_subtitle.text = "Reconnect it, or press a button on any free controller." if multi \
			else "Reconnect your controller, then press any button."
	_keyboard_row.visible = _keyboard_free()
	_rule.visible = _keyboard_row.visible
	_plate.visible = true
	_count_label.visible = false
	_screen.visible = true
	UIStyle.fade_in(_screen, 0.15)


## Solo always; split screen when no other player is on the keyboard.
func _keyboard_free() -> bool:
	if not race.is_multiplayer():
		return true
	var devices := race.config.player_devices
	for i in devices.size():
		if i != slot and devices[i] == -1:
			return false
	return true


## A pad no other player owns (any pad solo).
func _pad_free(device: int) -> bool:
	if not race.is_multiplayer():
		return true
	var devices := race.config.player_devices
	for i in devices.size():
		if i != slot and devices[i] == device:
			return false
	return true


func _input(event: InputEvent) -> void:
	if race == null:
		return
	if not is_open():
		# Solo: note which pads are actually driving.
		if not race.is_multiplayer():
			if (event is InputEventJoypadButton and event.pressed) \
					or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
				_used_pads[event.device] = true
		return
	# Nothing reaches the pause menu or the cars while this is up.
	get_viewport().set_input_as_handled()
	if _counting:
		return
	if event is InputEventJoypadButton and event.pressed and _pad_free(event.device):
		_resolve(event.device)
	elif event is InputEventKey and event.pressed and not event.echo \
			and ((event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER] \
			or (event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]) \
			and _keyboard_row.visible:
		_resolve(-1)


func _resolve(device: int) -> void:
	_queue.pop_front()
	if device >= 0:
		_used_pads[device] = true
	if race.is_multiplayer():
		race.config.player_devices[slot] = device
		InputSetup.build_player_actions(slot, device)
		if slot < race.players.size():
			var car := race.players[slot].vehicle
			if is_instance_valid(car) and car.haptics != null:
				car.haptics.device = device
		if race.championship != null and slot < race.championship.player_devices.size():
			race.championship.player_devices[slot] = device
	# Another player's pad went too: them next.
	if not _queue.is_empty():
		_open()
		return
	if _was_menu_open:
		_screen.visible = false
		race.pause_menu.show_panel()
		return
	_counting = true
	_count_time = 0.0
	_plate.visible = false
	_count_label.visible = true
	_show_number(3)


func _process(delta: float) -> void:
	if not _counting:
		return
	var before := int(_count_time / COUNT_STEP)
	_count_time += delta
	var step := int(_count_time / COUNT_STEP)
	if step >= 3:
		_counting = false
		_screen.visible = false
		get_tree().paused = false
	elif step != before:
		_show_number(3 - step)


func _show_number(n: int) -> void:
	_count_label.text = str(n)
	_count_label.pivot_offset = _count_label.size * 0.5
	_count_label.scale = Vector2.ONE * 1.35
	_count_label.modulate.a = 0.4
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_count_label, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_count_label, "modulate:a", 1.0, 0.12)


# --- building ---------------------------------------------------------------------

func _build() -> void:
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.visible = false
	add_child(_screen)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(dim)

	_plate = _Plate.new()
	_plate.name = "Plate"
	_plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_plate.offset_left = -PLATE_SIZE.x * 0.5
	_plate.offset_right = PLATE_SIZE.x * 0.5
	_plate.offset_top = -PLATE_SIZE.y * 0.5
	_plate.offset_bottom = PLATE_SIZE.y * 0.5
	_screen.add_child(_plate)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 26
	box.offset_bottom = -30
	box.offset_left = 50
	box.offset_right = -50
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(box)

	# Pad - broken link.
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 6)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icons)
	var pad := ControllerIcon.new("generic", Vector2(150, 96), false)
	pad.color = AMBER
	pad.muted = true
	icons.add_child(pad)
	icons.add_child(_BrokenLink.new())

	# CONTROLLER (white) DISCONNECTED (amber).
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_title_lead = _title_label("CONTROLLER", Color.WHITE)
	_title_tail = _title_label("DISCONNECTED", AMBER)
	title.add_child(_title_lead)
	title.add_child(_title_tail)

	_subtitle = UIStyle.label("Reconnect your controller, then press any button.", 24, Color(1, 1, 1, 0.9))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)

	var rule := ColorRect.new()
	_rule = rule
	rule.color = Color(PURPLE, 0.8)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	var row := HBoxContainer.new()
	row.name = "KeyboardRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var chip := PanelContainer.new()
	var chip_style := UIStyle.box_style(Color(0, 0, 0, 0), AMBER, 0, 2)
	chip_style.set_corner_radius_all(6)
	chip_style.content_margin_left = 18
	chip_style.content_margin_right = 18
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)
	var key := UIStyle.label("Enter", 24, Color.WHITE)
	key.add_theme_font_override("font", UIStyle.slanted_font(false))
	chip.add_child(key)
	row.add_child(chip)
	row.add_child(UIStyle.label("Continue with keyboard", 24, Color(1, 1, 1, 0.9)))
	_keyboard_row = row

	_count_label = UIStyle.stat("3", 160, AMBER)
	_count_label.name = "Countdown"
	_count_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	_count_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.1, 0.9))
	_count_label.add_theme_constant_override("outline_size", 14)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_count_label.offset_left = -150
	_count_label.offset_right = 150
	_count_label.offset_top = -120
	_count_label.offset_bottom = 120
	_count_label.visible = false
	_screen.add_child(_count_label)


func _title_label(text: String, color: Color) -> Label:
	var l := UIStyle.stat(text, TITLE_SIZE, color)
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	return l


## The cut-corner plate: dark fill, amber edge with a soft glow, purple
## stripes in the top-left and bottom-right corners.
class _Plate extends Control:
	const CUT := 34.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(CUT, 0), Vector2(w - CUT, 0), Vector2(w, CUT), Vector2(w, h - CUT),
				Vector2(w - CUT, h), Vector2(CUT, h), Vector2(0, h - CUT), Vector2(0, CUT)])
		draw_colored_polygon(pts, Color(0.04, 0.02, 0.1, 0.94))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(ControllerDisconnect.AMBER, 0.18), 9.0, true)
		draw_polyline(outline, ControllerDisconnect.AMBER, 2.0, true)
		for k in 3:
			var a := 0.85 - 0.22 * k
			var c := Color(ControllerDisconnect.PURPLE, a)
			var x := 48.0 + k * 20.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 10, 16), Vector2(x + 20, 16),
					Vector2(x + 8, 34), Vector2(x - 2, 34)]), c)
			var x2 := w - 48.0 - k * 20.0
			draw_colored_polygon(PackedVector2Array([Vector2(x2 + 2, h - 34), Vector2(x2 + 12, h - 34),
					Vector2(x2, h - 16), Vector2(x2 - 10, h - 16)]), c)


## "- (broken chain)" with little rays, amber.
class _BrokenLink extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(140, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := ControllerDisconnect.AMBER
		var mid := size.y * 0.5
		draw_line(Vector2(4, mid), Vector2(30, mid), c, 3.0, true)
		# Two half links of a chain, tilted, with a gap where they broke.
		var centre := Vector2(86, mid)
		var tilt := Transform2D(-0.45, centre)
		for side in [-1.0, 1.0]:
			# A capsule end (round side outward) with its two straight sides
			# reaching toward the break.
			var round_c := Vector2(side * 24.0, 0.0)
			var pts := PackedVector2Array()
			pts.append(Vector2(side * 5.0, -9.0))
			for i in 17:
				var a := -PI * 0.5 + PI * float(i) / 16.0
				pts.append(round_c + Vector2(side * cos(a) * 9.0, sin(a) * 9.0))
			pts.append(Vector2(side * 5.0, 9.0))
			draw_polyline(tilt * pts, c, 3.0, true)
		# Rays above and below the break.
		for dir in [Vector2(0, -1), Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0, 1), Vector2(-0.6, 0.8), Vector2(0.6, 0.8)]:
			var start: Vector2 = centre + dir * 20.0
			draw_line(start, start + dir * 9.0, c, 2.5, true)
