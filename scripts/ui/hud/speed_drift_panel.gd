class_name SpeedDriftPanel
extends PanelContainer
## Bottom-left driving gauge, after the slipstream art: an arc that fills
## cyan to magenta with speed, KM/H and the speed (eased so it doesn't
## flicker) in the middle, and a five-cell drift charge bar under the number
## in the current tier's colour. Under the gauge, the state line: CHARGING,
## BOOST READY (a boost is banked), BOOST <tier> while boosting, or
## SLIPSTREAM n% while drafting behind someone. The speed pops brighter when
## a boost starts.

var vehicle: VehicleController
var speed_value: Label
var speed_unit: Label
var drift_title: Label
var drift_percent: Label
## The drift charge source (hidden; the gauge draws the bar).
var meter: DriftMeter
var state_label: Label
var gauge: Gauge

var _shown_speed: float = 0.0
var _was_boosting: bool = false


func _init() -> void:
	name = "SpeedDrift"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 16.0
	offset_bottom = -12.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	gauge = Gauge.new()
	box.add_child(gauge)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", -10)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -26
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(center)
	speed_unit = UIStyle.heading("KM/H", 18, Color.WHITE)
	speed_unit.add_theme_font_override("font", UIStyle.slanted_font(true))
	speed_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(speed_unit)
	speed_value = UIStyle.heading("0", 58, Color.WHITE)
	speed_value.add_theme_font_override("font", UIStyle.slanted_font(true))
	speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_value.resized.connect(func() -> void: speed_value.pivot_offset = speed_value.size * 0.5)
	center.add_child(speed_value)
	state_label = UIStyle.stat("", 16, UIStyle.MUTED)
	state_label.custom_minimum_size = Vector2(0, 20)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(state_label)
	# Kept for the old readouts and tests; the gauge shows the charge.
	drift_title = UIStyle.stat("DRIFT CHARGE", 15, UIStyle.MUTED)
	drift_title.visible = false
	box.add_child(drift_title)
	drift_percent = UIStyle.heading("", 15, UIStyle.MUTED)
	drift_percent.visible = false
	box.add_child(drift_percent)
	meter = DriftMeter.new()
	meter.visible = false
	box.add_child(meter)


func setup(car: VehicleController) -> void:
	vehicle = car
	meter.drift = car.drift
	meter.vehicle = car


## "", "BOOST READY", "BOOST CYAN", ... (tests).
func get_state_text() -> String:
	return state_label.text


func _process(delta: float) -> void:
	if vehicle == null:
		return
	var speed := absf(vehicle.forward_speed) * 3.6
	_shown_speed = lerpf(_shown_speed, speed, minf(1.0, delta * 12.0))
	speed_value.text = str(roundi(_shown_speed))
	var top := maxf(vehicle.stats.top_speed * 3.6, 1.0) if vehicle.stats != null else 200.0
	gauge.speed_fraction = clampf(_shown_speed / (top * 1.1), 0.0, 1.0)
	var boosting := vehicle.is_boosting()
	if boosting and not _was_boosting:
		_boost_pop()
	_was_boosting = boosting
	var drift := vehicle.drift
	gauge.charge = 0.0
	gauge.charge_color = UIStyle.MAGENTA
	if boosting:
		state_label.text = "BOOST  %s" % vehicle.boost_label.to_upper()
		state_label.add_theme_color_override("font_color", vehicle.boost_color)
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
	elif drift.is_drifting():
		var color: Color = DriftController.LEVEL_COLORS[drift.level]
		gauge.charge = meter.charge_fraction()
		gauge.charge_color = color if drift.level > 0 else UIStyle.MAGENTA
		drift_percent.text = "%d%%" % roundi(meter.charge_fraction() * 100.0)
		drift_percent.add_theme_color_override("font_color", color if drift.level > 0 else Color.WHITE)
		drift_title.add_theme_color_override("font_color", UIStyle.MAGENTA)
		if drift.level >= DriftController.LEVEL_CYAN:
			state_label.text = "BOOST READY  -  %s" % DriftController.LEVEL_NAMES[drift.level].to_upper()
			state_label.add_theme_color_override("font_color", UIStyle.CYAN)
		else:
			state_label.text = "CHARGING"
			state_label.add_theme_color_override("font_color", UIStyle.MAGENTA)
	elif vehicle.in_slipstream or vehicle.slipstream_charge > 0.0:
		# Drafting behind someone: the slipstream meter fills.
		gauge.charge = vehicle.slipstream_charge
		gauge.charge_color = Slipstream.BOOST_COLOR
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
		state_label.text = "SLIPSTREAM  %d%%" % roundi(vehicle.slipstream_charge * 100.0)
		state_label.add_theme_color_override("font_color", Slipstream.BOOST_COLOR)
	else:
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
		state_label.text = ""
	gauge.queue_redraw()


func _boost_pop() -> void:
	speed_value.scale = Vector2.ONE * 1.15
	speed_value.modulate = Color(1.8, 1.8, 1.8) if not GameSettings.reduced_flashing else Color.WHITE
	var t := create_tween().set_parallel()
	t.tween_property(speed_value, "scale", Vector2.ONE, 0.3)
	t.tween_property(speed_value, "modulate", Color.WHITE, 0.4)


## The round gauge: dark track, speed arc (cyan to magenta), a thin outer
## ring and the five-cell charge bar under the number.
class Gauge extends Control:
	const START := PI * 0.75
	const SWEEP := PI * 1.5
	const CELLS := 5

	var speed_fraction: float = 0.0
	## 0..1 drift or slipstream charge, and its colour.
	var charge: float = 0.0
	var charge_color: Color = UIStyle.MAGENTA

	func _init() -> void:
		custom_minimum_size = Vector2(230, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var r := minf(size.x * 0.44, size.y * 0.48)
		draw_circle(c, r - 10.0, Color(0.04, 0.02, 0.12, 0.72))
		# Track and fill.
		draw_arc(c, r, START, START + SWEEP, 64, Color(0.12, 0.06, 0.24, 0.85), 18.0, true)
		var steps := 48
		var lit := int(round(steps * speed_fraction))
		for i in lit:
			var a0 := START + SWEEP * i / steps
			var a1 := START + SWEEP * (i + 1) / steps + 0.01
			var col := UIStyle.CYAN.lerp(UIStyle.MAGENTA, float(i) / steps)
			draw_arc(c, r, a0, a1, 3, Color(col, 0.3), 26.0, true)
			draw_arc(c, r, a0, a1, 3, col, 14.0, true)
		draw_arc(c, r + 14.0, START, START + SWEEP, 64, Color(UIStyle.CYAN, 0.45), 2.0, true)
		draw_arc(c, r - 13.0, START, START + SWEEP, 64, Color(UIStyle.MAGENTA, 0.35), 1.5, true)
		# Charge cells under the number.
		var cell_w := r * 0.22
		var gap := 4.0
		var total := cell_w * CELLS + gap * (CELLS - 1)
		var y := c.y + r * 0.5
		var hgt := 10.0
		var on := int(ceil(charge * CELLS - 0.001))
		for i in CELLS:
			var x := c.x - total * 0.5 + i * (cell_w + gap)
			var sk := hgt * 0.4
			var cell := PackedVector2Array([Vector2(x + sk, y), Vector2(x + cell_w + sk, y),
					Vector2(x + cell_w, y + hgt), Vector2(x, y + hgt)])
			draw_colored_polygon(cell, charge_color if i < on else Color(1, 1, 1, 0.12))
