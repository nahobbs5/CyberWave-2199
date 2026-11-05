class_name RaceHUD
extends CanvasLayer
## Race information (GDD 11.5 subset for Phase 2): position, lap, race timer,
## live standings, READY / SET / GO, wrong-way warning and the results screen.
## Speed and drift charge come from PrototypeHUD, which sits underneath.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)

var race: RaceManager

var _position_label: Label
var _lap_label: Label
var _time_label: Label
var _standings_label: Label
var _center_label: Label
var _wrong_way_label: Label
var _results_panel: PanelContainer
var _results_grid: GridContainer
var _center_time: float = 0.0
var _results_refresh: float = 0.0


func _ready() -> void:
	_build()


func setup(manager: RaceManager) -> void:
	race = manager
	race.countdown_tick.connect(_on_countdown_tick)
	race.lap_completed.connect(_on_lap_completed)
	race.player_finished.connect(_on_player_finished)


func is_results_visible() -> bool:
	return _results_panel.visible


func get_center_text() -> String:
	return _center_label.text if _center_label.visible else ""


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	_position_label.text = "POS %d / %d" % [p.position, race.racers.size()]
	_lap_label.text = "LAP %d / %d" % [p.display_lap(), race.total_laps]
	var shown_time := p.finish_time if p.finished else race.race_time
	_time_label.text = "TIME " + RaceProgress.format_time(shown_time)

	var lines: PackedStringArray = []
	for racer in race.get_standings():
		var marker := ">" if racer.is_player else " "
		lines.append("%s%d  %s" % [marker, racer.position, racer.display_name])
	_standings_label.text = "\n".join(lines)

	_wrong_way_label.visible = race.wrong_way
	if _center_time > 0.0:
		_center_time -= delta
		_center_label.visible = _center_time > 0.0

	if _results_panel.visible:
		_results_refresh -= delta
		if _results_refresh <= 0.0:
			_results_refresh = 0.25
			_fill_results()


func _on_countdown_tick(text: String) -> void:
	_show_center(text, 1.0 if text != "GO" else 0.8, CYAN if text != "GO" else MAGENTA)


func _on_lap_completed(racer: RaceProgress) -> void:
	if not racer.is_player or racer.finished:
		return
	var last := racer.lap_times[racer.lap_times.size() - 1]
	var text := "FINAL LAP" if racer.lap == race.total_laps else "LAP %d" % racer.lap
	_show_center("%s\n%s" % [text, RaceProgress.format_time(last)], 1.5, CYAN)


func _on_player_finished(racer: RaceProgress) -> void:
	_show_center("FINISH  P%d" % racer.finish_position, 2.0, MAGENTA)
	_results_panel.visible = true
	_fill_results()


func _show_center(text: String, seconds: float, color: Color) -> void:
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_label.visible = true
	_center_time = seconds


func _fill_results() -> void:
	for child in _results_grid.get_children():
		child.queue_free()
	for header in ["POS", "RACER", "TIME", "BEST LAP"]:
		_results_grid.add_child(_cell(header, CYAN, 16))
	for racer in race.get_standings():
		var color := Color.WHITE if not racer.is_player else MAGENTA
		var time_text := RaceProgress.format_time(racer.finish_time) if racer.finished \
				else "Lap %d" % racer.display_lap()
		_results_grid.add_child(_cell(str(racer.position), color, 18))
		_results_grid.add_child(_cell(racer.display_name, color, 18))
		_results_grid.add_child(_cell(time_text, color, 18))
		_results_grid.add_child(_cell(RaceProgress.format_time(racer.best_lap), color, 18))


# --- layout ----------------------------------------------------------------------

func _build() -> void:
	var info := VBoxContainer.new()
	info.position = Vector2(20, 52)
	add_child(info)
	_position_label = _label(34, Color.WHITE)
	_lap_label = _label(22, CYAN)
	_time_label = _label(22, Color.WHITE)
	_standings_label = _label(15, Color(1, 1, 1, 0.8))
	for label in [_position_label, _lap_label, _time_label, _standings_label]:
		info.add_child(label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stack)
	_center_label = _label(64, CYAN)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.visible = false
	stack.add_child(_center_label)
	_wrong_way_label = _label(40, Color(1.0, 0.25, 0.25))
	_wrong_way_label.text = "WRONG WAY"
	_wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrong_way_label.visible = false
	stack.add_child(_wrong_way_label)

	_results_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.06, 0.88)
	style.border_color = MAGENTA
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(6)
	_results_panel.add_theme_stylebox_override("panel", style)
	_results_panel.visible = false
	stack.add_child(_results_panel)
	var results_box := VBoxContainer.new()
	_results_panel.add_child(results_box)
	var title := _label(28, MAGENTA)
	title.text = "RESULTS"
	results_box.add_child(title)
	_results_grid = GridContainer.new()
	_results_grid.columns = 4
	_results_grid.add_theme_constant_override("h_separation", 28)
	results_box.add_child(_results_grid)
	var hint := _label(15, Color(1, 1, 1, 0.7))
	hint.text = "Enter / gamepad A: race again"
	results_box.add_child(hint)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _cell(text: String, color: Color, size: int) -> Label:
	var label := _label(size, color)
	label.text = text
	return label
