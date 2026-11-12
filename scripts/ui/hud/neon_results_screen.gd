class_name NeonResultsScreen
extends ResultsScreen
## Single-player results after "reference files/Cyberwave 2199 Race
## Results.png", over the dimmed race: the logo and a slanted RACE RESULTS
## title; a left card with your placement in gold laurels ("P3", "3RD
## PLACE"), your car, the track's picture, name and mode, and YOUR TIME /
## BEST LAP / LAPS / COINS rows (NEW BEST tags, the new coin balance under
## the card); a neon table of every racer (place badge, car picture in their
## paint, name, total time, best lap); RACE AGAIN and MAIN MENU; a hint bar.
## In a Grand Prix or a Versus set it's two pages, as in Mario Kart: the
## race with each racer's +points, then Continue shows the standings (rows
## slide into championship order while the totals count up), and Continue
## again goes on. Split screen keeps the plain ResultsScreen.

const DESIGN := Vector2(1280, 720)
const ROW_H := 44.0
## Table columns: badge, car, name, points, time, best lap (x start, width).
## Standings page: points column = total, time column = this race's gain.
const COLS: Array[Vector2] = [Vector2(0, 74), Vector2(80, 96), Vector2(186, 190), Vector2(376, 100),
		Vector2(476, 140), Vector2(616, 130)]
const SILVER := Color(0.78, 0.82, 0.9)
const BRONZE := Color(0.86, 0.5, 0.28)
const SLATE := Color(0.16, 0.18, 0.26)

## Grand Prix / series: the standings page is showing.
var standings_page: bool = false
## Big "P3" (or "OUT") between the laurels.
var big_place: Label
var mode_label: Label
var track_label: Label
var laps_value: Label
var balance_label: Label
## "Now affordable: ..." under the stat rows (empty when nothing is).
var affordable_note: Label
var lap_best_tag: Label
var time_best_tag: Label
var car_stage: _CarStage
## The stat-row captions / bars the split-screen version relabels or hides.
var time_caption: Label
var coins_row: Control

var _frame: Control
var _players_list: VBoxContainer
## Everything, in 1280x720 design coordinates, centred on _frame.
var _canvas: Control
var _left: NeonPanel
var _table: NeonPanel
var _title_bar: SetupWidgets.SlantBar
var _laurels: _Laurels
var _photo: _Photo
var _row_box: Control
var _row_ids: Array[int] = []
## Seconds into the standings slide (-1 = not sliding).
var _slide: float = -1.0
var _slide_from: Array[int] = []
var _slide_to: Array[int] = []
var _totals_before: Dictionary = {}


# --- open / pages -------------------------------------------------------------------

func open(manager: RaceManager) -> void:
	race = manager
	set_race_sfx_muted(true)
	Music.play(race.get_tree(), music_path())
	standings_page = false
	_slide = -1.0
	var mp := race.is_multiplayer()
	# Split screen: the card is about the best-placed human.
	var player := best_human() if mp else race.player
	var c := race.championship
	title.text = context_text()
	_title_bar.label.text = "RACE RESULTS"
	var place := player.finish_position
	placement.text = "ELIMINATED" if player.eliminated else "%s PLACE" % ordinal(place)
	subtitle.text = placement_subtitle()
	big_place.text = "OUT" if player.eliminated else "P%d" % place
	var ink := UIStyle.DANGER if player.eliminated else (UIStyle.GOLD if place == 1 else Color(1.0, 0.3, 0.9))
	if mp:
		ink = _highlight(player)
		placement.text = "%s  %s" % [player.display_name, "WINS!" if place == 1 else ordinal(place)]
	big_place.add_theme_color_override("font_color", ink)
	# Split screen pays and records nothing: a line per player instead of coins.
	time_caption.text = "TIME" if mp else "YOUR TIME"
	coins_row.visible = not mp
	balance_label.visible = not mp
	affordable_note.visible = not mp
	players_box.visible = mp
	if mp:
		_fill_players()
	_laurels.color = place_color(place) if place <= 3 and not player.eliminated else UIStyle.GOLD
	_laurels.queue_redraw()
	time_value.text = ("OUT  LAP %d" % player.eliminated_lap) if player.eliminated \
			else (RaceProgress.format_time(player.finish_time) if player.finish_time >= 0.0 else "DNF")
	best_value.text = RaceProgress.format_time(player.best_lap)
	laps_value.text = "%d / %d" % [mini(player.lap, race.total_laps) if player.eliminated else race.total_laps, race.total_laps]
	track_label.text = race.config.track_name.to_upper()
	mode_label.text = mode_text()
	var scene_path := race.config.track_scene.resource_path if race.config.track_scene != null else ""
	_photo.set_track(scene_path)
	_fill_rewards()
	_set_continue_text()
	menu_button.visible = c == null or not c.is_complete()
	# Split screen: back to the title screen (home), not car select.
	menu_button.text = "Quit to Home" if mp else "Main menu"
	(menu_button as NeonMenuButton).icon_kind = "home" if mp else "car"
	menu_button.queue_redraw()
	continue_button.disabled = true
	menu_button.disabled = true
	_buttons_delay = 1.5
	_set_columns(false)
	_row_ids.clear()
	for r in race.get_standings():
		_row_ids.append(r.racer_id)
	refresh()
	_request_pictures()
	visible = true
	_animate_in()


