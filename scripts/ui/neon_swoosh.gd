class_name NeonSwoosh
extends Control
## Glowing magenta curve along the bottom edge of the neon menu screens.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var pts := PackedVector2Array()
	var a := Vector2(-20, size.y - 14)
	var c := Vector2(size.x * 0.45, size.y - 70)
	var b := Vector2(size.x + 20, size.y - 64)
	for i in 49:
		var t := i / 48.0
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	draw_polyline(pts, Color(UIStyle.MAGENTA, 0.12), 16.0, true)
	draw_polyline(pts, Color(UIStyle.MAGENTA, 0.35), 6.0, true)
	draw_polyline(pts, Color(1.0, 0.6, 0.95), 2.0, true)
