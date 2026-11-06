class_name ControlsCard
extends PanelContainer
## The controls, read from the current bindings (so rebinds show), keyboard
## and gamepad side by side. Shown in the pause menu (not on the HUD).

const ROWS := [
	["Accelerate", [&"accelerate"]],
	["Brake / reverse", [&"brake"]],
	["Steer", [&"steer_left", &"steer_right"]],
	["Drift: hold + steer", [&"drift"]],
	["Use item", [&"use_weapon"]],
	["Trick (in the air off a ramp)", [&"trick"]],
	["Item slot 1 / 2", [&"select_slot_1", &"select_slot_2"]],
	["Camera", [&"cycle_camera"]],
	["Look back (hold)", [&"look_back"]],
	["Reset car", [&"reset_vehicle"]],
	["Pause", [&"pause"]],
]

func _init() -> void:
	name = "Controls"
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

