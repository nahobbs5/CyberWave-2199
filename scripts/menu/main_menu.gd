class_name MainMenu
extends Control
## Single-player menu (GDD 11.2), opened from the title's Single Player:
## Continue Grand Prix (only when a championship is saved), Grand Prix,
## Versus (Standard or Elimination, picked on the setup screen), Practice
## (free drive), Garage, Settings, Credits, Back to the title. Laid out
## after "reference files/Cyberwave 2199 Neon Racing Menu.png" (see
## StartMenuLayout); the car on the street is the garage's selected car.

## Logo, buttons, info box, coins and the garage car on a night street.
var layout: StartMenuLayout
var _continue_button: NeonMenuButton
var _buttons: Array[Button] = []


## Visible button labels, top to bottom (tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _buttons:
		out.append(b.text)
	return out


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = false
	GameSession.menu_return = GameSession.MAIN_MENU_SCENE
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	_buttons[0].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameSession.to_title(get_tree())


func has_continue() -> bool:
	return _continue_button.visible


func continue_grand_prix() -> void:
	var c := Championship.load_saved()
	if c != null:
		GameSession.start_race(get_tree(), c.make_race_config())


func _build() -> void:
	UIStyle.background(self)
	layout = StartMenuLayout.new(true, true)
	add_child(layout)
	layout.set_coins(PlayerProfile.get_profile().coins)
	var saved := Championship.load_saved()
	var tree := get_tree()
	_continue_button = layout.add_entry("Continue Grand Prix", "play", "", continue_grand_prix)
	_continue_button.visible = saved != null
	if saved != null:
		_continue_button.description = "Pick up the %s at race %d of %d." % [
				saved.gp.display_name, saved.race_index + 1, saved.race_count()]
	var entries: Array[NeonMenuButton] = [
		_continue_button,
		layout.add_entry("Grand Prix", "flags", "Compete in a cup and aim for the highest overall finish!",
				func() -> void: GameSession.to_cup_select(tree, RaceConfig.Mode.GRAND_PRIX)),
		layout.add_entry("Versus", "trophy", "Pick your tracks and race the field, standard or elimination.",
				func() -> void: GameSession.to_race_setup(tree, GameSession.last_versus_mode())),
		layout.add_entry("Practice", "stopwatch", "Free drive with no rivals to learn the handling.",
				func() -> void: GameSession.to_free_drive(tree)),
		layout.add_entry("Garage", "car", "Choose your car, buy paint and parts, and set your plate.",
				func() -> void: GameSession.to_garage(tree)),
		layout.add_entry("Settings", "gear", "Controls, audio and video.",
				func() -> void: GameSession.to_settings(tree)),
		layout.add_entry("Credits", "info", "The people, music and assets behind Cyberwave 2199.",
				func() -> void: GameSession.to_credits(tree)),
		layout.add_entry("Back", "back", "Return to the title screen.",
				func() -> void: GameSession.to_title(tree)),
	]
	layout.finish()
	for b in entries:
		if b.visible:
			_buttons.append(b)
