class_name MainMenu
extends Control
## Main menu (GDD 11.2): Versus, Grand Prix, Continue Grand Prix (when a
## championship is saved), Elimination, Garage, Settings, Exit. Free drive is
## an extra for practising.

var _continue_button: Button
var _buttons: Array[Button] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	_buttons[0].grab_focus.call_deferred()


func has_continue() -> bool:
	return _continue_button.visible


func continue_grand_prix() -> void:
	var c := Championship.load_saved()
	if c != null:
		GameSession.start_race(get_tree(), c.make_race_config())


func _build() -> void:
	UIStyle.background(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := UIStyle.heading("CYBERWAVE 2199", 56, UIStyle.MAGENTA)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var profile := PlayerProfile.get_profile()
	var vehicle := VehicleCatalog.by_id(profile.selected_vehicle)
	var info := UIStyle.label("%s   ·   %d coins   ·   plate %s" % [vehicle.display_name, profile.coins, profile.plate_text],
			15, Color(1, 1, 1, 0.6))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	box.add_child(Control.new())

	var saved := Championship.load_saved()
	_continue_button = UIStyle.button("Continue Grand Prix", continue_grand_prix)
	_continue_button.visible = saved != null
	if saved != null:
		_continue_button.text = "Continue Grand Prix  (%s, race %d / %d)" % [
				saved.gp.display_name.get_slice(" — ", 1), saved.race_index + 1, saved.race_count()]
	var tree := get_tree()
	var entries: Array[Button] = [
		_continue_button,
		UIStyle.button("Versus", func() -> void: GameSession.to_race_setup(tree, RaceConfig.Mode.VERSUS)),
		UIStyle.button("Grand Prix", func() -> void: GameSession.to_race_setup(tree, RaceConfig.Mode.GRAND_PRIX)),
		UIStyle.button("Elimination", func() -> void: GameSession.to_race_setup(tree, RaceConfig.Mode.ELIMINATION)),
		UIStyle.button("Garage", func() -> void: GameSession.to_garage(tree)),
		UIStyle.button("Settings", func() -> void: GameSession.to_settings(tree)),
		UIStyle.button("Free drive (practice)", func() -> void: GameSession.to_free_drive(tree)),
		UIStyle.button("Exit", func() -> void: tree.quit()),
	]
	for b in entries:
		b.custom_minimum_size = Vector2(440, 44)
		box.add_child(b)
		if b.visible:
			_buttons.append(b)
