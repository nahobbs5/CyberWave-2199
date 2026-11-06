class_name MainMenu
extends Control
## Main menu (GDD 11.2): Continue Grand Prix (only when a championship is
## saved), Grand Prix, Versus (Standard or Elimination, picked on the setup
## screen), Practice (free drive), Garage, Settings, Credits, Exit.

const LOGO := preload("res://assets/logo/Cyberwave 2199 Neon Cityscape.png")
## Additive blend drops the logo's black background, leaving only the neon;
## the edges fade out so the image's faint texture doesn't show as a box.
const LOGO_SHADER := preload("res://assets/logo/logo_blend.gdshader")

var _continue_button: Button
var _buttons: Array[Button] = []


## Visible button labels, top to bottom (tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _buttons:
		out.append(b.text)
	return out


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
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(540, 180)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := ShaderMaterial.new()
	blend.shader = LOGO_SHADER
	logo.material = blend
	box.add_child(logo)
	box.add_child(Control.new())

	var saved := Championship.load_saved()
	_continue_button = UIStyle.button("Continue Grand Prix", continue_grand_prix)
	_continue_button.visible = saved != null
	if saved != null:
		_continue_button.text = "Continue Grand Prix  (%s, race %d / %d)" % [
				saved.gp.display_name, saved.race_index + 1, saved.race_count()]
	var tree := get_tree()
	var entries: Array[Button] = [
		_continue_button,
		UIStyle.button("Grand Prix", func() -> void: GameSession.to_cup_select(tree, RaceConfig.Mode.GRAND_PRIX)),
		UIStyle.button("Versus", func() -> void: GameSession.to_cup_select(tree, GameSession.last_versus_mode())),
		UIStyle.button("Practice", func() -> void: GameSession.to_free_drive(tree)),
		UIStyle.button("Garage", func() -> void: GameSession.to_garage(tree)),
		UIStyle.button("Settings", func() -> void: GameSession.to_settings(tree)),
		UIStyle.button("Credits", func() -> void: GameSession.to_credits(tree)),
		UIStyle.button("Exit", func() -> void: tree.quit()),
	]
	for b in entries:
		b.custom_minimum_size = Vector2(440, 44)
		box.add_child(b)
		if b.visible:
			_buttons.append(b)
