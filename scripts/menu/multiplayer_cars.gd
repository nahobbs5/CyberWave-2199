class_name MultiplayerCars
extends Control
## Split screen, step 2 of 3: every player picks a car on their own device.
## Each card shows the car turning on its platform, its name and type, and
## its stats (top speed, acceleration, handling, drift), so players can
## compare before they choose. Left / right changes car, Enter / A readies
## up, Esc / B un-readies (or, when not ready, goes back to connecting
## controllers). When everyone is ready an ALL READY banner asks for one more
## Enter / A / Start (any player) before the race setup opens.
## Player 1 drives their Garage loadout; players 2-4 the stock car in their
## player colour. Everyone can set a license plate: Y (gamepad) or Tab
## (keyboard) on your card. The keyboard player types; gamepad players use
## a letter picker (up / down changes the letter, left / right moves, X
## deletes, A or Y is done). Player 1's plate is saved to their profile.
##
## Laid out after "reference files/Neon Cyberpunk Multiplayer Car Select.png"
## in the connect screen's style: two players get tall side-by-side cards
## with a strip of car pictures (CarThumbnails); three or four get a 2x2
## grid of wide cards, and with three the fourth cell lists the controls.

## Letters the gamepad picker cycles through.
const PLATE_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- "
const READY_GREEN := Color(0.35, 1.0, 0.45)

## One per player: {"device": int, "vehicle": int, "ready": bool,
## "plate": String, "editing": bool, "cursor": int}.
var slots: Array[Dictionary] = []
var plate_labels: Array[Label] = []

var previews: Array[VehiclePreview] = []
var cards: Array[CarCard] = []
var layout: NeonScreenLayout
## The gold "Race Setup" button (enabled when everyone is ready).
var next_button: NeonMenuButton
## The ALL READY banner (shown while everyone is ready).
var confirm_banner: PanelContainer
## Three players: the controls panel in the fourth cell.
var help_panel: Control
var _help_status: Label
var _hint_bar: Control
var _presses := DeviceInput.new()


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = true
	Music.play(get_tree(), Music.MENU)
	var count := VehicleCatalog.all().size()
	for i in GameSession.mp_devices.size():
		var index := -1
		if i < GameSession.mp_vehicles.size() and GameSession.mp_vehicles[i] != "":
			index = VehicleCatalog.index_of(GameSession.mp_vehicles[i])
		if index < 0:
			# Player 1: their garage car. Others: a different car each to start.
			index = VehicleCatalog.index_of(PlayerProfile.get_profile().selected_vehicle) if i == 0 else i % count
		var plate := "P%d" % (i + 1)
		if i < GameSession.mp_plates.size() and GameSession.mp_plates[i] != "":
			plate = GameSession.mp_plates[i]
		elif i == 0:
			plate = PlayerProfile.get_profile().plate_text
		slots.append({"device": GameSession.mp_devices[i], "vehicle": maxi(index, 0), "ready": false,
				"plate": plate, "editing": false, "cursor": 0})
	_build()
	for i in slots.size():
		_show_car(i)
	UIStyle.fade_in(self)
	_refresh()
	CarThumbnails.request(get_tree(), _on_thumbnails)


## Three or four players: wide cards in a 2x2 grid.
func quadrants() -> bool:
	return slots.size() >= 3


## Car pictures in a player's strip (0 in the quadrant layout).
func thumb_count(slot: int) -> int:
	return cards[slot].thumbs.cell_count() if cards[slot].thumbs != null else 0


## Mouse: picks a car straight from the strip.
func pick_vehicle(device: int, index: int) -> void:
	var i := slot_of(device)
	if i == -1 or bool(slots[i].ready) or bool(slots[i].editing):
		return
	slots[i].vehicle = posmod(index, VehicleCatalog.all().size())
	_show_car(i)
	_refresh()


func slot_of(device: int) -> int:
	for i in slots.size():
		if int(slots[i].device) == device:
			return i
	return -1


func vehicle_of(slot: int) -> VehicleData:
	return VehicleCatalog.all()[int(slots[slot].vehicle)]


