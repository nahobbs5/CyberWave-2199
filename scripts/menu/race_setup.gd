class_name RaceSetup
extends Control
## Race setup (GDD 11.3): vehicle (with the license plate on the preview),
## engine class (CC), AI difficulty and race settings. Choices last until the
## app closes; each launch starts on the defaults.
##   Grand Prix: straight from the main menu. CC, a Mirror toggle, NPC
##   difficulty, items; Choose Cup goes to the cup screen, whose START GRAND
##   PRIX begins the championship (GameSession.begin_grand_prix).
##   Versus: straight from the main menu (Mario Kart style). Race type
##   (Standard, Elimination (always 3 laps) or Mirror), CC, number of races,
##   laps; Next goes to the track screen, which lists every cup's tracks.
##   Time Trial (GDD 2.5): just the car and your name; always 3 laps,
##   100cc, one Triple Nitro, no crates. Track Selection goes to the track screen (with the
##   ghost picker). Only cars you've unlocked can be picked (any mode).
## Your Name (kept in the profile, used in the standings and results) is the
## last row, just above the gold button. A Race Results style title across
## the top (VERSUS or GRAND PRIX).
## Laid out after "reference files/Neon Versus Race Setup UI.png": settings
## rows with < value > steppers on the left, the car on
## the right (CarShowcase, neon style), on the dimmed 3D street
## (NeonScreenLayout). Y / G opens the garage and comes back here.

const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const RACE_TYPES: Array[String] = ["Standard", "Elimination", "Mirror"]
## RACE_TYPES index of Mirror: a Versus race with the track driven in reverse.
const MIRROR := 2
## Versus: how many races in a set (points add up over the set).
const RACE_COUNTS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16]
## Default Versus set: 3 races (index into RACE_COUNTS).
const DEFAULT_RACES: int = 2

## What a mode / race type means, for the setup screens ("NPCs" are the
## computer-driven rivals).
static func describe(p_mode: RaceConfig.Mode, _races: int = 1, npcs: bool = true, mirrored: bool = false) -> String:
	var lines: PackedStringArray = []
	match p_mode:
		RaceConfig.Mode.GRAND_PRIX:
			lines.append("GRAND PRIX: Race a Complete Cup")
			if mirrored:
				lines.append("MIRROR: Every track is driven in reverse.")
		RaceConfig.Mode.TIME_TRIAL:
			lines.append("TIME TRIAL: %d laps, %dcc, one Triple Nitro to use any time. Race a ghost: beat a rival to win its car, " \
					% [TimeTrialCatalog.LAPS, TimeTrialCatalog.CC] + "beat the expert for its signature look.")
		RaceConfig.Mode.ELIMINATION:
			lines.append("ELIMINATION: 3 laps total. At each checkpoint, slower players are knocked out of the "
					+ "race until there is only one victor. Requires NPCs to fill the grid.")
		_:
			if mirrored:
				lines.append("MIRROR: Track direction is reversed.")
			else:
				lines.append("STANDARD: Compete for the fastest time.")
	if not npcs:
		lines.append("NPCs OFF: just the players, no computer cars.")
	return "\n".join(lines)


var mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS
## The track driven in reverse: the Versus Mirror race type (mode stays
## VERSUS) or the Grand Prix Mirror toggle.
var mirrored: bool = false
var vehicle_index: int = 0

var layout: NeonScreenLayout
## Engine class: 50 / 100 / 150 / 200cc (RaceConfig.CC_CLASSES).
var _cc: NeonStepper
## Grand Prix only: Mirror on / off (Versus has it as a race type).
var _mirror: NeonToggle
var _difficulty: NeonStepper
var _laps: NeonStepper
var _laps_row: Control
## Versus only: Standard / Elimination.
var _race_type: NeonStepper
## Versus only: number of races.
var _races: NeonStepper
var _title: Label
var _weapons: NeonToggle
## Your name in races (saved in the profile; empty races as "You").
var name_field: LineEdit
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
		mirrored = bool(GameSession.race_settings.get("gp_mirror", false))
	else:
		mirrored = mode == RaceConfig.Mode.VERSUS and int(GameSession.race_settings.get("race_type", 0)) == MIRROR
	_build()
	UIStyle.fade_in(self)
	_restore()
	_start.grab_focus.call_deferred()


