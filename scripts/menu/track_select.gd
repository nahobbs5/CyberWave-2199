class_name TrackSelect
extends Control
## Versus (Mario Kart style): pick a cup, then a race from it. A row of cup
## badges previews each cup's races below; opening one (click, Enter or A)
## moves into its race cards (outline, location and your best time) and
## picking a card races it. The "?" badge opens a RANDOM card that picks a
## built track for you (in a series, one not raced yet while there are any).
## In a series it says which race is next and shows the points so far; the
## screen comes back after each race until the series is done. See CupBoard.

## Every race card, cup by cup (flat), and the track each one races.
var cards: Array[Button] = []
var track_names: PackedStringArray = PackedStringArray()
var random_card: Button
var board: CupBoard

var _title: Label


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	# Start on the cup of the last track raced (else the first cup).
	var last := str(PlayerProfile.get_profile().last_setup.get("track_name", ""))
	var cup := maxi(0, board.cup_of_track(last))
	board.preview(cup)
	board.badges[cup].grab_focus.call_deferred()


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
		if not board.handle_back():
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
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	_title = UIStyle.heading(title_text(), 30, UIStyle.MAGENTA)
	page.add_child(_title)

	board = CupBoard.new()
	board.name = "CupBoard"
	# Points so far, part-way through a series, beside the races.
	var s := GameSession.series
	if s != null and s.race_index > 0:
		var table := UIStyle.section_panel(12)
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
			box.add_child(UIStyle.stat("%d   %s   %d" % [i + 1, _racer_name(s, id), int(s.points.get(id, 0))], 14, color))
		board.side_panel = table
	var cups := GrandPrixData.all_cups()
	var any_built := false
	for cup in cups:
		for i in cup.track_names.size():
			any_built = any_built or cup.is_track_built(i)
	board.setup(cups, false, true, _laps(), "A track you haven't raced yet" if s != null else "Surprise me", any_built)
	board.race_picked.connect(pick_track)
	board.random_picked.connect(pick_random)
	page.add_child(board)
	cards.assign(board.flat_cards)
	track_names = board.flat_tracks
	random_card = board.random_card

	var back_button := UIStyle.button("Quit series" if s != null and s.race_index > 0 else "Back", back)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(back_button)


static func _racer_name(s: Championship, id: int) -> String:
	if RaceConfig.is_human_id(id):
		return "P%d" % (RaceConfig.human_slot(id) + 1) if s.is_multiplayer() else "You"
	return s.rival_names[id] if id < s.rival_names.size() else "Rival %d" % (id + 1)