## "VERSUS RACE", "ELIMINATION", "GRAND PRIX · RACE 2 OF 3", "VERSUS SET · RACE 2 OF 4".
func mode_text() -> String:
	var c := race.championship
	if c == null:
		return "ELIMINATION" if race.config.mode == RaceConfig.Mode.ELIMINATION else "VERSUS RACE"
	var kind := "%s SET" % RaceConfig.MODE_NAMES[c.series_mode].to_upper() if c.is_series() else c.gp.display_name.to_upper()
	return "%s · RACE %d OF %d" % [kind, c.results.size(), c.race_count()]


func _set_continue_text() -> void:
	var c := race.championship
	if c != null and not standings_page:
		continue_button.text = "Standings"
	elif c == null:
		continue_button.text = "Race again"
	elif c.is_complete():
		continue_button.text = "Back to car select" if race.is_multiplayer() else "Back to main menu"
	else:
		continue_button.text = "Next Race"
	(continue_button as NeonMenuButton).icon_kind = "reset" if c == null else "play"
	continue_button.queue_redraw()


func _on_continue() -> void:
	if race != null and race.championship != null and not standings_page:
		show_standings()
		return
	continue_pressed.emit()


## Grand Prix / series page 2: the totals, rows sliding into championship order.
func show_standings() -> void:
	var c := race.championship
	if c == null or standings_page:
		return
	skip_animation()
	standings_page = true
	_title_bar.label.text = "FINAL STANDINGS" if c.is_complete() else "STANDINGS"
	_set_columns(true)
	_totals_before.clear()
	var last := c.results.size() - 1
	for id in c.points:
		_totals_before[id] = int(c.points[id]) - (c.points_in_race(last, id) if last >= 0 else 0)
	_slide_from = _row_ids.duplicate()
	_slide_to = c.standings()
	_row_ids = _slide_to.duplicate()
	_slide = 0.0
	refresh()
	_set_continue_text()
	menu_button.visible = not c.is_complete()
	continue_button.grab_focus()


func _process(delta: float) -> void:
	super(delta)
	if _slide >= 0.0 and visible:
		_slide += delta
		_layout_rows()
		if _slide >= SLIDE_TIME:
			_slide = -1.0
			refresh()


const SLIDE_TIME := 0.9


func skip_animation() -> void:
	super()
	if _slide >= 0.0:
		_slide = -1.0
		_layout_rows()
		refresh()


func is_animating() -> bool:
	return super() or _slide >= 0.0


func _input(event: InputEvent) -> void:
	if not visible or not is_animating():
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("ui_accept"):
		skip_animation()
		get_viewport().set_input_as_handled()


static func place_color(place: int) -> Color:
	match place:
		1:
			return UIStyle.GOLD
		2:
			return SILVER
		3:
			return BRONZE
	return UIStyle.MAGENTA


# --- content ------------------------------------------------------------------------

