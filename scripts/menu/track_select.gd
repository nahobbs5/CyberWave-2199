class_name TrackSelect
extends Control
## Versus (Mario Kart style): pick a cup, then a race from it. A row of cup
## badges previews each cup's races below; opening one (click, Enter or A)
## moves into its race cards (outline, location and your best time) and
## picking a card races it. The "?" badge opens a RANDOM card that picks a
## built track for you (in a series, one not raced yet while there are any).
## In a series it says which race is next; the
## screen comes back after each race until the series is done. See CupBoard.
## Same neon frame as the Grand Prix cup screen (NeonScreenLayout).
## Time Trial (GDD 2.5): every cup's tracks plus a STRIP card for Vegas
## Overdrive, no RANDOM; each card names the rival car and what you've
## beaten; picking one opens the GhostPicker (Rival / Expert / Your Best /
## No Ghost), which starts the race.

## Every race card, cup by cup (flat), and the track each one races.
var cards: Array[Button] = []
var track_names: PackedStringArray = PackedStringArray()
var random_card: Button
var board: CupBoard
## Time Trial: the ghost choice overlay (null until a track is picked).
var ghost_picker: GhostPicker
var layout: NeonScreenLayout

## The screen title (the mode); the race / "choose a track" line is the
## subtitle under it.
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


## "VERSUS  -  RACE 2 OF 4" in a series, else just "VERSUS" (with the
## engine class when it isn't 100cc: "MIRROR 200CC").
func title_text() -> String:
	if is_time_trial():
		return "TIME TRIAL"
	var mode := RaceConfig.MODE_NAMES[_mode()].to_upper()
	if GameSession.versus_mirrored():
		mode = "MIRROR"
	var cc := GameSession.versus_cc()
	if cc != RaceConfig.BASE_CC:
		mode += " " + RaceConfig.cc_label(cc).to_upper() # "VERSUS 200CC"
	var s := GameSession.series
	if s != null:
		return "%s  -  RACE %d OF %d" % [mode, s.race_index + 1, s.race_count()]
	return mode


## Races card `index` (ignored for tracks that aren't built).
func pick(index: int) -> void:
	if index < 0 or index >= cards.size() or cards[index].disabled:
		return
	var track := track_names[index]
	GameSession.track_name = track
	var setup := PlayerProfile.get_profile().last_setup
	setup["track_name"] = track
	if is_time_trial():
		open_ghost_picker(track)
		return
	GameSession.start_versus_race(get_tree(), track)


## Time Trial: from the setup's Time Trial (not a Versus set, not split screen).
static func is_time_trial() -> bool:
	return GameSession.setup_mode == RaceConfig.Mode.TIME_TRIAL and GameSession.series == null \
			and not GameSession.split_screen


## Time Trial: choose the ghost for `track`.
func open_ghost_picker(track: String) -> GhostPicker:
	if ghost_picker != null:
		ghost_picker.queue_free()
	ghost_picker = GhostPicker.new(track)
	add_child(ghost_picker)
	ghost_picker.closed.connect(func() -> void:
		ghost_picker = null
		var i := track_names.find(track)
		if i >= 0:
			cards[i].grab_focus())
	return ghost_picker


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
		if ghost_picker != null:
			ghost_picker.close()
		elif not board.handle_back():
			back()


func _mode() -> RaceConfig.Mode:
	if is_time_trial():
		return RaceConfig.Mode.TIME_TRIAL
	if GameSession.series != null:
		return GameSession.series.series_mode
	if GameSession.versus_template != null:
		return GameSession.versus_template.mode
	return GameSession.setup_mode


func _laps() -> int:
	if is_time_trial():
		return TimeTrialCatalog.LAPS
	return GameSession.versus_template.total_laps if GameSession.versus_template != null else 3


func _build() -> void:
	var parts := title_text().split("  -  ")
	layout = NeonScreenLayout.new(parts[0], "flags")
	add_child(layout)
	layout.use_results_header()
	_title = layout.title_label
	layout.back_button.pressed.connect(back)
	layout.back_button.focus_mode = Control.FOCUS_NONE
	var s := GameSession.series
	if s != null and s.race_index > 0:
		layout.back_button.text = "Quit series"
	# Mid-series only: "RACE 2 OF 3" under the title.
	if s != null:
		CupSelect.add_subtitle(layout, parts[1])
	if not GameSession.split_screen:
		SetupWidgets.add_coin_pill(self, PlayerProfile.get_profile().coins)

	board = CupBoard.new()
	board.name = "CupBoard"
	var cups := GrandPrixData.all_cups()
	var tt := is_time_trial()
	if tt:
		cups = time_trial_cups()
	var any_built := false
	for cup in cups:
		for i in cup.track_names.size():
			any_built = any_built or cup.is_track_built(i)
	board.setup(cups, false, not tt, _laps(), "Surprise me", any_built)
	board.race_picked.connect(pick_track)
	board.random_picked.connect(pick_random)
	layout.content.add_theme_constant_override("margin_top", 26)
	layout.content.add_child(board)
	cards.assign(board.flat_cards)
	track_names = board.flat_tracks
	random_card = board.random_card

	var hints := MenuHints.new([["A", "Enter", "Select"], ["B", "Esc", "Back"]])
	hints.name = "Hints"
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.offset_right = -24
	hints.offset_top = -66
	hints.offset_bottom = -22
	add_child(hints)



## Time Trial: every cup, keeping only its Time Trial tracks, then a STRIP
## "cup" with the tracks no cup has (Vegas Overdrive).
static func time_trial_cups() -> Array[GrandPrixData]:
	var out: Array[GrandPrixData] = []
	var listed := PackedStringArray()
	for cup in GrandPrixData.all_cups():
		var c := cup.duplicate() as GrandPrixData
		c.track_names = PackedStringArray()
		c.track_scenes = PackedStringArray()
		c.locations = PackedStringArray()
		for i in cup.track_names.size():
			if TimeTrialCatalog.has_track(cup.track_names[i]) and cup.is_track_built(i):
				c.track_names.append(cup.track_names[i])
				c.track_scenes.append(cup.track_scenes[i] if i < cup.track_scenes.size() else "")
				c.locations.append(cup.locations[i] if i < cup.locations.size() else "")
				listed.append(cup.track_names[i])
		c.locked = false
		if not c.track_names.is_empty():
			out.append(c)
	var extra := GrandPrixData.new()
	extra.id = "time_trial_strip"
	extra.display_name = "The Strip"
	extra.emblem = "usa"
	for t in TimeTrialCatalog.tracks():
		if not listed.has(t):
			extra.track_names.append(t)
			extra.track_scenes.append(TrackCatalog.scene_path(t))
			extra.locations.append(TrackCatalog.location(t))
	if not extra.track_names.is_empty():
		out.append(extra)
	return out
