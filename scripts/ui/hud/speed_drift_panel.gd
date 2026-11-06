class_name SpeedDriftPanel
extends PanelContainer
## Bottom-left driving panel: big speed (cyan, eased so it doesn't flicker),
## then the drift charge (percentage, bar, state). States: idle, charging
## (tier colour), BOOST READY (a boost is banked), BOOST <tier> while
## boosting. The speed pops brighter when a boost starts.

var vehicle: VehicleController
var speed_value: Label
var speed_unit: Label
var drift_title: Label
var drift_percent: Label
var meter: DriftMeter
var state_label: Label

var _shown_speed: float = 0.0
var _was_boosting: bool = false


func _init() -> void:
	name = "SpeedDrift"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIStyle.box_style(UIStyle.PANEL_BG, Color(UIStyle.CYAN, 0.35), 12))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 20.0
	offset_bottom = -20.0
	custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	box.add_child(speed_row)
	speed_value = UIStyle.heading("0", 44, UIStyle.CYAN)
	speed_value.resized.connect(func() -> void: speed_value.pivot_offset = Vector2(0, speed_value.size.y * 0.5))
	speed_row.add_child(speed_value)
	speed_unit = UIStyle.stat("KM/H", 16, UIStyle.MUTED)
	speed_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_row.add_child(speed_unit)
	var header := HBoxContainer.new()
	box.add_child(header)
	drift_title = UIStyle.stat("DRIFT CHARGE", 15, UIStyle.MUTED)
	drift_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(drift_title)
	drift_percent = UIStyle.heading("", 15, UIStyle.MUTED)
	header.add_child(drift_percent)
	meter = DriftMeter.new()
	meter.custom_minimum_size = Vector2(276, 14)
	box.add_child(meter)
	state_label = UIStyle.stat("", 16, UIStyle.MUTED)
	state_label.custom_minimum_size = Vector2(0, 20)
	box.add_child(state_label)


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
	var boosting := vehicle.is_boosting()
	if boosting and not _was_boosting:
		_boost_pop()
	_was_boosting = boosting
	var drift := vehicle.drift
	if boosting:
		state_label.text = "BOOST  %s" % vehicle.boost_label.to_upper()
		state_label.add_theme_color_override("font_color", vehicle.boost_color)
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
	elif drift.is_drifting():
		var color: Color = DriftController.LEVEL_COLORS[drift.level]
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
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
		state_label.text = "SLIPSTREAM  %d%%" % roundi(vehicle.slipstream_charge * 100.0)
		state_label.add_theme_color_override("font_color", Slipstream.BOOST_COLOR)
	else:
		drift_percent.text = ""
		drift_title.add_theme_color_override("font_color", UIStyle.MUTED)
		state_label.text = ""


func _boost_pop() -> void:
	speed_value.scale = Vector2.ONE * 1.15
	speed_value.modulate = Color(1.8, 1.8, 1.8) if not GameSettings.reduced_flashing else Color.WHITE
	var t := create_tween().set_parallel()
	t.tween_property(speed_value, "scale", Vector2.ONE, 0.3)
	t.tween_property(speed_value, "modulate", Color.WHITE, 0.4)
