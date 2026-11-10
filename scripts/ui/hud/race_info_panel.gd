class_name RaceInfoPanel
extends PanelContainer
## Race info, after "reference files/Cyberpunk Slipstream Under the Neon
## Moon.png". This panel (top left) holds the mode / track line, POSITION
## with a big slanted number, and (Elimination) the active count and the
## next cut, on a dark band that fades out to the right. Lap, race time and
## coins live in `lap_block`, which RaceHUD puts top right in single player
## (coins under the time) or under this panel in split screen. Position
## changes pulse the number: cyan + "POSITION UP!" for a gain, orange for a
## loss.

var mode_label: Label
var pos_number: Label
var pos_total: Label
var pos_cue: Label
var lap_value: Label
var time_value: Label
## Coin count (the number only); the coin symbol sits to its right.
var coin_label: Label
var coin_icon: CoinIcon
## The coin count + symbol row (hidden in split screen).
var coin_row: HBoxContainer
var elim_label: Label
## LAP, race time and coins (placed by RaceHUD).
var lap_block: LapBlock

## Places gained / lost since the start (tests).
var gains: int = 0
var losses: int = 0

var _coin_holder: Control
var _pos_tween: Tween
var _cue_time: float = 0.0


func _init() -> void:
	name = "RaceInfo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 16
	empty.content_margin_right = 60
	empty.content_margin_top = 4
	empty.content_margin_bottom = 8
	add_theme_stylebox_override("panel", empty)
	custom_minimum_size = Vector2(250, 0)
	resized.connect(queue_redraw)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	mode_label = UIStyle.stat("", 13, UIStyle.MUTED)
	box.add_child(mode_label)
	box.add_child(_slanted("POSITION", 24, UIStyle.CYAN))

	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 4)
	box.add_child(pos_row)
	pos_number = _slanted("1", 66, Color.WHITE)
	pos_number.resized.connect(func() -> void: pos_number.pivot_offset = pos_number.size * 0.5)
	pos_row.add_child(pos_number)
	pos_total = _slanted("/ 8", 34, Color.WHITE)
	pos_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pos_row.add_child(pos_total)
	pos_cue = UIStyle.stat("", 16, UIStyle.CYAN)
	pos_cue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pos_row.add_child(pos_cue)

	elim_label = UIStyle.stat("", 16, Color(1.0, 0.45, 0.5))
	elim_label.visible = false
	box.add_child(elim_label)

	lap_block = LapBlock.new()
	lap_value = lap_block.lap_value
	time_value = lap_block.time_value
	coin_row = lap_block.coin_row
	coin_label = lap_block.coin_label
	coin_icon = lap_block.coin_icon
	_coin_holder = lap_block.coin_holder


## Leaning label in the HUD's display font (Oxanium Bold, slanted).
static func _slanted(text: String, size: int, color: Color) -> Label:
	var l := UIStyle.heading(text, size, color)
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	return l


func _draw() -> void:
	RaceInfoPanel.draw_band(self, false)


## A dark band fading out towards the screen's middle, with a thin cyan
## underline: behind the top-corner HUD blocks.
static func draw_band(c: Control, from_right: bool) -> void:
	var w := c.size.x
	var h := c.size.y
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	var cols := PackedColorArray()
	for p in pts:
		var t := p.x / maxf(w, 1.0)
		if from_right:
			t = 1.0 - t
		cols.append(Color(0.03, 0.02, 0.1, 0.72 * (1.0 - t * t)))
	c.draw_polygon(pts, cols)
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var a := 1.0 - t
		var x := w * t if not from_right else w * (1.0 - t) - w / steps
		c.draw_rect(Rect2(x, h - 2, w / steps + 1, 2), Color(UIStyle.CYAN, 0.55 * a))


func get_position_text() -> String:
	return "POS %s %s" % [pos_number.text, pos_total.text]


func show_position(place: int, of: int, out: bool) -> void:
	if out:
		pos_number.text = "OUT"
		pos_total.text = "P%d" % place
	else:
		pos_number.text = str(place)
		pos_total.text = "/ %d" % of


