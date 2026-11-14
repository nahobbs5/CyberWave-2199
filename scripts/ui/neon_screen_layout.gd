class_name NeonScreenLayout
extends Control
## Shared frame of the Settings and Credits screens ("reference files/
## Cyberwave 2199 Neon Settings Interface.png" and "... Neon Credits.png"):
## the start menus' live MenuStreetScene, dimmed, behind everything; a title
## row (logo / icon TITLE and a magenta checker strip); a slanted Back button
## bottom left; and `content` in between for the screen's own panels.
##
## Usage: new(title, icon_kind), add_child, fill `content`, connect
## `back_button.pressed`.
## The setup screens, Settings and the Garage use the results header instead:
## the Race Results look (logo, a slanted title bar with checker flags each
## side, centred, and a neon rule under the header).

var street: MenuStreetScene
## Fill this with the screen's panels.
var content: MarginContainer
var back_button: NeonMenuButton
var title_label: Label
## True after use_results_header().
var results_header: bool = false
## Results header: the flags + title bar row (centred), and the rule's y.
var title_bar_row: HBoxContainer
const RESULTS_RULE_Y := 84.0

var _title: String
var _title_row: HBoxContainer
var _icon_kind: String


func _init(title: String, icon_kind: String) -> void:
	_title = title
	_icon_kind = icon_kind
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	street = MenuStreetScene.new()
	add_child(street)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.09, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	add_child(NeonSwoosh.new())

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.position = Vector2(30, 4)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_row)
	_title_row = title_row
	title_row.add_child(UIStyle.logo(Vector2(210, 66)))
	var slash := UIStyle.stat("/", 52, Color(1, 1, 1, 0.75))
	slash.add_theme_font_override("font", UIStyle.slanted_font(true))
	slash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(slash)
	title_row.add_child(NeonWidgets.icon(_icon_kind, 46))
	title_label = UIStyle.stat(_title, 50, Color.WHITE)
	title_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	title_label.add_theme_color_override("font_shadow_color", Color(UIStyle.MAGENTA, 0.45))
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 0)
	title_label.add_theme_constant_override("shadow_outline_size", 10)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_label)
	var checker := NeonWidgets.Checker.new(UIStyle.MAGENTA, 2, false)
	checker.custom_minimum_size = Vector2(118, 34)
	checker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(checker)

	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 32
	content.offset_right = -32
	content.offset_top = 74
	content.offset_bottom = -88
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	back_button = NeonMenuButton.new("Back", "back")
	back_button.font_size = 30
	back_button.chevrons = false
	back_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.offset_left = 34
	back_button.offset_right = 34 + 270
	back_button.offset_top = -80
	back_button.offset_bottom = -26
	add_child(back_button)


## Swaps the classic title row for the Race Results header (see
## add_results_header). title_label becomes the bar's label.
func use_results_header() -> void:
	if results_header:
		return
	results_header = true
	_title_row.visible = false
	title_bar_row = add_results_header(self, _title)
	title_label = (title_bar_row.find_child("Text", true, false) as Label)
	content.offset_top = 94


## The Race Results header on any full-screen Control (setup screens,
## Settings, Garage): logo top left, a slanted title bar between two checker
## flags centred at the top, and a neon rule across the screen at
## RESULTS_RULE_Y. Returns the centred flags + bar row (the bar's label is
## its "Text" child). Keep content below about y = 92.
static func add_results_header(parent: Control, title: String) -> HBoxContainer:
	var logo := UIStyle.logo(Vector2(210, 70))
	logo.position = Vector2(30, 8)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo)
	var row := HBoxContainer.new()
	row.name = "ResultsTitle"
	row.add_theme_constant_override("separation", -4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = 16
	row.offset_bottom = 74
	parent.add_child(row)
	var bar := SetupWidgets.title_bar(title, 42)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [0, 1]:
		var flag := NeonWidgets.Checker.new(Color(UIStyle.MAGENTA, 0.9), 2, side == 0)
		flag.custom_minimum_size = Vector2(54, 28)
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(flag)
		if side == 0:
			row.add_child(bar)
	var rule := NeonWidgets.NeonRule.new()
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_top = RESULTS_RULE_Y - 3.0
	rule.offset_bottom = RESULTS_RULE_Y + 3.0
	parent.add_child(rule)
	return row