## The 1-10 ratings shown on a player's card, in display order (tests).
func shown_ratings(slot: int) -> Array[int]:
	return cards[slot].ratings()


func plate_of(slot: int) -> String:
	return str(slots[slot].plate)


func is_editing(device: int) -> bool:
	var i := slot_of(device)
	return i != -1 and bool(slots[i].editing)


## Starts editing this player's plate (not while ready).
func start_plate_edit(device: int) -> void:
	var i := slot_of(device)
	if i == -1 or bool(slots[i].ready):
		return
	slots[i].editing = true
	slots[i].cursor = maxi(0, plate_of(i).length() - 1)
	_refresh()


## Done editing: tidies the plate (player 1's is saved to their profile).
func finish_plate_edit(device: int) -> void:
	var i := slot_of(device)
	if i == -1 or not bool(slots[i].editing):
		return
	slots[i].editing = false
	var plate := PlayerProfile.sanitize_plate(plate_of(i)).strip_edges()
	if plate == "":
		plate = PlayerProfile.get_profile().plate_text if i == 0 else "P%d" % (i + 1)
	slots[i].plate = plate
	if i == 0:
		PlayerProfile.get_profile().set_plate(plate)
	_show_car(i)
	_refresh()


## Keyboard: adds typed characters to the plate (letters, digits, space, -).
func type_plate(device: int, text: String) -> void:
	var i := slot_of(device)
	if i == -1 or not bool(slots[i].editing):
		return
	var plate := PlayerProfile.sanitize_plate(plate_of(i) + text.to_upper())
	slots[i].plate = plate
	slots[i].cursor = maxi(0, plate.length() - 1)
	_show_car(i)
	_refresh()


## Deletes the character under the picker's cursor (keyboard: the last one).
func delete_plate_char(device: int) -> void:
	var i := slot_of(device)
	if i == -1 or not bool(slots[i].editing) or plate_of(i).is_empty():
		return
	var plate := plate_of(i)
	var at := clampi(int(slots[i].cursor), 0, plate.length() - 1)
	if device < 0:
		at = plate.length() - 1
	slots[i].plate = plate.substr(0, at) + plate.substr(at + 1)
	slots[i].cursor = clampi(at, 0, maxi(0, plate_of(i).length() - 1))
	_show_car(i)
	_refresh()


## Gamepad picker: up / down change the letter under the cursor.
func cycle_plate_char(device: int, delta: int) -> void:
	var i := slot_of(device)
	if i == -1 or not bool(slots[i].editing):
		return
	var plate := plate_of(i)
	var at := int(slots[i].cursor)
	if plate.is_empty():
		plate = "A"
		at = 0
	var now := PLATE_CHARS.find(plate[at])
	var ch := PLATE_CHARS[posmod(now + delta, PLATE_CHARS.length())]
	slots[i].plate = plate.substr(0, at) + ch + plate.substr(at + 1)
	slots[i].cursor = at
	_show_car(i)
	_refresh()


## Gamepad picker: left / right move the cursor; right past the end adds a
## letter (up to the plate's limit).
func move_plate_cursor(device: int, delta: int) -> void:
	var i := slot_of(device)
	if i == -1 or not bool(slots[i].editing):
		return
	var plate := plate_of(i)
	var at := int(slots[i].cursor) + delta
	if at >= plate.length() and plate.length() < PlayerProfile.PLATE_MAX:
		plate += "A"
		slots[i].plate = plate
		_show_car(i)
	slots[i].cursor = clampi(at, 0, maxi(0, plate.length() - 1))
	_refresh()


func step_vehicle(device: int, delta: int) -> void:
	var i := slot_of(device)
	if i == -1 or bool(slots[i].ready) or bool(slots[i].editing):
		return
	slots[i].vehicle = posmod(int(slots[i].vehicle) + delta, VehicleCatalog.all().size())
	_show_car(i)
	_refresh()


