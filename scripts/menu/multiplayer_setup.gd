class_name MultiplayerSetup
extends Control
## Split screen, step 3 of 3: the race settings. Mode (Grand Prix / Versus),
## race type and number of races (Versus), AI rivals, difficulty, laps,
## weapons. Grand Prix goes on to the cup screen; Versus to the track
## screen, which lists every cup's tracks and comes back before each race of
## the set. Any player can drive the menu. No coins or records in split screen.
##
## Laid out after "reference files/Cyberwave 2199 Race Setup.png" in the
## connect / car screens' style: a pill per player with their car, then a
## RACE SETTINGS panel whose rows are the single-player race setup's
## (SetupWidgets.setting_row with ‹ value › NeonSteppers and NeonToggles),
## an info box explaining the mode, and gold Next.

const MODES: Array[String] = ["Grand Prix", "Versus"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination"]
const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard"]

var layout: NeonScreenLayout
## One pill per player along the top.
var player_pills: Array[PlayerPill] = []
var next_button: NeonMenuButton
var _mode: NeonStepper
var _race_type: NeonStepper
var _race_type_row: Control
var _races: NeonStepper
var _races_row: Control
var _ai: NeonToggle
var _difficulty: NeonStepper
var _difficulty_row: Control
var _laps: NeonStepper
var _laps_row: Control
var _weapons: NeonToggle
var _note: RichTextLabel


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = true
	GameSession.series = null
	Music.play(get_tree(), Music.MENU)
	_build()
	_restore()
	UIStyle.fade_in(self)
	next_button.grab_focus.call_deferred()
	CarThumbnails.request(get_tree(), func() -> void:
		for p in player_pills:
			p.queue_redraw())


func is_grand_prix() -> bool:
	return _mode.selected == 0


## Elimination needs a full grid, so it's off when NPCs are off.
func elimination_allowed() -> bool:
	return _ai.button_pressed


func selected_mode() -> RaceConfig.Mode:
	if is_grand_prix():
		return RaceConfig.Mode.GRAND_PRIX
	if _race_type.selected == 1 and elimination_allowed():
		return RaceConfig.Mode.ELIMINATION
	return RaceConfig.Mode.VERSUS


func race_count() -> int:
	return RaceSetup.RACE_COUNTS[_races.selected]


## Test / menu hooks.
func set_mode(grand_prix: bool) -> void:
	_mode.selected = 0 if grand_prix else 1
	_update()


func set_ai_rivals(on: bool) -> void:
	_ai.button_pressed = on
	_update()


func set_race_type(index: int) -> void:
	_race_type.selected = index
	_update()


func set_races(count: int) -> void:
	_races.selected = maxi(0, RaceSetup.RACE_COUNTS.find(count))
	_update()


## Stores the settings and moves on: cups (Grand Prix) or tracks (Versus).
func next() -> void:
	GameSession.mp_settings = {
		"mode": _mode.selected,
		"race_type": _race_type.selected,
		"races": _races.selected,
		"ai": _ai.button_pressed,
		"difficulty": _difficulty.selected,
		"laps": _laps.selected,
		"weapons": _weapons.button_pressed,
	}
	GameSession.cup_path = ""
	GameSession.track_name = ""
	var mode := selected_mode()
	if mode == RaceConfig.Mode.GRAND_PRIX:
		GameSession.to_cup_select(get_tree(), mode)
	else:
		GameSession.setup_mode = mode
		GameSession.begin_versus(get_tree(), GameSession.make_multiplayer_config(mode, ""), race_count(),
				GameSession.difficulty_id())


func back() -> void:
	GameSession.to_mp_cars(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _update() -> void:
	var gp := is_grand_prix()
	_race_type_row.visible = not gp
	_races_row.visible = not gp
	# Without NPCs there's no Elimination: it snaps back to Standard.
	if not elimination_allowed() and _race_type.selected == 1:
		_race_type.selected = 0
	_laps_row.visible = not gp and _race_type.selected == 0
	_difficulty_row.visible = _ai.button_pressed
	var lines: PackedStringArray = []
	var text := RaceSetup.describe(selected_mode(), 1 if gp else race_count(), _ai.button_pressed)
	if not gp and not elimination_allowed():
		text += "\nELIMINATION: needs NPCs to fill the grid, so turn NPCs on to pick it."
	for line in text.split("\n"):
		# "STANDARD: pick any ..." -> a cyan "STANDARD:", then the rest.
		var colon := line.find(":")
		if colon > 0 and colon < 24:
			lines.append("[color=#%s]%s:[/color]%s" % [UIStyle.CYAN.to_html(false), line.substr(0, colon), line.substr(colon + 1)])
		else:
			lines.append(line)
	_note.text = "\n".join(lines)
	next_button.text = "Cup Selection" if gp else "Track Selection"
	next_button.queue_redraw()
	_link_focus()


func _restore() -> void:
	var s := GameSession.mp_settings
	_mode.selected = clampi(int(s.get("mode", 1)), 0, MODES.size() - 1)
	_race_type.selected = clampi(int(s.get("race_type", 0)), 0, 1)
	_races.selected = clampi(int(s.get("races", RaceSetup.DEFAULT_RACES)), 0, RaceSetup.RACE_COUNTS.size() - 1)
	_ai.set_pressed_no_signal(bool(s.get("ai", true)))
	_difficulty.selected = clampi(int(s.get("difficulty", 1)), 0, 2)
	_laps.selected = clampi(int(s.get("laps", 2)), 0, 8)
	_weapons.set_pressed_no_signal(bool(s.get("weapons", true)))
	_ai.queue_redraw()
	_weapons.queue_redraw()
	_update()


## Up / down: the visible rows (left column, then right), Next, Back.
func _link_focus() -> void:
	var chain: Array[Control] = []
	for c: Control in [_mode, _race_type, _races, _ai, _difficulty, _laps, _weapons, next_button, layout.back_button]:
		var row := c.get_parent().get_parent() if c is NeonStepper or c is NeonToggle else null
		if row == null or (row as Control).visible:
			chain.append(c)
	for i in chain.size():
		chain[i].focus_neighbor_top = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])
		chain[i].focus_neighbor_bottom = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		if not chain[i] is NeonStepper:
			chain[i].focus_neighbor_left = NodePath(".")
			chain[i].focus_neighbor_right = NodePath(".")


