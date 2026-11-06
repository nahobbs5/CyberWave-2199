class_name TrackSelect
extends Control
## Versus, step 2: pick one of the chosen cup's tracks. One card per track
## with its outline, name, location and your best time at the lap count you
## used last. Back returns to the cup screen.

var cup: GrandPrixData
var cards: Array[Button] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	cup = GrandPrixData.cup_by_path(GameSession.cup_path)
	if cup == null or cup.locked:
		cup = GrandPrixData.all_cups()[0]
		GameSession.cup_path = GrandPrixData.CUPS[0]
	_build()
	UIStyle.fade_in(self)
	var last := str(PlayerProfile.get_profile().last_setup.get("track_name", ""))
	var focus := cards[0]
	for i in cup.track_names.size():
		if cup.track_names[i] == last:
			focus = cards[i]
	focus.grab_focus.call_deferred()


func pick(index: int) -> void:
	GameSession.track_name = cup.track_names[index]
	var setup := PlayerProfile.get_profile().last_setup
	setup["track_name"] = GameSession.track_name
	GameSession.to_race_setup(get_tree(), GameSession.setup_mode)


func back() -> void:
	GameSession.to_cup_select(get_tree(), GameSession.setup_mode)


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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	page.add_child(head)
	head.add_child(TrophyIcon.new(cup.emblem, false, 56.0))
	var title := UIStyle.heading("%s  -  %s" % [RaceConfig.MODE_NAMES[GameSession.setup_mode].to_upper(), cup.display_name.to_upper()],
			34, UIStyle.MAGENTA)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	page.add_child(UIStyle.stat("CHOOSE A TRACK", 18, UIStyle.CYAN))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	var laps := int(PlayerProfile.get_profile().last_setup.get("laps", 2)) + 1
	for i in cup.track_names.size():
		var card := _card(i, laps)
		row.add_child(card)
		cards.append(card)
	for i in cards.size():
		cards[i].focus_neighbor_left = cards[i].get_path_to(cards[(i - 1 + cards.size()) % cards.size()])
		cards[i].focus_neighbor_right = cards[i].get_path_to(cards[(i + 1) % cards.size()])
	var back_button := UIStyle.button("Back", back)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(back_button)


func _card(index: int, laps: int) -> Button:
	var track := cup.track_names[index]
	var card := UIStyle.button("", pick.bind(index))
	card.name = "Track%d" % (index + 1)
	card.custom_minimum_size = Vector2(340, 340)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var scene := cup.track_scenes[index] if index < cup.track_scenes.size() else TrackCatalog.scene_path(track)
	var thumb := TrackThumbnail.new(scene, Vector2(300, 180))
	thumb.name = "Thumbnail"
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	var name_label := UIStyle.heading(track.to_upper(), 22, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var where := cup.locations[index] if index < cup.locations.size() else TrackCatalog.location(track)
	var loc := UIStyle.stat(where, 15, UIStyle.MUTED)
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(loc)
	var best := PlayerProfile.get_profile().best_for(track, laps)
	var best_text := "Best (%d laps): %s" % [laps, RaceProgress.format_time(float(best.race))] if best.has("race") else "No time yet"
	var best_label := UIStyle.stat(best_text, 15, UIStyle.CYAN)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best_label)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