func set_ready(device: int, value: bool) -> void:
	var i := slot_of(device)
	if i == -1 or bool(slots[i].editing):
		return
	slots[i].ready = value
	_refresh()


func all_ready() -> bool:
	if slots.is_empty():
		return false
	for s in slots:
		if not bool(s.ready):
			return false
	return true


func continue_to_setup() -> void:
	_store()
	GameSession.to_mp_setup(get_tree())


func back() -> void:
	_store()
	GameSession.to_multiplayer(get_tree())


func _store() -> void:
	var cars := PackedStringArray()
	var plates := PackedStringArray()
	for i in slots.size():
		cars.append(vehicle_of(i).id)
		plates.append(plate_of(i))
	GameSession.mp_vehicles = cars
	GameSession.mp_plates = plates


func _input(event: InputEvent) -> void:
	var device := DeviceInput.device_of(event)
	if device == -2:
		return
	var slot := slot_of(device)
	if slot == -1:
		return
	if bool(slots[slot].editing):
		_edit_input(event, device)
		return
	var press := _presses.press_of(event)
	if press == "":
		return
	get_viewport().set_input_as_handled()
	match press:
		"plate":
			start_plate_edit(device)
		"accept", "start":
			if all_ready():
				continue_to_setup()
			else:
				set_ready(device, true)
		"cancel":
			if bool(slots[slot].ready):
				set_ready(device, false)
			else:
				back()
		"left":
			step_vehicle(device, -1)
		"right":
			step_vehicle(device, 1)


## Keys and buttons while a plate is being edited.
func _edit_input(event: InputEvent, device: int) -> void:
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed:
			return
		match k.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_ESCAPE:
				if not k.echo:
					finish_plate_edit(device)
			KEY_BACKSPACE:
				delete_plate_char(device)
			_:
				if k.unicode > 0 and not k.echo:
					type_plate(device, String.chr(k.unicode))
		return
	match _presses.press_of(event):
		"up":
			cycle_plate_char(device, 1)
		"down":
			cycle_plate_char(device, -1)
		"left":
			move_plate_cursor(device, -1)
		"right":
			move_plate_cursor(device, 1)
		"delete":
			delete_plate_char(device)
		"accept", "plate", "cancel", "start":
			finish_plate_edit(device)



func _show_car(slot: int) -> void:
	var v := vehicle_of(slot)
	var profile := PlayerProfile.get_profile()
	if slot == 0:
		previews[slot].show_vehicle(v, profile.loadout_for(v.id), plate_of(slot))
	else:
		previews[slot].show_vehicle(v, {}, plate_of(slot))
		previews[slot].car.set_body_color(SplitScreen.PLAYER_COLORS[slot].darkened(0.15))
	cards[slot].show_vehicle(v, int(slots[slot].vehicle))


func _refresh() -> void:
	if cards.is_empty():
		return
	var everyone := all_ready()
	confirm_banner.visible = everyone
	if _hint_bar != null:
		_hint_bar.visible = not everyone
	next_button.disabled = not everyone
	var waiting: PackedStringArray = []
	for i in slots.size():
		var ready := bool(slots[i].ready)
		var editing := bool(slots[i].editing)
		var keyboard := int(slots[i].device) < 0
		if not ready:
			waiting.append("P%d" % (i + 1))
		var caption := "LICENSE PLATE"
		if editing:
			caption = "TYPE, ENTER: DONE" if keyboard else "UP/DOWN, X DEL, A DONE"
		var plate := plate_of(i)
		if editing and keyboard:
			plate += "_"
		elif editing:
			var at := clampi(int(slots[i].cursor), 0, maxi(0, plate.length() - 1))
			plate = plate.substr(0, at) + "[" + plate.substr(at, 1) + "]" + plate.substr(at + 1) if not plate.is_empty() else "[ ]"
		cards[i].set_state(ready, editing, plate, caption)
	if _help_status != null:
		_help_status.text = "ALL READY!" if everyone else "Waiting for " + ", ".join(waiting)
		_help_status.add_theme_color_override("font_color", READY_GREEN if everyone else UIStyle.GOLD)


