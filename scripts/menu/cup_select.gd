class_name CupSelect
extends Control
## Grand Prix, step 1 (Mario Kart style): a row of cup cards. Moving across
## them previews each cup's races below; opening one (click, Enter or A)
## shows its races and START GRAND PRIX to confirm. Cups locked for Grand
## Prix say "coming soon" and can't be confirmed. Confirming goes to the race
## setup (or, in split screen, straight into the Grand Prix). See CupBoard.
## Laid out after "reference files/Cyberwave 2199_ Europe Cup Grand
## Prix.png" on the dimmed 3D street (NeonScreenLayout).

var mode: RaceConfig.Mode = RaceConfig.Mode.GRAND_PRIX
var cups: Array[GrandPrixData] = []
## One badge button per cup.
var cards: Array[Button] = []
var board: CupBoard
var layout: NeonScreenLayout


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	mode = GameSession.setup_mode
	cups = GrandPrixData.all_cups()
	_build()
	UIStyle.fade_in(self)
	var last := str(PlayerProfile.get_profile().last_setup.get("cup", GrandPrixData.CUPS[0]))
	var start := 0
	for i in cups.size():
		if GrandPrixData.CUPS[i] == last and cups[i].is_open(is_grand_prix()):
			start = i
	board.preview(start)
	cards[start].grab_focus.call_deferred()


func is_grand_prix() -> bool:
	return mode == RaceConfig.Mode.GRAND_PRIX


## Opens cup `index` and confirms it (tests and shortcuts; ignored for cups
## that are locked for Grand Prix).
func pick(index: int) -> void:
	board.preview(index)
	confirm()


## Shows cup `index`'s races and moves focus to START GRAND PRIX.
func open(index: int) -> void:
	board.open(index)


## START GRAND PRIX: races the selected cup.
func confirm() -> void:
	var index := board.selected
	if index < 0 or index >= cups.size():
		return
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
		if not board.handle_back():
			back()


func _build() -> void:
	var title := "GRAND PRIX" if is_grand_prix() else RaceConfig.MODE_NAMES[mode].to_upper()
	layout = NeonScreenLayout.new(title, "trophy")
	add_child(layout)
	layout.back_button.pressed.connect(back)
	layout.back_button.focus_mode = Control.FOCUS_NONE
	CupSelect.add_subtitle(layout, "CHOOSE A CUP")
	if not GameSession.split_screen:
		SetupWidgets.add_coin_pill(self, PlayerProfile.get_profile().coins)
	# START GRAND PRIX sits bottom right, level with Back.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	footer.offset_right = -40
	footer.offset_top = -84
	footer.offset_bottom = -18
	add_child(footer)
	board = CupBoard.new()
	board.name = "CupBoard"
	board.footer = footer
	board.setup(cups, true, false)
	board.confirmed.connect(func(_i: int) -> void: confirm())
	layout.content.add_theme_constant_override("margin_top", 26)
	layout.content.add_child(board)
	cards.assign(board.badges)


## A spaced-out magenta subtitle tucked under the screen title ("CHOOSE A
## CUP"), like the Grand Prix mockup.
static func add_subtitle(p_layout: NeonScreenLayout, text: String) -> Label:
	var spaced := ""
	for ch in text:
		spaced += ch + " "
	var sub := UIStyle.stat(spaced.strip_edges(), 20, Color(1, 1, 1, 0.92))
	sub.name = "Subtitle"
	sub.add_theme_font_override("font", UIStyle.slanted_font(true))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(UIStyle.MAGENTA, 0.75)
	bar.skew = Vector2(0.4, 0)
	bar.content_margin_left = 16
	bar.content_margin_right = 30
	sub.add_theme_stylebox_override("normal", bar)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_layout.add_child(sub)
	# Under the title text, once the title row has its size.
	var place := func() -> void:
		var t := p_layout.title_label
		sub.position = t.get_global_rect().position - p_layout.get_global_rect().position + Vector2(6, t.size.y - 2)
	p_layout.title_label.resized.connect(place)
	place.call_deferred()
	return sub
