class_name PracticeSelect
extends Control
## Practice: pick a track to free drive (TrackCatalog.PRACTICE_TRACKS), one
## TrackCard each, on the same neon frame as the cup / track screens.
## Picking a card opens free drive on it; Back returns to the main menu.

## The first card is focused when the screen opens.
const DEFAULT_TRACK := "Vegas Overdrive"

var cards: Array[TrackCard] = []
var layout: NeonScreenLayout


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.MENU)
	_build()
	UIStyle.fade_in(self)
	var start := maxi(0, track_names().find(DEFAULT_TRACK))
	cards[start].grab_focus.call_deferred()


func track_names() -> PackedStringArray:
	return PackedStringArray(TrackCatalog.PRACTICE_TRACKS)


## Free drives card `index`.
func pick(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	GameSession.to_free_drive(get_tree(), cards[index].track)


## Picks a track by name (tests).
func pick_track(track: String) -> void:
	pick(track_names().find(track))


func back() -> void:
	GameSession.to_main_menu(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## The practice tracks as a cup, so TrackCard.for_race can draw them.
static func practice_cup() -> GrandPrixData:
	var cup := GrandPrixData.new()
	cup.id = "practice"
	cup.display_name = "Practice"
	for track in TrackCatalog.PRACTICE_TRACKS:
		cup.track_names.append(track)
		cup.locations.append(TrackCatalog.location(track))
		cup.track_scenes.append(TrackCatalog.scene_path(track))
	return cup


func _build() -> void:
	layout = NeonScreenLayout.new("PRACTICE", "stopwatch")
	add_child(layout)
	layout.use_results_header()
	layout.back_button.pressed.connect(back)
	layout.back_button.focus_mode = Control.FOCUS_NONE
	CupSelect.add_subtitle(layout, "FREE DRIVE  -  NO RIVALS")
	SetupWidgets.add_coin_pill(self, PlayerProfile.get_profile().coins)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.content.add_theme_constant_override("margin_top", 40)
	layout.content.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Cards"
	row.add_theme_constant_override("separation", 36)
	center.add_child(row)
	var cup := practice_cup()
	for i in cup.track_names.size():
		var card := TrackCard.for_race(cup, i, false, 0)
		card.number = 0 # no race-number tab: these aren't a series
		card.custom_minimum_size = Vector2(460, 300)
		card.pressed.connect(pick.bind(i))
		row.add_child(card)
		cards.append(card)
	for i in cards.size():
		var left := cards[(i - 1 + cards.size()) % cards.size()]
		var right := cards[(i + 1) % cards.size()]
		cards[i].focus_neighbor_left = cards[i].get_path_to(left)
		cards[i].focus_neighbor_right = cards[i].get_path_to(right)
		cards[i].focus_neighbor_top = cards[i].get_path_to(cards[i])
		cards[i].focus_neighbor_bottom = cards[i].get_path_to(cards[i])

	var hints := MenuHints.new([["A", "Enter", "Drive"], ["B", "Esc", "Back"]])
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.offset_right = -24
	hints.offset_top = -66
	hints.offset_bottom = -22
	add_child(hints)