func _build() -> void:
	layout = MultiplayerWidgets.frame(self, "RACE SETUP", 3)
	layout.back_button.focus_mode = Control.FOCUS_ALL
	layout.back_button.pressed.connect(back)
	next_button = MultiplayerWidgets.next_button("Track Selection", next)
	next_button.focus_mode = Control.FOCUS_ALL
	add_child(next_button)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var page_margin := MarginContainer.new()
	page_margin.add_theme_constant_override("margin_left", 60)
	page_margin.add_theme_constant_override("margin_right", 60)
	page_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.content.add_child(page_margin)
	page_margin.add_child(page)

	# Who's racing in what.
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 24 if GameSession.mp_devices.size() <= 2 else 14)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(strip)
	var players := GameSession.mp_devices.size()
	for i in players:
		var car: VehicleData = VehicleCatalog.by_id(GameSession.mp_vehicles[i]) if i < GameSession.mp_vehicles.size() else null
		var pill := PlayerPill.new(i, car, 380.0 if players <= 2 else 262.0)
		strip.add_child(pill)
		player_pills.append(pill)

	# The settings: single-player style rows in two columns.
	var panel := NeonPanel.new(16, UIStyle.MAGENTA, Color(0.6, 0.3, 1.0))
	panel.radius = 20.0
	page.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	inner.add_child(header)
	var checker := NeonWidgets.Checker.new(UIStyle.MAGENTA, 2, false)
	checker.custom_minimum_size = Vector2(40, 28)
	checker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(checker)
	var title := UIStyle.label("RACE SETTINGS", 28, Color.WHITE)
	title.add_theme_font_override("font", UIStyle.slanted_font(true))
	header.add_child(title)
	inner.add_child(NeonWidgets.Divider.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	inner.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	columns.add_child(ColumnDivider.new())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_mode = _stepper(MODES)
	left.add_child(SetupWidgets.setting_row("flags", "Mode", _mode))
	_race_type = _stepper(RACE_TYPES)
	_race_type_row = SetupWidgets.setting_row("flags", "Race Type", _race_type)
	left.add_child(_race_type_row)
	var counts: Array[String] = []
	for n in RaceSetup.RACE_COUNTS:
		counts.append("%d Race%s" % [n, "" if n == 1 else "s"])
	_races = _stepper(counts)
	_races_row = SetupWidgets.setting_row("checker", "Races", _races)
	left.add_child(_races_row)
	_ai = NeonToggle.new()
	_ai.toggled.connect(func(_on: bool) -> void: _update())
	left.add_child(_toggle_row("robot", "NPCs", _ai))

	_difficulty = _stepper(DIFFICULTIES)
	_difficulty_row = SetupWidgets.setting_row("robot", "NPC Difficulty", _difficulty)
	right.add_child(_difficulty_row)
	var laps: Array[String] = []
	for i in range(1, 10):
		laps.append(str(i))
	_laps = _stepper(laps)
	_laps_row = SetupWidgets.setting_row("flags", "Laps", _laps)
	right.add_child(_laps_row)
	_weapons = NeonToggle.new()
	right.add_child(_toggle_row("item_box", "Items", _weapons))

	# What the chosen mode means (Elimination especially).
	var info := MultiplayerWidgets.InfoBox.new()
	page.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 18)
	info.add_child(info_row)
	info_row.add_child(MultiplayerWidgets.InfoGlyph.new())
	_note = RichTextLabel.new()
	_note.bbcode_enabled = true
	_note.fit_content = true
	_note.scroll_active = false
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_font_override("normal_font", UIStyle.bold_font())
	_note.add_theme_font_size_override("normal_font_size", 18)
	info_row.add_child(_note)


