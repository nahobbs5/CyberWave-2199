class_name MenuInfoBox
extends MarginContainer
## The start menus' description panel (bottom right of the reference art):
## a slanted dark panel with a neon edge, a magenta checker emblem on the
## left, the focused option's name in gold and one line about it.

var _title: Label
var _body: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(700, 92)
	add_theme_constant_override("margin_left", 150)
	add_theme_constant_override("margin_right", 40)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 12)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	_title = Label.new()
	_title.uppercase = true
	_title.add_theme_font_override("font", UIStyle.slanted_font(true))
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", NeonMenuButton.GOLD_TOP)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 5)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_override("font", UIStyle.slanted_font(false))
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)


func show_info(title: String, body: String) -> void:
	_title.text = title
	_body.text = body


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func _draw() -> void:
	var h := size.y
	var slant := h * 0.32
	var pts := PackedVector2Array([
		Vector2(slant, 0), Vector2(size.x, 0), Vector2(size.x - slant, h), Vector2(0, h)])
	var cols := PackedColorArray([
		Color(0.08, 0.03, 0.18, 0.88), Color(0.08, 0.03, 0.18, 0.88),
		Color(0.03, 0.01, 0.08, 0.9), Color(0.03, 0.01, 0.08, 0.9)])
	draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	var edge := PackedColorArray()
	for p in outline:
		edge.append(Color(0.65, 0.4, 1.0).lerp(UIStyle.MAGENTA, p.x / size.x))
	var glow := PackedColorArray()
	for c in edge:
		glow.append(Color(c, 0.2))
	draw_polyline_colors(outline, glow, 9.0, true)
	draw_polyline_colors(outline, edge, 2.0, true)
	# Checker emblem: slanted squares fading out to the right.
	var cell := h * 0.2
	var origin := Vector2(slant + 6.0, h * 0.18)
	for row in 3:
		for col in 4:
			if (row + col) % 2 != 0:
				continue
			var fade := 1.0 - col * 0.2
			var p := origin + Vector2(col * cell - row * cell * 0.35, row * cell)
			var q := PackedVector2Array([
				p + Vector2(cell * 0.35, 0), p + Vector2(cell * 1.35, 0),
				p + Vector2(cell, cell), p + Vector2(0, cell)])
			draw_colored_polygon(q, Color(UIStyle.MAGENTA, 0.85 * fade))
