class_name CarUnlockScreen
extends CanvasLayer
## CAR UNLOCKED (GDD 9.1a) after "reference files/Switchback car unlocked
## screen.png": shown after a race that unlocked a car (rival ghost beaten,
## cup won, Elimination won, Mirror podium, 200cc win), after the results:
## the results button you press (Race again, Next Race, Main menu...) opens
## it first, so the scores come before it. The
## new car stands in the dark garage on the right (rear three-quarter view,
## turning slowly). On the left: CAR UNLOCKED, the car's name, where and how
## it was won (two lines), then Continue (on to what the results button
## does, or the next unlocked car) and View in Garage (straight to the garage with the car
## selected). The logo sits between cyan / magenta bars at the top, inside a
## thin cyan frame with magenta corner ticks.

signal continue_pressed
signal garage_pressed

const DESIGN := Vector2(1280, 720)
const CYAN := Color(0.1, 0.8, 0.85)
## Over the HUD (and the podium, layer 15).
const LAYER := 16

## Tests: skip the screen and carry out the results button straight away.
static var instant: bool = false
## The scene View in Garage last went to (tests; they turn off
## GameSession.scene_changes_enabled).
static var last_scene: String = ""

## {"vehicle", "line1", "line2"} (RaceManager.unlocks.cards).
var card: Dictionary = {}
var preview: VehiclePreview
var name_label: Label
var line1_label: Label
var line2_label: Label
var continue_button: Button
var garage_button: Button

var _root: Control
var _frame: Control
var _canvas: Control


## Leaving the results: shows a CAR UNLOCKED screen for each car the race
## unlocked, one after the other, then calls `then` (what the results
## button does). Once per race; with nothing unlocked (or `instant`), calls
## `then` now. Single player or split screen.
static func show_then(race: RaceManager, then: Callable) -> CarUnlockScreen:
	var cards: Array = race.unlocks.get("cards", []) if race != null else []
	if instant or cards.is_empty() or race.has_meta(&"unlocks_shown"):
		then.call()
		return null
	race.set_meta(&"unlocks_shown", true)
	return show_cards(race, cards, then)


## Shows `cards` ({vehicle, line1, line2}) one after the other on `host`,
## then calls `then` (now, with no cards or `instant`). Free drive uses it
## for the Practice-lap car.
static func show_cards(host: Node, cards: Array, then: Callable) -> CarUnlockScreen:
	if instant or cards.is_empty():
		then.call()
		return null
	return _show_card(host, then, cards, 0)


static func _show_card(host: Node, then: Callable, cards: Array, i: int) -> CarUnlockScreen:
	var screen := CarUnlockScreen.new()
	screen.card = cards[i]
	screen.continue_pressed.connect(func() -> void:
		screen.queue_free()
		if not is_instance_valid(host):
			return
		if i + 1 < cards.size():
			_show_card(host, then, cards, i + 1)
		else:
			then.call())
	screen.garage_pressed.connect(func() -> void:
		to_garage(host.get_tree(), str(screen.card.get("vehicle", ""))))
	host.add_child(screen)
	return screen


## Straight to the garage with the new car selected; back from there goes to
## the main menu (the race and its rewards are already saved).
static func to_garage(tree: SceneTree, vehicle_id: String) -> void:
	var profile := PlayerProfile.get_profile()
	if vehicle_id != "":
		profile.set_selected_vehicle(vehicle_id)
	GameSession.split_screen = false
	GameSession.garage_return = GameSession.MAIN_MENU_SCENE
	GameSession.series = null
	ResultsScreen.set_race_sfx_muted(false)
	last_scene = GameSession.GARAGE_SCENE
	GameSession.to_garage(tree)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	ResultsScreen.set_race_sfx_muted(true)
	Music.play(get_tree(), Music.VICTORY)
	_build()
	_fill()
	if visible:
		_focus.call_deferred()


func vehicle() -> VehicleData:
	return VehicleCatalog.by_id(str(card.get("vehicle", "")))


