class_name NeonWidgets
extends RefCounted
## Building blocks for the neon Settings and Credits screens (see
## NeonScreenLayout): section headers with a checker fade, icon + slider and
## icon + toggle rows, note lines, binding buttons and an outlined button.

const ROW_HEIGHT := 40.0
const LABEL_WIDTH := 200.0
const TOGGLE_ON := Color(0.16, 0.72, 0.3)


## Icon (cyan) and slanted heading, a checker fade on the right and a thin
## divider underneath. banner: draw it on a slanted bar instead (the
## mockup's AUDIO header).
static func section_header(icon_kind: String, text: String, banner: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(icon(icon_kind, 30, UIStyle.CYAN))
	var title := UIStyle.stat(text, 26, UIStyle.CYAN)
	title.add_theme_font_override("font", UIStyle.slanted_font(true))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var checker := Checker.new(Color(0.55, 0.3, 0.95, 0.5), 2, true)
	checker.custom_minimum_size = Vector2(130, 30)
	row.add_child(checker)
	if banner:
		var bar := Banner.new()
		bar.add_child(row)
		return bar
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(row)
	box.add_child(Divider.new())
	return box


## A white (or tinted) icon at a fixed size.
static func icon(kind: String, px: int, color: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UIStyle.cached_icon(kind, px)
	rect.modulate = color
	rect.custom_minimum_size = Vector2(px, px)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _row(parent: Container, icon_kind: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(40, 0)
	holder.add_child(icon(icon_kind, 30))
	row.add_child(holder)
	var l := UIStyle.label(text, 21)
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row


## Icon, label, magenta slider and a readout ("%d%%"). Calls on_change with
## the new value, then saves the settings (like UIStyle.slider_row).
static func slider_row(parent: Container, icon_kind: String, text: String, lo: float, hi: float,
		step: float, value: float, fmt: String, on_change: Callable) -> HSlider:
	var row := _row(parent, icon_kind, text)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(180, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_slider(slider)
	row.add_child(slider)
	var readout := UIStyle.label(fmt % roundi(value), 21)
	readout.custom_minimum_size = Vector2(66, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		readout.text = fmt % roundi(v)
		GameSettings.save_settings())
	return slider


## Icon, label and an ON / OFF pill. Calls on_change, then saves.
static func toggle_row(parent: Container, icon_kind: String, text: String, value: bool,
		on_change: Callable) -> NeonToggle:
	var row := _row(parent, icon_kind, text)
	var toggle := NeonToggle.new()
	toggle.button_pressed = value
	toggle.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		GameSettings.save_settings())
	row.add_child(toggle)
	return toggle


## Magenta fill, grey track, round white grabber.
static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.32, 0.3, 0.4, 0.85)
	track.set_corner_radius_all(5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UIStyle.MAGENTA
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = UIStyle.MAGENTA.lightened(0.2)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	slider.add_theme_icon_override("grabber", grabber_texture(false))
	slider.add_theme_icon_override("grabber_highlight", grabber_texture(true))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.55)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(8)
	focus.set_expand_margin_all(4)
	slider.add_theme_stylebox_override("focus", focus)


static var _grabbers: Dictionary = {}


## A white disc (with a magenta ring when highlighted).
static func grabber_texture(highlight: bool) -> Texture2D:
	if not _grabbers.has(highlight):
		var n := 30
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n, n) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				var col := Color(1, 1, 1, clampf(11.5 - d, 0.0, 1.0))
				if highlight and d >= 11.0:
					col = Color(UIStyle.MAGENTA.lightened(0.4), clampf(14.5 - d, 0.0, 1.0) * 0.9)
				img.set_pixel(x, y, col)
		_grabbers[highlight] = ImageTexture.create_from_image(img)
	return _grabbers[highlight]


## An (i) icon and a line of slanted text, optionally in a rounded outline.
## The text Label is named "Text".
static func note(text: String, color: Color, boxed: bool) -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(icon("info", 26, color if not boxed else Color.WHITE))
	var l := UIStyle.label(text, 17, color)
	l.name = "Text"
	l.add_theme_font_override("font", UIStyle.slanted_font(false))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	if not boxed:
		return row
	var box := PanelContainer.new()
	var style := UIStyle.box_style(Color(0.04, 0.02, 0.1, 0.6), Color(0.45, 0.45, 1.0, 0.7), 0, 2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	box.add_child(row)
	return box


## A key / gamepad binding box in the controls table.
static func binding_button(on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = "-"
	b.custom_minimum_size = Vector2(170, 25)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	var font := UIStyle.bold_font()
	if font != null:
		b.add_theme_font_override("font", font)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(5)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.bg_color = Color(0.03, 0.02, 0.08, 0.9) if state != "hover" else Color(0.12, 0.06, 0.22, 0.95)
		style.border_color = Color(0.62, 0.66, 0.95, 0.75)
		style.set_border_width_all(2)
		if state == "focus":
			style.bg_color = Color(0.2, 0.05, 0.22, 0.95)
			style.border_color = Color.WHITE
			style.shadow_color = Color(UIStyle.MAGENTA, 0.5)
			style.shadow_size = 5
		if state == "disabled":
			style.border_color = Color(1, 1, 1, 0.15)
		b.add_theme_stylebox_override(state, style)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(on_pressed)
	return b


## Rounded outline button with an icon and slanted text ("Reset to Defaults").
static func outline_button(text: String, icon_kind: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UIStyle.cached_icon(icon_kind, 26)
	b.add_theme_constant_override("h_separation", 12)
	b.add_theme_font_override("font", UIStyle.slanted_font(false))
	b.add_theme_font_size_override("font_size", 21)
	b.custom_minimum_size = Vector2(0, 40)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_right = 18
		style.bg_color = Color(0.04, 0.02, 0.1, 0.85) if state == "normal" else Color(0.14, 0.06, 0.24, 0.95)
		style.border_color = Color(0.85, 0.85, 1.0, 0.85)
		style.set_border_width_all(2)
		if state == "focus":
			style.border_color = UIStyle.GOLD
			style.shadow_color = Color(UIStyle.GOLD, 0.35)
			style.shadow_size = 6
		b.add_theme_stylebox_override(state, style)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.pressed.connect(on_pressed)
	return b


## Slanted squares in a checkerboard, fading out towards one end.
class Checker extends Control:
	var color: Color
	var rows: int
	## true: solid on the right, fading to the left.
	var fade_left: bool

	func _init(c: Color = UIStyle.MAGENTA, row_count: int = 2, fade_to_left: bool = false) -> void:
		color = c
		rows = row_count
		fade_left = fade_to_left
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var cell := size.y / rows
		var slant := 0.35
		var cols := int(ceil((size.x - size.y * slant) / cell))
		for col in cols:
			var t := float(col) / maxf(cols - 1, 1)
			var a := t if fade_left else 1.0 - t * 0.85
			for r in rows:
				if (col + r) % 2 != 0:
					continue
				var y0 := r * cell
				var x0 := col * cell + (size.y - y0) * slant
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, y0), Vector2(x0 + cell, y0),
					Vector2(x0 + cell - cell * slant, y0 + cell), Vector2(x0 - cell * slant, y0 + cell),
				]), Color(color, color.a * a))


## Thin line fading from cyan-violet to clear.
class Divider extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps := 24
		for i in steps:
			var t := float(i) / steps
			draw_rect(Rect2(size.x * t, 0, size.x / steps + 1, 2), Color(0.45, 0.4, 1.0, 0.6 * (1.0 - t)))


## The AUDIO header's slanted bar: deep blue to magenta, cyan edge.
class Banner extends MarginContainer:
	func _init() -> void:
		add_theme_constant_override("margin_left", 30)
		add_theme_constant_override("margin_right", 26)
		add_theme_constant_override("margin_top", 6)
		add_theme_constant_override("margin_bottom", 6)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size.y * 0.3
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, size.y), Vector2(0, size.y)])
		var cols := PackedColorArray()
		for p in pts:
			cols.append(Color(0.08, 0.06, 0.3, 0.9).lerp(Color(0.5, 0.1, 0.55, 0.9), p.x / size.x))
		draw_polygon(pts, cols)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(UIStyle.CYAN, 0.18), 7.0, true)
		draw_polyline(outline, Color(0.4, 0.75, 1.0), 2.0, true)