func _on_thumbnails() -> void:
	for card in cards:
		if card.thumbs != null:
			card.thumbs.queue_redraw()


func _build() -> void:
	layout = MultiplayerWidgets.frame(self, "CHOOSE YOUR CARS", 2)
	layout.back_button.pressed.connect(back)
	var quad := quadrants()
	if quad:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 14)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var grid_margin := MarginContainer.new()
		grid_margin.add_theme_constant_override("margin_left", 46)
		grid_margin.add_theme_constant_override("margin_right", 46)
		grid_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.content.add_child(grid_margin)
		grid_margin.add_child(grid)
		for i in slots.size():
			grid.add_child(_make_card(i, false))
		if slots.size() == 3:
			help_panel = _build_help_panel()
			grid.add_child(help_panel)
	else:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 60)
		margin.add_theme_constant_override("margin_right", 60)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.content.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 34)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)
		for i in slots.size():
			row.add_child(_make_card(i, true))

	next_button = MultiplayerWidgets.next_button("Race Setup", func() -> void:
		if all_ready():
			continue_to_setup())
	next_button.font_size = 26
	next_button.offset_left = -34 - 360
	add_child(next_button)

	# Bottom middle, between Back and Next: the controls (unless the
	# three-player panel lists them) or the ALL READY banner.
	var bottom := Control.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 318
	bottom.offset_right = -34 - 360 - 12
	bottom.offset_top = -92
	bottom.offset_bottom = -14
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(center)
	if help_panel == null:
		var bar := HintBar.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		bar.add_child(row)
		_hint(row, [ArrowsGlyph.new()], "Change Car")
		_hint(row, [_glyph("Y", true), _slash(), _glyph("Tab", false)], "Edit Plate")
		_hint(row, [_glyph("A", true), _slash(), _glyph("Enter", false)], "Ready")
		center.add_child(bar)
		_hint_bar = bar
	confirm_banner = MultiplayerConnect.ready_banner("Press Enter / A / Start to continue")
	center.add_child(confirm_banner)


func _make_card(i: int, tall: bool) -> CarCard:
	var device := int(slots[i].device)
	var kind := DeviceInput.controller_kind(device)
	var label := "Keyboard" if device < 0 else DeviceInput.kind_label(kind).capitalize()
	var card := CarCard.new(i, SplitScreen.PLAYER_COLORS[i], kind, label, tall)
	card.stepped.connect(func(d: int) -> void: step_vehicle(device, d))
	card.picked.connect(func(index: int) -> void: pick_vehicle(device, index))
	cards.append(card)
	previews.append(card.preview)
	plate_labels.append(card.plate_label)
	return card


