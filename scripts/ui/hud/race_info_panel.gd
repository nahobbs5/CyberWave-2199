class_name RaceInfoPanel
extends PanelContainer
## Top-left race panel: mode / track, a large position, lap, race time,
## coins, and (Elimination) the active count and the next cut. Position
## changes pulse the number: cyan + "POSITION UP!" for a gain, orange for
## a loss.

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

## Places gained / lost since the start (tests).
var gains: int = 0
var losses: int = 0

var _coin_holder: Control
var _pos_tween: Tween
var _cue_time: float = 0.0


func _init() -> void:
	name = "RaceInfo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIStyle.box_style(UIStyle.PANEL_BG, UIStyle.PANEL_BORDER, 12))
	custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	mode_label = UIStyle.stat("", 14, UIStyle.MUTED)
	box.add_child(mode_label)

	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 6)
	box.add_child(pos_row)
	var tag := UIStyle.stat("POS", 18, UIStyle.CYAN)
	tag.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_row.add_child(tag)
	pos_number = UIStyle.heading("1", 56, Color.WHITE)
	pos_number.resized.connect(func() -> void: pos_number.pivot_offset = pos_number.size * 0.5)
	pos_row.add_child(pos_number)
	pos_total = UIStyle.heading("/ 8", 24, UIStyle.MUTED)
	pos_total.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_row.add_child(pos_total)
	pos_cue = UIStyle.stat("", 16, UIStyle.CYAN)
	pos_cue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pos_row.add_child(pos_cue)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", -2)
	box.add_child(grid)
	grid.add_child(UIStyle.stat("LAP", 16, UIStyle.MUTED))
	lap_value = UIStyle.heading("1 / 3", 22, UIStyle.CYAN)
	grid.add_child(lap_value)
	grid.add_child(UIStyle.stat("TIME", 16, UIStyle.MUTED))
	time_value = UIStyle.heading("0:00.00", 22, Color.WHITE)
	grid.add_child(time_value)

	# Coins: the count with a coin symbol on its right.
	coin_row = HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 6)
	box.add_child(coin_row)
	coin_label = UIStyle.heading("0", 22, UIStyle.GOLD)
	coin_label.resized.connect(func() -> void: coin_label.pivot_offset = Vector2(0, coin_label.size.y * 0.5))
	coin_row.add_child(coin_label)
	coin_icon = CoinIcon.new(20.0)
	coin_icon.resized.connect(func() -> void: coin_icon.pivot_offset = coin_icon.size * 0.5)
	coin_row.add_child(coin_icon)
	# Free-positioned holder for the floating "+1".
	_coin_holder = Control.new()
	_coin_holder.custom_minimum_size = Vector2(30, 0)
	_coin_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(_coin_holder)

	elim_label = UIStyle.stat("", 16, Color(1.0, 0.45, 0.5))
	elim_label.visible = false
	box.add_child(elim_label)


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
