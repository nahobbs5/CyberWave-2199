class_name CupSelect
extends Control
## Grand Prix / Versus, step 1 (Mario Kart style): pick a cup. One big card
## per cup with its trophy, name, races and (Grand Prix) your best finish.
## Locked cups are greyed out ("coming soon"). Grand Prix goes straight to
## the race setup; Versus goes on to pick a track from the cup.

var mode: RaceConfig.Mode = RaceConfig.Mode.GRAND_PRIX
var cups: Array[GrandPrixData] = []
var cards: Array[Button] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	mode = GameSession.setup_mode
	cups = GrandPrixData.all_cups()
	_build()
	UIStyle.fade_in(self)
	var last := str(PlayerProfile.get_profile().last_setup.get("cup", GrandPrixData.CUPS[0]))
	var focus := cards[0]
	for i in cups.size():
		if GrandPrixData.CUPS[i] == last and cups[i].is_open(is_grand_prix()):
			focus = cards[i]
	focus.grab_focus.call_deferred()


func is_grand_prix() -> bool:
	return mode == RaceConfig.Mode.GRAND_PRIX


## Picks cup `index` (ignored for locked cups) and moves on.
func pick(index: int) -> void:
	var cup := cups[index]
	if not cup.is_open(is_grand_prix()):
		return
	GameSession.cup_path = GrandPrixData.CUPS[index]
	var setup := PlayerProfile.get_profile().last_setup
	setup["cup"] = GameSession.cup_path
	if is_grand_prix() and GameSession.split_screen:
		# Split screen: the lobby already has the cars and settings.
		GameSession.start_multiplayer_grand_prix(get_tree(), cup)
	elif is_grand_prix():
		GameSession.track_name = ""
		GameSession.to_race_setup(get_tree(), mode)
	else:
		GameSession.to_track_select(get_tree())


func back() -> void:
	if GameSession.split_screen:
		GameSession.to_mp_setup(get_tree())
	else:
		GameSession.to_main_menu(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


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
	var title := "GRAND PRIX" if is_grand_prix() else RaceConfig.MODE_NAMES[mode].to_upper()
	var coins := UIStyle.header(page, title + "  -  CHOOSE A CUP")
	coins.text = "%d coins" % PlayerProfile.get_profile().coins
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28 if cups.size() <= 3 else 16)
	center.add_child(row)
	for i in cups.size():
		var card := _card(i)
		row.add_child(card)
		cards.append(card)
	for i in cards.size():
		cards[i].focus_neighbor_left = cards[i].get_path_to(cards[(i - 1 + cards.size()) % cards.size()])
		cards[i].focus_neighbor_right = cards[i].get_path_to(cards[(i + 1) % cards.size()])
	var back_button := UIStyle.button("Back", back)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(back_button)


func _card(index: int) -> Button:
	var cup := cups[index]
	var card := UIStyle.button("", pick.bind(index))
	card.name = "Cup%d" % (index + 1)
	# Four or more cups: narrower cards so they still fit at 1280x720.
	var compact := cups.size() > 3
	card.custom_minimum_size = Vector2(380, 430) if not compact else Vector2(284, 410)
	var shut := not cup.is_open(is_grand_prix())
	card.disabled = shut
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var trophy := TrophyIcon.new(cup.emblem, shut, 190.0 if not compact else 160.0)
	trophy.name = "Trophy"
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(trophy)
	var name_label := UIStyle.heading(cup.display_name.to_upper(), 30 if not compact else 23, UIStyle.GOLD if not shut else UIStyle.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	for i in cup.track_names.size():
		var track_open := not shut and (not cup.locked or cup.is_track_built(i))
		var l := UIStyle.stat(cup.track_names[i], 17, Color.WHITE if track_open else UIStyle.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var footer := ""
	if shut:
		footer = "COMING SOON"
	elif cup.locked:
		footer = "More tracks coming soon"
	elif is_grand_prix():
		var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
		footer = "Best finish: %s" % ResultsScreen.ordinal(best) if best > 0 else "Not won yet"
	var foot := UIStyle.stat(footer, 15, UIStyle.CYAN if not shut else UIStyle.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(foot)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
