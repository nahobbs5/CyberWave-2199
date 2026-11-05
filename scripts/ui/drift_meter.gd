class_name DriftMeter
extends Control
## Drift charge bar. Fills in the current tier's colour (Cyan, Magenta, Gold:
## the boost you'll get) with tick marks at each tier, and glows more as
## charge builds. Once a boost is banked (tier 1+), a cyan outline pulses.
## While boosting, the bar shows the boost draining with a bright sweep.

var drift: DriftController
var vehicle: VehicleController

var _boost_full: float = 0.0


## 0..1 of the way to the top tier.
func charge_fraction() -> float:
	if drift == null:
		return 0.0
	var max_time: float = drift.level_thresholds[drift.level_thresholds.size() - 1]
	return clampf(drift.charge_time / max_time, 0.0, 1.0) if drift.is_drifting() else 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.0, 0.06, 0.7))
	if drift == null:
		return
	var calm := GameSettings.reduced_flashing
	var t := Time.get_ticks_msec() / 1000.0
	var boosting := vehicle != null and vehicle.is_boosting()
	if boosting:
		_boost_full = maxf(_boost_full, vehicle.boost_time_left)
		var left := clampf(vehicle.boost_time_left / maxf(_boost_full, 0.01), 0.0, 1.0)
		var color := vehicle.boost_color
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * left, size.y)), color)
		if not calm:
			var sweep := fposmod(t * 1.6, 1.0) * size.x * left
			draw_rect(Rect2(Vector2(sweep - 14.0, 0.0), Vector2(28.0, size.y)).intersection(rect), Color(1, 1, 1, 0.45))
		draw_rect(rect.grow(2.0), Color(color, 0.8), false, 2.0)
		return
	_boost_full = 0.0
	var fill := charge_fraction()
	var color: Color = DriftController.LEVEL_COLORS[drift.level] if drift.is_drifting() else Color(1, 1, 1, 0.2)
	if fill > 0.0:
		# Glow grows with the charge.
		draw_rect(Rect2(Vector2(0.0, -3.0), Vector2(size.x * fill, size.y + 6.0)), Color(color, 0.12 + 0.25 * fill))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)), color)
	var max_time: float = drift.level_thresholds[drift.level_thresholds.size() - 1]
	for i in drift.level_thresholds.size():
		var x := size.x * drift.level_thresholds[i] / max_time
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(DriftController.LEVEL_COLORS[i + 1], 0.9), 2.0)
	var border := Color(0.6, 0.5, 0.85, 0.6)
	if drift.is_drifting() and drift.level >= DriftController.LEVEL_CYAN:
		var pulse := 1.0 if calm else 0.55 + 0.45 * sin(t * 10.0)
		border = Color(UIStyle.CYAN, pulse)
		draw_rect(rect.grow(3.0), Color(UIStyle.CYAN, 0.25 * pulse), false, 3.0)
	draw_rect(rect, border, false, 2.0)
