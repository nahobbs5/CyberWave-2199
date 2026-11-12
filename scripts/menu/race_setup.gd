class_name RaceSetup
extends Control
## Race setup (GDD 11.3): vehicle (with the license plate on the preview),
## AI difficulty and race settings. Choices are remembered in the profile.
##   Grand Prix: after picking a cup; Start Grand Prix begins the championship.
##   Versus: straight from the main menu (Mario Kart style). Race type
##   (Standard or Elimination, always 3 laps), number of races, laps; Next
##   goes to the track screen, which lists every cup's tracks.
## Opened directly (tests), Grand Prix uses the remembered or first cup.
## Laid out after "reference files/Neon Versus Race Setup UI.png": settings
## rows with < value > steppers on the left under a gold banner, the car on
## the right (CarShowcase, neon style), on the dimmed 3D street
## (NeonScreenLayout). Y / G opens the garage and comes back here.

const ROSTER := "res://resources/racers/rival_roster.tres"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination"]
## Versus: how many races in a set (points add up over the set).
const RACE_COUNTS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16]

## What a mode / race type means, for the setup screens ("NPCs" are the
## computer-driven rivals).
static func describe(p_mode: RaceConfig.Mode, _races: int = 1, npcs: bool = true) -> String:
	var lines: PackedStringArray = []
	match p_mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("GRAND PRIX: every race in a cup. Points after every race (15, 12, 10, 8, 6, 4, 2, 1). "
					+ "Each race starts in the order the last one finished. Most points wins the cup.")
		RaceConfig.Mode.ELIMINATION:
			lines.append("ELIMINATION: 3 laps total. At each checkpoint, slower players are knocked out of the "
					+ "race until there is only one victor. Requires NPCs to fill the grid.")
		_:
			lines.append("STANDARD: Compete for the fastest time.")
	if not npcs:
		lines.append("NPCs OFF: just the players, no computer cars.")
	return "\n".join(lines)


var mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
var vehicle_index: int = 0

## Grand Prix: the cup (null in Versus).
var cup: GrandPrixData
var cup_path: String = ""

var layout: NeonScreenLayout
## The gold banner's text ("VERSUS  ·  1 RACE" / the cup's name).
var _summary: Label
var _difficulty: NeonStepper
var _laps: NeonStepper
var _laps_row: Control
## Versus only: Standard / Elimination.
var _race_type: NeonStepper
## Versus only: number of races.
var _races: NeonStepper
var _title: Label
var _weapons: NeonToggle
var showcase: CarShowcase
## The showcase's 3D preview.
var _preview: VehiclePreview
var _note: RichTextLabel
var _start: Button
var _hints: MenuHints


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


## Y / G: the garage, coming back here afterwards.
func open_garage() -> void:
	_remember()
	GameSession.setup_mode = mode
	GameSession.garage_return = GameSession.RACE_SETUP_SCENE
	GameSession.to_garage(get_tree())


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
	var lines: PackedStringArray = []
	for line in describe(mode, race_count()).split("\n"):
		# "STANDARD: pick any ..." -> a gold "Standard:", then the rest.
		var colon := line.find(":")
		if colon > 0 and colon < 24:
			lines.append("[color=#%s]%s:[/color]%s" % [UIStyle.GOLD.to_html(false),
					line.substr(0, colon).to_lower().capitalize(), line.substr(colon + 1)])
		else:
			lines.append(line)
	match mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("Races: " + ", ".join(cup.track_names) + ". Saved between races.")
			var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
			if best > 0:
				lines.append("Your best result: P%d" % best)
			if Championship.load_saved() != null:
				lines.append("Starting a new Grand Prix replaces the saved one.")
	_note.text = "\n".join(lines)