## Brief pulse when the player gains or loses a place.
func position_changed(gained: bool) -> void:
	if gained:
		gains += 1
	else:
		losses += 1
	var color := UIStyle.CYAN if gained else UIStyle.WARN
	if _pos_tween != null and _pos_tween.is_valid():
		_pos_tween.kill()
	pos_number.scale = Vector2.ONE * 1.3
	pos_number.add_theme_color_override("font_color", color)
	_pos_tween = create_tween()
	_pos_tween.tween_property(pos_number, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pos_tween.tween_interval(0.35)
	_pos_tween.tween_callback(func() -> void: pos_number.add_theme_color_override("font_color", Color.WHITE))
	if gained:
		pos_cue.text = "POSITION UP!"
		_cue_time = 1.0


## Shows or hides the coin counter (split screen has no coins).
func set_coins_visible(on: bool) -> void:
	coin_row.visible = on


## Gold pulse on the count and coin, and a floating "+1".
func coin_collected() -> void:
	coin_label.scale = Vector2.ONE * 1.2
	coin_icon.scale = Vector2.ONE * 1.35
	var t := create_tween().set_parallel()
	t.tween_property(coin_label, "scale", Vector2.ONE, 0.2)
	t.tween_property(coin_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var plus := UIStyle.stat("+1", 16, UIStyle.GOLD)
	plus.position = Vector2(2, 0)
	_coin_holder.add_child(plus)
	var f := create_tween().set_parallel()
	f.tween_property(plus, "position:y", -18.0, 0.5)
	f.tween_property(plus, "modulate:a", 0.0, 0.5)
	f.chain().tween_callback(plus.queue_free)


func _process(delta: float) -> void:
	if _cue_time > 0.0:
		_cue_time -= delta
		pos_cue.modulate.a = clampf(_cue_time / 0.3, 0.0, 1.0)
		if _cue_time <= 0.0:
			pos_cue.text = ""


## LAP 1 / 3, the race time on its own band, and the coins under it, all
## right-aligned (top right in single player).
class LapBlock extends PanelContainer:
	var lap_value: Label
	var time_value: Label
	var coin_row: HBoxContainer
	var coin_label: Label
	var coin_icon: CoinIcon
	var coin_holder: Control
	## Right-aligned (top right) or left-aligned (under the position panel).
	var right_aligned: bool = true

	func _init() -> void:
		name = "LapTime"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 60
		empty.content_margin_right = 16
		empty.content_margin_top = 4
		empty.content_margin_bottom = 8
		add_theme_stylebox_override("panel", empty)
		custom_minimum_size = Vector2(230, 0)
		resized.connect(queue_redraw)
		var box := VBoxContainer.new()
		box.name = "Box"
		box.add_theme_constant_override("separation", -4)
		add_child(box)
		box.add_child(RaceInfoPanel._slanted("LAP", 22, UIStyle.CYAN))
		lap_value = RaceInfoPanel._slanted("1 / 3", 44, Color.WHITE)
		box.add_child(lap_value)
		time_value = RaceInfoPanel._slanted("0:00.00", 28, Color.WHITE)
		box.add_child(time_value)
		# Coins under the time: "+1" float, count, coin symbol.
		coin_row = HBoxContainer.new()
		coin_row.add_theme_constant_override("separation", 6)
		box.add_child(coin_row)
		coin_holder = Control.new()
		coin_holder.custom_minimum_size = Vector2(26, 0)
		coin_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_row.add_child(coin_holder)
		coin_label = RaceInfoPanel._slanted("0", 26, UIStyle.GOLD)
		coin_label.resized.connect(func() -> void: coin_label.pivot_offset = Vector2(0, coin_label.size.y * 0.5))
		coin_row.add_child(coin_label)
		coin_icon = CoinIcon.new(22.0)
		coin_icon.resized.connect(func() -> void: coin_icon.pivot_offset = coin_icon.size * 0.5)
		coin_row.add_child(coin_icon)
		set_right_aligned(true)

	func set_right_aligned(on: bool) -> void:
		right_aligned = on
		var box := get_node("Box") as VBoxContainer
		for child in box.get_children():
			if child is Label:
				(child as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if on else HORIZONTAL_ALIGNMENT_LEFT
		coin_row.alignment = BoxContainer.ALIGNMENT_END if on else BoxContainer.ALIGNMENT_BEGIN
		var style := get_theme_stylebox("panel") as StyleBoxEmpty
		style.content_margin_left = 60 if on else 16
		style.content_margin_right = 16 if on else 60
		queue_redraw()

	func _draw() -> void:
		RaceInfoPanel.draw_band(self, right_aligned)