func refresh() -> void:
	if race == null:
		return
	var c := race.championship
	var by_id := {}
	for r in race.racers:
		by_id[r.racer_id] = r
	if not standings_page:
		# The race table follows the live order (others may still be finishing).
		_row_ids.clear()
		for r in race.get_standings():
			_row_ids.append(r.racer_id)
	var t := 1.0 if _slide < 0.0 else clampf(_slide / SLIDE_TIME, 0.0, 1.0)
	for i in _rows.size():
		var row := _rows[i] as ResultRow
		if i >= _row_ids.size() or not by_id.has(_row_ids[i]):
			row.visible = false
			continue
		row.visible = true
		var racer: RaceProgress = by_id[_row_ids[i]]
		var cells: Array = _cells[i]
		row.racer_id = racer.racer_id
		row.mine = racer.is_player
		row.fill = _highlight(racer)
		row.accent = racer.color
		row.place = i + 1
		row.picture = CarThumbnails.get_look_texture(racer.racer_id)
		if standings_page and c != null:
			var total := int(c.points.get(racer.racer_id, 0))
			var before := int(_totals_before.get(racer.racer_id, total))
			var shown := roundi(lerpf(before, total, smoothstep(0.3, 1.0, t)))
			var gained := c.points_in_race(c.results.size() - 1, racer.racer_id) if not c.results.is_empty() else 0
			var texts := [str(i + 1), racer.display_name, str(shown), "+%d" % gained, "", ""]
			for k in 5:
				(cells[k] as Label).text = texts[k]
		else:
			var time_text := "LAP %d" % racer.display_lap()
			if racer.eliminated:
				time_text = "OUT  LAP %d" % racer.eliminated_lap
			elif racer.finished:
				time_text = RaceProgress.format_time(racer.finish_time) if racer.finish_time >= 0.0 else "DNF"
			# Points in every race: the cup's record, else what the place is worth
			# (shown once the racer is placed).
			var pts := ""
			if c != null and not c.results.is_empty():
				pts = "+%d" % c.points_in_race(c.results.size() - 1, racer.racer_id)
			elif c == null and (racer.finished or racer.eliminated) and racer.finish_position > 0:
				pts = "+%d" % Championship.points_for(racer.finish_position)
			var texts := [str(racer.position), racer.display_name, pts, time_text, RaceProgress.format_time(racer.best_lap)]
			for k in 5:
				(cells[k] as Label).text = texts[k]
		for k in 5:
			(cells[k] as Label).add_theme_color_override("font_color", Color.WHITE if racer.is_player or k == 0 else Color(0.9, 0.9, 1.0))
		row.queue_redraw()
	if _slide < 0.0:
		_layout_rows()


## Rows at their places (sliding from race order to standings order).
func _layout_rows() -> void:
	var t := 1.0 if _slide < 0.0 else smoothstep(0.0, 1.0, clampf(_slide / SLIDE_TIME, 0.0, 1.0))
	for i in _rows.size():
		var y := i * (ROW_H + 6.0)
		if _slide >= 0.0 and i < _row_ids.size():
			var from := _slide_from.find(_row_ids[i])
			if from >= 0:
				y = lerpf(from * (ROW_H + 6.0), y, t)
		_rows[i].position = Vector2(0, y)


func _fill_rewards() -> void:
	if race.is_multiplayer():
		time_best_tag.visible = false
		lap_best_tag.visible = false
		best_banner.visible = false
		_coins_total = 0
		coins_value.text = "+0"
		_rewards_final = ""
		return
	var r := race.reward_summary
	var race_best := not r.is_empty() and bool(r.best_race)
	var lap_best := not r.is_empty() and bool(r.best_lap)
	time_best_tag.visible = race_best
	lap_best_tag.visible = lap_best
	best_banner.visible = race_best or lap_best
	var bests: PackedStringArray = []
	if race_best:
		bests.append("race time")
	if lap_best:
		bests.append("lap")
	if r.is_empty():
		_coins_total = 0
		coins_value.text = "+0"
		_rewards_final = ""
		balance_label.text = ""
		affordable_note.text = ""
		return
	_coins_total = int(r.total)
	var lines: PackedStringArray = []
	for line in r.lines:
		lines.append("%s +%d" % [line[0], line[1]])
	_rewards_final = "COINS  +%d   (%s)   BALANCE %d" % [r.total, "  ".join(lines) if not lines.is_empty() else "none", r.coins_after]
	if not bests.is_empty():
		_rewards_final += "\nNEW PERSONAL BEST: " + " and ".join(bests)
	balance_label.text = "Balance %s" % _thousands(int(r.coins_after))
	affordable_note.text = ""
	var affordable: Array = r.affordable
	if not affordable.is_empty():
		var names: PackedStringArray = []
		for item in affordable.slice(0, 2):
			names.append((item as CosmeticItem).display_name)
		var more := "..." if affordable.size() > 2 else ""
		affordable_note.text = "Now affordable: " + ", ".join(names) + more
		_rewards_final += "\nNow affordable in the Garage: " + ", ".join(names) + more