func _stepper(items: Array[String]) -> NeonStepper:
	var s := NeonStepper.new()
	for item in items:
		s.add_item(item)
	s.custom_minimum_size = Vector2(230, 40)
	s.item_selected.connect(func(_i: int) -> void: _update())
	return s


func _toggle_row(icon: String, text: String, toggle: NeonToggle) -> Control:
	var row := SetupWidgets.setting_row(icon, text, toggle)
	row.add_theme_constant_override("margin_right", 14)
	return row


# --- pieces ------------------------------------------------------------------

## "P1  Aurora GT  [car]" in a slanted frame in the player's colour.
class PlayerPill extends Control:
	var slot: int
	var color: Color
	var car: VehicleData

	func _init(index: int, vehicle: VehicleData, width: float) -> void:
		slot = index
		color = SplitScreen.PLAYER_COLORS[index]
		car = vehicle
		custom_minimum_size = Vector2(width, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.32
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h)])
		draw_colored_polygon(pts, Color(0.04, 0.03, 0.1, 0.9))
		var tag_w := 70.0
		draw_colored_polygon(PackedVector2Array([Vector2(s, 0), Vector2(s + tag_w, 0), Vector2(tag_w, h), Vector2(0, h)]),
				Color(color, 0.35))
		draw_line(Vector2(s + tag_w, 0), Vector2(tag_w, h), color, 2.0, true)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(color, 0.18), 14.0, true)
		draw_polyline(outline, Color(color, 0.35), 6.0, true)
		draw_polyline(outline, color, 2.5, true)
		var font := UIStyle.slanted_font(true)
		var fs := 30
		var tag := "P%d" % (slot + 1)
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(s * 0.5 + (tag_w - tw) * 0.5, base), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				color.lerp(Color.WHITE, 0.25))
		# Car picture on the right, the name between.
		var pic_w := 0.0
		var tex := CarThumbnails.get_texture(car.id) if car != null else null
		# Narrow pills (3-4 players) leave the room for the name.
		if tex != null and size.x >= 320.0:
			var ts := tex.get_size()
			var k := (h + 6.0) / ts.y
			pic_w = ts.x * k
			draw_texture_rect(tex, Rect2(Vector2(size.x - s - pic_w + 4.0, -4.0), ts * k), false)
		var name_fs := 22
		var car_name := car.display_name if car != null else "?"
		var name_font := UIStyle.bold_font()
		var x := s + tag_w + 14.0
		var max_w := size.x - x - pic_w - s
		draw_string(name_font, Vector2(x, (h + name_font.get_ascent(name_fs) - name_font.get_descent(name_fs)) * 0.5),
				car_name, HORIZONTAL_ALIGNMENT_LEFT, max_w, name_fs, Color.WHITE)


## Thin vertical line between the two settings columns.
class ColumnDivider extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(2, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 6, 2, size.y - 12), Color(0.6, 0.4, 1.0, 0.4))
