class_name UIStyle
extends RefCounted
## Placeholder neon styling shared by the code-built menus (pause, results,
## mode select) until the Phase 5 interface pass.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)
const BACKGROUND := Color(0.02, 0.01, 0.06, 0.92)


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func panel(border: Color = MAGENTA) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", style)
	return p


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 40)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.03, 0.14, 0.95) if state != "hover" else Color(0.12, 0.05, 0.25, 0.95)
		style.border_color = MAGENTA if state == "focus" or state == "pressed" else Color(1, 1, 1, 0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(on_pressed)
	return b


## Focus chain for keyboard / gamepad navigation in a vertical list.
static func chain_focus(buttons: Array) -> void:
	for i in buttons.size():
		var b := buttons[i] as Control
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])


## Full-screen dark background for menu screens.
static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.008, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Screen title on the left, coin balance on the right. Returns the coin label.
static func header(parent: Container, title: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(label(title, 34, MAGENTA))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var coins := label("", 22, Color(1.0, 0.82, 0.3))
	row.add_child(coins)
	return coins


## Horizontal bar for a 1-10 stat rating.
static func stat_bar(rating: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.value = rating
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = MAGENTA
	fill.set_corner_radius_all(2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


## Vehicle name, type, description and four stat bars, rebuilt in place.
static func fill_vehicle_info(box: VBoxContainer, vehicle: VehicleData) -> void:
	for child in box.get_children():
		child.queue_free()
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	title.add_child(label(vehicle.display_name, 24, Color.WHITE))
	title.add_child(label(vehicle.vehicle_type, 15, CYAN))
	box.add_child(title)
	var desc := label(vehicle.character, 14, Color(1, 1, 1, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(400, 0)
	box.add_child(desc)
	var names: Array = VehicleCatalog.STAT_RANGES.keys()
	var values := VehicleCatalog.primary_stats(vehicle.stats)
	for i in names.size():
		var row := HBoxContainer.new()
		var name_label := label(names[i], 15)
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)
		row.add_child(stat_bar(VehicleCatalog.rating(names[i], values[i])))
		box.add_child(row)
	box.add_child(label("Top speed %d km/h" % roundi(vehicle.stats.top_speed * 3.6), 13, Color(1, 1, 1, 0.55)))
