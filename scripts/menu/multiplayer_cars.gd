class_name MultiplayerCars
extends Control
## Split screen, step 2 of 3: every player picks a car on their own device.
## Each card shows the car turning on its platform, its name and type, and
## its stats (top speed, acceleration, handling, drift as 1-10 bars), so
## players can compare before they choose. Left / right changes car, Enter /
## A readies up, Esc / B un-readies (or, when not ready, goes back to
## connecting controllers). When everyone is ready an ALL READY banner asks
## for one more Enter / A / Start (any player) before the race setup opens.
## Player 1 drives their Garage loadout; players 2-4 the stock car in their
## player colour. Everyone can set a license plate: Y (gamepad) or Tab
## (keyboard) on your card. The keyboard player types; gamepad players use
## a letter picker (up / down changes the letter, left / right moves, X
## deletes, A or Y is done). Player 1's plate is saved to their profile.

## Letters the gamepad picker cycles through.
const PLATE_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- "

## One per player: {"device": int, "vehicle": int, "ready": bool,
## "plate": String, "editing": bool, "cursor": int}.
var slots: Array[Dictionary] = []
var plate_labels: Array[Label] = []

var previews: Array[VehiclePreview] = []
var stat_grids: Array[GridContainer] = []
var _cards: Array[PanelContainer] = []
var _names: Array[Label] = []
var _types: Array[Label] = []
var _status: Array[Label] = []
var _presses := DeviceInput.new()
var _hint: Label
## The ALL READY banner (shown while everyone is ready).
var confirm_banner: PanelContainer


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


func slot_of(device: int) -> int:
	for i in slots.size():
		if int(slots[i].device) == device:
			return i
	return -1


func vehicle_of(slot: int) -> VehicleData:
	return VehicleCatalog.all()[int(slots[slot].vehicle)]


## The 1-10 ratings shown on a player's card, in display order (tests).
func shown_ratings(slot: int) -> Array[int]:
	var out: Array[int] = []
	var grid := stat_grids[slot]
	for i in range(2, grid.get_child_count(), 3):
		out.append(int((grid.get_child(i) as Label).text) / 10)
	return out


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
	_names[slot].text = v.display_name
	_types[slot].text = v.vehicle_type.to_upper()
	CarShowcase.fill_stat_grid(stat_grids[slot], v, 90.0, 14)


func _refresh() -> void:
	if confirm_banner != null:
		confirm_banner.visible = all_ready()
		_hint.visible = not confirm_banner.visible
	for i in slots.size():
		var color: Color = SplitScreen.PLAYER_COLORS[i]
		var ready := bool(slots[i].ready)
		var style := _cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = color
		style.set_border_width_all(4 if ready else 2)
		style.bg_color = Color(color, 0.12) if ready else Color(0.04, 0.02, 0.08, 0.92)
		var editing := bool(slots[i].editing)
		var keyboard := int(slots[i].device) < 0
		_status[i].text = "READY!" if ready else ("Enter / A: ready    %s: plate" % ("Tab" if keyboard else "Y"))
		if editing:
			_status[i].text = "Type the plate, Enter: done" if keyboard else "Up/down letter, X delete, A done"
		_status[i].add_theme_color_override("font_color", color if ready or editing else UIStyle.MUTED)
		_names[i].text = vehicle_of(i).display_name if ready or editing else "<   %s   >" % vehicle_of(i).display_name
		var plate := plate_of(i)
		if editing and keyboard:
			plate += "_"
		elif editing:
			var at := clampi(int(slots[i].cursor), 0, maxi(0, plate.length() - 1))
			plate = plate.substr(0, at) + "[" + plate.substr(at, 1) + "]" + plate.substr(at + 1) if not plate.is_empty() else "[ ]"
		plate_labels[i].text = plate
		var plate_style := plate_labels[i].get_theme_stylebox("normal") as StyleBoxFlat
		plate_style.border_color = color if editing else Color(1, 1, 1, 0.5)


func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	MultiplayerConnect.title_row(page, "CHOOSE YOUR CARS", 2)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	var width := 296.0 if slots.size() >= 4 else 340.0
	for i in slots.size():
		row.add_child(_card(i, width))

	_hint = UIStyle.stat("Left / right: change car    Y / Tab: license plate    Enter / A: ready    Esc / B: not ready / back", 16, Color.WHITE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_hint)
	confirm_banner = MultiplayerConnect.ready_banner("Press Enter / A / Start to continue")
	page.add_child(confirm_banner)


func _card(i: int, width: float) -> PanelContainer:
	var color: Color = SplitScreen.PLAYER_COLORS[i]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.box_style(Color(0.04, 0.02, 0.08, 0.92), color, 10, 2))
	card.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UIStyle.heading("P%d" % (i + 1), 30, color))
	var device := UIStyle.stat(DeviceInput.device_name(int(slots[i].device), false), 14, UIStyle.MUTED)
	device.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	device.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(device)
	var preview := VehiclePreview.new()
	# Four of these can be on screen: the lighter garage.
	preview.detail = VehiclePreview.Detail.LITE
	preview.custom_minimum_size = Vector2(width - 20.0, 170)
	preview.spin_speed = 0.6
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	var car_name := UIStyle.heading("", 21, Color.WHITE)
	car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(car_name)
	var type := UIStyle.stat("", 13, UIStyle.CYAN)
	type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(type)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var plate_row := HBoxContainer.new()
	plate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_row.add_theme_constant_override("separation", 10)
	box.add_child(plate_row)
	var plate_caption := UIStyle.stat("PLATE", 13, UIStyle.MUTED)
	plate_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate_row.add_child(plate_caption)
	var plate := UIStyle.heading("", 20, Color.WHITE)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.custom_minimum_size = Vector2(150, 0)
	var plate_style := UIStyle.box_style(Color(0.02, 0.01, 0.05, 0.95), Color(1, 1, 1, 0.5), 4, 2)
	plate_style.content_margin_left = 10
	plate_style.content_margin_right = 10
	plate.add_theme_stylebox_override("normal", plate_style)
	plate_row.add_child(plate)
	plate_labels.append(plate)
	var status := UIStyle.stat("", 15, UIStyle.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	_cards.append(card)
	previews.append(preview)
	_names.append(car_name)
	_types.append(type)
	stat_grids.append(grid)
	_status.append(status)
	return card
