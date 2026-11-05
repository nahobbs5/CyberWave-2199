class_name DriftMeter
extends Control
## Horizontal drift charge bar with Cyan / Magenta / Gold threshold marks.

var drift: DriftController


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
	if drift == null:
		return
	var max_time: float = drift.level_thresholds[drift.level_thresholds.size() - 1]
	var fill := clampf(drift.charge_time / max_time, 0.0, 1.0)
	var color: Color = DriftController.LEVEL_COLORS[drift.level]
	if not drift.is_drifting():
		color.a = 0.35
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)), color)
	for i in drift.level_thresholds.size():
		var x := size.x * drift.level_thresholds[i] / max_time
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), DriftController.LEVEL_COLORS[i + 1], 3.0)
	draw_rect(rect, Color(0.8, 0.9, 1.0, 0.8), false, 2.0)
