class_name StartMenuLayout
extends Control
## Shared look of the title and single-player menus ("reference files/
## Cyberwave 2199 Racing Menu.png" and "... Neon Racing Menu.png"): the live
## MenuStreetScene with the garage car behind everything, the logo top left,
## a column of slanted NeonMenuButtons, the info box bottom right that describes
## the focused button, A/B hints, a neon swoosh along the bottom and
## (optionally) the coin pill top right.
##
## Usage: new(), add_child, add_entry(...) per button, then finish().

var street: MenuStreetScene
var info_box: MenuInfoBox
var hints: MenuHints
## Null when built without coins.
var coin_pill: PanelContainer

var _compact: bool
var _with_coins: bool
var _column: VBoxContainer
var _buttons: Array[NeonMenuButton] = []
var _rows: Array[MarginContainer] = []


## compact: smaller buttons and logo so 7-8 entries fit.
func _init(with_coins: bool = false, compact: bool = false) -> void:
	_with_coins = with_coins
	_compact = compact
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


func button_height() -> float:
	return 50.0 if _compact else 62.0


func add_entry(label_text: String, icon_kind: String, info: String, on_pressed: Callable) -> NeonMenuButton:
	if _column == null:
		_build()
	var b := NeonMenuButton.new(label_text, icon_kind, info)
	b.custom_minimum_size = Vector2(430 if _compact else 450, button_height())
	b.font_size = 27 if _compact else 32
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(on_pressed)
	b.focus_entered.connect(func() -> void: info_box.show_info(b.text, b.description))
	var row := MarginContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(b)
	_column.add_child(row)
	_buttons.append(b)
	_rows.append(row)
	return b


## Call after adding the entries (and after hiding any): steps the visible
## rows out to the left like the reference, links focus, fills the info box.
func finish() -> void:
	var visible: Array[NeonMenuButton] = []
	for b in _buttons:
		if b.visible:
			visible.append(b)
	for i in _rows.size():
		_rows[i].visible = _buttons[i].visible
	var step := 20.0 if _compact else 24.0
	var n := visible.size()
	for i in n:
		var row := visible[i].get_parent() as MarginContainer
		row.add_theme_constant_override("margin_left", int((n - 1 - i) * step))
	UIStyle.chain_focus(visible)
	if n > 0:
		info_box.show_info(visible[0].text, visible[0].description)


func set_coins(amount: int) -> void:
	if coin_pill != null:
		(coin_pill.find_child("Count", true, false) as Label).text = "%d Coins" % amount


func coin_text() -> String:
	return (coin_pill.find_child("Count", true, false) as Label).text if coin_pill != null else ""


func _build() -> void:
	if _column != null:
		return
	street = MenuStreetScene.new()
	add_child(street)

	# Darken the left side so the buttons read against the city.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.62])
	grad.colors = PackedColorArray([Color(0.02, 0.0, 0.06, 0.82), Color(0.02, 0.0, 0.06, 0.45), Color(0.02, 0.0, 0.06, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 4
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	add_child(_Swoosh.new())

	var logo := UIStyle.logo(Vector2(480, 160) if _compact else Vector2(570, 190))
	logo.position = Vector2(40, 6 if _compact else 12)
	logo.size = logo.custom_minimum_size
	add_child(logo)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 9 if _compact else 14)
	_column.position = Vector2(36, 172 if _compact else 218)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	info_box = MenuInfoBox.new()
	info_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info_box.offset_left = -730
	info_box.offset_right = -40
	info_box.offset_top = -186
	info_box.offset_bottom = -92
	add_child(info_box)

	hints = MenuHints.new()
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.offset_left = -330
	hints.offset_right = -24
	hints.offset_top = -70
	hints.offset_bottom = -26
	hints.alignment = BoxContainer.ALIGNMENT_END
	add_child(hints)

	if _with_coins:
		coin_pill = UIStyle.coin_pill(24)
		coin_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		coin_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		coin_pill.offset_right = -40
		coin_pill.offset_top = 24
		add_child(coin_pill)


## Glowing magenta curve along the bottom edge.
class _Swoosh extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := PackedVector2Array()
		var a := Vector2(-20, size.y - 14)
		var c := Vector2(size.x * 0.45, size.y - 70)
		var b := Vector2(size.x + 20, size.y - 64)
		for i in 49:
			var t := i / 48.0
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		draw_polyline(pts, Color(UIStyle.MAGENTA, 0.12), 16.0, true)
		draw_polyline(pts, Color(UIStyle.MAGENTA, 0.35), 6.0, true)
		draw_polyline(pts, Color(1.0, 0.6, 0.95), 2.0, true)