## Split screen: one coloured line per player on the card.
func _fill_players() -> void:
	for child in _players_list.get_children():
		_players_list.remove_child(child)
		child.queue_free()
	for p in race.players:
		var time := ("OUT  LAP %d" % p.eliminated_lap) if p.eliminated \
				else (RaceProgress.format_time(p.finish_time) if p.finish_time >= 0.0 else "DNF")
		var place := "OUT" if p.eliminated else ordinal(p.finish_position)
		var line := UIStyle.stat("%s    %s    %s" % [p.display_name, place, time], 17, _highlight(p))
		line.add_theme_font_override("font", UIStyle.slanted_font(true))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_players_list.add_child(line)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _set_columns(totals: bool) -> void:
	var c := race.championship if race != null else null
	var names := ["POS", "", "RACER", "TOTAL PTS", "THIS RACE", ""] if totals \
			else ["POS", "", "RACER", "PTS", "TOTAL TIME", "BEST LAP"]
	for k in _header_cells.size():
		_header_cells[k].text = names[k]
	for row in _rows:
		(row as ResultRow).totals = totals


## Car pictures in each racer's paint (rendered once the screen opens).
func _request_pictures() -> void:
	var looks := {}
	var sizes := {}
	for r in race.racers:
		looks[r.racer_id] = race.racer_look(r.racer_id, r.color)
	var shown := best_human() if race.is_multiplayer() else race.player
	sizes[shown.racer_id] = Vector2i(480, 256)
	car_stage.picture = null
	car_stage.queue_redraw()
	var screen: WeakRef = weakref(self)
	CarThumbnails.request_looks(race.get_tree(), looks, func() -> void:
		var me := screen.get_ref() as NeonResultsScreen
		if me == null or me.race == null:
			return
		var who := me.best_human() if me.race.is_multiplayer() else me.race.player
		me.car_stage.picture = CarThumbnails.get_look_texture(who.racer_id)
		me.car_stage.queue_redraw()
		me.refresh(), sizes)


# --- animation ----------------------------------------------------------------------

func _animate_in() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	var calm := GameSettings.reduced_flashing
	_frame.modulate.a = 0.0
	_left.position.x -= 40.0
	_table.position.x += 40.0
	big_place.scale = Vector2.ONE * 1.7
	big_place.modulate = Color(2.2, 2.2, 2.2) if not calm else Color.WHITE
	best_banner.modulate.a = 0.0
	for row in _rows:
		row.modulate.a = 0.0
	coins_value.text = "+0"
	_anim = create_tween()
	_anim.set_parallel()
	_anim.tween_property(_frame, "modulate:a", 1.0, 0.25)
	_anim.tween_property(_left, "position:x", _left.position.x + 40.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim.tween_property(_table, "position:x", _table.position.x - 40.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim.tween_property(big_place, "scale", Vector2.ONE, 0.4).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(big_place, "modulate", Color.WHITE, 0.6).set_delay(0.15)
	for i in _rows.size():
		_anim.tween_property(_rows[i], "modulate:a", 1.0, 0.15).set_delay(0.35 + i * 0.06)
	_anim.tween_method(func(v: int) -> void: coins_value.text = "+%d" % v, 0, _coins_total, 0.8).set_delay(0.4)
	_anim.tween_property(best_banner, "modulate:a", 1.0, 0.2).set_delay(1.0)
	if not calm:
		_anim.tween_property(best_banner, "scale", Vector2.ONE * 1.12, 0.15).set_delay(1.0)
		_anim.tween_property(best_banner, "scale", Vector2.ONE, 0.2).set_delay(1.15)


# --- layout -------------------------------------------------------------------------

func _draw() -> void:
	# Over the race: a dark navy-to-magenta tint and neon streaks at the edges.
	var r := Rect2(Vector2.ZERO, size)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)])
	var cols := PackedColorArray([Color(0.02, 0.03, 0.12, 0.93), Color(0.08, 0.02, 0.14, 0.9),
			Color(0.12, 0.02, 0.16, 0.93), Color(0.02, 0.04, 0.14, 0.95)])
	draw_polygon(pts, cols)
	for k in 6:
		var y := size.y * (0.12 + k * 0.15)
		var c := UIStyle.CYAN if k % 2 == 0 else UIStyle.MAGENTA
		draw_line(Vector2(0, y), Vector2(size.x * 0.06, y + 30), Color(c, 0.35), 2.0)
		draw_line(Vector2(size.x, y + 20), Vector2(size.x * 0.94, y + 50), Color(c, 0.35), 2.0)