func _fill() -> void:
	var v := vehicle()
	name_label.text = v.display_name.to_upper()
	line1_label.text = str(card.get("line1", ""))
	line2_label.text = str(card.get("line2", ""))
	line2_label.visible = line2_label.text != ""
	var profile := PlayerProfile.get_profile()
	preview.show_vehicle(v, profile.loadout_for(v.id), profile.plate_text)


func _focus() -> void:
	if is_instance_valid(continue_button) and continue_button.is_inside_tree():
		continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		continue_pressed.emit()


# --- layout ------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color(0.01, 0.01, 0.03)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)

	# The car, full screen, pushed right and seen from behind.
	preview = VehiclePreview.new()
	preview.name = "Preview"
	preview.detail = VehiclePreview.Detail.FULL
	preview.view_offset = Vector2(-2.3, -0.35)
	preview.zoom = 1.45
	preview.spin_speed = 0.12
	preview.start_yaw = VehiclePreview.START_YAW + PI + 0.35
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(preview)
	var shade := _Shade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	# Everything else on a 1280x720 canvas scaled to fit.
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = DESIGN
	_frame.add_child(_canvas)
	_root.resized.connect(_fit)
	_fit()

	var border := _Border.new()
	border.position = Vector2(14, 34)
	border.size = Vector2(1252, 670)
	_canvas.add_child(border)
	var header := _Header.new()
	header.position = Vector2(0, 4)
	header.size = Vector2(DESIGN.x, 64)
	_canvas.add_child(header)
	var logo := UIStyle.logo(Vector2(330, 60))
	logo.position = Vector2(DESIGN.x * 0.5 - 165, 4)
	logo.size = Vector2(330, 60)
	_canvas.add_child(logo)

	var col := VBoxContainer.new()
	col.name = "Info"
	col.position = Vector2(66, 182)
	col.size = Vector2(560, 480)
	col.add_theme_constant_override("separation", 0)
	_canvas.add_child(col)
	var tag := UIStyle.heading("CAR UNLOCKED", 30, CYAN)
	tag.name = "Tag"
	tag.add_theme_font_override("font", UIStyle.slanted_font(true))
	col.add_child(tag)
	var tag_rule := _Underline.new(CYAN, 300.0)
	col.add_child(tag_rule)
	_gap(col, 18)
	name_label = UIStyle.heading("", 64, Color(0.98, 0.96, 0.9))
	name_label.name = "CarName"
	name_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	name_label.add_theme_constant_override("outline_size", 6)
	col.add_child(name_label)
	col.add_child(_Underline.new(UIStyle.MAGENTA, 520.0))
	_gap(col, 30)
	line1_label = UIStyle.label("", 28, Color(0.95, 0.95, 0.95))
	line1_label.name = "Line1"
	line1_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	col.add_child(line1_label)
	_gap(col, 6)
	line2_label = UIStyle.label("", 28, Color(0.95, 0.95, 0.95))
	line2_label.name = "Line2"
	line2_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	col.add_child(line2_label)
	_gap(col, 56)
	continue_button = _SlantButton.new("Continue")
	continue_button.name = "Continue"
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	col.add_child(continue_button)
	_gap(col, 20)
	garage_button = _SlantButton.new("View in Garage")
	garage_button.name = "ViewInGarage"
	garage_button.pressed.connect(func() -> void: garage_pressed.emit())
	col.add_child(garage_button)
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(garage_button)
	garage_button.focus_neighbor_top = garage_button.get_path_to(continue_button)
	continue_button.focus_neighbor_top = continue_button.get_path_to(garage_button)
	garage_button.focus_neighbor_bottom = garage_button.get_path_to(continue_button)


func _gap(parent: Control, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


func _fit() -> void:
	if _root == null or _frame == null:
		return
	var area := _root.size if _root.size.x > 0.0 else Vector2(get_viewport().get_visible_rect().size) if is_inside_tree() else DESIGN
	var k := minf(area.x / DESIGN.x, area.y / DESIGN.y)
	_frame.scale = Vector2.ONE * k
	_frame.position = (area - DESIGN * k) * 0.5


## Darkens the garage, most of all on the left behind the text and at the
## edges, like the reference's dim underground garage.
class _Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.04, 0.22))
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.62, 0), Vector2(w * 0.62, h), Vector2(0, h)])
		var dark := Color(0.0, 0.01, 0.04, 0.82)
		var clear := Color(0.0, 0.01, 0.04, 0.0)
		draw_polygon(pts, PackedColorArray([dark, clear, clear, dark]))
		draw_rect(Rect2(0, 0, w, h * 0.14), Color(0.0, 0.0, 0.02, 0.5))


