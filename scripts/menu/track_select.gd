class_name TrackSelect
extends Control
## Versus: pick a track from every cup on one screen (Mario Kart style).
## One row per cup (trophy and name, then its track cards with outline,
## location and your best time), then a RANDOM card that picks a built
## track for you (in a series, one not raced yet while there are any). In a
## series of races it says which race is next and shows the points so far;
## the screen comes back after each race until the series is done.

## Every track card, cup by cup (flat), and the track each one races.
var cards: Array[Button] = []
var track_names: PackedStringArray = PackedStringArray()
var random_card: Button

var _title: Label


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	var last := str(PlayerProfile.get_profile().last_setup.get("track_name", ""))
	var focus: Button = null
	for i in cards.size():
		if cards[i].disabled:
			continue
		if focus == null or track_names[i] == last:
			focus = cards[i]
	if focus != null:
		focus.grab_focus.call_deferred()


## "VERSUS  -  RACE 2 OF 4" in a series, else "VERSUS  -  CHOOSE A TRACK".
func title_text() -> String:
	var mode := RaceConfig.MODE_NAMES[_mode()].to_upper()
	var s := GameSession.series
	if s != null:
		return "%s  -  RACE %d OF %d" % [mode, s.race_index + 1, s.race_count()]
	return "%s  -  CHOOSE A TRACK" % mode


## Races card `index` (ignored for tracks that aren't built).
func pick(index: int) -> void:
	if index < 0 or index >= cards.size() or cards[index].disabled:
		return
	var track := track_names[index]
	GameSession.track_name = track
	var setup := PlayerProfile.get_profile().last_setup
	setup["track_name"] = track
	GameSession.start_versus_race(get_tree(), track)


## Picks a track by name (tests).
func pick_track(track: String) -> void:
	pick(track_names.find(track))


## A random built track. In a series, tracks already raced are skipped
## until every track has had a turn.
func random_track() -> String:
	var built: PackedStringArray = []
	for i in cards.size():
		if not cards[i].disabled and not built.has(track_names[i]):
			built.append(track_names[i])
	if built.is_empty():
		return ""
	var fresh := built
	if GameSession.series != null:
		var raced := GameSession.series.gp.track_names
		fresh = PackedStringArray(Array(built).filter(func(t: String) -> bool: return not raced.has(t)))
		if fresh.is_empty():
			fresh = built
	return fresh[randi() % fresh.size()]


## RANDOM: races a random track (not remembered as the last pick).
func pick_random() -> void:
	var track := random_track()
	if track == "":
		return
	GameSession.track_name = track
	GameSession.start_versus_race(get_tree(), track)


func back() -> void:
	if GameSession.series != null and GameSession.series.race_index > 0:
		GameSession.to_menu(get_tree()) # quitting a series part-way
	else:
		GameSession.back_from_tracks(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _mode() -> RaceConfig.Mode:
	if GameSession.series != null:
		return GameSession.series.series_mode
	if GameSession.versus_template != null:
		return GameSession.versus_template.mode
	return GameSession.setup_mode


func _laps() -> int:
	return GameSession.versus_template.total_laps if GameSession.versus_template != null else 3


func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	_title = UIStyle.heading(title_text(), 32, UIStyle.MAGENTA)
	page.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 14)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(rows_box)
	var rows: Array = []
	for cup in GrandPrixData.all_cups():
		var row_cards: Array[Button] = []
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		rows_box.add_child(row)
		var badge := VBoxContainer.new()
		badge.custom_minimum_size = Vector2(130, 0)
		badge.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(badge)
		var trophy := TrophyIcon.new(cup.emblem, false, 92.0)
		trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.add_child(trophy)
		var cup_name := UIStyle.heading(cup.display_name.to_upper(), 17, UIStyle.GOLD)
		cup_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(cup_name)
		for i in cup.track_names.size():
			var card := _card(cup, i)
			row.add_child(card)
			cards.append(card)
			row_cards.append(card)
			track_names.append(cup.track_names[i])
		rows.append(row_cards)
	rows.append([_random_row(rows_box)] as Array[Button])
	_link_focus(rows)

	# Points so far, part-way through a series.
	var s := GameSession.series
	if s != null and s.race_index > 0:
		var table := UIStyle.section_panel(12)
		table.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		columns.add_child(table)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		table.add_child(box)
		box.add_child(UIStyle.stat("POINTS", 15, UIStyle.CYAN))
		var ranking := s.standings()
		for i in ranking.size():
			var id := ranking[i]
			var color := UIStyle.MUTED
			if RaceConfig.is_human_id(id):
				color = SplitScreen.PLAYER_COLORS[RaceConfig.human_slot(id)] if s.is_multiplayer() else UIStyle.MAGENTA
			box.add_child(UIStyle.stat("%d   %s   %d" % [i + 1, _racer_name(s, id), int(s.points.get(id, 0))], 15, color))

	var back_button := UIStyle.button("Quit series" if s != null and s.race_index > 0 else "Back", back)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(back_button)


