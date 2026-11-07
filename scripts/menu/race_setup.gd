class_name RaceSetup
extends Control
## Race setup (GDD 11.3): vehicle (with the license plate on the preview),
## AI difficulty and race settings. Choices are remembered in the profile.
##   Grand Prix: after picking a cup; Start race begins the championship.
##   Versus: straight from the main menu (Mario Kart style). Race type
##   (Standard or Elimination, always 3 laps), number of races, laps; Next
##   goes to the track screen, which lists every cup's tracks.
## Opened directly (tests), Grand Prix uses the remembered or first cup.

const ROSTER := "res://resources/racers/rival_roster.tres"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination"]
## Versus: how many races in a set (points add up over the set).
const RACE_COUNTS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16]

## What a mode / race type means, for the setup screens ("NPCs" are the
## computer-driven rivals).
static func describe(p_mode: RaceConfig.Mode, races: int = 1, npcs: bool = true) -> String:
	var lines: PackedStringArray = []
	match p_mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("GRAND PRIX: every race in a cup. Points after every race (15, 12, 10, 8, 6, 4, 2, 1). "
					+ "Each race starts in the order the last one finished. Most points wins the cup.")
		RaceConfig.Mode.ELIMINATION:
			lines.append("ELIMINATION: always 3 laps. At the halfway gate of every lap, the last two cars "
					+ "across it are knocked out (8, then 6, then 4, then 2 left). The final two race to the "
					+ "line for the win. Needs NPCs to fill the grid.")
		_:
			lines.append("STANDARD: pick any track, race the laps you chose, first across the line wins.")
	if p_mode != RaceConfig.Mode.GRAND_PRIX and races > 1:
		lines.append("%d RACES: pick a track before each one. Points add up like a Grand Prix and the most points wins the set." % races)
	if not npcs:
		lines.append("NPCs OFF: just the players, no computer cars.")
	return "\n".join(lines)


var mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
var vehicle_index: int = 0

## Grand Prix: the cup (null in Versus).
var cup: GrandPrixData
var cup_path: String = ""

var _summary: Label
var _difficulty: OptionButton
var _laps: OptionButton
var _laps_row: HBoxContainer
## Versus only: Standard / Elimination.
var _race_type: OptionButton
## Versus only: number of races.
var _races: OptionButton
var _title: Label
var _weapons: CheckButton
var showcase: CarShowcase
## The showcase's 3D preview.
var _preview: VehiclePreview
var _note: Label
var _start: Button


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	mode = GameSession.setup_mode
	if is_grand_prix():
		_resolve_selection()
	_build()
	UIStyle.fade_in(self)
	_restore()
	_start.grab_focus.call_deferred()


func vehicle() -> VehicleData:
	return VehicleCatalog.all()[vehicle_index]


func select_vehicle(index: int) -> void:
	var count := VehicleCatalog.all().size()
	vehicle_index = posmod(index, count)
	var profile := PlayerProfile.get_profile()
	profile.set_selected_vehicle(vehicle().id)
	if showcase != null:
		showcase.set_vehicle(vehicle_index, profile.loadout_for(vehicle().id), profile.plate_text)


func difficulty_id() -> String:
	return DIFFICULTIES[_difficulty.selected]


func is_grand_prix() -> bool:
	return mode == RaceConfig.Mode.GRAND_PRIX


## Versus: races in the set.
func race_count() -> int:
	return RACE_COUNTS[_races.selected] if _races != null else 1


## The race settings (Versus: everything but the track, which the track
## screen adds).
func make_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = _laps.selected + 1
	config.weapons_enabled = _weapons.button_pressed
	config.vehicle_id = vehicle().id
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	config.rival_vehicles = RaceConfig.random_vehicles(7)
	return config


## Grand Prix: starts the championship. Versus: on to the track screen.
## Remembers the choices either way.
func start() -> void:
	_remember()
	if is_grand_prix():
		if cup.locked:
			return
		var c := Championship.create(cup, difficulty_id(), _weapons.button_pressed,
				load(ROSTER) as RivalRoster, vehicle().id)
		c.save()
		GameSession.start_race(get_tree(), c.make_race_config())
	else:
		GameSession.setup_mode = mode
		GameSession.begin_versus(get_tree(), make_config(), race_count(), difficulty_id())


func _remember() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	setup["difficulty"] = _difficulty.selected
	setup["laps"] = _laps.selected
	if mode != RaceConfig.Mode.GRAND_PRIX:
		setup["race_type"] = 1 if mode == RaceConfig.Mode.ELIMINATION else 0
	setup["weapons"] = _weapons.button_pressed
	if is_grand_prix():
		setup["cup"] = cup_path
	else:
		setup["races"] = _races.selected
	profile.last_setup = setup
	profile.save()


