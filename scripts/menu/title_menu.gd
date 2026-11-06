class_name TitleMenu
extends Control
## The first menu: Single Player (the main menu: Grand Prix, Versus,
## Practice, Garage...), Multiplayer (split-screen lobby), Settings,
## Credits, Exit.

const LOGO := preload("res://assets/logo/Cyberwave 2199 Neon Cityscape.png")
const LOGO_SHADER := preload("res://assets/logo/logo_blend.gdshader")

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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(600, 210)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := ShaderMaterial.new()
	blend.shader = LOGO_SHADER
	logo.material = blend
	box.add_child(logo)
	box.add_child(Control.new())

	var tree := get_tree()
	var entries: Array[Button] = [
		UIStyle.primary_button("Single Player", func() -> void: GameSession.to_main_menu(tree)),
		UIStyle.primary_button("Multiplayer", func() -> void: GameSession.to_multiplayer(tree)),
		UIStyle.button("Settings", func() -> void: GameSession.to_settings(tree)),
		UIStyle.button("Credits", func() -> void: GameSession.to_credits(tree)),
		UIStyle.button("Exit", func() -> void: tree.quit()),
	]
	for b in entries:
		b.custom_minimum_size = Vector2(440, 50 if _buttons.size() < 2 else 44)
		box.add_child(b)
		_buttons.append(b)