func _build_help_panel() -> Control:
	var panel := NeonPanel.new(12, UIStyle.CYAN, UIStyle.MAGENTA)
	panel.radius = 20.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := UIStyle.label("CONTROLS", 22, Color.WHITE)
	title.add_theme_font_override("font", UIStyle.slanted_font(true))
	box.add_child(title)
	var rows: Array = [
		[[ArrowsGlyph.new()], "Change car"],
		[[_glyph("Y", true), _slash(), _glyph("Tab", false)], "Edit license plate"],
		[[_glyph("A", true), _slash(), _glyph("Enter", false)], "Ready"],
		[[_glyph("B", true), _slash(), _glyph("Esc", false)], "Not ready / back"],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		_hint(row, r[0], r[1])
	_help_status = UIStyle.label("", 20, UIStyle.GOLD)
	_help_status.add_theme_font_override("font", UIStyle.slanted_font(true))
	box.add_child(_help_status)
	return panel


func _hint(row: HBoxContainer, glyphs: Array, text: String) -> void:
	for g: Control in glyphs:
		row.add_child(g)
	var l := UIStyle.label(text, 17, Color.WHITE)
	l.add_theme_font_override("font", UIStyle.slanted_font(false))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	row.add_child(gap)


func _glyph(text: String, pad: bool) -> Control:
	var g := MenuHints._Glyph.new(text, text)
	g.gamepad = pad
	g.update_minimum_size()
	return g


func _slash() -> Label:
	var l := UIStyle.label("/", 18, UIStyle.MUTED)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


# --- pieces ------------------------------------------------------------------

## One player's card: a neon frame in their colour with a header (P tag,
## device, READY), the car on its platform with < > arrows, name, type,
## stat bars, the car strip (tall cards) and the license plate.
class CarCard extends Control:
	signal stepped(direction: int)
	signal picked(index: int)

	const HEADER_TALL := 48.0
	const HEADER_WIDE := 40.0

	var slot: int
	var color: Color
	var tall: bool
	var preview: VehiclePreview
	var thumbs: ThumbStrip
	var plate_label: Label
	var ready_state: bool = false
	var editing: bool = false
	var _name: Label
	var _type: Label
	var _stats: VBoxContainer
	var _counter: Label
	var _caption: Label
	var _plate_box: PlateBox
	var _header_h: float

	func _init(index: int, player_color: Color, device_kind: String, device_label: String, tall_card: bool) -> void:
		slot = index
		color = player_color
		tall = tall_card
		_header_h = HEADER_TALL if tall else HEADER_WIDE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		_build_header(device_kind, device_label)
		var body_margin := MarginContainer.new()
		body_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body_margin.offset_top = _header_h + 4
		body_margin.offset_left = 14
		body_margin.offset_right = -14
		body_margin.offset_bottom = -10
		body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(body_margin)
		if tall:
			_build_tall(body_margin)
		else:
			_build_wide(body_margin)

	## Device icon and name in the header (the tag and READY are drawn).
	func _build_header(device_kind: String, device_label: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.position = Vector2(118 if tall else 96, 0)
		row.size = Vector2(300, _header_h)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var icon := ControllerIcon.new(device_kind, Vector2(40, _header_h - 14), false)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var l := UIStyle.label(device_label, 20 if tall else 18, Color.WHITE)
		l.add_theme_font_override("font", UIStyle.bold_font())
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)

	func _build_stage(min_height: float) -> Control:
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(0, min_height)
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.clip_contents = true
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview = VehiclePreview.new()
		# Up to four of these on screen: the lighter garage.
		preview.detail = VehiclePreview.Detail.LITE
		preview.ring_color = color
		preview.custom_minimum_size = Vector2(200, min_height)
		preview.spin_speed = 0.6
		if not tall:
			# Narrow stage: step back so the whole car fits.
			preview.zoom = 1.45
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(preview)
		for d in [-1, 1]:
			var b := CarShowcase._Chevron.new(d)
			b.gold = false
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void: stepped.emit(d))
			b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if d < 0 else Control.PRESET_CENTER_RIGHT)
			b.offset_left = 4 if d < 0 else -4 - 44
			b.offset_right = b.offset_left + 44
			b.offset_top = -34
			b.offset_bottom = 34
			stage.add_child(b)
		return stage

	func _build_tall(parent: Control) -> void:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(box)
		box.add_child(_build_stage(130))
		var plate := NamePlate.new(self)
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(plate)
		_name = _name_label(26)
		plate.add_child(_name)
		_type = _type_label(17)
		box.add_child(_type)
		_stats = _stat_box(3)
		box.add_child(_stats)
		var strip_row := HBoxContainer.new()
		strip_row.add_theme_constant_override("separation", 4)
		strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(strip_row)
		strip_row.add_child(_small_arrow(-1))
		thumbs = ThumbStrip.new(color)
		thumbs.picked.connect(func(i: int) -> void: picked.emit(i))
		strip_row.add_child(thumbs)
		strip_row.add_child(_small_arrow(1))
		box.add_child(_plate_row(17, 200))

	func _build_wide(parent: Control) -> void:
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 12)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(body)
		var stage := _build_stage(120)
		stage.size_flags_stretch_ratio = 0.85
		body.add_child(stage)
		_counter = UIStyle.label("", 16, Color(1, 1, 1, 0.85))
		_counter.add_theme_font_override("font", UIStyle.slanted_font(true))
		_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_counter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_counter.offset_left = -50
		_counter.offset_right = 50
		_counter.offset_top = -26
		_counter.offset_bottom = -2
		stage.add_child(_counter)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 3)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(info)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(top)
		var plate := NamePlate.new(self)
		top.add_child(plate)
		_name = _name_label(20)
		plate.add_child(_name)
		_type = _type_label(14)
		_type.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_type)
		_stats = _stat_box(1)
		info.add_child(_stats)
		info.add_child(_plate_row(14, 160))

	func _name_label(fs: int) -> Label:
		var l := UIStyle.label("", fs, Color.WHITE)
		l.add_theme_font_override("font", UIStyle.slanted_font(true))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l

	func _type_label(fs: int) -> Label:
		var l := UIStyle.label("", fs, UIStyle.CYAN)
		l.add_theme_font_override("font", UIStyle.slanted_font(true))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l

	func _stat_box(gap: int) -> VBoxContainer:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", gap)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return box

	func _small_arrow(d: int) -> Button:
		var b := CarShowcase._Chevron.new(d)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 0)
		b.pressed.connect(func() -> void: stepped.emit(d))
		return b

	func _plate_row(fs: int, width: float) -> HBoxContainer:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption = UIStyle.label("LICENSE PLATE", fs, color.lerp(Color.WHITE, 0.2))
		_caption.add_theme_font_override("font", UIStyle.slanted_font(true))
		_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_caption)
		_plate_box = PlateBox.new(color)
		_plate_box.custom_minimum_size = Vector2(width, 0)
		row.add_child(_plate_box)
		plate_label = UIStyle.label("", fs + 6, Color.WHITE)
		plate_label.add_theme_font_override("font", UIStyle.slanted_font(true))
		plate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_plate_box.add_child(plate_label)
		return row

	func show_vehicle(v: VehicleData, index: int) -> void:
		_name.text = v.display_name
		_type.text = v.vehicle_type.to_upper()
		for child in _stats.get_children():
			_stats.remove_child(child)
			child.queue_free()
		var names: Array = VehicleCatalog.STAT_RANGES.keys()
		var values := VehicleCatalog.primary_stats(v.stats)
		var fs := 18 if tall else 15
		for i in names.size():
			var rating := VehicleCatalog.rating(names[i], values[i])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stats.add_child(row)
			row.add_child(RaceIcons.rect(CarShowcase.STAT_ICONS.get(names[i], "gauge"), fs + 4))
			var l := UIStyle.label(str(names[i]).capitalize(), fs)
			l.add_theme_font_override("font", UIStyle.bold_font())
			l.custom_minimum_size = Vector2(fs * 6.4, 0)
			row.add_child(l)
			var bar := StatBar.new(color, rating)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bar)
			var number := UIStyle.label(str(rating * 10), fs)
			number.name = "Value"
			number.add_theme_font_override("font", UIStyle.bold_font())
			number.custom_minimum_size = Vector2(30, 0)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(number)
		if thumbs != null:
			thumbs.current = index
			thumbs.queue_redraw()
		if _counter != null:
			_counter.text = "%d / %d" % [index + 1, VehicleCatalog.all().size()]

	## The 1-10 ratings as shown, in order (tests).
	func ratings() -> Array[int]:
		var out: Array[int] = []
		for row in _stats.get_children():
			if row.is_queued_for_deletion():
				continue
			out.append(int((row.get_node("Value") as Label).text) / 10)
		return out

	func set_state(is_ready: bool, is_editing: bool, plate: String, caption: String) -> void:
		ready_state = is_ready
		editing = is_editing
		plate_label.text = plate
		_caption.text = caption
		_plate_box.editing = is_editing
		_plate_box.queue_redraw()
		queue_redraw()

	func _draw() -> void:
		var r := 20.0
		var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), r)
		draw_colored_polygon(pts, Color(0.04, 0.03, 0.1, 0.9))
		# Header band with rounded top corners.
		var h := _header_h
		var head := PackedVector2Array()
		for i in 7:
			var a := PI + PI * 0.5 * i / 6.0
			head.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
		for i in 7:
			var a := PI * 1.5 + PI * 0.5 * i / 6.0
			head.append(Vector2(size.x - r, r) + Vector2(cos(a), sin(a)) * r)
		head.append(Vector2(size.x, h))
		head.append(Vector2(0, h))
		draw_colored_polygon(head, Color(color.darkened(0.78), 0.95))
		# P tag: player-colour block with a slanted right edge.
		var tag_w := 100.0 if tall else 80.0
		var tag := PackedVector2Array()
		for i in 7:
			var a := PI + PI * 0.5 * i / 6.0
			tag.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
		tag.append(Vector2(tag_w, 0))
		tag.append(Vector2(tag_w - h * 0.35, h))
		tag.append(Vector2(0, h))
		draw_colored_polygon(tag, Color(color, 0.35))
		draw_line(Vector2(tag_w, 0), Vector2(tag_w - h * 0.35, h), color, 2.0, true)
		var font := UIStyle.slanted_font(true)
		var fs := int(h * 0.78)
		var tag_text := "P%d" % (slot + 1)
		var ts := font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var base_y := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2((tag_w - h * 0.2 - ts.x) * 0.5, base_y), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				color.lerp(Color.WHITE, 0.25))
		# READY / NOT READY / EDITING on the right, after a slanted divider.
		var state_w := 170.0 if tall else 140.0
		var sx := size.x - state_w
		draw_line(Vector2(sx + h * 0.35, 0), Vector2(sx, h), Color(color, 0.8), 2.0, true)
		var sfs := int(h * 0.44)
		var text := "NOT READY"
		var ink := Color(1, 1, 1, 0.5)
		if ready_state:
			text = "READY"
			ink = MultiplayerCars.READY_GREEN
		elif editing:
			text = "EDITING"
			ink = UIStyle.GOLD
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var tx := sx + (state_w - tw) * 0.5 + (10.0 if ready_state else 0.0)
		var ty := (h + font.get_ascent(sfs) - font.get_descent(sfs)) * 0.5
		if ready_state:
			var c := Vector2(tx - 16, h * 0.5)
			draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(9, -8)]), ink, 4.0, true)
		draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, ink)
		draw_line(Vector2(0, h), Vector2(size.x, h), Color(color, 0.7), 2.0)
		# Frame.
		var outline := pts.duplicate()
		outline.append(pts[0])
		var glow := 0.3 if ready_state else 0.16
		draw_polyline(outline, Color(color, glow * 0.5), 20.0, true)
		draw_polyline(outline, Color(color, glow), 8.0, true)
		draw_polyline(outline, color, 3.0 if ready_state else 2.5, true)


