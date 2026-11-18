class_name MainMenu
extends Control
## Single-player menu (GDD 11.2), opened from the title's Single Player:
## Grand Prix, Versus (Standard, Elimination or Mirror, picked on the setup
## screen), Time Trial (race a ghost; beating a rival can unlock its car),
## Practice (free drive), Garage, Settings, Credits, Back to the title. Laid out
## after "reference files/Cyberwave 2199 Neon Racing Menu.png" (see
## StartMenuLayout); the car on the street is the garage's selected car.

## Logo, buttons, info box, coins and the garage car on a night street.
var layout: StartMenuLayout
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


func _build() -> void:
	UIStyle.background(self)
	layout = StartMenuLayout.new(true, true)
	add_child(layout)
	layout.set_coins(PlayerProfile.get_profile().coins)
	var tree := get_tree()
	var entries: Array[NeonMenuButton] = [
		layout.add_entry("Grand Prix", "flags", "Compete in a cup and aim for the highest overall finish!",
				func() -> void: GameSession.to_race_setup(tree, RaceConfig.Mode.GRAND_PRIX)),
		layout.add_entry("Versus", "trophy", "Pick your tracks and race the field, standard or elimination.",
				func() -> void: GameSession.to_race_setup(tree, GameSession.last_versus_mode())),
		layout.add_entry("Time Trial", "stopwatch", "Race the ghosts to win new cars and signature paint.",
				func() -> void: GameSession.to_race_setup(tree, RaceConfig.Mode.TIME_TRIAL)),
		layout.add_entry("Practice", "play", "Free drive with no rivals to learn the handling.",
				func() -> void: GameSession.to_practice_select(tree)),
		layout.add_entry("Garage", "car", "Choose your car, buy paint and parts, and set your plate.",
				func() -> void: GameSession.to_garage(tree)),
		layout.add_entry("Settings", "gear", "Controls, audio and video.",
				func() -> void: GameSession.to_settings(tree)),
		layout.add_entry("Credits", "info", "The people, music and assets behind Cyberwave 2199.",
				func() -> void: GameSession.to_credits(tree)),
		_back_entry(layout, tree),
	]
	layout.finish()
	for b in entries:
		if b.visible:
			_buttons.append(b)


## Back steps out of the menu rather than forward, so it gets no » chevrons.
func _back_entry(layout: StartMenuLayout, tree: SceneTree) -> NeonMenuButton:
	var b := layout.add_entry("Back", "back", "Return to the title screen.",
			func() -> void: GameSession.to_title(tree))
	b.chevrons = false
	return b