func vehicle() -> VehicleData:
	return VehicleCatalog.all()[vehicle_index]


## Shows car `index`, in the fixed list order (starters first). A locked
## car shows as a mystery ("?", how to unlock it) and can't be raced: Start
## is disabled until you step to a car you own. Only owned cars become the
## selected car.
func select_vehicle(index: int) -> void:
	vehicle_index = posmod(index, VehicleCatalog.all().size())
	var profile := PlayerProfile.get_profile()
	profile.set_selected_vehicle(vehicle().id)
	if showcase != null:
		showcase.set_vehicle(vehicle_index, profile.loadout_for(vehicle().id), profile.plate_text)
	if _start != null:
		_start.disabled = vehicle_locked()


## The car on show hasn't been unlocked yet.
func vehicle_locked() -> bool:
	return not PlayerProfile.get_profile().has_vehicle(vehicle().id)


## The first unlocked car from `index` stepping by `dir` (the default car
## if somehow none is).
static func next_available(index: int, dir: int) -> int:
	var all := VehicleCatalog.all()
	var profile := PlayerProfile.get_profile()
	for k in all.size():
		var i := posmod(index + k * dir, all.size())
		if profile.has_vehicle(all[i].id):
			return i
	return VehicleCatalog.index_of(PlayerProfile.DEFAULT_VEHICLE)


func is_time_trial() -> bool:
	return mode == RaceConfig.Mode.TIME_TRIAL


func difficulty_id() -> String:
	return DIFFICULTIES[_difficulty.selected]


func is_grand_prix() -> bool:
	return mode == RaceConfig.Mode.GRAND_PRIX


## The engine class picked (50 / 100 / 150 / 200).
func cc() -> int:
	if is_time_trial():
		return TimeTrialCatalog.CC
	return RaceConfig.CC_CLASSES[_cc.selected] if _cc != null else RaceConfig.BASE_CC


func set_cc(value: int) -> void:
	_cc.selected = RaceConfig.cc_index(value)
	_cc_changed()


## The CC row moved: the note and the car's top-speed card follow it.
func _cc_changed() -> void:
	if showcase != null:
		showcase.set_cc(cc())
	_update_note()


## Grand Prix: the Mirror toggle.
func set_mirror(on: bool) -> void:
	if not is_grand_prix():
		return
	mirrored = on
	if _mirror.button_pressed != on:
		_mirror.button_pressed = on
	_update_note()


## Versus: races in the set.
func race_count() -> int:
	return RACE_COUNTS[_races.selected] if _races != null else 1


## The race settings (Versus: everything but the track, which the track
## screen adds; Grand Prix: the template the championship is made from).
func make_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.mirrored = mirrored and mode != RaceConfig.Mode.ELIMINATION
	config.cc = cc()
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = _laps.selected + 1
	config.weapons_enabled = _weapons.button_pressed
	config.vehicle_id = vehicle().id
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	config.rival_vehicles = RaceConfig.random_vehicles(7)
	return config


## Grand Prix: on to the cup screen (its START GRAND PRIX begins the
## championship). Versus: on to the track screen. Remembers the choices
## either way.
func start() -> void:
	if vehicle_locked():
		return
	_remember()
	if is_time_trial():
		GameSession.setup_mode = mode
		GameSession.series = null
		GameSession.to_track_select(get_tree())
	elif is_grand_prix():
		GameSession.begin_grand_prix(get_tree(), make_config(), difficulty_id())
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
	# Race settings last until the app closes, then go back to the defaults
	# (GameSession.race_settings). The cup screen keeps the cup in the profile.
	var settings := GameSession.race_settings
	if is_time_trial():
		PlayerProfile.get_profile().save() # nothing to remember but the car
		return
	settings["difficulty"] = _difficulty.selected
	settings["laps"] = _laps.selected
	settings["cc"] = _cc.selected
	if mode != RaceConfig.Mode.GRAND_PRIX:
		settings["race_type"] = race_type_index()
	else:
		settings["gp_mirror"] = mirrored
	settings["weapons"] = _weapons.button_pressed
	if not is_grand_prix():
		settings["races"] = _races.selected
	var profile := PlayerProfile.get_profile()
	var setup := profile.last_setup
	for key in ["difficulty", "laps", "race_type", "weapons", "races"]:
		setup.erase(key)
	profile.last_setup = setup
	profile.save()


