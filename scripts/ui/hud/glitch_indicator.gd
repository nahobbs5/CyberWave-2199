class_name GlitchIndicator
extends PanelContainer
## "SYSTEM GLITCH" warning at the top centre of a racer's HUD while their car
## is glitched (GDD 6.3): the weapon's icon, a corrupting title, the seconds
## left and a draining bar. It sits above the scrambled middle of the screen
## and draws on top of it, so it always reads. Reduced flashing (GDD 11.9):
## no letter scrambling or border flicker.

const ICON := preload("res://assets/ui/weapons/system_glitch.png")
const TITLE := "SYSTEM GLITCH"
const GLITCH_CHARS := "#%/<>01!?"
const COLOR := Color(0.9, 0.3, 0.75)
const ALT := Color(0.2, 1.0, 0.95)

## The car whose status drives this indicator (set by RaceHUD.setup).
var vehicle: VehicleController

var title: Label
var timer_label: Label
var bar: _DrainBar
var _style: StyleBoxFlat
var _total: float = 0.0
var _tick: float = 0.0
var _fade: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "GlitchIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 14.0
	_rng.randomize()
	_style = UIStyle.box_style(Color(0.06, 0.0, 0.08, 0.85), COLOR, 10, 2)
	add_theme_stylebox_override("panel", _style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	title = UIStyle.heading(TITLE, 24, Color.WHITE)
	title.custom_minimum_size = Vector2(230, 0)
	column.add_child(title)
	bar = _DrainBar.new()
	bar.custom_minimum_size = Vector2(230, 6)
	column.add_child(bar)
	timer_label = UIStyle.stat("0.0s", 24, COLOR)
	timer_label.custom_minimum_size = Vector2(56, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(timer_label)
	visible = false


## Seconds of glitch left on the followed car (0 = not glitched).
func time_left() -> float:
	if vehicle == null or not is_instance_valid(vehicle) or vehicle.status == null:
		return 0.0
	return vehicle.status.time_left(&"glitch")


func _process(delta: float) -> void:
	var left := time_left()
	if left <= 0.0:
		_total = 0.0
		_fade = move_toward(_fade, 0.0, delta / 0.2)
	else:
		_total = maxf(_total, left)
		_fade = move_toward(_fade, 1.0, delta / 0.15)
	visible = _fade > 0.0
	if not visible:
		return
	modulate.a = _fade
	var calm := GameSettings.reduced_flashing
	timer_label.text = "%.1fs" % left
	bar.fraction = left / _total if _total > 0.0 else 0.0
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.08
	if calm:
		title.text = TITLE
		_style.border_color = COLOR
		bar.color = COLOR
		return
	# Corrupting title: a letter or two swapped out, the border flickering.
	var text := TITLE
	for i in _rng.randi_range(0, 2):
		var at := _rng.randi_range(0, text.length() - 1)
		if text[at] != " ":
			text = text.substr(0, at) + GLITCH_CHARS[_rng.randi_range(0, GLITCH_CHARS.length() - 1)] + text.substr(at + 1)
	title.text = text
	_style.border_color = ALT if _rng.randf() < 0.3 else COLOR
	bar.color = _style.border_color


class _DrainBar extends Control:
	var fraction: float = 1.0:
		set(v):
			fraction = clampf(v, 0.0, 1.0)
			queue_redraw()
	var color: Color = GlitchIndicator.COLOR:
		set(v):
			color = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fraction, size.y)), color)