func _build() -> void:
	resized.connect(_fit)
	# The container centres _frame (no minimum size); the design canvas hangs
	# off its centre and _frame scales it to fit the HUD area.
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.position = -DESIGN * 0.5
	_canvas.size = DESIGN
	_frame.add_child(_canvas)
	panel = PanelContainer.new() # unused by this layout (ResultsScreen API)
	panel.visible = false
	_canvas.add_child(panel)
	title = UIStyle.stat("", 14, UIStyle.MUTED)
	title.visible = false
	_canvas.add_child(title)

	# Header: logo, slanted title with checker flags, a neon rule.
	var logo := UIStyle.logo(Vector2(250, 84))
	logo.position = Vector2(34, 12)
	logo.size = Vector2(250, 84)
	_canvas.add_child(logo)
	_title_bar = SetupWidgets.title_bar("RACE RESULTS", 46)
	_title_bar.position = Vector2(690, 24)
	_title_bar.size = Vector2(560, 64)
	_canvas.add_child(_title_bar)
	for side in [0, 1]:
		var flag := NeonWidgets.Checker.new(Color(UIStyle.MAGENTA, 0.9), 2, side == 0)
		flag.position = Vector2(640 if side == 0 else 1196, 40)
		flag.size = Vector2(54, 28)
		_canvas.add_child(flag)
	var rule := _Rule.new()
	rule.position = Vector2(0, 98)
	rule.size = Vector2(DESIGN.x, 6)
	_canvas.add_child(rule)

	_build_left()
	_build_table()

	# Buttons and hints.
	var go := NeonMenuButton.new("Race again", "reset")
	go.font_size = 28
	go.chevrons = false
	go.custom_minimum_size = Vector2(360, 60)
	go.position = Vector2(470, 604)
	go.size = Vector2(360, 60)
	go.pressed.connect(_on_continue)
	_canvas.add_child(go)
	continue_button = go
	var menu := NeonMenuButton.new("Main menu", "car")
	menu.font_size = 28
	menu.chevrons = false
	menu.custom_minimum_size = Vector2(360, 60)
	menu.position = Vector2(866, 604)
	menu.size = Vector2(360, 60)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_canvas.add_child(menu)
	menu_button = menu
	continue_button.focus_neighbor_right = continue_button.get_path_to(menu_button)
	continue_button.focus_neighbor_left = NodePath(".")
	menu_button.focus_neighbor_left = menu_button.get_path_to(continue_button)
	menu_button.focus_neighbor_right = NodePath(".")
	for b in [continue_button, menu_button]:
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")
	var hints := MenuHints.new([["A", "Enter", "Confirm"], ["Start", "Esc", "Pause"]])
	hints.position = Vector2(560, 676)
	hints.scale = Vector2.ONE * 0.8
	_canvas.add_child(hints)

	# Kept for the ResultsScreen API (split-screen parts this layout doesn't show).
	_tiles = HBoxContainer.new()
	_rewards_caption = Label.new()
	rewards_box = VBoxContainer.new()
	affordable_label = Label.new()
	standings_box = VBoxContainer.new()
	grid_box = VBoxContainer.new()
	_championship_grid = GridContainer.new()
	_grid_label = Label.new()
	# The left card's player list stands in for the plain screen's players_box.
	players_box = _players_list
	for n in [_tiles, _rewards_caption, rewards_box, affordable_label, standings_box, grid_box,
			_championship_grid, _grid_label]:
		(n as Control).visible = false
		_canvas.add_child(n)