func _build() -> void:
	layout = NeonScreenLayout.new(_title_text(), "flags")
	add_child(layout)
	_title = layout.title_label
	# No logo here (like the mockup): the long titles need the room.
	var title_row := _title.get_parent()
	for i in 2:
		(title_row.get_child(i) as CanvasItem).visible = false
	layout.back_button.pressed.connect(back)
	SetupWidgets.add_coin_pill(self, PlayerProfile.get_profile().coins)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.content.add_child(columns)

	# Left: the settings panel, then the gold Next / Start button.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(470, 0)
	columns.add_child(left)
	var panel := NeonPanel.new(0, Color(0.3, 0.5, 1.0), Color(0.55, 0.3, 1.0))
	panel.radius = 18.0
	left.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var art: Control = TrophyIcon.new(cup.emblem, false, 54.0) if is_grand_prix() else null
	var banner := SetupWidgets.gold_banner(summary_text(), art)
	inner.add_child(banner)
	_summary = banner.label
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	var rows_margin := MarginContainer.new()
	for side in ["left", "right"]:
		rows_margin.add_theme_constant_override("margin_" + side, 14)
	rows_margin.add_theme_constant_override("margin_bottom", 14)
	rows_margin.add_child(rows)
	inner.add_child(rows_margin)
	if mode != RaceConfig.Mode.GRAND_PRIX:
		_race_type = NeonStepper.new()
		for t in RACE_TYPES:
			_race_type.add_item(t)
		_race_type.selected = 1 if mode == RaceConfig.Mode.ELIMINATION else 0
		_race_type.item_selected.connect(set_race_type)
		rows.add_child(SetupWidgets.setting_row("flags", "Race Type", _race_type))
		_races = NeonStepper.new()
		for n in RACE_COUNTS:
			_races.add_item("%d Race%s" % [n, "" if n == 1 else "s"])
		_races.item_selected.connect(func(_i: int) -> void:
			_summary.text = summary_text()
			_update_note())
		rows.add_child(SetupWidgets.setting_row("checker", "Races", _races))
	_difficulty = NeonStepper.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	rows.add_child(SetupWidgets.setting_row("robot", "NPC Difficulty", _difficulty))
	_laps = NeonStepper.new()
	for i in range(1, 10):
		_laps.add_item(str(i))
	_laps.item_selected.connect(func(_i: int) -> void: _update_note())
	_laps_row = SetupWidgets.setting_row("flags", "Laps", _laps)
	_laps_row.visible = mode == RaceConfig.Mode.VERSUS
	rows.add_child(_laps_row)
	_weapons = NeonToggle.new()
	var weapons_row := SetupWidgets.setting_row("item_box", "Items", _weapons)
	weapons_row.add_theme_constant_override("margin_right", 14)
	rows.add_child(weapons_row)
	rows.add_child(_note_box())
	_start = SetupWidgets.gold_action("Start Grand Prix" if is_grand_prix() else "Track Selection", start)
	left.add_child(_start)

	# Right: the car.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	showcase = CarShowcase.new(230.0, true)
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase.vehicle_changed.connect(select_vehicle)
	# LB / RB and the mouse change the car; the d-pad stays on the settings.
	showcase.prev_button.focus_mode = Control.FOCUS_NONE
	showcase.next_button.focus_mode = Control.FOCUS_NONE
	right.add_child(showcase)
	_preview = showcase.preview
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override("separation", 10)
	plate.add_child(RaceIcons.rect("pencil", 22))
	var plate_label := UIStyle.label("Plate: %s   (Edit it in the Garage)" % PlayerProfile.get_profile().plate_text, 18,
			Color(1, 1, 1, 0.85))
	plate_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	plate.add_child(plate_label)
	right.add_child(plate)

	_hints = MenuHints.new([["B", "Esc", "Back"], ["A", "Enter", "Start" if is_grand_prix() else "Next"],
			["Y", "G", "Garage"]])
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints.offset_right = -24
	_hints.offset_top = -66
	_hints.offset_bottom = -22
	_hints.alignment = BoxContainer.ALIGNMENT_END
	add_child(_hints)
	_link_focus()


## The (i) note under the settings, with the mode's name in gold.
func _note_box() -> Control:
	var box := PanelContainer.new()
	var style := UIStyle.box_style(Color(0.03, 0.02, 0.1, 0.7), Color(0.4, 0.45, 1.0, 0.7), 0, 2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var info := NeonWidgets.icon("info", 28)
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(info)
	_note = RichTextLabel.new()
	_note.bbcode_enabled = true
	_note.fit_content = true
	_note.scroll_active = false
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.custom_minimum_size = Vector2(300, 0)
	_note.add_theme_font_override("normal_font", UIStyle.slanted_font(false))
	_note.add_theme_font_size_override("normal_font_size", 17)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_note)
	return box


## Up / down through the visible settings, then the gold button and Back.
func _link_focus() -> void:
	var chain: Array[Control] = []
	for c: Control in [_race_type, _races, _difficulty, _laps, _weapons, _start, layout.back_button]:
		if c != null and (c != _laps or _laps_row.visible):
			chain.append(c)
	for i in chain.size():
		chain[i].focus_neighbor_top = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])
		chain[i].focus_neighbor_bottom = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		if not chain[i] is NeonStepper:
			chain[i].focus_neighbor_left = NodePath(".")
			chain[i].focus_neighbor_right = NodePath(".")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()
		return
	var garage := false
	if event is InputEventJoypadButton:
		garage = event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	elif event is InputEventKey:
		garage = event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G
	if garage:
		get_viewport().set_input_as_handled()
		open_garage()


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
	_link_focus()
	_update_note()


func _title_text() -> String:
	return RaceConfig.MODE_NAMES[mode].to_upper() + " - RACE SETUP"
