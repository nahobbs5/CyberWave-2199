class_name ControlsCard
extends PanelContainer
## The controls, read from the current bindings (so rebinds show), keyboard
## and gamepad side by side. In a race it shows for a few seconds on your
## first race (and every time in free drive), then fades; the pause menu
## shows it permanently.

const ROWS := [
	["Accelerate", [&"accelerate"]],
	["Brake / reverse", [&"brake"]],
	["Steer", [&"steer_left", &"steer_right"]],
	["Drift: hold + steer", [&"drift"], [&"drift_left", &"drift_right"]],
	["Use item", [&"use_weapon"]],
	["Item slot 1 / 2", [&"select_slot_1", &"select_slot_2"]],
	["Camera", [&"cycle_camera"]],
	["Reset car", [&"reset_vehicle"]],
	["Pause", [&"pause"]],
]

## Seconds before fading; 0 = stays.
var show_seconds: float = 0.0
var _time: float = 0.0


func _init(p_show_seconds: float = 0.0) -> void:
	name = "Controls"
	show_seconds = p_show_seconds
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIStyle.box_style(Color(UIStyle.PANEL_BG, 0.8), UIStyle.PANEL_BORDER, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	box.add_child(UIStyle.stat("CONTROLS", 15, UIStyle.CYAN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", -3)
	box.add_child(grid)
	grid.add_child(UIStyle.stat("", 13, UIStyle.MUTED))
	grid.add_child(UIStyle.stat("KEYBOARD", 13, UIStyle.MUTED))
	grid.add_child(UIStyle.stat("GAMEPAD", 13, UIStyle.MUTED))
	for row in ROWS:
		grid.add_child(UIStyle.stat(row[0], 15, Color.WHITE))
		grid.add_child(UIStyle.stat(_names(row[1], true), 15, UIStyle.MAGENTA))
		var pad_actions: Array = row[2] if row.size() > 2 else row[1]
		grid.add_child(UIStyle.stat(_names(pad_actions, false), 15, UIStyle.CYAN))


static func _names(actions: Array, keyboard: bool) -> String:
	var parts: PackedStringArray = []
	for action in actions:
		parts.append(InputSetup.describe(action, keyboard))
	return " / ".join(parts)


func _process(delta: float) -> void:
	if show_seconds <= 0.0 or not visible:
		return
	_time += delta
	modulate.a = clampf((show_seconds - _time) / 0.6, 0.0, 1.0)
	if _time >= show_seconds:
		visible = false
