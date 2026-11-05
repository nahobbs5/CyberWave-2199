class_name ResultsScreen
extends CenterContainer
## End-of-race screen. Mode / track line; a big placement ("1ST PLACE" /
## "VICTORY!"); race time, best lap and coins earned; the full standings with
## your row highlighted (plus championship standings and the next grid in a
## Grand Prix); the coin breakdown and personal bests; Race again / Main menu.
## It animates in (panel, placement, rows one by one, coins counting up);
## Enter / A / a click skips straight to the end.

signal continue_pressed
signal menu_pressed

const ROW_COUNT := 8
const COLUMN_WIDTHS: Array[float] = [44.0, 190.0, 112.0, 92.0]

var race: RaceManager

var panel: PanelContainer
var title: Label
var placement: Label
var subtitle: Label
var time_value: Label
var best_value: Label
var coins_value: Label
var best_banner: Label
var rewards_box: VBoxContainer
var affordable_label: Label
var continue_button: Button
var menu_button: Button
var standings_box: VBoxContainer
var grid_box: VBoxContainer

var _header_cells: Array[Label] = []
var _rows: Array[PanelContainer] = []
var _cells: Array = []
var _championship_grid: GridContainer
var _grid_label: Label
var _rewards_final: String = ""
var _coins_total: int = 0
var _anim: Tween
var _buttons_delay: float = 0.0
var _refresh: float = 0.0


func _init() -> void:
	name = "Results"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func is_animating() -> bool:
	return _anim != null and _anim.is_valid() and _anim.is_running()


## Coin breakdown, total, balance, personal bests and newly affordable items.
func get_rewards_text() -> String:
	return _rewards_final


func get_coins_shown() -> String:
	return coins_value.text


## Shows the results for the player's finish and starts the animation.
func open(manager: RaceManager) -> void:
	race = manager
	var player := race.player
	var c := race.championship
	title.text = context_text()
	var place := player.finish_position
	placement.text = "ELIMINATED" if player.eliminated else "%s PLACE" % ordinal(place)
	subtitle.text = placement_subtitle()
	placement.add_theme_color_override("font_color", UIStyle.DANGER if player.eliminated else (UIStyle.GOLD if place == 1 else UIStyle.MAGENTA))
	time_value.text = ("OUT  LAP %d" % player.eliminated_lap) if player.eliminated else RaceProgress.format_time(player.finish_time)
	best_value.text = RaceProgress.format_time(player.best_lap)
	_fill_rewards()
	if c == null:
		continue_button.text = "Race again"
	elif c.is_complete():
		continue_button.text = "Back to main menu"
	else:
		continue_button.text = "Next race: %s" % c.current_track_name()
	menu_button.visible = c == null or not c.is_complete()
	continue_button.disabled = true
	menu_button.disabled = true
	_buttons_delay = 1.5
	standings_box.visible = c != null
	grid_box.visible = c != null and not c.is_complete()
	_header_cells[3].text = "PTS" if c != null else "BEST LAP"
	refresh()
	visible = true
	_animate_in()


## "VERSUS / TEST CIRCUIT", "ELIMINATION / ...", "AMERICAN CIRCUIT / RACE 2 OF 4 / ...",
## "CHAMPIONSHIP FINAL / AMERICAN CIRCUIT".
func context_text() -> String:
	var c := race.championship
	var track := race.config.track_name.to_upper()
	if c == null:
		return "%s / %s" % [RaceConfig.MODE_NAMES[race.config.mode].to_upper(), track]
	if c.is_complete():
		return "CHAMPIONSHIP FINAL / %s" % c.gp.display_name.to_upper()
	return "%s / RACE %d OF %d / %s" % [c.gp.display_name.to_upper(), c.race_index, c.race_count(), track]


