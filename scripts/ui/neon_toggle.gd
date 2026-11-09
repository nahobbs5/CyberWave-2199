class_name NeonToggle
extends Button
## ON / OFF pill switch: green with the knob on the right when on, grey with
## the knob on the left when off. Use button_pressed and the toggled signal
## like a CheckButton.


func _init() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(104, 38)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var on := button_pressed
	var rect := Rect2(Vector2.ZERO, size)
	var pill := StyleBoxFlat.new()
	pill.set_corner_radius_all(int(size.y * 0.5))
	pill.bg_color = NeonWidgets.TOGGLE_ON if on else Color(0.26, 0.24, 0.34)
	pill.border_color = Color(0.55, 1.0, 0.6) if on else Color(0.62, 0.6, 0.72)
	pill.set_border_width_all(2)
	if has_focus():
		pill.shadow_color = Color(1, 1, 1, 0.45)
		pill.shadow_size = 5
		pill.border_color = Color.WHITE
	draw_style_box(pill, rect)
	var r := size.y * 0.5 - 6.0
	var knob_x := size.x - size.y * 0.5 if on else size.y * 0.5
	draw_circle(Vector2(knob_x, size.y * 0.5), r, Color.WHITE)
	var font := UIStyle.bold_font()
	if font == null:
		return
	var text_size := 22
	var label := "ON" if on else "OFF"
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var area_x := 8.0 if on else size.y
	var area_w := size.x - size.y - 8.0
	var baseline := (size.y + font.get_ascent(text_size) - font.get_descent(text_size)) * 0.5
	draw_string(font, Vector2(area_x + (area_w - w) * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color.WHITE if on else Color(1, 1, 1, 0.85))