func _fit() -> void:
	queue_redraw()
	if _frame != null and size.x > 0.0:
		_frame.scale = Vector2.ONE * minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _build_left() -> void:
	_left = NeonPanel.new(16, UIStyle.MAGENTA, UIStyle.CYAN)
	_left.position = Vector2(34, 112)
	_left.size = Vector2(390, 596)
	_left.custom_minimum_size = Vector2(390, 596)
	_canvas.add_child(_left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_left.add_child(box)

	# Placement in laurels.
	_laurels = _Laurels.new()
	_laurels.custom_minimum_size = Vector2(0, 104)
	box.add_child(_laurels)
	big_place = UIStyle.heading("P1", 80, UIStyle.GOLD)
	big_place.add_theme_font_override("font", UIStyle.slanted_font(true))
	big_place.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2, 0.95))
	big_place.add_theme_constant_override("outline_size", 12)
	big_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_place.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_place.resized.connect(func() -> void: big_place.pivot_offset = big_place.size * 0.5)
	_laurels.add_child(big_place)
	placement = UIStyle.heading("1ST PLACE", 34, Color.WHITE)
	placement.add_theme_font_override("font", UIStyle.slanted_font(true))
	placement.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.15, 0.9))
	placement.add_theme_constant_override("outline_size", 6)
	placement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(placement)
	subtitle = UIStyle.stat("VICTORY!", 17, UIStyle.GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	car_stage = _CarStage.new()
	car_stage.custom_minimum_size = Vector2(0, 100)
	box.add_child(car_stage)

	# Track picture, name and mode.
	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 12)
	box.add_child(track_row)
	_photo = _Photo.new()
	_photo.custom_minimum_size = Vector2(150, 84)
	track_row.add_child(_photo)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_row.add_child(words)
	track_label = UIStyle.stat("", 22, Color.WHITE)
	track_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	track_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_label.custom_minimum_size = Vector2(190, 0)
	words.add_child(track_label)
	mode_label = UIStyle.stat("", 15, UIStyle.CYAN)
	mode_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(mode_label)

	# Stat rows.
	var t := _stat_row(box, "stopwatch", "YOUR TIME", UIStyle.CYAN)
	time_value = t[0]
	time_best_tag = t[1]
	time_caption = (t[0] as Label).get_parent().get_child(1) as Label
	var b := _stat_row(box, "trophy", "BEST LAP", UIStyle.CYAN)
	best_value = b[0]
	lap_best_tag = b[1]
	laps_value = _stat_row(box, "flags", "LAPS", Color.WHITE)[0]
	var coins := _stat_row(box, "coin", "COINS", UIStyle.GOLD)
	coins_value = coins[0]
	coins_row = (coins[0] as Label).get_parent().get_parent() as Control
	# Split screen: "P1   3RD   2:31.40" per player where the coins go.
	_players_list = VBoxContainer.new()
	_players_list.add_theme_constant_override("separation", 0)
	_players_list.visible = false
	box.add_child(_players_list)
	balance_label = UIStyle.stat("", 14, UIStyle.MUTED)
	balance_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(coins[1] as Label).get_parent().add_child(balance_label)
	(coins[1] as Label).get_parent().move_child(balance_label, (coins[1] as Label).get_index())
	# best_banner: shows when either row has a NEW BEST tag (pops on arrival).
	best_banner = UIStyle.stat("NEW PERSONAL BEST!", 14, UIStyle.GOLD)
	best_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_banner.resized.connect(func() -> void: best_banner.pivot_offset = best_banner.size * 0.5)
	box.add_child(best_banner)
	affordable_note = UIStyle.stat("", 13, UIStyle.MUTED)
	affordable_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	affordable_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	affordable_note.custom_minimum_size = Vector2(340, 0)
	box.add_child(affordable_note)


## A stat row: [value label, NEW BEST tag].
func _stat_row(parent: Container, icon_kind: String, caption: String, color: Color) -> Array:
	var row := _StatBar.new()
	row.custom_minimum_size = Vector2(0, 38)
	parent.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 18
	line.offset_right = -14
	row.add_child(line)
	var icon := TextureRect.new()
	icon.texture = UIStyle.coin_texture() if icon_kind == "coin" else UIStyle.cached_icon(icon_kind, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var cap := UIStyle.stat(caption, 17, Color.WHITE)
	cap.add_theme_font_override("font", UIStyle.slanted_font(false))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cap)
	var tag := UIStyle.label("NEW BEST", 13, Color(0.12, 0.05, 0.0))
	tag.add_theme_constant_override("outline_size", 0)
	var tag_style := UIStyle.box_style(UIStyle.GOLD, UIStyle.GOLD, 2)
	tag_style.content_margin_left = 6
	tag_style.content_margin_right = 6
	tag.add_theme_stylebox_override("normal", tag_style)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.visible = false
	line.add_child(tag)
	var value := UIStyle.heading("", 24, color)
	value.add_theme_font_override("font", UIStyle.slanted_font(true))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(value)
	return [value, tag]


