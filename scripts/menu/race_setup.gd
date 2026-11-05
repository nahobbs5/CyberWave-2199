class_name RaceSetup
extends Control
## Race setup (GDD 11.3): track or championship, vehicle (with the license
## plate on the preview), AI difficulty, race settings, Start race. Choices
## are remembered in the player profile for next time.

const GRAND_PRIX: Array[String] = [
	"res://resources/grand_prix/american_circuit.tres",
	"res://resources/grand_prix/world_circuit.tres",
]
const ROSTER := "res://resources/racers/rival_roster.tres"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

var mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
var vehicle_index: int = 0

var _track: OptionButton
var _difficulty: OptionButton
var _laps: OptionButton
var _weapons: CheckButton
var _vehicle_info: VBoxContainer
var _preview: VehiclePreview
var _note: Label
var _start: Button


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	mode = GameSession.setup_mode
	_build()
	_restore()
	_start.grab_focus.call_deferred()


func vehicle() -> VehicleData:
	return VehicleCatalog.all()[vehicle_index]


func select_vehicle(index: int) -> void:
	var count := VehicleCatalog.all().size()
	vehicle_index = posmod(index, count)
	var profile := PlayerProfile.get_profile()
	profile.set_selected_vehicle(vehicle().id)
	UIStyle.fill_vehicle_info(_vehicle_info, vehicle())
	if _preview != null:
		_preview.show_vehicle(vehicle(), profile.loadout_for(vehicle().id), profile.plate_text)


func difficulty_id() -> String:
	return DIFFICULTIES[_difficulty.selected]


func make_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = _laps.selected + 1
	config.weapons_enabled = _weapons.button_pressed
	if mode != RaceConfig.Mode.GRAND_PRIX:
		config.track_name = TrackCatalog.names()[_track.selected]
		config.track_scene = TrackCatalog.scene(config.track_name)
	config.vehicle_id = vehicle().id
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	return config


## Starts the race (or a new championship) and remembers the choices.
func start() -> void:
	_remember()
	if mode == RaceConfig.Mode.GRAND_PRIX:
		var gp := load(GRAND_PRIX[_track.selected]) as GrandPrixData
		var c := Championship.create(gp, difficulty_id(), _weapons.button_pressed,
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
	setup["weapons"] = _weapons.button_pressed
	setup["gp" if mode == RaceConfig.Mode.GRAND_PRIX else "track"] = _track.selected
	profile.last_setup = setup
	profile.save()


func _restore() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	_difficulty.selected = clampi(int(setup.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	_laps.selected = clampi(int(setup.get("laps", 2)), 0, 8)
	_weapons.button_pressed = bool(setup.get("weapons", true))
	var key := "gp" if mode == RaceConfig.Mode.GRAND_PRIX else "track"
	_track.selected = clampi(int(setup.get(key, 0)), 0, _track.item_count - 1)
	vehicle_index = VehicleCatalog.index_of(profile.selected_vehicle)
	select_vehicle(vehicle_index)
	_update_note()


func _update_note() -> void:
	var lines: PackedStringArray = []
	match mode:
		RaceConfig.Mode.GRAND_PRIX:
			var gp := load(GRAND_PRIX[_track.selected]) as GrandPrixData
			lines.append("Races: " + ", ".join(gp.track_names))
			lines.append("3 races, 3 laps each, saved between races. Tracks not built yet run on the test circuit.")
			var best := PlayerProfile.get_profile().best_grand_prix(gp.id)
			if best > 0:
				lines.append("Your best result: P%d" % best)
			if Championship.load_saved() != null:
				lines.append("Starting a new Grand Prix replaces the saved one.")
		RaceConfig.Mode.ELIMINATION:
			lines.append("Always 3 laps. The last two are out at each lap's midpoint gate.")
		_:
			var best := PlayerProfile.get_profile().best_for(TrackCatalog.names()[_track.selected], _laps.selected + 1)
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
	var coins := UIStyle.header(page, RaceConfig.MODE_NAMES[mode].to_upper() + "  -  RACE SETUP")
	coins.text = "%d coins" % PlayerProfile.get_profile().coins

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	_track = OptionButton.new()
	if mode == RaceConfig.Mode.GRAND_PRIX:
		for path in GRAND_PRIX:
			_track.add_item((load(path) as GrandPrixData).display_name)
	else:
		for t in TrackCatalog.names():
			_track.add_item(t)
	_track.item_selected.connect(func(_i: int) -> void: _update_note())
	left.add_child(_row("Championship" if mode == RaceConfig.Mode.GRAND_PRIX else "Track", _track))
	_difficulty = OptionButton.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	left.add_child(_row("AI difficulty", _difficulty))
	_laps = OptionButton.new()
	for i in range(1, 10):
		_laps.add_item(str(i))
	_laps.item_selected.connect(func(_i: int) -> void: _update_note())
	var laps_row := _row("Laps", _laps)
	laps_row.visible = mode == RaceConfig.Mode.VERSUS
	left.add_child(laps_row)
	_weapons = CheckButton.new()
	left.add_child(_row("Weapons", _weapons))
	_note = UIStyle.label("", 14, Color(1, 1, 1, 0.65))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(420, 0)
	left.add_child(_note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_start = UIStyle.button("Start race", start)
	_start.custom_minimum_size = Vector2(420, 52)
	left.add_child(_start)
	left.add_child(UIStyle.button("Back", func() -> void: GameSession.to_main_menu(get_tree())))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(UIStyle.label("VEHICLE", 18, UIStyle.CYAN))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 10)
	right.add_child(picker)
	var prev := UIStyle.button("<  Previous", func() -> void: select_vehicle(vehicle_index - 1))
	var next := UIStyle.button("Next  >", func() -> void: select_vehicle(vehicle_index + 1))
	prev.custom_minimum_size = Vector2(200, 40)
	next.custom_minimum_size = Vector2(200, 40)
	picker.add_child(prev)
	picker.add_child(next)
	_preview = VehiclePreview.new()
	_preview.custom_minimum_size = Vector2(520, 300)
	right.add_child(_preview)
	_vehicle_info = VBoxContainer.new()
	right.add_child(_vehicle_info)
	right.add_child(UIStyle.label("Plate: %s   (edit it in the Garage)" % PlayerProfile.get_profile().plate_text,
			14, Color(1, 1, 1, 0.6)))


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UIStyle.label(text, 17)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	control.custom_minimum_size = Vector2(260, 36)
	row.add_child(control)
	return row
