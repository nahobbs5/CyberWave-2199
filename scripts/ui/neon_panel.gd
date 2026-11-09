class_name NeonPanel
extends PanelContainer
## A rounded, dark see-through panel with a glowing neon edge that runs from
## `edge_from` (left) to `edge_to` (right), like the Settings and Credits
## mockups. Fill and edge are drawn here (not by a StyleBox) so the edge sits
## on top of the fill.

var edge_from: Color = UIStyle.CYAN
var edge_to: Color = UIStyle.MAGENTA
var fill_color: Color = Color(0.05, 0.02, 0.12, 0.82)
var radius: float = 16.0
var edge_width: float = 2.5
## Soft outer glow width (0 for none).
var glow: float = 10.0


func _init(padding: int = 18, from: Color = UIStyle.CYAN, to: Color = UIStyle.MAGENTA) -> void:
	edge_from = from
	edge_to = to
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(padding)
	add_theme_stylebox_override("panel", empty)
	resized.connect(queue_redraw)


func _draw() -> void:
	var pts := rounded_rect(Rect2(Vector2.ZERO, size), radius)
	draw_colored_polygon(pts, fill_color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	var cols := PackedColorArray()
	for p in outline:
		cols.append(edge_from.lerp(edge_to, clampf(p.x / maxf(size.x, 1.0), 0.0, 1.0)))
	if glow > 0.0:
		var soft := PackedColorArray()
		for c in cols:
			soft.append(Color(c, 0.14))
		draw_polyline_colors(outline, soft, glow, true)
		var mid := PackedColorArray()
		for c in cols:
			mid.append(Color(c, 0.3))
		draw_polyline_colors(outline, mid, glow * 0.45, true)
	draw_polyline_colors(outline, cols, edge_width, true)


## Corner points of a rounded rectangle, clockwise from the top-left.
static func rounded_rect(rect: Rect2, r: float, steps: int = 6) -> PackedVector2Array:
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[rect.end - Vector2(r, r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
	]
	for corner in corners:
		for i in steps + 1:
			var a: float = corner[1] + PI * 0.5 * i / steps
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * r)
	return pts