func _restore() -> void:
	var profile := PlayerProfile.get_profile()
	var setup := GameSession.race_settings
	_difficulty.selected = clampi(int(setup.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	_laps.selected = clampi(int(setup.get("laps", 2)), 0, 8)
	_weapons.button_pressed = bool(setup.get("weapons", true))
	_cc.selected = clampi(int(setup.get("cc", RaceConfig.DEFAULT_CC_INDEX)), 0, RaceConfig.CC_CLASSES.size() - 1)
	if _mirror != null:
		_mirror.button_pressed = mirrored
	if _races != null:
		_races.selected = clampi(int(setup.get("races", DEFAULT_RACES)), 0, RACE_COUNTS.size() - 1)
	vehicle_index = VehicleCatalog.index_of(profile.selected_vehicle)
	if showcase != null:
		showcase.cc = cc()
	select_vehicle(vehicle_index)
	_update_note()


func _update_note() -> void:
	var lines: PackedStringArray = []
	for line in describe(mode, race_count(), true, mirrored).split("\n"):
		# "STANDARD: pick any ..." -> a gold "Standard:", then the rest.
		var colon := line.find(":")
		if colon > 0 and colon < 24:
			var head := line.substr(0, colon)
			# "STANDARD" -> "Standard".
			head = head.to_lower().capitalize()
			lines.append("[color=#%s]%s:[/color]%s" % [UIStyle.GOLD.to_html(false), head, line.substr(colon + 1)])
		else:
			lines.append(line)
	_note.text = "\n".join(lines)


func _build() -> void:
	# The Race Results style title, centred: GRAND PRIX or VERSUS.
	var heading := "GRAND PRIX" if is_grand_prix() else ("TIME TRIAL" if is_time_trial() else "VERSUS")
	layout = NeonScreenLayout.new(heading, "flags")
	add_child(layout)
	layout.use_results_header()
	_title = layout.title_label
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
		_race_type.selected = race_type_index()
		_race_type.item_selected.connect(set_race_type)
		_add_row(rows, SetupWidgets.setting_row("race_flags", "Race Type", _race_type))
	# Engine class: under Race Type in Versus, first in Grand Prix.
	_cc = NeonStepper.new()
	for c in RaceConfig.CC_CLASSES:
		_cc.add_item(RaceConfig.cc_label(c))
	_cc.item_selected.connect(func(_i: int) -> void: _cc_changed())
	_add_row(rows, SetupWidgets.setting_row("gauge", "CC", _cc))
	if is_grand_prix():
		_mirror = NeonToggle.new()
		_mirror.toggled.connect(set_mirror)
		var mirror_row := SetupWidgets.setting_row("flags", "Mirror", _mirror)
		mirror_row.add_theme_constant_override("margin_right", 14)
		rows.add_child(mirror_row)
	if mode != RaceConfig.Mode.GRAND_PRIX:
		_races = NeonStepper.new()
		for n in RACE_COUNTS:
			_races.add_item("%d Race%s" % [n, "" if n == 1 else "s"])
		_races.item_selected.connect(func(_i: int) -> void: _update_note())
		_add_row(rows, SetupWidgets.setting_row("checker", "Races", _races))
	_difficulty = NeonStepper.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	_add_row(rows, SetupWidgets.setting_row("robot", "NPC Difficulty", _difficulty))
	_laps = NeonStepper.new()
	for i in range(1, 10):
		_laps.add_item(str(i))
	_laps.item_selected.connect(func(_i: int) -> void: _update_note())
	_laps_row = SetupWidgets.setting_row("circuit", "Laps", _laps)
	_laps_row.visible = mode == RaceConfig.Mode.VERSUS
	rows.add_child(_laps_row)
	_weapons = NeonToggle.new()
	var weapons_row := SetupWidgets.setting_row("item_box", "Items", _weapons)
	weapons_row.add_theme_constant_override("margin_right", 14)
	_add_row(rows, weapons_row)
	rows.add_child(_note_box())
	rows.add_child(_name_row())
	_start = SetupWidgets.gold_action("Choose Cup" if is_grand_prix() else "Track Selection", start)
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

	_hints = MenuHints.new([["B", "Esc", "Back"], ["A", "Enter", "Next"],
			["Y", "G", "Garage"]])
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints.offset_right = -24
	_hints.offset_top = -66
	_hints.offset_bottom = -22
	_hints.alignment = BoxContainer.ALIGNMENT_END
	add_child(_hints)
	_link_focus()


## A settings row (hidden in Time Trial, which has no settings).
func _add_row(rows: Container, row: Control) -> void:
	rows.add_child(row)
	row.visible = not is_time_trial()


## Name: a text field styled like the Garage's plate. Saved as you type.
func _name_row() -> Control:
	name_field = LineEdit.new()
	name_field.max_length = PlayerProfile.NAME_MAX
	name_field.text = PlayerProfile.get_profile().player_name
	name_field.placeholder_text = "You"
	name_field.custom_minimum_size = Vector2(230, 40)
	name_field.add_theme_font_size_override("font_size", 22)
	name_field.add_theme_font_override("font", UIStyle.slanted_font(true))
	name_field.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.4))
	for state in ["normal", "focus"]:
		var style := UIStyle.box_style(Color(0.02, 0.01, 0.05, 0.95),
				UIStyle.MAGENTA if state == "focus" else Color(1, 1, 1, 0.6), 8, 2)
		style.set_corner_radius_all(20)
		style.content_margin_left = 16
		name_field.add_theme_stylebox_override(state, style)
	name_field.right_icon = RaceIcons.texture("pencil", 20)
	name_field.text_changed.connect(set_player_name)
	name_field.text_submitted.connect(func(_t: String) -> void: _start.grab_focus())
	var row := SetupWidgets.setting_row("pencil", "Name", name_field)
	row.add_theme_constant_override("margin_right", 14)
	return row


