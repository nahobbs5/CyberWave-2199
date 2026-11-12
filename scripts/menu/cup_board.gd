class_name CupBoard
extends VBoxContainer
## The cup screen's body, Mario Kart style, shared by Grand Prix and Versus,
## laid out after "reference files/Cyberwave 2199_ Europe Cup Grand
## Prix.png": a row of cup cards between gold < > arrows, with a neon panel
## below that previews the focused cup's races (trophy, name, race count and
## best finish, then a TrackCard per race). Opening a cup (click, Enter or A
## on its card) moves into the panel:
## - Grand Prix: the races are shown, and START GRAND PRIX confirms the cup
##   (disabled for a cup that's locked for Grand Prix). The screen places
##   the button: set `footer` before setup(), else it sits in the header.
## - Versus: the race cards are buttons; picking one races it. A "?" card at
##   the end opens a RANDOM card.
## Back from the panel returns to the cups (handle_back()).

signal race_picked(track: String)
signal random_picked
signal confirmed(index: int)

const CARD_HEIGHT := 140.0
const CARD_MAX_WIDTH := 236.0
## Room the row has for cards (between the arrows), at the base 1280 width.
const ROW_WIDTH := 1060.0

var cups: Array[GrandPrixData] = []
var grand_prix: bool = true
var with_random: bool = false
var laps: int = 3
## One button per cup card (and the Random card last, in Versus).
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
## Optional parent for START GRAND PRIX (set before setup()).
var footer: Control
var prev_arrow: Button
var next_arrow: Button

var _rows: Array[Control] = []
var _badge_art: Array[CupBadge] = []
var _trophy_holder: CenterContainer
var _cup_title: Label
var _cup_info: RichTextLabel
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
	add_theme_constant_override("separation", 4)
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
	var cyan := UIStyle.CYAN.to_html(false)
	if is_random(index):
		_trophy_holder.add_child(CupBadge.new("random", false, 84.0))
		_cup_title.text = "RANDOM"
		_cup_info.text = "Any track from any cup"
	else:
		var cup := cups[index]
		var shut := not cup.is_open(grand_prix)
		var trophy := TrophyIcon.new(cup.emblem, shut, 84.0)
		trophy.name = "Trophy"
		_trophy_holder.add_child(trophy)
		_cup_title.text = cup.display_name.to_upper()
		if grand_prix and shut:
			_cup_info.text = "[color=#%s]COMING SOON[/color]   |   More tracks to build" % cyan
		elif grand_prix:
			var best := PlayerProfile.get_profile().best_grand_prix(cup.id)
			_cup_info.text = "%d Races   |   Best Finish: [color=#%s]%s[/color]" % [cup.race_count(), cyan,
					ResultsScreen.ordinal(best) if best > 0 else "Not Won Yet"]
		elif cup.locked:
			_cup_info.text = "%d Races   |   [color=#%s]More tracks coming soon[/color]" % [cup.race_count(), cyan]
		else:
			# Versus, open cup: the race cards say it all.
			_cup_info.text = ""
	_link_focus()


## Opens cup `index`: previews it and moves focus into the panel.
func open(index: int) -> void:
	preview(index)
	var target := first_panel_focus()
	if target != null:
		target.grab_focus()


## The < > arrows: focus (and preview) the next cup along.
func step(delta: int) -> void:
	var i := posmod((selected if selected >= 0 else 0) + delta, badge_count())
	badges[i].grab_focus()
	preview(i)


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


## Back pressed: from inside the panel, return to the cups (true). From the
## cups, false (the screen goes back).
func handle_back() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and selected >= 0 and not badges.has(focused) \
			and (is_ancestor_of(focused) or focused == confirm_button):
		badges[selected].grab_focus()
		return true
	return false


