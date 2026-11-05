class_name CoinIcon
extends Control
## Small gold coin drawn in code (there's no coin image): a gold disc with a
## darker rim, an inner ring and a highlight, like the coins on the track.

const GOLD := Color(1.0, 0.8, 0.2)


func _init(diameter: float = 20.0) -> void:
	custom_minimum_size = Vector2.ONE * diameter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.75))
	draw_circle(c, r - 1.5, GOLD.darkened(0.35))
	draw_circle(c, r - 3.0, GOLD)
	draw_arc(c, r * 0.5, 0.0, TAU, 24, GOLD.darkened(0.3), 1.5, true)
	draw_circle(c + Vector2(-r, -r) * 0.32, r * 0.18, Color(1.0, 1.0, 0.9, 0.85))
