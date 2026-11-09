class_name NeonStepper
extends Button
## "‹  value  ›" pill from the Versus setup mockup: a dark rounded pill with
## gold arrows either side of the value. Left / right (keys, d-pad, stick)
## step it while focused; clicking the left or right half steps it too.
## Keeps OptionButton's API (add_item, selected, item_selected, item_count)
## so it drops in where an OptionButton was. Wraps around at the ends.

signal item_selected(index: int)

const ARROW := Color(1.0, 0.8, 0.2)

var items: PackedStringArray = PackedStringArray()
var selected: int = -1:
	set(value):
		selected = clampi(value, -1, items.size() - 1)
		queue_redraw()
## Draw a gold glow while the row this sits in is focused (set by the row).
var highlight: bool = false:
	set(value):
		highlight = value
		queue_redraw()

var _font: Font


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(270, 42)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	_font = UIStyle.slanted_font(false)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func() -> void:
		if focus_mode != Control.FOCUS_NONE:
			grab_focus())


func add_item(label: String) -> void:
	items.append(label)
	if selected < 0:
		selected = 0


func get_item_count() -> int:
	return items.size()


func get_item_text(i: int) -> String:
	return items[i]


func value_text() -> String:
	return items[selected] if selected >= 0 and selected < items.size() else ""


## Moves by `delta` (wrapping) and emits item_selected.
func step(delta: int) -> void:
	if items.is_empty() or disabled:
		return
	selected = posmod(selected + delta, items.size())
	item_selected.emit(selected)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		step(-1 if (event as InputEventMouseButton).position.x < size.x * 0.5 else 1)
		accept_event()
		return
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		step(1)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var pill := StyleBoxFlat.new()
	pill.set_corner_radius_all(int(size.y * 0.5))
	pill.bg_color = Color(0.03, 0.02, 0.1, 0.95)
	pill.border_color = Color(0.35, 0.4, 0.9, 0.7)
	pill.set_border_width_all(2)
	var lit := has_focus() or highlight
	if lit:
		pill.border_color = ARROW
		pill.shadow_color = Color(ARROW, 0.35)
		pill.shadow_size = 6
	draw_style_box(pill, rect)
	# Gold chevrons at both ends.
	var cy := size.y * 0.5
	var h := size.y * 0.22
	for dir in [-1, 1]:
		var cx := 24.0 if dir < 0 else size.x - 24.0
		var pts := PackedVector2Array([Vector2(cx + 5 * dir * -1, cy - h), Vector2(cx + 5 * dir, cy), Vector2(cx + 5 * dir * -1, cy + h)])
		draw_polyline(pts, Color(ARROW, 0.3), 8.0, true)
		draw_polyline(pts, ARROW if not disabled else Color(1, 1, 1, 0.3), 4.0, true)
	if _font == null:
		return
	var fs := int(size.y * 0.56)
	var t := value_text()
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := (size.y + _font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	draw_string(_font, Vector2((size.x - w) * 0.5, baseline), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color.WHITE if not disabled else Color(1, 1, 1, 0.4))
