class_name HudAnnouncer
extends VBoxContainer
## Upper-centre race announcements: READY / SET / GO, FINAL LAP!, NEW BEST
## LAP!, FINISH!, QUALIFIED, POSITION feed... Each one pops in, holds and
## fades, high enough to keep the road clear. Also holds the persistent
## warnings (WRONG WAY, INCOMING) and the Elimination feed line.

const FADE_IN := 0.12
const FADE_OUT := 0.3

var incoming: Label
var main: Label
var sub: Label
var wrong_way: Label
var feed: Label

var _time_left: float = 0.0
var _duration: float = 0.0
var _feed_time: float = 0.0


func _init() -> void:
	name = "Announcer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 96.0
	incoming = _line(UIStyle.heading("!! INCOMING !!", 30, UIStyle.DANGER))
	main = _line(UIStyle.heading("", 60, UIStyle.CYAN))
	main.add_theme_constant_override("outline_size", 10)
	sub = _line(UIStyle.stat("", 24, Color.WHITE))
	wrong_way = _line(UIStyle.heading("WRONG WAY", 40, UIStyle.DANGER))
	feed = _line(UIStyle.stat("", 26, Color.WHITE))


func _line(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)
	add_child(label)
	return label


## Shows a big announcement (and an optional smaller second line).
func announce(text: String, seconds: float, color: Color, subtitle: String = "") -> void:
	main.text = text
	main.add_theme_color_override("font_color", color)
	sub.text = subtitle
	main.visible = true
	sub.visible = subtitle != ""
	_time_left = seconds
	_duration = seconds
	_apply_fade()


func show_feed(text: String, color: Color, seconds: float = 2.5) -> void:
	feed.text = text
	feed.add_theme_color_override("font_color", color)
	feed.visible = true
	_feed_time = seconds


## The announcement on screen ("" when none); the subtitle on a second line.
func get_text() -> String:
	if not main.visible:
		return ""
	return main.text + ("\n" + sub.text if sub.visible else "")


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			main.visible = false
			sub.visible = false
		else:
			_apply_fade()
	if _feed_time > 0.0:
		_feed_time -= delta
		feed.visible = _feed_time > 0.0


## Pop in (slightly large, quickly settling), hold, fade out.
func _apply_fade() -> void:
	var shown := _duration - _time_left
	var alpha := minf(1.0, shown / FADE_IN) * minf(1.0, _time_left / FADE_OUT)
	main.modulate.a = alpha
	sub.modulate.a = alpha
	var grow := 1.0 + 0.18 * maxf(0.0, 1.0 - shown / 0.18)
	main.scale = Vector2.ONE * grow
