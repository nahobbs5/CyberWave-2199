class_name Credits
extends Control
## Credits: who made the game and where the music, sounds, fonts and
## textures come from. Back (or Esc / gamepad B) returns to the main menu.
## Laid out after "reference files/Cyberwave 2199 Neon Credits.png"
## (NeonScreenLayout): one neon panel of rows, each a slanted heading tab
## with an icon on the left and the credit on the right.

## [heading, icon kind, [lines...]]; docs/Reference.md's Credits section lists the
## same. MUSIC is drawn from MUSIC below instead of its lines.
const SECTIONS := [
	["GAME", "car", ["Cyberwave 2199 by Nathan Hobbs"]],
	["MUSIC", "note", []],
	["SOUND", "speaker", [
		"Short beep countdown, Shield drop, Electric zap 001, Crowbar drop 1 (rear),",
		"Planks clattering and Missile lock detected by freesound_community",
		"Sci-fi energy shield activation by vadim_makes_sound",
		"Electrical current 2 by 49053354",
		"Sci-fi weapon shoot firing pulse TM 05 by rescopicsound",
		"Field: launching a small model rocket by fronbondi_skegs",
		"Missile explosion by voicebosch",
	]],
	["FONTS", "fonts", [
		"Oxanium and Rajdhani  (SIL Open Font License 1.1)",
	]],
	["TEXTURES AND SKY", "layers", [
		"Poly Haven (polyhaven.com), CC0: asphalt, concrete, rust, metal, brick, wood,",
		"bark, grass, mud, rock, snow, plaster, stone, paving, reed and tile textures,",
		"and the kloofendal skies",
	]],
	["ENGINE", "gear", ["Made with Godot Engine (godotengine.org), MIT License"]],
]

## [title, artist, where it plays].
const MUSIC := [
	["Cyberpunk", "ikoliks_aj", "main theme"],
	["Wings of Hope", "ikoliks", "garage"],
	["Cyber Dreams", "Lilex", "The Stacks"],
	["Race Winner", "TheBoysBeats", "Six Flags New Orleans"],
	["Heavy Racing", "SPmusic", "Vegas Overdrive"],
	["Cyberpunk Music", "kulakovka", "Hoia Baciu Run"],
	["Hard Cyberpunk", "kulakovka", "Catacombs Descent"],
	["The Cyber Geisha", "Ob-Lix", "Arashiyama Circuit"],
	["Besieged Castle", "ed-musicproductions", "Vatnajökull Glacier"],
	["Spooky Halloween Strange House", "sonican", "Crazy House"],
	["To the Moon and Back", "theorienvibes", "Parque Quinta Normal"],
	["Garden Fairytale", "elisaveta_stoycheva", "Gardens by the Bay"],
	["Rise of the Phoenix", "restum-anoush", "Vale da Lua"],
	["Epic Victory March for Heroes", "DesiFreeMusic", "Choquequirao"],
	["The Dragon's Lair", "vishiv", "Kilwa Kisiwani Ruins"],
	["The Garden Wakes", "stageechoesmusic", "Test Circuit and free drive"],
	["Background Music", "alex-morgan", "other results screens"],
	["Victory", "alex-morgan", "podium and the results after it"],
]

const TAB_WIDTH := 300.0

var layout: NeonScreenLayout
var back_button: Button
## The music table (title, dots, artist, note per song).
var music_grid: GridContainer


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
		if section[0] == "MUSIC":
			for song in MUSIC:
				lines.append("\"%s\" by %s  (%s)" % song)
		lines.append_array(PackedStringArray(section[2]))
	return "\n".join(lines)


