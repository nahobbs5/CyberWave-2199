class_name MenuHints
extends HBoxContainer
## "A Select   B Back" in the bottom-right corner of the start menus. Shows
## gamepad buttons (green A, pink B) while a pad is in use and Enter / Esc
## keycaps after a key press.

const PAD_A := Color(0.2, 0.85, 0.3)
const PAD_B := Color(1.0, 0.2, 0.6)

var _gamepad: bool = false
var _glyphs: Array[_Glyph] = []


func _init(entries: Array = [["A", "Enter", "Select"], ["B", "Esc", "Back"]]) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14)
	for e in entries:
		var glyph := _Glyph.new(e[0], e[1])
		add_child(glyph)
		_glyphs.append(glyph)
		var l := Label.new()
		l.text = e[2]
		l.add_theme_font_override("font", UIStyle.slanted_font(false))
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 5)
		add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(18, 0)
		add_child(gap)
	_set_gamepad(not Input.get_connected_joypads().is_empty())


func is_gamepad() -> bool:
	return _gamepad


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		_set_gamepad(true)
	elif event is InputEventKey:
		_set_gamepad(false)


func _set_gamepad(on: bool) -> void:
	if on == _gamepad and not _glyphs.is_empty() and _glyphs[0].gamepad == on:
		return
	_gamepad = on
	for g in _glyphs:
		g.gamepad = on
		g.update_minimum_size()
		g.queue_redraw()


## A round pad button ("A" green, "B" pink) or a keycap ("Enter").
class _Glyph extends Control:
	var pad_label: String
	var key_label: String
	var gamepad: bool = false

	func _init(pad: String, key: String) -> void:
		pad_label = pad
		key_label = key
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _get_minimum_size() -> Vector2:
		if gamepad:
			return Vector2(38, 38)
		var font := UIStyle.bold_font()
		var w := font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x if font != null else 40.0
		return Vector2(w + 22, 34)

	func _draw() -> void:
		var font := UIStyle.bold_font()
		if gamepad:
			var c := size * 0.5
			var col := MenuHints.PAD_A if pad_label == "A" else MenuHints.PAD_B
			draw_circle(c, 18.0, Color(col, 0.3))
			draw_circle(c, 15.5, col.darkened(0.2))
			draw_arc(c, 15.5, 0.0, TAU, 32, col.lightened(0.4), 2.0, true)
			if font != null:
				var sz := font.get_string_size(pad_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
				draw_string(font, c + Vector2(-sz.x * 0.5, font.get_ascent(22) * 0.5 - 1), pad_label,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.05, 0.02, 0.08))
		else:
			var r := Rect2(Vector2.ZERO, size)
			var style := UIStyle.box_style(Color(0.08, 0.04, 0.16, 0.9), Color(1, 1, 1, 0.6), 0, 2)
			style.set_corner_radius_all(6)
			draw_style_box(style, r)
			if font != null:
				var sz := font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
				draw_string(font, Vector2((size.x - sz.x) * 0.5, size.y * 0.5 + font.get_ascent(18) * 0.5 - 2), key_label,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