func _build_table() -> void:
	_table = NeonPanel.new(18, UIStyle.MAGENTA, UIStyle.CYAN)
	_table.position = Vector2(450, 116)
	_table.size = Vector2(800, 468)
	_table.custom_minimum_size = Vector2(800, 468)
	_canvas.add_child(_table)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_table.add_child(box)
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, 30)
	box.add_child(header)
	for k in 6:
		var cell := UIStyle.stat("", 17, Color(0.85, 0.9, 1.0))
		cell.add_theme_font_override("font", UIStyle.slanted_font(false))
		cell.position = Vector2(COLS[k].x + (10.0 if k == 0 else 0.0), 2)
		cell.size = Vector2(COLS[k].y, 26)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if k < 3 else HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(cell)
		_header_cells.append(cell)
	var under := _Rule.new()
	under.custom_minimum_size = Vector2(0, 3)
	box.add_child(under)
	_row_box = Control.new()
	_row_box.custom_minimum_size = Vector2(764, ROW_COUNT * (ROW_H + 6.0))
	box.add_child(_row_box)
	for i in ROW_COUNT:
		var row := ResultRow.new()
		row.position = Vector2(0, i * (ROW_H + 6.0))
		row.size = Vector2(764, ROW_H)
		_row_box.add_child(row)
		# A plain Control: the row (a PanelContainer) would stretch labels over it.
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		var cells: Array = []
		for k in 5:
			var cell: Label
			if k == 0:
				cell = UIStyle.heading("", 24, Color.WHITE)
				cell.add_theme_font_override("font", UIStyle.slanted_font(true))
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elif k == 1:
				cell = UIStyle.stat("", 22, Color.WHITE)
				cell.add_theme_font_override("font", UIStyle.slanted_font(true))
			else:
				cell = UIStyle.heading("", 21, Color.WHITE)
				cell.add_theme_font_override("font", UIStyle.slanted_font(true))
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var col: Vector2 = COLS[0] if k == 0 else COLS[k + 1]
			cell.position = Vector2(col.x, 0)
			cell.size = Vector2(col.y, ROW_H)
			cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1, 0.8))
			cell.add_theme_constant_override("outline_size", 4)
			holder.add_child(cell)
			cells.append(cell)
		_rows.append(row)
		_cells.append(cells)


# --- drawn parts --------------------------------------------------------------------