## The car name inside a slanted outline in the player's colour.
class NamePlate extends MarginContainer:
	var _card: CarCard

	func _init(card: CarCard) -> void:
		_card = card
		add_theme_constant_override("margin_left", 34)
		add_theme_constant_override("margin_right", 34)
		add_theme_constant_override("margin_top", 1)
		add_theme_constant_override("margin_bottom", 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.3
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h), Vector2(s, 0)])
		draw_colored_polygon(pts.slice(0, 4), Color(0.03, 0.02, 0.08, 0.92))
		draw_polyline(pts, Color(_card.color, 0.25), 8.0, true)
		draw_polyline(pts, _card.color, 2.0, true)


## A rating bar: dark track, the player's colour filled to rating / 10.
class StatBar extends Control:
	var color: Color
	var rating: int

	func _init(c: Color, value: int) -> void:
		color = c
		rating = value
		custom_minimum_size = Vector2(80, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		var w := size.x * clampf(rating / 10.0, 0.0, 1.0)
		draw_rect(Rect2(-1, -1, w + 2, size.y + 2), Color(color, 0.25))
		draw_rect(Rect2(0, 0, w, size.y), color)
		draw_rect(Rect2(0, 0, w, size.y * 0.35), Color(1, 1, 1, 0.25))


## Four car pictures around the current car; the current one is framed in
## the player's colour. Click one to pick it.
class ThumbStrip extends Control:
	signal picked(index: int)

	const CELLS := 4
	var color: Color
	var current: int = 0

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(0, 50)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)

	func cell_count() -> int:
		return mini(CELLS, VehicleCatalog.all().size())

	func first() -> int:
		return clampi(current - 1, 0, maxi(0, VehicleCatalog.all().size() - cell_count()))

	func _cell_rect(i: int) -> Rect2:
		var gap := 8.0
		var w := (size.x - gap * (cell_count() - 1)) / cell_count()
		return Rect2(i * (w + gap), 0, w, size.y)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in cell_count():
			if _cell_rect(i).has_point(mb.position):
				picked.emit(first() + i)
				accept_event()
				return

	func _draw() -> void:
		var cars := VehicleCatalog.all()
		for i in cell_count():
			var index := first() + i
			var r := _cell_rect(i)
			var on := index == current
			var pts := NeonPanel.rounded_rect(r, 10.0, 3)
			draw_colored_polygon(pts, Color(0.1, 0.08, 0.22, 0.9) if not on else Color(color.darkened(0.6), 0.9))
			var tex := CarThumbnails.get_texture(cars[index].id)
			if tex != null:
				var ts := tex.get_size()
				var k := minf(r.size.x / ts.x, r.size.y / ts.y) * 1.1
				var dst := Rect2(r.get_center() - ts * k * 0.5, ts * k)
				draw_texture_rect(tex, dst, false)
			var outline := pts.duplicate()
			outline.append(pts[0])
			if on:
				draw_polyline(outline, Color(color, 0.3), 8.0, true)
				draw_polyline(outline, color, 2.5, true)
			else:
				draw_polyline(outline, Color(1, 1, 1, 0.18), 1.5, true)


