class_name Credits
extends Control
## Credits: who made the game and where the music, sounds, fonts, textures
## and art come from. Back (or Esc / gamepad B) returns to the main menu.

## [heading, [lines...]]; the README's Credits section lists the same.
const SECTIONS := [
	["GAME", ["Cyberwave 2199 by Nathan Hobbs"]],
	["MUSIC", [
		"\"Cyberpunk\" by ikoliks_aj  (main theme)",
		"\"Wings of Hope\" by ikoliks  (garage)",
		"\"Cyber Dreams\" by Lilex  (The Stacks)",
		"\"Race Winner\" by TheBoysBeats  (Six Flags New Orleans)",
		"\"Heavy Racing\" by SPmusic  (Vegas Overdrive)",
		"\"Cyberpunk Music\" by kulakovka  (Hoia Baciu Run)",
		"\"Hard Cyberpunk\" by kulakovka  (Catacombs Descent)",
	]],
	["SOUND", ["Short beep countdown by freesound_community"]],
	["FONTS", [
		"Oxanium and Rajdhani  (SIL Open Font License 1.1)",
	]],
	["TEXTURES AND SKY", [
		"Poly Haven (polyhaven.com), CC0: asphalt, concrete, rust, metal, brick, wood,",
		"grass, mud and tile textures, and the kloofendal overcast sky",
	]],
	["ART", ["Weapon icons from the Weapon Arsenal concept art"]],
	["ENGINE", ["Made with Godot Engine (godotengine.org), MIT License"]],
]

var back_button: Button


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	back_button.grab_focus.call_deferred()


## Every credit line, for tests.
func get_text() -> String:
	var lines: PackedStringArray = []
	for section in SECTIONS:
		lines.append(section[0])
		lines.append_array(PackedStringArray(section[1]))
	return "\n".join(lines)


func back() -> void:
	GameSession.to_main_menu(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var header := UIStyle.header(page, "CREDITS")
	header.text = ""
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	center.add_child(list)
	for section in SECTIONS:
		var heading := UIStyle.stat(section[0], 17, UIStyle.CYAN)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(heading)
		for line in section[1]:
			var l := UIStyle.label(line, 19, Color.WHITE)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list.add_child(l)
		list.add_child(Control.new())
	back_button = UIStyle.button("Back", back)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(back_button)