func _build() -> void:
	# The cups, between the arrows.
	var badge_row := HBoxContainer.new()
	badge_row.name = "Badges"
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 14)
	add_child(badge_row)
	prev_arrow = _arrow(-1)
	badge_row.add_child(prev_arrow)
	var n := badge_count()
	var card_w := minf(CARD_MAX_WIDTH, (ROW_WIDTH - 14.0 * (n - 1)) / n)
	for i in n:
		var b := _badge(i, Vector2(card_w, CARD_HEIGHT))
		badge_row.add_child(b)
		badges.append(b)
	next_arrow = _arrow(1)
	badge_row.add_child(next_arrow)
	for i in badges.size():
		badges[i].focus_neighbor_left = badges[i].get_path_to(badges[(i - 1 + badges.size()) % badges.size()])
		badges[i].focus_neighbor_right = badges[i].get_path_to(badges[(i + 1) % badges.size()])

	# The panel: header (trophy, name, info), the races, the side panel.
	var panel := NeonPanel.new(16, UIStyle.CYAN, UIStyle.MAGENTA)
	panel.name = "CupPanel"
	panel.radius = 22.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	panel.add_child(columns)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	columns.add_child(main)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	main.add_child(head)
	_trophy_holder = CenterContainer.new()
	_trophy_holder.custom_minimum_size = Vector2(90, 70)
	head.add_child(_trophy_holder)
	var bar := SetupWidgets.title_bar("", 38)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bar)
	_cup_title = bar.label
	_cup_info = RichTextLabel.new()
	_cup_info.bbcode_enabled = true
	_cup_info.fit_content = true
	_cup_info.scroll_active = false
	_cup_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cup_info.custom_minimum_size = Vector2(380, 0)
	_cup_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cup_info.add_theme_font_override("normal_font", UIStyle.slanted_font(false))
	_cup_info.add_theme_font_size_override("normal_font_size", 22)
	_cup_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 18)
	info_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_margin.add_child(_cup_info)
	head.add_child(info_margin)
	var fade := NeonWidgets.Checker.new(Color(0.35, 0.45, 1.0, 0.45), 2, true)
	fade.custom_minimum_size = Vector2(120, 34)
	fade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(fade)
	if grand_prix:
		confirm_button = SetupWidgets.gold_action("START GRAND PRIX", func() -> void: confirmed.emit(selected))
		confirm_button.name = "Confirm"
		if footer != null:
			confirm_button.custom_minimum_size = Vector2(560, 66)
			footer.add_child(confirm_button)
		else:
			confirm_button.custom_minimum_size = Vector2(380, 60)
			confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(confirm_button)
	var rows_holder := VBoxContainer.new()
	rows_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(rows_holder)
	for i in cups.size():
		var row := HBoxContainer.new()
		row.name = "Races_%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.visible = false
		rows_holder.add_child(row)
		_rows.append(row)
		random_card = TrackCard.random(_random_note, _random_enabled)
		random_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		random_card.custom_minimum_size = Vector2(340, 196)
		random_card.pressed.connect(func() -> void: random_picked.emit())
		row.add_child(random_card)
		race_cards.append([random_card] as Array[Button])
	if side_panel != null:
		var side := NeonPanel.new(12, Color(0.4, 0.5, 1.0), UIStyle.MAGENTA)
		side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		side.add_child(side_panel)
		columns.add_child(side)


func _badge(index: int, card_size: Vector2) -> Button:
	var random := is_random(index)
	var b := Button.new()
	b.name = "Badge_random" if random else "Cup%d" % (index + 1)
	b.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var shut := not random and not cups[index].is_open(grand_prix)
	var title := "RANDOM" if random else cups[index].display_name.to_upper()
	var art := CupBadge.new("random" if random else cups[index].emblem, shut, 0.0, title, card_size)
	art.name = "Badge"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.custom_minimum_size = art.custom_minimum_size
	b.add_child(art)
	_badge_art.append(art)
	b.focus_entered.connect(preview.bind(index))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(open.bind(index))
	return b


func _arrow(direction: int) -> Button:
	var a := CarShowcase._Chevron.new(direction)
	a.gold = true
	a.name = "Prev" if direction < 0 else "Next"
	a.tooltip_text = "Previous cup" if direction < 0 else "Next cup"
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = Vector2(56, CARD_HEIGHT)
	a.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	a.pressed.connect(step.bind(direction))
	return a


## Left / right within the open cup's races; up goes back to its card, and
## down from a card goes into its panel.
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
	var card := TrackCard.for_race(cup, index, not grand_prix, laps)
	var track := cup.track_names[index]
	card.pressed.connect(func() -> void: race_picked.emit(track))
	if grand_prix:
		card.set_display_only()
	return card
