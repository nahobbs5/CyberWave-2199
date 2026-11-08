class_name CupBoard
extends VBoxContainer
## The cup screen's body, Mario Kart style, shared by Grand Prix and Versus:
## a row of cup badges with a panel below that previews the focused cup's
## races (outline, name, location, best time). Opening a cup (click, Enter
## or A on its badge) moves into the panel:
## - Grand Prix: the races are shown, and START GRAND PRIX confirms the cup
##   (missing for a cup that's locked for Grand Prix).
## - Versus: the race cards are buttons; picking one races it. A "?" badge
##   at the end opens a RANDOM card.
## Back from the panel returns to the badges (handle_back()).

signal race_picked(track: String)
signal random_picked
signal confirmed(index: int)

const BADGE_SIDE := 132.0
const CARD_SIZE := Vector2(236, 214)
const THUMB_SIZE := Vector2(208, 108)

var cups: Array[GrandPrixData] = []
var grand_prix: bool = true
var with_random: bool = false
var laps: int = 3
## One button per cup badge (and the Random badge last, in Versus).
var badges: Array[Button] = []
## Race cards per cup (Array of Array[Button]), and every card flat with the
## track it races.
var race_cards: Array = []
var flat_cards: Array[Button] = []
var flat_tracks: PackedStringArray = PackedStringArray()
var confirm_button: Button
var random_card: Button
var selected: int = -1
## Optional control shown at the panel's right (Versus series points).
var side_panel: Control

var _rows: Array[Control] = []
var _badge_art: Array[CupBadge] = []
var _trophy_holder: CenterContainer
var _cup_title: Label
var _cup_info: Label
var _random_note: String = "Surprise me"
var _random_enabled: bool = true


## Builds the board. random_note / random_enabled set up the RANDOM card.
func setup(p_cups: Array[GrandPrixData], p_grand_prix: bool, p_with_random: bool, p_laps: int = 3,
		random_note: String = "Surprise me", random_enabled: bool = true) -> void:
	cups = p_cups
	grand_prix = p_grand_prix
	with_random = p_with_random
	laps = p_laps
	_random_note = random_note
	_random_enabled = random_enabled
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()


func badge_count() -> int:
	return cups.size() + (1 if with_random else 0)


func is_random(index: int) -> bool:
	return with_random and index == cups.size()


## Which cup a track belongs to (-1 if none).
func cup_of_track(track: String) -> int:
	for i in cups.size():
		if cups[i].track_names.has(track):
			return i
	return -1


## Shows cup `index`'s races in the panel (focus stays where it is).
func preview(index: int) -> void:
	if index < 0 or index >= badge_count():
		return
	selected = index
	for i in _badge_art.size():
		_badge_art[i].selected = i == index
	for i in _rows.size():
		_rows[i].visible = i == index
	if confirm_button != null:
		confirm_button.visible = not is_random(index)
		confirm_button.disabled = is_random(index) or not cups[index].is_open(true)
	for c in _trophy_holder.get_children():
		_trophy_holder.remove_child(c)
		c.queue_free()
	if is_random(index):
		_trophy_holder.add_child(CupBadge.new("random", false, 74.0))
		_cup_title.text = "RANDOM"
		_cup_info.text = "Any track from any cup"
	else:
		var cup := cups[index]
		var shut := not cup.is_open(grand_prix)
		var trophy := TrophyIcon.new(cup.emblem, shut, 74.0)
		trophy.name = "Trophy"
		_trophy_holder.add_child(trophy)
		_cup_title.text = cup.display_name.to_upper()
		if grand_prix and shut:
			_cup_info.text = "COMING SOON  -  more tracks to build"
		elif grand_prix:
			var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
			_cup_info.text = "%d races   Best finish: %s" % [cup.race_count(), ResultsScreen.ordinal(best) if best > 0 else "not won yet"]
		elif cup.locked:
			_cup_info.text = "More tracks coming soon"
		else:
			_cup_info.text = "%d races" % cup.race_count()
	_link_focus()


## Opens cup `index`: previews it and moves focus into the panel.
func open(index: int) -> void:
	preview(index)
	var target := first_panel_focus()
	if target != null:
		target.grab_focus()


## The control focus goes to when a cup is opened (null if none).
func first_panel_focus() -> Control:
	if selected < 0:
		return null
	if is_random(selected):
		return random_card if not random_card.disabled else null
	if grand_prix:
		return confirm_button if not confirm_button.disabled else null
	for card: Button in race_cards[selected]:
		if not card.disabled:
			return card
	return null


## Back pressed: from inside the panel, return to the badges (true). From
## the badges, false (the screen goes back).
func handle_back() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and selected >= 0 and not badges.has(focused) and is_ancestor_of(focused):
		badges[selected].grab_focus()
		return true
	return false