func _restore() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	_difficulty.selected = clampi(int(setup.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	_laps.selected = clampi(int(setup.get("laps", 2)), 0, 8)
	_weapons.button_pressed = bool(setup.get("weapons", true))
	if _races != null:
		_races.selected = clampi(int(setup.get("races", 0)), 0, RACE_COUNTS.size() - 1)
		_summary.text = summary_text()
	vehicle_index = VehicleCatalog.index_of(profile.selected_vehicle)
	select_vehicle(vehicle_index)
	_update_note()


func _update_note() -> void:
	var lines: PackedStringArray = [describe(mode, race_count())]
	match mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("Races: " + ", ".join(cup.track_names) + ". Saved between races.")
			var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
			if best > 0:
				lines.append("Your best result: P%d" % best)
			if Championship.load_saved() != null:
				lines.append("Starting a new Grand Prix replaces the saved one.")
		_:
			lines.append("Next you pick the track from every cup.")
	_note.text = "\n".join(lines)


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
	var coins := UIStyle.header(page, _title_text())
	_title = coins.get_parent().get_child(0) as Label
	coins.text = "%d coins" % PlayerProfile.get_profile().coins

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	# Grand Prix: the cup picked on the cup screen. Versus: how many races.
	var picked := HBoxContainer.new()
	picked.add_theme_constant_override("separation", 12)
	left.add_child(picked)
	if is_grand_prix():
		picked.add_child(TrophyIcon.new(cup.emblem, false, 64.0))
	_summary = UIStyle.heading(summary_text(), 22, UIStyle.GOLD)
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picked.add_child(_summary)
	if mode != RaceConfig.Mode.GRAND_PRIX:
		_race_type = OptionButton.new()
		for t in RACE_TYPES:
			_race_type.add_item(t)
		_race_type.selected = 1 if mode == RaceConfig.Mode.ELIMINATION else 0
		_race_type.item_selected.connect(set_race_type)
		left.add_child(_row("Race type", _race_type))
		_races = OptionButton.new()
		for n in RACE_COUNTS:
			_races.add_item("%d race%s" % [n, "" if n == 1 else "s"])
		_races.item_selected.connect(func(_i: int) -> void:
			_summary.text = summary_text()
			_update_note())
		left.add_child(_row("Races", _races))
	_difficulty = OptionButton.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	left.add_child(_row("NPC difficulty", _difficulty))
	_laps = OptionButton.new()
	for i in range(1, 10):
		_laps.add_item(str(i))
	_laps.item_selected.connect(func(_i: int) -> void: _update_note())
	_laps_row = _row("Laps", _laps)
	_laps_row.visible = mode == RaceConfig.Mode.VERSUS
	left.add_child(_laps_row)
	_weapons = CheckButton.new()
	left.add_child(_row("Weapons", _weapons))
	_note = UIStyle.label("", 14, Color(1, 1, 1, 0.65))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(420, 0)
	left.add_child(_note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_start = UIStyle.primary_button("Start race" if is_grand_prix() else "Next: pick a track", start)
	_start.custom_minimum_size = Vector2(420, 52)
	left.add_child(_start)
	left.add_child(UIStyle.button("Back", back))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UIStyle.label("VEHICLE", 18, UIStyle.CYAN))
	showcase = CarShowcase.new(280.0)
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase.vehicle_changed.connect(select_vehicle)
	right.add_child(showcase)
	_preview = showcase.preview
	right.add_child(UIStyle.label("Plate: %s   (edit it in the Garage)" % PlayerProfile.get_profile().plate_text,
			14, Color(1, 1, 1, 0.6)))


## "AMERICAN CUP" (Grand Prix) or "VERSUS  ·  4 RACES".
func summary_text() -> String:
	if is_grand_prix():
		return cup.display_name.to_upper()
	var n := race_count()
	return "%s  ·  %d RACE%s" % [RaceConfig.MODE_NAMES[mode].to_upper(), n, "" if n == 1 else "S"]


## Back: the cup screen (Grand Prix) or the main menu (Versus).
func back() -> void:
	if is_grand_prix():
		GameSession.to_cup_select(get_tree(), mode)
	else:
		GameSession.to_main_menu(get_tree())


## Grand Prix: the cup from the cup screen, else the remembered one, else
## the first unlocked cup.
func _resolve_selection() -> void:
	var setup := PlayerProfile.get_profile().last_setup
	cup_path = GameSession.cup_path if GameSession.cup_path != "" else str(setup.get("cup", ""))
	cup = GrandPrixData.cup_by_path(cup_path)
	if cup == null or not cup.is_open(mode == RaceConfig.Mode.GRAND_PRIX):
		cup_path = GrandPrixData.CUPS[0]
		cup = GrandPrixData.cup_by_path(cup_path)


## Versus race type: 0 = Standard, 1 = Elimination.
func set_race_type(index: int) -> void:
	if mode == RaceConfig.Mode.GRAND_PRIX:
		return
	mode = RaceConfig.Mode.ELIMINATION if index == 1 else RaceConfig.Mode.VERSUS
	if _race_type.selected != index:
		_race_type.selected = index
	_title.text = _title_text()
	_summary.text = summary_text()
	_laps_row.visible = mode == RaceConfig.Mode.VERSUS
	_update_note()


func _title_text() -> String:
	return RaceConfig.MODE_NAMES[mode].to_upper() + "  -  RACE SETUP"


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UIStyle.label(text, 17)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	control.custom_minimum_size = Vector2(260, 36)
	row.add_child(control)
	return row