## Saves the name (cleaned up) and keeps the field showing the clean text.
func set_player_name(text: String) -> void:
	var clean := PlayerProfile.sanitize_name(text)
	PlayerProfile.get_profile().set_player_name(clean)
	if name_field.text != clean:
		var caret := name_field.caret_column
		name_field.text = clean
		name_field.caret_column = mini(caret, clean.length())


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
	for c: Control in [_race_type, _cc, _mirror, _races, _difficulty, _laps, _weapons, name_field, _start, layout.back_button]:
		if c != null and (c != _laps or _laps_row.visible):
			if is_time_trial() and not c in [name_field, _start, layout.back_button]:
				continue
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
		if name_field.has_focus():
			_start.grab_focus() # Esc leaves the Name field, not the screen
		else:
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


## "GRAND PRIX  ·  150CC" or "VERSUS  ·  4 RACES  ·  150CC".
func summary_text() -> String:
	var cc_text := RaceConfig.cc_label(cc()).to_upper()
	if is_time_trial():
		return "TIME TRIAL  ·  %d LAPS  ·  %dCC" % [TimeTrialCatalog.LAPS, TimeTrialCatalog.CC]
	if is_grand_prix():
		return "GRAND PRIX  ·  " + cc_text + ("  ·  MIRROR" if mirrored else "")
	var n := race_count()
	return "%s  ·  %d RACE%s  ·  %s" % [RaceConfig.MODE_NAMES[mode].to_upper(), n, "" if n == 1 else "S", cc_text]


## Back: the main menu (Grand Prix and Versus both start here).
func back() -> void:
	GameSession.to_main_menu(get_tree())


## The Race Type stepper's index for the current choice.
func race_type_index() -> int:
	if mode == RaceConfig.Mode.ELIMINATION:
		return 1
	return MIRROR if mirrored else 0


## Versus race type: 0 = Standard, 1 = Elimination, 2 = Mirror.
func set_race_type(index: int) -> void:
	if mode == RaceConfig.Mode.GRAND_PRIX:
		return
	mode = RaceConfig.Mode.ELIMINATION if index == 1 else RaceConfig.Mode.VERSUS
	mirrored = index == MIRROR
	if _race_type.selected != index:
		_race_type.selected = index
	_laps_row.visible = mode == RaceConfig.Mode.VERSUS
	_link_focus()
	_update_note()

