class_name ModeSelect
extends Control
## Placeholder launch screen for Phase 4: pick Versus, a Grand Prix,
## Continue Grand Prix or Elimination, plus the race settings from GDD 2.1.
## The real main menu and race setup replace this in Phase 5. Only one
## track and one vehicle exist so far.

const GRAND_PRIX: Array[String] = [
	"res://resources/grand_prix/american_circuit.tres",
	"res://resources/grand_prix/world_circuit.tres",
]
const ROSTER := "res://resources/racers/rival_roster.tres"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const FREE_DRIVE_SCENE := "res://scenes/free_drive.tscn"

var _difficulty: OptionButton
var _laps: OptionButton
var _weapons: CheckButton
var _continue_button: Button
var _first_button: Button


func _ready() -> void:
	InputSetup.ensure_actions()
	_build()
	_first_button.grab_focus.call_deferred()


func difficulty_id() -> String:
	return DIFFICULTIES[_difficulty.selected]


func make_config(mode: RaceConfig.Mode) -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load(Championship.DIFFICULTY_PATH % difficulty_id()) as AIDifficulty
	config.total_laps = _laps.selected + 1
	config.weapons_enabled = _weapons.button_pressed
	return config


func start_versus() -> void:
	GameSession.start_race(get_tree(), make_config(RaceConfig.Mode.VERSUS))


func start_elimination() -> void:
	GameSession.start_race(get_tree(), make_config(RaceConfig.Mode.ELIMINATION))


## Starts a new championship, replacing any saved one.
func start_grand_prix(index: int) -> void:
	var gp := load(GRAND_PRIX[index]) as GrandPrixData
	var c := Championship.create(gp, difficulty_id(), _weapons.button_pressed, load(ROSTER) as RivalRoster)
	c.save()
	GameSession.start_race(get_tree(), c.make_race_config())


func continue_grand_prix() -> void:
	var c := Championship.load_saved()
	if c != null:
		GameSession.start_race(get_tree(), c.make_race_config())


func has_continue() -> bool:
	return _continue_button.visible


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.015, 0.008, 0.04)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	center.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UIStyle.label("CYBERWAVE 2199", 44, UIStyle.MAGENTA))
	left.add_child(UIStyle.label("Phase 4 mode select (placeholder)", 14, Color(1, 1, 1, 0.5)))
	var saved := Championship.load_saved()
	_continue_button = UIStyle.button("Continue Grand Prix", continue_grand_prix)
	_continue_button.visible = saved != null
	if saved != null:
		_continue_button.text = "Continue Grand Prix: %s, race %d / %d" % [
				saved.gp.display_name.get_slice(" — ", 0), saved.race_index + 1, saved.race_count()]
	var buttons: Array[Button] = [
		_continue_button,
		UIStyle.button("Versus", start_versus),
	]
	for i in GRAND_PRIX.size():
		var gp := load(GRAND_PRIX[i]) as GrandPrixData
		buttons.append(UIStyle.button(gp.display_name, start_grand_prix.bind(i)))
	buttons.append(UIStyle.button("Elimination", start_elimination))
	buttons.append(UIStyle.button("Free drive", func() -> void:
			if GameSession.scene_changes_enabled:
				get_tree().change_scene_to_file(FREE_DRIVE_SCENE)))
	buttons.append(UIStyle.button("Quit", func() -> void: get_tree().quit()))
	for b in buttons:
		b.custom_minimum_size = Vector2(380, 42)
		left.add_child(b)
	_first_button = _continue_button if saved != null else buttons[1]

	var right := UIStyle.panel(UIStyle.CYAN)
	columns.add_child(right)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	right.add_child(settings)
	settings.add_child(UIStyle.label("RACE SETTINGS", 22, UIStyle.CYAN))
	_difficulty = OptionButton.new()
	for d in DIFFICULTIES:
		_difficulty.add_item(d.capitalize())
	_difficulty.selected = 1
	settings.add_child(_row("AI difficulty", _difficulty))
	_laps = OptionButton.new()
	for i in range(1, 10):
		_laps.add_item(str(i))
	_laps.selected = 2
	settings.add_child(_row("Laps (Versus)", _laps))
	_weapons = CheckButton.new()
	_weapons.button_pressed = true
	settings.add_child(_row("Weapons", _weapons))
	var notes := UIStyle.label(
			"Track: Test Circuit (all races until Phase 6)\n" +
			"Vehicle: Placeholder GT\n" +
			"Grand Prix: 3 races, 3 laps each, saved between races.\n" +
			"Starting a new Grand Prix replaces the saved one.\n" +
			"Elimination: always 3 laps; last two are out at\neach lap's midpoint gate.", 13, Color(1, 1, 1, 0.6))
	settings.add_child(notes)


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UIStyle.label(text, 16)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	control.custom_minimum_size = Vector2(130, 0)
	row.add_child(control)
	return row
