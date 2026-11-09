class_name CarShowcase
extends VBoxContainer
## The car picker shared by the garage and race setup (GDD 11.3, 11.4): the
## rotating car on its neon platform with < > arrows and a dot per car, then
## the name, type, description and stat bars with a top-speed card.
## Emits vehicle_changed when the player asks for another car; the owner
## then calls set_vehicle (so it can save the choice and pick the loadout).
## LB / RB and Page Up / Page Down also step through the cars.

signal vehicle_changed(index: int)

var index: int = 0
var preview: VehiclePreview
var prev_button: Button
var next_button: Button
var dots: Array[Button] = []

var _name: Label
var _type: Label
var _description: Label
var _stats: GridContainer
var _top_speed: Label


func _init(stage_height: float = 300.0) -> void:
	add_theme_constant_override("separation", 6)
	_build(stage_height)


func vehicle() -> VehicleData:
	return VehicleCatalog.all()[index]


## Shows car `i` with this loadout and plate.
func set_vehicle(i: int, loadout: Dictionary, plate_text: String) -> void:
	index = posmod(i, VehicleCatalog.all().size())
	var v := vehicle()
	_name.text = v.display_name.to_upper()
	_type.text = v.vehicle_type.to_upper()
	_description.text = v.character
	_fill_stats(v)
	_top_speed.text = "%d km/h" % roundi(v.stats.top_speed * 3.6)
	for d in dots.size():
		dots[d].set_meta("current", d == index)
		dots[d].queue_redraw()
	preview.show_vehicle(v, loadout, plate_text)


## Re-dresses the car without changing which one is shown (try-ons, plate).
func show_loadout(loadout: Dictionary, plate_text: String) -> void:
	preview.show_vehicle(vehicle(), loadout, plate_text)


func step(delta: int) -> void:
	vehicle_changed.emit(posmod(index + delta, VehicleCatalog.all().size()))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var delta := 0
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER: delta = -1
			JOY_BUTTON_RIGHT_SHOULDER: delta = 1
	elif event is InputEventKey:
		match (event as InputEventKey).keycode:
			KEY_PAGEUP: delta = -1
			KEY_PAGEDOWN: delta = 1
	if delta != 0:
		step(delta)
		get_viewport().set_input_as_handled()


# --- layout ------------------------------------------------------------------

func _build(stage_height: float) -> void:
	# Stage: the 3D preview with arrows and dots laid over it.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, stage_height)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	add_child(stage)
	preview = VehiclePreview.new()
	preview.custom_minimum_size = Vector2(320, 200)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(preview)
	prev_button = _Chevron.new(-1)
	prev_button.pressed.connect(step.bind(-1))
	prev_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	prev_button.offset_left = 6
	prev_button.offset_right = 6 + 48
	prev_button.offset_top = -40
	prev_button.offset_bottom = 40
	stage.add_child(prev_button)
	next_button = _Chevron.new(1)
	next_button.pressed.connect(step.bind(1))
	next_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	next_button.offset_left = -6 - 48
	next_button.offset_right = -6
	next_button.offset_top = -40
	next_button.offset_bottom = 40
	stage.add_child(next_button)
	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.add_theme_constant_override("separation", 6)
	dot_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dot_row.offset_top = -30
	dot_row.offset_bottom = -8
	dot_row.offset_left = -200
	dot_row.offset_right = 200
	dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(dot_row)
	for i in VehicleCatalog.all().size():
		var dot := _Dot.new()
		dot.tooltip_text = VehicleCatalog.all()[i].display_name
		dot.pressed.connect(func() -> void: vehicle_changed.emit(i))
		dot_row.add_child(dot)
		dots.append(dot)

	# Name block: magenta slashes, slanted name, cyan type, description.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	add_child(name_row)
	var slashes := UIStyle.heading("//", 44, UIStyle.MAGENTA)
	slashes.add_theme_font_override("font", _slanted())
	name_row.add_child(slashes)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -6)
	name_row.add_child(titles)
	_name = UIStyle.heading("", 32)
	_name.add_theme_font_override("font", _slanted())
	titles.add_child(_name)
	_type = UIStyle.label("", 16, UIStyle.CYAN)
	_type.add_theme_font_override("font", _slanted(false))
	titles.add_child(_type)
	_description = UIStyle.label("", 15, Color(1, 1, 1, 0.75))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(300, 0)
	add_child(_description)

	# Stat bars with numbers, and the top-speed card beside them.
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 18)
	add_child(stats_row)
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 14)
	_stats.add_theme_constant_override("v_separation", 4)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(_stats)
	var card := UIStyle.hud_panel(Color(0.6, 0.4, 0.9, 0.45), 10)
	card.custom_minimum_size = Vector2(150, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_row.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(card_box)
	var card_title := UIStyle.label("Top Speed", 15, UIStyle.MUTED)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(card_title)
	_top_speed = UIStyle.heading("", 24)
	_top_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_top_speed)


func _fill_stats(v: VehicleData) -> void:
	fill_stat_grid(_stats, v)


## Fills a 3-column grid with the car's four stat rows (name, 1-10 bar,
## rating x10). Shared by the garage, race setup and split-screen car select.
static func fill_stat_grid(grid: GridContainer, v: VehicleData, bar_width: float = 150.0,
		font_size: int = 16) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var names: Array = VehicleCatalog.STAT_RANGES.keys()
	var values := VehicleCatalog.primary_stats(v.stats)
	for i in names.size():
		var rating := VehicleCatalog.rating(names[i], values[i])
		var name_label := UIStyle.label(str(names[i]), font_size)
		name_label.custom_minimum_size = Vector2(font_size * 6.5, 0)
		grid.add_child(name_label)
		var bar := UIStyle.stat_bar(rating)
		bar.custom_minimum_size = Vector2(bar_width, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bar)
		var number := UIStyle.stat(str(rating * 10), font_size + 1)
		number.custom_minimum_size = Vector2(30, 0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(number)


## Oxanium (or Rajdhani Bold) leaned forward like the reference's car name.
static func _slanted(heading: bool = true) -> Font:
	return UIStyle.slanted_font(heading)


## Big neon chevron arrow drawn in code.
class _Chevron extends Button:
	var direction: int = 1

	func _init(dir: int) -> void:
		direction = dir
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Previous car" if dir < 0 else "Next car"
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var w := 12.0
		var h := 26.0
		var pts := PackedVector2Array([
			c + Vector2(-w * direction, -h), c + Vector2(w * direction, 0), c + Vector2(-w * direction, h)])
		var hot := is_hovered() or has_focus()
		var col := Color.WHITE if hot else Color(0.85, 0.95, 1.0, 0.85)
		draw_polyline(pts, Color(UIStyle.CYAN, 0.25 if hot else 0.15), 14.0, true)
		draw_polyline(pts, Color(UIStyle.CYAN, 0.5), 8.0, true)
		draw_polyline(pts, col, 4.0, true)


## One dot per car under the preview; filled magenta for the current one.
class _Dot extends Button:
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(20, 20)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		if get_meta("current", false):
			draw_circle(c, 8.0, Color(UIStyle.MAGENTA, 0.3))
			draw_circle(c, 5.5, UIStyle.MAGENTA)
			draw_arc(c, 6.5, 0.0, TAU, 24, Color.WHITE, 1.5, true)
		else:
			var col := Color.WHITE if is_hovered() else Color(1, 1, 1, 0.6)
			draw_arc(c, 6.0, 0.0, TAU, 24, col, 1.5, true)
