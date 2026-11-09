class_name NeonMenuButton
extends Button
## Start-menu button after "reference files/Cyberwave 2199 Racing Menu.png":
## a slanted bar with a cyan-to-magenta neon edge, an icon and upper-case
## italic lettering. The focused button turns gold with dark lettering and a
## ">>" chevron. Hovering with the mouse moves focus, so only one is lit.
## `text` keeps its normal casing (tests read it); the drawn label is
## upper case.

const GOLD_TOP := Color(1.0, 0.86, 0.25)
const GOLD_BOTTOM := Color(0.98, 0.66, 0.08)
const DARK_TEXT := Color(0.08, 0.03, 0.12)

## Icon kind for UIStyle.cached_icon ("" for none).
var icon_kind: String = ""
## One line about this option, shown in the menu's info box.
var description: String = ""
## Pixels the bar's left end is pulled left (the reference's column steps
## out a little at each row).
var lean: float = 0.0
var font_size: int = 30
## A second icon drawn after the first (the Settings tabs).
var extra_icon_kind: String = ""
## Draw the ">>" on the lit button's right end.
var chevrons: bool = true
## Tabs: when set (true / false) this, not focus, decides the gold look.
var lit_override: Variant = null

var _font: Font


func _init(label_text: String = "", kind: String = "", info: String = "") -> void:
	text = label_text
	icon_kind = kind
	description = info
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(500, 58)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	# The Button's own text is hidden; _draw letters it.
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	_font = UIStyle.slanted_font(true)
	mouse_entered.connect(func() -> void:
		if not disabled and focus_mode != Control.FOCUS_NONE:
			grab_focus())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	focus_entered.connect(_pop)
	resized.connect(func() -> void: pivot_offset = Vector2(size.x * 0.3, size.y * 0.5))


func is_lit() -> bool:
	return bool(lit_override) if lit_override != null else has_focus()


func set_lit(on: bool) -> void:
	lit_override = on
	queue_redraw()


func _pop() -> void:
	if not is_inside_tree():
		return
	scale = Vector2.ONE * 1.04
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.14)


func _draw() -> void:
	var h := size.y
	var slant := h * 0.42
	var x0 := -lean
	var x1 := size.x
	var lit := is_lit()
	# Parallelogram leaning right, with clipped corners.
	var cut := 7.0
	var pts := PackedVector2Array([
		Vector2(x0 + slant + cut, 0), Vector2(x1 - cut, 0), Vector2(x1, cut),
		Vector2(x1 - slant, h - cut), Vector2(x1 - slant - cut, h),
		Vector2(x0 + cut, h), Vector2(x0, h - cut), Vector2(x0 + slant, cut),
	])
	var fill_top := GOLD_TOP if lit else Color(0.09, 0.04, 0.2, 0.86)
	var fill_bottom := GOLD_BOTTOM if lit else Color(0.04, 0.02, 0.1, 0.86)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(fill_top.lerp(fill_bottom, p.y / h))
	draw_polygon(pts, cols)
	if not lit:
		# Faint lighter band across the top, like glass.
		draw_line(Vector2(x0 + slant + 10, 3), Vector2(x1 - 12, 3), Color(1, 1, 1, 0.08), 2.0)
	var outline := pts.duplicate()
	outline.append(pts[0])
	var edge := PackedColorArray()
	for p in outline:
		var t := clampf((p.x - x0) / (x1 - x0), 0.0, 1.0)
		edge.append(Color(1.0, 0.95, 0.7) if lit else UIStyle.CYAN.lerp(UIStyle.MAGENTA, t))
	var glow := PackedColorArray()
	for c in edge:
		glow.append(Color(c, 0.22))
	draw_polyline_colors(outline, glow, 8.0, true)
	draw_polyline_colors(outline, edge, 2.5, true)

	var ink := DARK_TEXT if lit else Color.WHITE
	var ix := x0 + slant + 18.0
	var icon_size := int(h * 0.6)
	if icon_kind != "":
		var tex := UIStyle.cached_icon(icon_kind, icon_size)
		draw_texture_rect(tex, Rect2(Vector2(ix, (h - icon_size) * 0.5), Vector2(icon_size, icon_size)), false, ink)
	var tx := ix + icon_size + 22.0
	if extra_icon_kind != "":
		var tex2 := UIStyle.cached_icon(extra_icon_kind, icon_size)
		draw_texture_rect(tex2, Rect2(Vector2(ix + icon_size + 6.0, (h - icon_size) * 0.5), Vector2(icon_size, icon_size)), false, ink)
		tx += icon_size + 6.0
	var asc := _font.get_ascent(font_size)
	var desc := _font.get_descent(font_size)
	var baseline := (h + asc - desc) * 0.5
	if not lit:
		draw_string(_font, Vector2(tx + 2, baseline + 2), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(0, 0, 0, 0.6))
	draw_string(_font, Vector2(tx, baseline), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if lit and chevrons:
		# ">>" on the right end.
		var cx := x1 - slant * 0.5 - 40.0
		var cy := h * 0.5
		for k in 2:
			var bx := cx + k * 15.0
			draw_polyline(PackedVector2Array([Vector2(bx - 6, cy - 11), Vector2(bx + 6, cy), Vector2(bx - 6, cy + 11)]),
					ink, 5.0, true)