func placement_subtitle() -> String:
	var player := race.player
	var c := race.championship
	if player.eliminated:
		return "KNOCKED OUT ON LAP %d" % player.eliminated_lap
	if c != null and c.is_complete():
		return "CHAMPION!" if c.standings()[0] == RaceConfig.PLAYER_ID else "CHAMPIONSHIP COMPLETE"
	match player.finish_position:
		1:
			return "VICTORY!"
		2, 3:
			return "PODIUM!"
	return "RACE COMPLETE"


static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1:
				suffix = "ST"
			2:
				suffix = "ND"
			3:
				suffix = "RD"
	return "%d%s" % [n, suffix]


func _process(delta: float) -> void:
	if not visible or race == null:
		return
	if _buttons_delay > 0.0:
		_buttons_delay -= delta
		if _buttons_delay <= 0.0:
			continue_button.disabled = false
			menu_button.disabled = false
			continue_button.grab_focus()
	elif get_viewport().gui_get_focus_owner() == null and not get_tree().paused:
		continue_button.grab_focus() # e.g. after closing the pause menu
	# Others may still be finishing (Grand Prix, Elimination): keep the table live.
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		refresh()


func _input(event: InputEvent) -> void:
	if not visible or not is_animating():
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("ui_accept"):
		skip_animation()
		get_viewport().set_input_as_handled()


func skip_animation() -> void:
	if is_animating():
		_anim.custom_step(60.0)


# --- content ----------------------------------------------------------------------

## Updates the standings table (and Grand Prix tables) in place.
func refresh() -> void:
	var c := race.championship
	var standings := race.get_standings()
	for i in _rows.size():
		var row := _rows[i]
		if i >= standings.size():
			row.visible = false
			continue
		row.visible = true
		var racer := standings[i]
		var time_text := "LAP %d" % racer.display_lap()
		if racer.eliminated:
			time_text = "OUT  LAP %d" % racer.eliminated_lap
		elif racer.finished:
			# Classified without crossing the line (GP at your finish, Elimination runner-up).
			time_text = RaceProgress.format_time(racer.finish_time) if racer.finish_time >= 0.0 else "classified"
		var last := RaceProgress.format_time(racer.best_lap)
		if c != null and not c.results.is_empty():
			last = "+%d" % c.points_in_race(c.results.size() - 1, racer.racer_id)
		var cells: Array = _cells[i]
		var texts := [str(racer.position), racer.display_name, time_text, last]
		for k in 4:
			var cell := cells[k] as Label
			cell.text = texts[k]
			cell.add_theme_color_override("font_color", Color.WHITE if racer.is_player else UIStyle.MUTED)
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = Color(UIStyle.MAGENTA, 0.28) if racer.is_player else Color(1, 1, 1, 0.03)
		style.border_color = UIStyle.MAGENTA if racer.is_player else Color(0, 0, 0, 0)
	if c != null:
		_fill_championship(c)
		var lines: PackedStringArray = []
		for i in c.next_grid.size():
			lines.append("%d  %s" % [i + 1, _name_of(c.next_grid[i])])
		_grid_label.text = "\n".join(lines)


func _fill_rewards() -> void:
	for child in rewards_box.get_children():
		child.queue_free()
	var r := race.reward_summary
	var bests: PackedStringArray = []
	if not r.is_empty():
		if r.best_race:
			bests.append("race time")
		if r.best_lap:
			bests.append("lap")
	best_banner.visible = not bests.is_empty()
	best_banner.text = "NEW PERSONAL BEST!  (%s)" % " and ".join(bests) if not bests.is_empty() else ""
	if r.is_empty():
		_coins_total = 0
		coins_value.text = "+0"
		_rewards_final = ""
		affordable_label.text = ""
		return
	_coins_total = r.total
	var lines: PackedStringArray = []
	for line in r.lines:
		_reward_row(str(line[0]), "+%d" % line[1], Color.WHITE)
		lines.append("%s +%d" % [line[0], line[1]])
	if r.lines.is_empty():
		_reward_row("No coins this time", "", UIStyle.MUTED)
	_reward_row("TOTAL", "+%d" % r.total, UIStyle.GOLD)
	_reward_row("BALANCE", str(r.coins_after), UIStyle.MUTED)
	_rewards_final = "COINS  +%d   (%s)   BALANCE %d" % [r.total, "  ".join(lines) if not lines.is_empty() else "none", r.coins_after]
	if not bests.is_empty():
		_rewards_final += "\nNEW PERSONAL BEST: " + " and ".join(bests)
	var affordable: Array = r.affordable
	affordable_label.text = ""
	if not affordable.is_empty():
		var names: PackedStringArray = []
		for item in affordable.slice(0, 3):
			names.append((item as CosmeticItem).display_name)
		affordable_label.text = "Now affordable in the Garage: " + ", ".join(names) + ("..." if affordable.size() > 3 else "")
		_rewards_final += "\n" + affordable_label.text


