class_name RaceInfoPanel
extends PanelContainer
## Race info, after "reference files/Cyberpunk Slipstream Under the Neon
## Moon.png". This panel (top left) holds POSITION with a big slanted
## "2/8", and (Elimination) the active count and the
## next cut, on a dark band that fades out to the right. Lap, race time and
## coins live in `lap_block`, which RaceHUD puts top right in single player
## (coins under the time) or under this panel in split screen. Position
## changes pulse the number: cyan + "POSITION UP!" for a gain, orange for a
## loss.

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
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	box.add_child(_slanted("POSITION", 24, UIStyle.CYAN))

	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 4)
	box.add_child(pos_row)
	pos_number = _slanted("1", 66, Color.WHITE)
	pos_number.resized.connect(func() -> void: pos_number.pivot_offset = pos_number.size * 0.5)
	pos_row.add_child(pos_number)
	pos_total = _slanted("/8", 34, Color.WHITE)
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


## "POS 2 / 8" (or "POS OUT P7"), whatever the on-screen spacing.
func get_position_text() -> String:
	var total := pos_total.text
	if total.begins_with("/"):
		total = "/ " + total.substr(1)
	return "POS %s %s" % [pos_number.text, total]


func show_position(place: int, of: int, out: bool) -> void:
	if out:
		pos_number.text = "OUT"
		pos_total.text = "P%d" % place
	else:
		pos_number.text = str(place)
		pos_total.text = "/%d" % of


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


## Top right: LAP "1/3", the race time under it, and (single player) the
## coins under the time, straight on the picture (no bands). Split screen
## puts it under the position, left-aligned on dark bands.
class LapBlock extends VBoxContainer:
	var lap_value: Label
	var time_value: Label
	var coin_row: HBoxContainer
	var coin_label: Label
	var coin_icon: CoinIcon
	var coin_holder: Control
	## Right-aligned (top right) or left-aligned (under the position panel).
	var right_aligned: bool = true
	var _bands: Array[Band] = []
	var _lap_caption: Label
	var _coin_margin: MarginContainer

	func _init() -> void:
		name = "LapTime"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 6)
		# LAP and "1/3".
		var lap_band := _band(230.0)
		var lap_box := VBoxContainer.new()
		lap_box.add_theme_constant_override("separation", 2)
		lap_band.add_child(lap_box)
		_lap_caption = RaceInfoPanel._slanted("LAP", 24, UIStyle.CYAN)
		lap_box.add_child(_lap_caption)
		lap_value = RaceInfoPanel._slanted("1/3", 54, Color.WHITE)
		lap_box.add_child(lap_value)
		# The race time on its own band.
		var time_band := _band(230.0)
		time_value = RaceInfoPanel._slanted("00:00.000", 30, Color.WHITE)
		time_band.add_child(time_value)
		# Coins under the time: "+1" float, count, coin symbol (no band),
		# inset like the text on the bands.
		_coin_margin = MarginContainer.new()
		_coin_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_coin_margin)
		coin_row = HBoxContainer.new()
		coin_row.add_theme_constant_override("separation", 6)
		_coin_margin.add_child(coin_row)
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

	func _band(min_width: float) -> Band:
		var b := Band.new()
		b.custom_minimum_size = Vector2(min_width, 0)
		add_child(b)
		_bands.append(b)
		return b

	func set_right_aligned(on: bool) -> void:
		right_aligned = on
		var shrink := Control.SIZE_SHRINK_END if on else Control.SIZE_SHRINK_BEGIN
		for b in _bands:
			b.from_right = on
			b.size_flags_horizontal = shrink
			var style := b.get_theme_stylebox("panel") as StyleBoxEmpty
			style.content_margin_left = 60 if on else 16
			style.content_margin_right = 16 if on else 60
			b.queue_redraw()
		for l: Label in [_lap_caption, lap_value, time_value]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if on else HORIZONTAL_ALIGNMENT_LEFT
		_coin_margin.size_flags_horizontal = shrink
		_coin_margin.add_theme_constant_override("margin_right", 16 if on else 0)
		_coin_margin.add_theme_constant_override("margin_left", 0 if on else 16)
		coin_row.alignment = BoxContainer.ALIGNMENT_END if on else BoxContainer.ALIGNMENT_BEGIN


## One HUD band: a dark strip fading towards the screen's middle with a cyan
## underline (RaceInfoPanel.draw_band).
class Band extends PanelContainer:
	var from_right: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 60
		empty.content_margin_right = 16
		empty.content_margin_top = 2
		empty.content_margin_bottom = 6
		add_theme_stylebox_override("panel", empty)
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Top right goes without bands; left-aligned (split screen) keeps them.
		if not from_right:
			RaceInfoPanel.draw_band(self, false)