func _build() -> void:
	# The badges.
	var badge_row := HBoxContainer.new()
	badge_row.name = "Badges"
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 22)
	add_child(badge_row)
	for i in badge_count():
		var b := _badge(i)
		badge_row.add_child(b)
		badges.append(b)
	for i in badges.size():
		badges[i].focus_neighbor_left = badges[i].get_path_to(badges[(i - 1 + badges.size()) % badges.size()])
		badges[i].focus_neighbor_right = badges[i].get_path_to(badges[(i + 1) % badges.size()])

	# The panel: header (trophy, name, info), the races, confirm / side panel.
	var panel := UIStyle.section_panel(14)
	panel.name = "CupPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	panel.add_child(columns)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	columns.add_child(main)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	main.add_child(head)
	_trophy_holder = CenterContainer.new()
	_trophy_holder.custom_minimum_size = Vector2(78, 78)
	head.add_child(_trophy_holder)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_cup_title = UIStyle.heading("", 28, UIStyle.GOLD)
	titles.add_child(_cup_title)
	_cup_info = UIStyle.stat("", 16, UIStyle.CYAN)
	titles.add_child(_cup_info)
	if grand_prix:
		confirm_button = UIStyle.button("START GRAND PRIX", func() -> void: confirmed.emit(selected))
		confirm_button.name = "Confirm"
		confirm_button.custom_minimum_size = Vector2(260, 64)
		confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(confirm_button)
	var rows_holder := VBoxContainer.new()
	main.add_child(rows_holder)
	for i in cups.size():
		var row := HBoxContainer.new()
		row.name = "Races_%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		row.visible = false
		rows_holder.add_child(row)
		_rows.append(row)
		var list: Array[Button] = []
		for t in cups[i].track_names.size():
			var card := _race_card(cups[i], t)
			row.add_child(card)
			list.append(card)
			flat_cards.append(card)
			flat_tracks.append(cups[i].track_names[t])
		race_cards.append(list)
	if with_random:
		var row := HBoxContainer.new()
		row.name = "Races_random"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.visible = false
		rows_holder.add_child(row)
		_rows.append(row)
		random_card = _random_card()
		row.add_child(random_card)
		race_cards.append([random_card] as Array[Button])
	if side_panel != null:
		side_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		columns.add_child(side_panel)


func _badge(index: int) -> Button:
	var random := is_random(index)
	var b := Button.new()
	b.name = "Badge_random" if random else "Cup%d" % (index + 1)
	b.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(BADGE_SIDE + 34.0, BADGE_SIDE + 34.0)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var shut := not random and not cups[index].is_open(grand_prix)
	var art := CupBadge.new("random" if random else cups[index].emblem, shut, BADGE_SIDE)
	art.name = "Badge"
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	_badge_art.append(art)
	var label := UIStyle.heading("RANDOM" if random else cups[index].display_name.to_upper().replace(" CUP", ""), 16,
			UIStyle.GOLD if not shut else UIStyle.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	b.focus_entered.connect(preview.bind(index))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(open.bind(index))
	return b


## Left / right within the open cup's races; up goes back to its badge, and
## down from a badge goes into its panel.
func _link_focus() -> void:
	if selected < 0:
		return
	var badge := badges[selected]
	var target := first_panel_focus()
	for b in badges:
		b.focus_neighbor_bottom = b.get_path_to(target) if target != null and b == badge else NodePath()
	var row: Array = race_cards[selected] if not grand_prix or is_random(selected) else []
	var focusable: Array = row.filter(func(c: Button) -> bool: return not c.disabled)
	if grand_prix and confirm_button != null:
		focusable = [confirm_button] if not confirm_button.disabled else []
	for i in focusable.size():
		var c: Control = focusable[i]
		c.focus_neighbor_left = c.get_path_to(focusable[(i - 1 + focusable.size()) % focusable.size()])
		c.focus_neighbor_right = c.get_path_to(focusable[(i + 1) % focusable.size()])
		c.focus_neighbor_top = c.get_path_to(badge)
		c.focus_neighbor_bottom = c.get_path_to(badge)


func _race_card(cup: GrandPrixData, index: int) -> Button:
	var track := cup.track_names[index]
	var card := UIStyle.button("", func() -> void: race_picked.emit(track))
	card.name = "Track_%s" % track.replace(" ", "")
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not cup.is_track_built(index)
	if grand_prix:
		# Shown, not picked: Grand Prix races the whole cup.
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var number := UIStyle.stat("RACE %d" % (index + 1), 13, UIStyle.MAGENTA)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(number)
	var scene := cup.track_scenes[index] if index < cup.track_scenes.size() else TrackCatalog.scene_path(track)
	var thumb := TrackThumbnail.new(scene, THUMB_SIZE)
	thumb.name = "Thumbnail"
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	var name_label := UIStyle.heading(track.to_upper() if not card.disabled else "COMING SOON", 16, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var where := cup.locations[index] if index < cup.locations.size() else TrackCatalog.location(track)
	var loc := UIStyle.stat(where, 13, UIStyle.MUTED)
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(loc)
	var foot := ""
	if card.disabled:
		foot = "Still being built"
	elif not GameSession.split_screen:
		var best := PlayerProfile.get_profile().best_for(track, laps)
		foot = "Best (%d laps): %s" % [laps, RaceProgress.format_time(float(best.race))] if best.has("race") else "No time yet"
	var best_label := UIStyle.stat(foot, 13, UIStyle.CYAN)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best_label)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _random_card() -> Button:
	var card := UIStyle.button("", func() -> void: random_picked.emit())
	card.name = "Track_Random"
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not _random_enabled
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var art := CupBadge.new("random", false, 96.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var title := UIStyle.heading("RANDOM", 22, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UIStyle.stat(_random_note, 14, UIStyle.CYAN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	for c in box.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