func _reward_row(what: String, amount: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := UIStyle.stat(what, 16, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UIStyle.heading(amount, 16, color))
	rewards_box.add_child(row)


func _fill_championship(c: Championship) -> void:
	for child in _championship_grid.get_children():
		child.queue_free()
	for header in ["", "STANDINGS", "PTS"]:
		_championship_grid.add_child(UIStyle.stat(header, 15, UIStyle.CYAN))
	var ranking := c.standings()
	for i in ranking.size():
		var id := ranking[i]
		var color := UIStyle.MAGENTA if id == RaceConfig.PLAYER_ID else UIStyle.MUTED
		if i == 0 and c.is_complete():
			color = UIStyle.GOLD
		_championship_grid.add_child(UIStyle.stat(str(i + 1), 16, color))
		_championship_grid.add_child(UIStyle.stat(_name_of(id), 16, color))
		_championship_grid.add_child(UIStyle.heading(str(c.points.get(id, 0)), 15, color))


func _name_of(id: int) -> String:
	for racer in race.racers:
		if racer.racer_id == id:
			return racer.display_name
	return "?"


# --- animation ----------------------------------------------------------------------

func _animate_in() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	var calm := GameSettings.reduced_flashing
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.96
	placement.scale = Vector2.ONE * 1.6
	placement.modulate = Color(2.2, 2.2, 2.2) if not calm else Color.WHITE
	best_banner.modulate.a = 0.0
	for row in _rows:
		row.modulate.a = 0.0
	coins_value.text = "+0"
	_anim = create_tween()
	_anim.set_parallel()
	_anim.tween_property(panel, "modulate:a", 1.0, 0.25)
	_anim.tween_property(panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)
	_anim.tween_property(placement, "scale", Vector2.ONE, 0.35).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(placement, "modulate", Color.WHITE, 0.6).set_delay(0.15)
	for i in _rows.size():
		_anim.tween_property(_rows[i], "modulate:a", 1.0, 0.15).set_delay(0.35 + i * 0.06)
	_anim.tween_method(func(v: int) -> void: coins_value.text = "+%d" % v, 0, _coins_total, 0.8).set_delay(0.4)
	_anim.tween_property(best_banner, "modulate:a", 1.0, 0.2).set_delay(1.0)
	if not calm:
		_anim.tween_property(best_banner, "scale", Vector2.ONE * 1.08, 0.15).set_delay(1.0)
		_anim.tween_property(best_banner, "scale", Vector2.ONE, 0.2).set_delay(1.15)


# --- layout -------------------------------------------------------------------------

func _build() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box_style(Color(0.03, 0.01, 0.07, 0.94), UIStyle.MAGENTA, 20, 2))
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	outer.add_child(columns)

	# Left: placement, stats, rewards.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	title = UIStyle.stat("RESULTS", 16, UIStyle.CYAN)
	left.add_child(title)
	placement = UIStyle.heading("1ST PLACE", 50, UIStyle.MAGENTA)
	placement.add_theme_constant_override("outline_size", 10)
	placement.resized.connect(func() -> void: placement.pivot_offset = placement.size * 0.5)
	left.add_child(placement)
	subtitle = UIStyle.heading("VICTORY!", 22, Color.WHITE)
	left.add_child(subtitle)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	left.add_child(tiles)
	time_value = _tile(tiles, "RACE TIME", Color.WHITE)
	best_value = _tile(tiles, "BEST LAP", UIStyle.CYAN)
	coins_value = _tile(tiles, "COINS", UIStyle.GOLD)
	best_banner = UIStyle.heading("NEW PERSONAL BEST!", 18, UIStyle.GOLD)
	best_banner.resized.connect(func() -> void: best_banner.pivot_offset = best_banner.size * 0.5)
	best_banner.visible = false
	left.add_child(best_banner)
	left.add_child(UIStyle.stat("REWARDS", 15, UIStyle.CYAN))
	rewards_box = VBoxContainer.new()
	rewards_box.add_theme_constant_override("separation", -2)
	left.add_child(rewards_box)
	affordable_label = UIStyle.stat("", 14, UIStyle.MUTED)
	affordable_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	affordable_label.custom_minimum_size = Vector2(300, 0)
	left.add_child(affordable_label)

	# Middle: final standings.
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 2)
	columns.add_child(middle)
	middle.add_child(UIStyle.stat("FINAL STANDINGS", 15, UIStyle.CYAN))
	var header := HBoxContainer.new()
	middle.add_child(header)
	for k in 4:
		var cell := UIStyle.stat(["POS", "RACER", "TIME", "BEST LAP"][k], 14, UIStyle.MUTED)
		cell.custom_minimum_size = Vector2(COLUMN_WIDTHS[k], 0)
		header.add_child(cell)
		_header_cells.append(cell)
	for i in ROW_COUNT:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIStyle.box_style(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 3))
		(row.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 6
		middle.add_child(row)
		var line := HBoxContainer.new()
		row.add_child(line)
		var cells: Array = []
		for k in 4:
			var cell := UIStyle.heading("", 16, UIStyle.MUTED) if k != 1 else UIStyle.stat("", 18, UIStyle.MUTED)
			cell.custom_minimum_size = Vector2(COLUMN_WIDTHS[k], 0)
			line.add_child(cell)
			cells.append(cell)
		_rows.append(row)
		_cells.append(cells)

	# Right (Grand Prix): championship standings and the next grid.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	standings_box = VBoxContainer.new()
	standings_box.visible = false
	right.add_child(standings_box)
	_championship_grid = GridContainer.new()
	_championship_grid.columns = 3
	_championship_grid.add_theme_constant_override("h_separation", 14)
	_championship_grid.add_theme_constant_override("v_separation", -2)
	standings_box.add_child(_championship_grid)
	grid_box = VBoxContainer.new()
	grid_box.visible = false
	right.add_child(grid_box)
	grid_box.add_child(UIStyle.stat("NEXT GRID", 15, UIStyle.CYAN))
	_grid_label = UIStyle.stat("", 15, UIStyle.MUTED)
	grid_box.add_child(_grid_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	outer.add_child(buttons)
	continue_button = UIStyle.primary_button("Race again", func() -> void: continue_pressed.emit())
	menu_button = UIStyle.secondary_button("Main menu", func() -> void: menu_pressed.emit())
	buttons.add_child(continue_button)
	buttons.add_child(menu_button)
	continue_button.focus_neighbor_right = continue_button.get_path_to(menu_button)
	menu_button.focus_neighbor_left = menu_button.get_path_to(continue_button)
	var hint := UIStyle.stat("Enter / A: select    Esc / Start: pause menu", 13, UIStyle.FAINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(hint)


func _tile(parent: Container, caption: String, color: Color) -> Label:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UIStyle.box_style(Color(1, 1, 1, 0.04), Color(color, 0.35), 6))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	tile.add_child(box)
	box.add_child(UIStyle.stat(caption, 13, UIStyle.MUTED))
	var value := UIStyle.heading("", 20, color)
	box.add_child(value)
	return value
