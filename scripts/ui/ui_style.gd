class_name UIStyle
extends RefCounted
## Shared neon styling for the code-built menus and HUD. Colours carry
## meaning: magenta = you / selection / drifting, cyan = boost / speed /
## navigation, gold = coins and rewards, orange-red = warnings and lost
## places, white = primary text, muted = secondary. Oxanium for headings and
## big numbers, Rajdhani (the theme's default font) for everything else.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)
const GOLD := Color(1.0, 0.82, 0.3)
const WARN := Color(1.0, 0.45, 0.2)
const DANGER := Color(1.0, 0.25, 0.3)
const TEXT := Color(1, 1, 1)
const MUTED := Color(0.75, 0.7, 0.85, 0.75)
const FAINT := Color(1, 1, 1, 0.5)
const BACKGROUND := Color(0.02, 0.01, 0.06, 0.92)
## Translucent purple for HUD panels over the track.
const PANEL_BG := Color(0.05, 0.02, 0.1, 0.62)
const PANEL_BORDER := Color(0.55, 0.3, 0.8, 0.55)
const RADIUS := 6
const PADDING := 12

const HEADING_FONT_PATH := "res://assets/fonts/Oxanium-Variable.ttf"
const BOLD_FONT_PATH := "res://assets/fonts/Rajdhani-Bold.ttf"

static var _heading_font: Font
static var _bold_font: Font


## Oxanium Bold (the variable font at weight 700).
static func heading_font() -> Font:
	if _heading_font == null:
		var base := load(HEADING_FONT_PATH) as FontFile
		if base == null:
			return null
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_heading_font = v
	return _heading_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load(BOLD_FONT_PATH) as Font
	return _bold_font


## Big numbers and headings (Oxanium).
static func heading(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	var font := heading_font()
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Stats and labels in Rajdhani Bold.
static func stat(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	var font := bold_font()
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Translucent HUD panel: dark purple, thin neon border.
static func hud_panel(border: Color = PANEL_BORDER, padding: int = PADDING) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box_style(PANEL_BG, border, padding))
	return p


static func box_style(bg: Color, border: Color, padding: int = PADDING, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(padding)
	return style


## Fades a screen or panel in (150-300 ms menu transitions).
static func fade_in(control: CanvasItem, seconds: float = 0.2) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var t := control.create_tween()
	t.tween_property(control, "modulate:a", 1.0, seconds)


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


## Standard menu button (secondary look: dark fill, outline on focus).
static func button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, false)


## Filled magenta button for the main action on a screen.
static func primary_button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, true)


## Outlined button for the alternative action.
static func secondary_button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, false)


static func _make_button(text: String, on_pressed: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 42)
	b.add_theme_font_size_override("font_size", 19)
	var font := bold_font()
	if font != null:
		b.add_theme_font_override("font", font)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		if primary:
			style.bg_color = MAGENTA.darkened(0.25) if state in ["normal", "disabled"] else MAGENTA
			style.border_color = Color.WHITE if state == "focus" else MAGENTA.lightened(0.2)
			style.set_border_width_all(3 if state == "focus" else 2)
			if state == "disabled":
				style.bg_color = Color(0.3, 0.12, 0.28, 0.9)
		else:
			style.bg_color = Color(0.06, 0.03, 0.14, 0.95) if state != "hover" else Color(0.12, 0.05, 0.25, 0.95)
			style.border_color = MAGENTA if state in ["focus", "pressed", "hover"] else Color(1, 1, 1, 0.25)
			style.set_border_width_all(3 if state == "focus" else 2)
		if state == "focus":
			# Focus ring: a soft glow outside the border.
			style.shadow_color = Color(MAGENTA, 0.45)
			style.shadow_size = 6
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.pressed.connect(on_pressed)
	# A short pop on hover / focus.
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(_pop.bind(b))
	b.focus_entered.connect(_pop.bind(b))
	return b


static func _pop(b: Button) -> void:
	if not b.is_inside_tree() or b.disabled:
		return
	b.scale = Vector2.ONE * 1.04
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE, 0.12)


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
	row.add_child(heading(title, 34, MAGENTA))
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
