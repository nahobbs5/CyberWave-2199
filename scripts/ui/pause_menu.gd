class_name PauseMenu
extends CanvasLayer
## Esc / gamepad Start pauses the whole race (physics, timers, AI) and shows
## the neon pause screen after "reference files/Cyberwave 2199 Neon Pause
## Menu.png" (GDD 3.2, 3.3): logo and PAUSED along the top; Resume / Restart
## Race / Quit to Main Menu, a VOLUME panel (Master / Music / Sound Effects,
## saved straight away) and the player's car on the left; the controls table
## (current bindings) on the right. The mockup's Race Info tab is left out.
## Runs while the tree is paused. Restart is disabled once a Grand Prix
## result is saved.

const VOLUMES := [["Master", "master", "speaker"], ["Music", "music", "note"], ["Sound Effects", "sfx", "wave"]]
const LEFT := 40.0
const LEFT_WIDTH := 450.0
const TOP := 104.0

var race: RaceManager

## The whole screen (shown while open).
var _panel: Control
var _resume: NeonMenuButton
var _restart: NeonMenuButton
var _quit: NeonMenuButton
var _title: Label
var controls: ControlsCard
var car_picture: TextureRect
## bus key ("master", "music", "sfx") -> HSlider
var volume_sliders: Dictionary = {}
var _car_requested: bool = false


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
	_restart.modulate = Color(1, 1, 1, 0.4) if _restart.disabled else Color.WHITE
	for bus in volume_sliders:
		# In case Settings changed it; only fires value_changed if it differs.
		(volume_sliders[bus] as HSlider).value = GameSettings.volume(bus) * 100.0
	controls.refresh()
	_request_car()
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


## The player's car (P1 in split screen), rendered once on first pause.
func _request_car() -> void:
	if _car_requested or race == null or race.player == null:
		return
	_car_requested = true
	var id := race.player.racer_id
	var looks := {id: race.racer_look(id, race.player.color)}
	CarThumbnails.request_looks(get_tree(), looks, func() -> void:
		if is_instance_valid(car_picture):
			car_picture.texture = CarThumbnails.get_look_texture(id),
			{id: Vector2i(440, 220)})


func _build() -> void:
	_panel = Control.new()
	_panel.name = "Screen"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.09, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	_panel.add_child(NeonSwoosh.new())

	var logo := UIStyle.logo(Vector2(250, 78))
	logo.position = Vector2(LEFT - 6, 10)
	_panel.add_child(logo)
	_build_title()

	# Left: the buttons, the volume panel and the car.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.position = Vector2(LEFT, TOP + 6)
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	_panel.add_child(left)
	_resume = _button("Resume", "play", close)
	_restart = _button("Restart Race", "reset", func() -> void: race.restart())
	_quit = _button("Quit to Main Menu", "home", func() -> void: race.quit_to_menu())
	for b in [_resume, _restart, _quit]:
		left.add_child(b)
	var volume := NeonPanel.new(14, UIStyle.MAGENTA, UIStyle.CYAN)
	left.add_child(volume)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	volume.add_child(vbox)
	vbox.add_child(NeonWidgets.section_header("speaker", "VOLUME"))
	var focus: Array = [_resume, _restart, _quit]
	for v in VOLUMES:
		var slider := NeonWidgets.slider_row(vbox, v[2], v[0], 0, 100, 5, GameSettings.volume(v[1]) * 100.0, "%d%%",
				func(value: float) -> void: GameSettings.set_volume(v[1], value / 100.0))
		slider.name = "Volume_" + v[1]
		# Narrower than the Settings rows so the panel fits the 450 px column.
		var row := slider.get_parent() as HBoxContainer
		row.add_theme_constant_override("separation", 10)
		var label := row.get_child(1) as Label
		label.custom_minimum_size.x = 136
		label.clip_text = true
		slider.custom_minimum_size.x = 130
		(row.get_child(3) as Label).custom_minimum_size.x = 58
		volume_sliders[v[1]] = slider
		focus.append(slider)
	UIStyle.chain_focus(focus)
	car_picture = TextureRect.new()
	car_picture.name = "CarPicture"
	car_picture.custom_minimum_size = Vector2(LEFT_WIDTH, 118)
	car_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	car_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	car_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(car_picture)

	# Right: the Controls tab and table (no Race Info tab).
	var right := NeonPanel.new(14, UIStyle.MAGENTA, UIStyle.CYAN)
	right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right.offset_left = LEFT + LEFT_WIDTH + 30
	right.offset_right = -36
	right.offset_top = TOP
	right.offset_bottom = -66
	_panel.add_child(right)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	right.add_child(page)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	page.add_child(tabs)
	var tab := NeonMenuButton.new("Controls", "gamepad")
	tab.name = "ControlsTab"
	tab.chevrons = false
	tab.lit_override = true
	tab.focus_mode = Control.FOCUS_NONE
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.font_size = 26
	tab.custom_minimum_size = Vector2(380, 46)
	tabs.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var checker := NeonWidgets.Checker.new(Color(UIStyle.MAGENTA, 0.6), 2, true)
	checker.custom_minimum_size = Vector2(110, 34)
	checker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(checker)
	controls = ControlsCard.new()
	page.add_child(controls)

	var hints := MenuHints.new([["A", "Enter", "Select"], ["B", "Esc", "Resume"]])
	hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hints.offset_top = -54
	hints.offset_bottom = -14
	_panel.add_child(hints)


## "PAUSED" top right between checker strips, over a magenta-to-cyan rule.
func _build_title() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -40
	row.offset_top = 8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	for side in 2:
		if side == 1:
			_title = UIStyle.stat("PAUSED", 60, Color.WHITE)
			_title.add_theme_font_override("font", UIStyle.slanted_font(true))
			_title.add_theme_color_override("font_shadow_color", Color(UIStyle.MAGENTA, 0.5))
			_title.add_theme_constant_override("shadow_offset_x", 0)
			_title.add_theme_constant_override("shadow_offset_y", 0)
			_title.add_theme_constant_override("shadow_outline_size", 12)
			_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(_title)
		var checker := NeonWidgets.Checker.new(UIStyle.MAGENTA if side == 0 else UIStyle.CYAN, 2, side == 0)
		checker.custom_minimum_size = Vector2(80, 34)
		checker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(checker)
	var rule := _Rule.new()
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = 640
	rule.offset_right = -40
	rule.offset_top = 88
	rule.offset_bottom = 92
	_panel.add_child(rule)


func _button(text: String, icon_kind: String, on_pressed: Callable) -> NeonMenuButton:
	var b := NeonMenuButton.new(text, icon_kind)
	b.font_size = 30
	b.custom_minimum_size = Vector2(LEFT_WIDTH, 58)
	b.pressed.connect(on_pressed)
	return b


## A thin rule fading in from the left: magenta, then cyan on the right.
class _Rule extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var steps := 32
		for i in steps:
			var t := float(i) / steps
			var c := UIStyle.MAGENTA.lerp(UIStyle.CYAN, t)
			draw_rect(Rect2(size.x * t, 0, size.x / steps + 1, size.y), Color(c, 0.9 * minf(1.0, t * 3.0)))