## One table row: slanted bar, place badge, car picture. Labels on top.
class ResultRow extends PanelContainer:
	var racer_id: int = 0
	var place: int = 1
	## A human's row: filled with `fill` (magenta; split screen: their player colour).
	var mine: bool = false
	var fill: Color = UIStyle.MAGENTA
	var accent: Color = Color.WHITE
	var picture: Texture2D
	## Standings page: no car picture column shift.
	var totals: bool = false

	func _init() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var s := h * 0.32
		var bar := PackedVector2Array([Vector2(s + 8, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(8, h)])
		var fill_l := Color(fill.darkened(0.05), 0.95) if mine else Color(0.1, 0.1, 0.2, 0.86)
		var fill_r := Color(fill.darkened(0.35), 0.95) if mine else Color(0.06, 0.06, 0.14, 0.86)
		draw_polygon(bar, PackedColorArray([fill_l, fill_r, fill_r, fill_l]))
		var outline := bar.duplicate()
		outline.append(bar[0])
		var edge := fill.lightened(0.5) if mine else Color(accent, 0.35)
		if mine:
			draw_polyline(outline, Color(fill, 0.35), 8.0, true)
		draw_polyline(outline, edge, 2.0 if mine else 1.2, true)
		# Place badge.
		var bw := 66.0
		var badge := PackedVector2Array([Vector2(s, 0), Vector2(bw + s, 0), Vector2(bw, h), Vector2(0, h)])
		var c := NeonResultsScreen.place_color(place) if place <= 3 else NeonResultsScreen.SLATE
		draw_polygon(badge, PackedColorArray([c.lightened(0.25), c, c.darkened(0.25), c]))
		var bo := badge.duplicate()
		bo.append(badge[0])
		draw_polyline(bo, Color(1, 1, 1, 0.35), 1.2, true)
		# Car picture (cropped to the middle of the render).
		if picture != null:
			var col: Vector2 = NeonResultsScreen.COLS[1]
			var tex := picture.get_size()
			var src := Rect2(tex.x * 0.08, tex.y * 0.18, tex.x * 0.84, tex.y * 0.64)
			var dh := h - 4.0
			var dw := minf(col.y, dh * src.size.x / src.size.y)
			draw_texture_rect_region(picture, Rect2(Vector2(col.x + (col.y - dw) * 0.5, 2), Vector2(dw, dh)), src)


## Gold laurels behind the big placement.
class _Laurels extends Control:
	var color: Color = UIStyle.GOLD

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var tex := RaceIcons.texture("laurel", int(h))
		var w := h * 1.9
		draw_texture_rect(tex, Rect2(Vector2((size.x - w) * 0.5, 0), Vector2(w, h)), false, color)


## Your car on a slanted neon backdrop (a silhouette until its picture is rendered).
class _CarStage extends Control:
	var picture: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for k in 4:
			var x := w * (0.05 + k * 0.08)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 30, 6), Vector2(x + 44, 6), Vector2(x + 14, h * 0.5),
					Vector2(x, h * 0.5)]), Color(UIStyle.MAGENTA, 0.5 - k * 0.1))
		# Floor glow.
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, h - 8), Vector2(w * 0.9, h - 8), Vector2(w * 0.75, h),
				Vector2(w * 0.25, h)]), Color(UIStyle.MAGENTA, 0.35))
		if picture != null:
			var tex := picture.get_size()
			var src := Rect2(tex.x * 0.05, tex.y * 0.1, tex.x * 0.9, tex.y * 0.8)
			var dh := h
			var dw := minf(w, dh * src.size.x / src.size.y)
			draw_texture_rect_region(picture, Rect2(Vector2((w - dw) * 0.5, 0), Vector2(dw, dh)), src)
			return
		# Silhouette: a low wedge with wheel arches.
		var cx := w * 0.5
		var body := PackedVector2Array([Vector2(cx - 120, h - 26), Vector2(cx - 100, h - 52), Vector2(cx - 30, h - 72),
				Vector2(cx + 50, h - 70), Vector2(cx + 120, h - 44), Vector2(cx + 125, h - 26)])
		draw_colored_polygon(body, Color(0.08, 0.04, 0.16, 0.95))
		draw_polyline(body + PackedVector2Array([body[0]]), Color(UIStyle.MAGENTA, 0.8), 2.0, true)
		for x in [cx - 72, cx + 78]:
			draw_circle(Vector2(x, h - 24), 15, Color(0.03, 0.02, 0.06))
			draw_arc(Vector2(x, h - 24), 15, 0, TAU, 20, Color(UIStyle.CYAN, 0.7), 2.0, true)


## The track's photo (cover-cropped, framed), or its outline when there's none.
class _Photo extends Control:
	var texture: Texture2D
	var outline: TrackThumbnail

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_track(scene_path: String) -> void:
		if outline != null:
			outline.queue_free()
			outline = null
		var path := TrackCard.photo_path(scene_path) if scene_path != "" else ""
		texture = load(path) as Texture2D if path != "" else null
		if texture == null and scene_path != "":
			outline = TrackThumbnail.new(scene_path, custom_minimum_size)
			outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(outline)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(NeonPanel.rounded_rect(r, 8.0), Color(0.08, 0.04, 0.18, 0.95))
		if texture != null:
			var ts := texture.get_size()
			var want := size.x / size.y
			var src := Rect2(Vector2.ZERO, ts)
			if ts.x / ts.y > want:
				src.size.x = ts.y * want
				src.position.x = (ts.x - src.size.x) * 0.5
			else:
				src.size.y = ts.x / want
				src.position.y = (ts.y - src.size.y) * 0.5
			draw_texture_rect_region(texture, r.grow(-2), src)
		var pts := NeonPanel.rounded_rect(r, 8.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.75, 0.85, 1.0, 0.9), 2.0, true)


## A slanted dark bar behind a stat row.
class _StatBar extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.3
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h)])
		draw_polygon(pts, PackedColorArray([Color(0.1, 0.08, 0.22, 0.9), Color(0.05, 0.04, 0.12, 0.9),
				Color(0.05, 0.04, 0.12, 0.9), Color(0.1, 0.08, 0.22, 0.9)]))
		draw_line(Vector2(s, 0.5), Vector2(size.x, 0.5), Color(0.6, 0.7, 1.0, 0.35), 1.0)


## A thin neon line fading out at both ends.
class _Rule extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y * 0.5
		var n := 24
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var a := sin(PI * (t0 + t1) * 0.5)
			draw_line(Vector2(size.x * t0, y), Vector2(size.x * t1, y),
					Color(UIStyle.CYAN.lerp(UIStyle.MAGENTA, t0), 0.8 * a), 2.0)
