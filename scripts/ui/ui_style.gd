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
