class_name MultiplayerSetup
extends Control
## Split screen, step 3 of 3: the race settings. Mode (Grand Prix / Versus),
## race type and number of races (Versus), AI rivals, difficulty, laps,
## weapons. Grand Prix goes on to the cup screen; Versus to the track
## screen, which lists every cup's tracks and comes back before each race of
## the set. Any player can drive the menu. No coins or records in split screen.

const MODES: Array[String] = ["Grand Prix", "Versus"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination"]
const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard"]

var _mode: OptionButton
var _race_type: OptionButton
var _race_type_row: HBoxContainer
var _races: OptionButton
var _races_row: HBoxContainer
var _ai: CheckButton
var _difficulty: OptionButton
var _difficulty_row: HBoxContainer
var _laps: OptionButton
var _laps_row: HBoxContainer
var _weapons: CheckButton
var _next: Button
var _note: Label


func _ready() -> void:
	InputSetup.ensure_actions()
	GameSession.split_screen = true
	GameSession.series = null
	Music.play(get_tree(), Music.MENU)
	_build()
	_restore()
	UIStyle.fade_in(self)
	_next.grab_focus.call_deferred()


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
	_race_type.set_item_disabled(1, not elimination_allowed())
	if not elimination_allowed() and _race_type.selected == 1:
		_race_type.selected = 0
	_laps_row.visible = not gp and _race_type.selected == 0
	_difficulty_row.visible = _ai.button_pressed
	_note.text = RaceSetup.describe(selected_mode(), 1 if gp else race_count(), _ai.button_pressed)
	_next.text = "Next: pick a cup" if gp else "Next: pick a track"


func _restore() -> void:
	var s := GameSession.mp_settings
	_mode.selected = clampi(int(s.get("mode", 1)), 0, MODES.size() - 1)
	_race_type.selected = clampi(int(s.get("race_type", 0)), 0, 1)
	_races.selected = clampi(int(s.get("races", 3)), 0, RaceSetup.RACE_COUNTS.size() - 1)
	_ai.button_pressed = bool(s.get("ai", true))
	_difficulty.selected = clampi(int(s.get("difficulty", 1)), 0, 2)
	_laps.selected = clampi(int(s.get("laps", 2)), 0, 8)
	_weapons.button_pressed = bool(s.get("weapons", true))
	_update()


func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	MultiplayerConnect.title_row(page, "RACE SETUP", 3)

	# Who's racing in what.
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 28)
	page.add_child(strip)
	for i in GameSession.mp_devices.size():
		var car := VehicleCatalog.by_id(GameSession.mp_vehicles[i]) if i < GameSession.mp_vehicles.size() else null
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 8)
		who.add_child(UIStyle.heading("P%d" % (i + 1), 24, SplitScreen.PLAYER_COLORS[i]))
		var name_label := UIStyle.stat(car.display_name if car != null else "?", 18, Color.WHITE)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_child(name_label)
		strip.add_child(who)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var panel := UIStyle.section_panel(22)
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 44)
	panel.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	_mode = _options(MODES)
	_mode.item_selected.connect(func(_i: int) -> void: _update())
	left.add_child(_row("Mode", _mode))
	_race_type = _options(RACE_TYPES)
	_race_type.item_selected.connect(func(_i: int) -> void: _update())
	_race_type_row = _row("Race type", _race_type)
	left.add_child(_race_type_row)
	var counts: Array[String] = []
	for n in RaceSetup.RACE_COUNTS:
		counts.append("%d race%s" % [n, "" if n == 1 else "s"])
	_races = _options(counts)
	_races.item_selected.connect(func(_i: int) -> void: _update())
	_races_row = _row("Races", _races)
	left.add_child(_races_row)
	_ai = CheckButton.new()
	_ai.toggled.connect(func(_on: bool) -> void: _update())
	left.add_child(_row("NPCs", _ai))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_difficulty = _options(DIFFICULTIES)
	_difficulty_row = _row("NPC difficulty", _difficulty)
	right.add_child(_difficulty_row)
	var laps: Array[String] = []
	for i in range(1, 10):
		laps.append(str(i))
	_laps = _options(laps)
	_laps_row = _row("Laps", _laps)
	right.add_child(_laps_row)
	_weapons = CheckButton.new()
	right.add_child(_row("Weapons", _weapons))

	# What the chosen mode means (Elimination especially).
	var about := UIStyle.section_panel(14)
	about.custom_minimum_size = Vector2(760, 0)
	about.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(about)
	_note = UIStyle.stat("", 16, Color(1, 1, 1, 0.85))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	page.add_child(buttons)
	buttons.add_child(UIStyle.secondary_button("Back", back))
	_next = UIStyle.primary_button("Next", next)
	buttons.add_child(_next)


func _options(items: Array[String]) -> OptionButton:
	var b := OptionButton.new()
	for item in items:
		b.add_item(item)
	b.custom_minimum_size = Vector2(190, 36)
	return b


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UIStyle.label(text, 18)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	row.add_child(control)
	return row
