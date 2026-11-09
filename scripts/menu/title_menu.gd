class_name TitleMenu
extends Control
## The first menu: Single Player (the main menu: Grand Prix, Versus,
## Practice, Garage...), Multiplayer (split-screen lobby), Settings,
## Credits, Exit. Laid out after "reference files/Cyberwave 2199 Racing
## Menu.png" (see StartMenuLayout).

## Logo, buttons, info box and the garage car on a night street.
var layout: StartMenuLayout
var _buttons: Array[Button] = []


## Button labels, top to bottom (tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _buttons:
		out.append(b.text)
	return out


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = false
	GameSession.menu_return = GameSession.TITLE_SCENE
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	_buttons[0].grab_focus.call_deferred()


func _build() -> void:
	UIStyle.background(self)
	layout = StartMenuLayout.new(false, false)
	add_child(layout)
	var tree := get_tree()
	var entries: Array[NeonMenuButton] = [
		layout.add_entry("Single Player", "person", "Race in Grand Prix, Versus, or Practice mode.",
				func() -> void: GameSession.to_main_menu(tree)),
		layout.add_entry("Multiplayer", "group", "Split-screen racing for 2 to 4 players.",
				func() -> void: GameSession.to_multiplayer(tree)),
		layout.add_entry("Settings", "gear", "Controls, audio and video.",
				func() -> void: GameSession.to_settings(tree)),
		layout.add_entry("Credits", "info", "The people, music and assets behind Cyberwave 2199.",
				func() -> void: GameSession.to_credits(tree)),
		layout.add_entry("Exit", "exit", "Close the game.", func() -> void: tree.quit()),
	]
	layout.finish()
	_buttons.assign(entries)