static func _racer_name(s: Championship, id: int) -> String:
	if RaceConfig.is_human_id(id):
		return "P%d" % (RaceConfig.human_slot(id) + 1) if s.is_multiplayer() else "You"
	return s.rival_names[id] if id < s.rival_names.size() else "Rival %d" % (id + 1)


## Left / right wrap within a cup's row; up / down move between cups.
func _link_focus(rows: Array) -> void:
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var card: Button = row[i]
			card.focus_neighbor_left = card.get_path_to(row[(i - 1 + row.size()) % row.size()])
			card.focus_neighbor_right = card.get_path_to(row[(i + 1) % row.size()])
			var up: Array = rows[(r - 1 + rows.size()) % rows.size()]
			var down: Array = rows[(r + 1) % rows.size()]
			card.focus_neighbor_top = card.get_path_to(up[mini(i, up.size() - 1)])
			card.focus_neighbor_bottom = card.get_path_to(down[mini(i, down.size() - 1)])


## The last row: a "?" badge and the RANDOM card.
func _random_row(rows_box: VBoxContainer) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	rows_box.add_child(row)
	var badge := VBoxContainer.new()
	badge.custom_minimum_size = Vector2(130, 0)
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(badge)
	var mark := UIStyle.heading("?", 64, UIStyle.CYAN)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(mark)
	var caption := UIStyle.heading("ANY CUP", 17, UIStyle.GOLD)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(caption)
	random_card = UIStyle.button("", pick_random)
	random_card.name = "Track_Random"
	random_card.custom_minimum_size = Vector2(250, 120)
	random_card.disabled = random_track() == ""
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	random_card.add_child(box)
	var title := UIStyle.heading("RANDOM", 22, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := "A track you haven't raced yet" if GameSession.series != null else "Surprise me"
	var sub := UIStyle.stat(note, 14, UIStyle.CYAN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	for c in box.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(random_card)
	return random_card


func _card(cup: GrandPrixData, index: int) -> Button:
	var track := cup.track_names[index]
	var card := UIStyle.button("", func() -> void: pick_track(track))
	card.name = "Track_%s" % track.replace(" ", "")
	card.custom_minimum_size = Vector2(250, 236)
	card.disabled = not cup.is_track_built(index)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var scene := cup.track_scenes[index] if index < cup.track_scenes.size() else TrackCatalog.scene_path(track)
	var thumb := TrackThumbnail.new(scene, Vector2(220, 128))
	thumb.name = "Thumbnail"
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	var name_label := UIStyle.heading(track.to_upper(), 17, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var where := cup.locations[index] if index < cup.locations.size() else TrackCatalog.location(track)
	var loc := UIStyle.stat(where, 14, UIStyle.MUTED)
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(loc)
	var foot := ""
	if card.disabled:
		foot = "COMING SOON"
	elif not GameSession.split_screen:
		var best := PlayerProfile.get_profile().best_for(track, _laps())
		foot = "Best (%d laps): %s" % [_laps(), RaceProgress.format_time(float(best.race))] if best.has("race") else "No time yet"
	var best_label := UIStyle.stat(foot, 14, UIStyle.CYAN)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best_label)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
