class_name RaceSetup
extends Control
## Race setup (GDD 11.3), the last step after picking a cup (and, in Versus,
## a track): vehicle (with the license plate on the preview), AI difficulty,
## race settings, Start race. Choices are remembered in the player profile.
## Versus has a Race type: Standard or Elimination (always 3 laps). Opened
## directly (tests), it uses the remembered or first cup and track.

const ROSTER := "res://resources/racers/rival_roster.tres"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination"]

var mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
var vehicle_index: int = 0

## The cup (Grand Prix: the championship; Versus: where the track is from).
var cup: GrandPrixData
var cup_path: String = ""
## Versus: the track to race.
var track_name: String = ""

var _summary: Label
var _difficulty: OptionButton
var _laps: OptionButton
var _laps_row: HBoxContainer
## Versus only: Standard / Elimination.
var _race_type: OptionButton
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


func make_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = _laps.selected + 1
	config.weapons_enabled = _weapons.button_pressed
	if mode != RaceConfig.Mode.GRAND_PRIX:
		config.track_name = track_name
		config.track_scene = TrackCatalog.scene(track_name)
	config.vehicle_id = vehicle().id
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	config.rival_vehicles = RaceConfig.random_vehicles(7)
	return config


## Starts the race (or a new championship) and remembers the choices.
func start() -> void:
	_remember()
	if mode == RaceConfig.Mode.GRAND_PRIX:
		if cup.locked:
			return
		var c := Championship.create(cup, difficulty_id(), _weapons.button_pressed,
				load(ROSTER) as RivalRoster, vehicle().id)
		c.save()
		GameSession.start_race(get_tree(), c.make_race_config())
	else:
		GameSession.start_race(get_tree(), make_config())


func _remember() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	setup["difficulty"] = _difficulty.selected
	setup["laps"] = _laps.selected
	if mode != RaceConfig.Mode.GRAND_PRIX:
		setup["race_type"] = 1 if mode == RaceConfig.Mode.ELIMINATION else 0
	setup["weapons"] = _weapons.button_pressed
	setup["cup"] = cup_path
	if mode != RaceConfig.Mode.GRAND_PRIX:
		setup["track_name"] = track_name
	profile.last_setup = setup
	profile.save()


func _restore() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	_difficulty.selected = clampi(int(setup.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	_laps.selected = clampi(int(setup.get("laps", 2)), 0, 8)
	_weapons.button_pressed = bool(setup.get("weapons", true))
	vehicle_index = VehicleCatalog.index_of(profile.selected_vehicle)
	select_vehicle(vehicle_index)
	_update_note()


func _update_note() -> void:
	var lines: PackedStringArray = []
	match mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("Races: " + ", ".join(cup.track_names))
			lines.append("3 races, 3 laps each, saved between races.")
			var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
			if best > 0:
				lines.append("Your best result: P%d" % best)
			if Championship.load_saved() != null:
				lines.append("Starting a new Grand Prix replaces the saved one.")
		RaceConfig.Mode.ELIMINATION:
			lines.append("Always 3 laps. The last two are out at each lap's midpoint gate.")
		_:
			var best := PlayerProfile.get_profile().best_for(track_name, _laps.selected + 1)
			if best.has("race"):
				lines.append("Personal best (%d laps): %s   best lap %s" % [_laps.selected + 1,
						RaceProgress.format_time(float(best.race)), RaceProgress.format_time(float(best.get("lap", -1.0)))])
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
	# What was picked on the cup / track screens.
	var picked := HBoxContainer.new()
	picked.add_theme_constant_override("separation", 12)
	left.add_child(picked)
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
	_difficulty = OptionButton.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	left.add_child(_row("AI difficulty", _difficulty))
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
	_start = UIStyle.primary_button("Start race", start)
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


## "American Cup" (Grand Prix) or "American Cup  ·  Vegas Overdrive" (Versus).
func summary_text() -> String:
	if mode == RaceConfig.Mode.GRAND_PRIX:
		return cup.display_name.to_upper()
	return "%s  ·  %s" % [cup.display_name.to_upper(), track_name.to_upper()]


## Back to the previous step: the track screen (Versus) or the cup screen.
func back() -> void:
	if mode == RaceConfig.Mode.GRAND_PRIX:
		GameSession.to_cup_select(get_tree(), mode)
	else:
		GameSession.to_track_select(get_tree())


## The cup and track from the cup / track screens, else the remembered ones,
## else the first unlocked cup and its first track.
func _resolve_selection() -> void:
	var setup := PlayerProfile.get_profile().last_setup
	cup_path = GameSession.cup_path if GameSession.cup_path != "" else str(setup.get("cup", ""))
	cup = GrandPrixData.cup_by_path(cup_path)
	if cup == null or not cup.is_open(mode == RaceConfig.Mode.GRAND_PRIX):
		cup_path = GrandPrixData.CUPS[0]
		cup = GrandPrixData.cup_by_path(cup_path)
	track_name = GameSession.track_name if GameSession.track_name != "" else str(setup.get("track_name", ""))
	var index := cup.track_names.find(track_name)
	if index < 0 or (cup.locked and not cup.is_track_built(index)):
		# First raceable track of the cup.
		track_name = cup.track_names[0]
		for i in cup.track_names.size():
			if not cup.locked or cup.is_track_built(i):
				track_name = cup.track_names[i]
				break


## Versus race type: 0 = Standard, 1 = Elimination.
func set_race_type(index: int) -> void:
	if mode == RaceConfig.Mode.GRAND_PRIX:
		return
	mode = RaceConfig.Mode.ELIMINATION if index == 1 else RaceConfig.Mode.VERSUS
	if _race_type.selected != index:
		_race_type.selected = index
	_title.text = _title_text()
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