## Thin cyan frame (open at the top for the header) with magenta "///"
## ticks in the bottom corners.
class _Border extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Color(CarUnlockScreen.CYAN, 0.75)
		var w := size.x
		var h := size.y
		var cut := 22.0
		var gap0 := w * 0.17
		var gap1 := w * 0.83
		var pts := PackedVector2Array([Vector2(gap0, 0), Vector2(cut, 0), Vector2(0, cut), Vector2(0, h - cut),
				Vector2(cut, h), Vector2(w - cut, h), Vector2(w, h - cut), Vector2(w, cut), Vector2(w - cut, 0), Vector2(gap1, 0)])
		draw_polyline(pts, Color(c, 0.25), 6.0, true)
		draw_polyline(pts, c, 1.6, true)
		for side: int in [0, 1]:
			for k in 3:
				var x := 46.0 + k * 9.0 if side == 0 else w - 46.0 - k * 9.0 - 10.0
				draw_line(Vector2(x, h - 6), Vector2(x + 7, h - 18), UIStyle.MAGENTA, 3.0, true)


## The bars either side of the logo: cyan over magenta, the cyan longer.
class _Header extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := size.x * 0.5
		var y := 34.0
		for side: int in [-1, 1]:
			var inner := mid + side * 190.0
			var outer := mid + side * 380.0
			_bar(inner, outer, y - 5.0, CarUnlockScreen.CYAN, 4.0)
			_bar(inner + side * 6.0, inner + side * 120.0, y + 3.0, UIStyle.MAGENTA, 4.0)
			_bar(inner + side * 128.0, outer - side * 20.0, y + 3.0, Color(CarUnlockScreen.CYAN, 0.55), 3.0)

	func _bar(x0: float, x1: float, y: float, c: Color, w: float) -> void:
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(c, 0.3), w + 5.0, true)
		draw_line(Vector2(x0, y), Vector2(x1, y), c, w, true)


## A glowing rule under a heading with a little step down at the left end.
class _Underline extends Control:
	var color: Color
	var length: float

	func _init(c: Color, len: float) -> void:
		color = c
		length = len
		custom_minimum_size = Vector2(len, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 7), Vector2(length * 0.4, 7), Vector2(length * 0.43, 3), Vector2(length, 3)])
		draw_polyline(pts, Color(color, 0.3), 6.0, true)
		draw_polyline(pts, color, 2.4, true)


## Slanted button: the focused one is filled cyan, the other a cyan outline
## on dark glass (Continue / View in Garage in the reference).
class _SlantButton extends Button:
	var _font: Font

	func _init(label_text: String) -> void:
		text = label_text
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(400, 64)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		_font = UIStyle.slanted_font(false)
		mouse_entered.connect(func() -> void: grab_focus())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.32
		var w := size.x
		var c := 10.0
		var pts := PackedVector2Array([Vector2(s + c, 0), Vector2(w, 0), Vector2(w - s, h - c), Vector2(w - s - c, h),
				Vector2(0, h), Vector2(s, c)])
		var lit := has_focus()
		var cyan := CarUnlockScreen.CYAN
		var outline := pts.duplicate()
		outline.append(pts[0])
		if lit:
			draw_colored_polygon(pts, cyan)
			draw_polyline(outline, Color(cyan, 0.35), 8.0, true)
		else:
			draw_colored_polygon(pts, Color(0.02, 0.05, 0.08, 0.8))
			draw_polyline(outline, Color(cyan, 0.3), 7.0, true)
			draw_polyline(outline, cyan, 3.0, true)
		var fs := 32
		var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := Vector2((w - ts.x) * 0.5, (h + _font.get_ascent(fs) - _font.get_descent(fs)) * 0.5)
		var ink := Color(0.97, 1.0, 0.95)
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.0, 0.15, 0.18, 0.7))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