func back() -> void:
	GameSession.back_from_options(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _build() -> void:
	UIStyle.background(self)
	layout = NeonScreenLayout.new("CREDITS", "clapper")
	add_child(layout)
	layout.content.add_theme_constant_override("margin_left", 60)
	layout.content.add_theme_constant_override("margin_right", 60)
	back_button = layout.back_button
	back_button.pressed.connect(back)
	var frame := NeonPanel.new(16, UIStyle.MAGENTA, UIStyle.CYAN)
	frame.fill_color = Color(0.05, 0.02, 0.12, 0.7)
	frame.radius = 22.0
	frame.glow = 16.0
	frame.edge_width = 3.0
	layout.content.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for section in SECTIONS:
		list.add_child(_section_row(section))


func _section_row(section: Array) -> Control:
	var row := NeonPanel.new(0, Color(0.45, 0.55, 1.0), Color(0.75, 0.45, 1.0))
	row.fill_color = Color(0.08, 0.04, 0.18, 0.85)
	row.radius = 10.0
	row.glow = 5.0
	row.edge_width = 1.5
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 26)
	row.add_child(line)
	var tab := _HeadingTab.new()
	tab.custom_minimum_size = Vector2(TAB_WIDTH, 44)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 14)
	tab.add_child(tab_row)
	tab_row.add_child(NeonWidgets.icon(section[1], 32))
	var heading := UIStyle.stat(section[0], 25 if section[0].length() < 12 else 20, UIStyle.CYAN)
	heading.add_theme_font_override("font", UIStyle.slanted_font(true))
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab_row.add_child(heading)
	line.add_child(tab)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(body)
	# The tab draws at most 56 px tall from its top, so on a tall row (music,
	# the multi-line sound list) keep it pinned to the top instead of letting it
	# stretch: otherwise its icon and heading centre below the drawn box.
	if section[0] == "MUSIC" or section[2].size() > 2:
		tab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if section[0] == "MUSIC":
		body.add_child(_music_table())
	for text in section[2]:
		body.add_child(UIStyle.label(text, 20, Color.WHITE))
	if section[0] == "GAME":
		var checker := NeonWidgets.Checker.new(Color(0.6, 0.35, 1.0, 0.55), 2, true)
		checker.custom_minimum_size = Vector2(170, 44)
		line.add_child(checker)
	return row


func _music_table() -> GridContainer:
	music_grid = GridContainer.new()
	music_grid.columns = 4
	music_grid.add_theme_constant_override("h_separation", 18)
	music_grid.add_theme_constant_override("v_separation", -2)
	var italic := UIStyle.slanted_font(false)
	for song in MUSIC:
		var title := UIStyle.label("\"%s\"" % song[0], 19, Color.WHITE)
		title.custom_minimum_size = Vector2(170, 0)
		music_grid.add_child(title)
		var dots := UIStyle.label(". ".repeat(16), 15, Color(1, 1, 1, 0.45))
		music_grid.add_child(dots)
		var artist := UIStyle.stat(song[1], 19, Color.WHITE)
		artist.custom_minimum_size = Vector2(120, 0)
		music_grid.add_child(artist)
		var where := UIStyle.label("(%s)" % song[2], 18, Color(0.85, 0.82, 0.95))
		where.add_theme_font_override("font", italic)
		music_grid.add_child(where)
	return music_grid


## The slanted heading block on the left of each credits row.
class _HeadingTab extends MarginContainer:
	func _init() -> void:
		add_theme_constant_override("margin_left", 30)
		add_theme_constant_override("margin_right", 30)
		add_theme_constant_override("margin_top", 6)
		add_theme_constant_override("margin_bottom", 2)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := minf(size.y, 56.0)
		var s := h * 0.32
		var pts := PackedVector2Array([Vector2(8, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(8, h)])
		var cols := PackedColorArray()
		for p in pts:
			cols.append(Color(0.22, 0.14, 0.45, 0.95).lerp(Color(0.14, 0.08, 0.3, 0.95), p.x / size.x))
		draw_polygon(pts, cols)
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(0.55, 0.6, 1.0, 0.25), 5.0, true)
		draw_polyline(edge, Color(0.6, 0.65, 1.0, 0.85), 1.5, true)
