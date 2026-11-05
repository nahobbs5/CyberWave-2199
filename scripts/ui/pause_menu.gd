class_name PauseMenu
extends CanvasLayer
## Esc / gamepad Start pauses the whole race (physics, timers, AI) and shows
## Resume / Restart race / Quit to main menu (GDD 3.2, 3.3). Runs while the
## tree is paused. Restart is disabled once a Grand Prix result is saved.
## The controls (current bindings) sit beside the buttons.

var race: RaceManager

var _panel: PanelContainer
var _resume: Button
var _restart: Button
var _quit: Button
var _title: Label


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(manager: RaceManager) -> void:
	race = manager
	_build()


func is_open() -> bool:
	return _panel != null and _panel.visible


func open() -> void:
	if race == null:
		return
	get_tree().paused = true
	_restart.disabled = not race.can_restart()
	_title.text = "PAUSED  -  %s" % RaceConfig.MODE_NAMES[race.mode()]
	_panel.visible = true
	UIStyle.fade_in(_panel, 0.15)
	_resume.grab_focus()


func close() -> void:
	_panel.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = UIStyle.panel()
	_panel.visible = false
	center.add_child(_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	_panel.add_child(columns)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	columns.add_child(box)
	columns.add_child(ControlsCard.new())
	_title = UIStyle.heading("PAUSED", 30, UIStyle.CYAN)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_resume = UIStyle.primary_button("Resume", close)
	_restart = UIStyle.button("Restart race", func() -> void: race.restart())
	_quit = UIStyle.button("Quit to main menu", func() -> void: race.quit_to_menu())
	for b in [_resume, _restart, _quit]:
		box.add_child(b)
	UIStyle.chain_focus([_resume, _restart, _quit])
	var hint := UIStyle.label("Esc / Start: resume", 13, Color(1, 1, 1, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