## The license plate box; its edge lights up while it's being edited.
class PlateBox extends MarginContainer:
	var color: Color
	var editing: bool = false

	func _init(c: Color) -> void:
		color = c
		add_theme_constant_override("margin_left", 16)
		add_theme_constant_override("margin_right", 34)
		add_theme_constant_override("margin_top", 2)
		add_theme_constant_override("margin_bottom", 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), 10.0, 3)
		draw_colored_polygon(pts, Color(0.02, 0.01, 0.06, 0.95))
		pts.append(pts[0])
		var edge := UIStyle.GOLD if editing else color
		draw_polyline(pts, Color(edge, 0.25), 8.0, true)
		draw_polyline(pts, edge, 2.0, true)
		# Pencil on the right.
		var c := Vector2(size.x - 18, size.y * 0.5)
		var d := Vector2(1, -1).normalized()
		var n := Vector2(d.y, -d.x)
		var tip := c - d * 8.0
		var back := c + d * 8.0
		var ink := Color(1, 1, 1, 0.85)
		draw_colored_polygon(PackedVector2Array([tip, tip + d * 4.0 + n * 3.0, back + n * 3.0, back - n * 3.0, tip + d * 4.0 - n * 3.0]), ink)


## Rounded dark bar holding the control hints at the bottom.
class HintBar extends MarginContainer:
	func _init() -> void:
		add_theme_constant_override("margin_left", 18)
		add_theme_constant_override("margin_right", 10)
		add_theme_constant_override("margin_top", 8)
		add_theme_constant_override("margin_bottom", 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), 12.0)
		draw_colored_polygon(pts, Color(0.04, 0.03, 0.12, 0.85))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.55, 0.5, 0.9, 0.6), 2.0, true)


## "<-->" arrows glyph for "Change car".
class ArrowsGlyph extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(40, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var ink := Color.WHITE
		draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), ink, 3.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(-8, -7), c + Vector2(-16, 0), c + Vector2(-8, 7)]), ink, 3.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(8, -7), c + Vector2(16, 0), c + Vector2(8, 7)]), ink, 3.0, true)
