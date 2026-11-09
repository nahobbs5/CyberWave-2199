class_name ControllerIcon
extends Control
## Neon line drawing of a player's input device, for the split-screen
## connect cards: "xbox" (offset sticks, guide button, coloured A B X Y),
## "playstation" (touchpad, symmetric sticks, shape buttons), "nintendo"
## (Pro-style, + / - and lettered buttons), "generic" (the reference art's
## pad) or "keyboard" (WASD lit). DeviceInput.controller_kind() picks the
## kind for a device. `excited` adds the gold rays of a READY player.

const XBOX_COLORS := {"top": Color(1.0, 0.82, 0.2), "right": Color(1.0, 0.3, 0.3),
		"bottom": Color(0.3, 0.9, 0.35), "left": Color(0.3, 0.6, 1.0)}
const PS_COLORS := {"top": Color(0.3, 0.9, 0.7), "right": Color(1.0, 0.35, 0.4),
		"bottom": Color(0.45, 0.65, 1.0), "left": Color(1.0, 0.5, 0.85)}
const NINTENDO_LETTERS := {"top": "X", "right": "A", "bottom": "B", "left": "Y"}
const LED_COLORS: Array[Color] = [Color(1.0, 0.3, 0.85), Color(0.2, 0.95, 1.0), Color(0.3, 1.0, 0.5)]
const RAY_COLOR := Color(1.0, 0.82, 0.2)

## Body outline of the pads (x 0..1 across, y 0..1 down), smoothed when drawn.
const PAD_OUTLINE := [
	Vector2(0.20, 0.10), Vector2(0.35, 0.06), Vector2(0.5, 0.08), Vector2(0.65, 0.06), Vector2(0.80, 0.10),
	Vector2(0.92, 0.22), Vector2(0.98, 0.48), Vector2(1.0, 0.76), Vector2(0.95, 0.92), Vector2(0.86, 0.95),
	Vector2(0.78, 0.86), Vector2(0.70, 0.72), Vector2(0.6, 0.68), Vector2(0.5, 0.68), Vector2(0.4, 0.68),
	Vector2(0.30, 0.72), Vector2(0.22, 0.86), Vector2(0.14, 0.95), Vector2(0.05, 0.92), Vector2(0.0, 0.76),
	Vector2(0.02, 0.48), Vector2(0.08, 0.22),
]

var kind: String = "generic":
	set(value):
		kind = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## Grey the coloured buttons too (an empty slot).
var muted: bool = false:
	set(value):
		muted = value
		queue_redraw()
## Gold rays either side (READY).
var excited: bool = false:
	set(value):
		excited = value
		queue_redraw()
## Leave room at the sides for the rays (off for small inline icons).
var ray_room: bool = true

var _o := Vector2.ZERO
var _w: float = 1.0
var _h: float = 1.0
var _sw: float = 2.0


func _init(device_kind: String = "generic", size_px: Vector2 = Vector2(180, 110), with_rays: bool = true) -> void:
	kind = device_kind
	ray_room = with_rays
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	_w = size.x * (0.66 if ray_room else 1.0)
	_h = _w * 0.64
	if _h > size.y * 0.95:
		_h = size.y * 0.95
		_w = _h / 0.64
	_o = (size - Vector2(_w, _h)) * 0.5
	_sw = maxf(1.5, _w * 0.024)
	if kind == "keyboard":
		_draw_keyboard()
	else:
		_draw_pad()
	if excited:
		for side in [-1.0, 1.0]:
			var c := _p(0.5 + side * 0.56, 0.42)
			for a in [-0.45, 0.0, 0.45]:
				var dir := Vector2(side * cos(a), sin(a))
				_stroke(PackedVector2Array([c + dir * _w * 0.02, c + dir * _w * 0.13]), RAY_COLOR, 1.5)


# --- pads --------------------------------------------------------------------

func _draw_pad() -> void:
	var outline := PackedVector2Array()
	for p: Vector2 in _smooth(PAD_OUTLINE, 6):
		var q := p
		if kind == "playstation":
			# Longer, slimmer grips.
			q.y = p.y + maxf(p.y - 0.7, 0.0) * 0.25
		outline.append(_p(q.x, q.y))
	outline.append(outline[0])
	_fill(outline, Color(color, 0.06))
	_stroke(outline, color)
	match kind:
		"xbox":
			_stick(0.24, 0.38, 0.075)
			_dpad(0.37, 0.58, 0.075)
			_stick(0.63, 0.58, 0.065)
			_face_buttons(0.76, 0.38)
			_circle(_p(0.5, 0.22), 0.045, color)
			var g := _p(0.5, 0.22)
			var k := _w * 0.022
			_stroke(PackedVector2Array([g + Vector2(-k, -k), g + Vector2(k, k)]), color, 0.6)
			_stroke(PackedVector2Array([g + Vector2(k, -k), g + Vector2(-k, k)]), color, 0.6)
			_dot(_p(0.42, 0.36), 0.014, color)
			_dot(_p(0.58, 0.36), 0.014, color)
		"playstation":
			var a := _p(0.36, 0.11)
			var b := _p(0.64, 0.38)
			var pad := NeonPanel.rounded_rect(Rect2(a, b - a), _w * 0.025, 3)
			pad.append(pad[0])
			_stroke(pad, color, 0.8)
			_dpad(0.22, 0.38, 0.085)
			_face_buttons(0.78, 0.38)
			_stick(0.37, 0.62, 0.065)
			_stick(0.63, 0.62, 0.065)
			_dot(_p(0.5, 0.52), 0.018, color)
		"nintendo":
			_stick(0.24, 0.38, 0.075)
			_dpad(0.37, 0.58, 0.075)
			_stick(0.63, 0.58, 0.065)
			_face_buttons(0.76, 0.38)
			var m := _p(0.41, 0.25)
			var pl := _p(0.59, 0.25)
			var k := _w * 0.018
			_stroke(PackedVector2Array([m - Vector2(k, 0), m + Vector2(k, 0)]), color, 0.7)
			_stroke(PackedVector2Array([pl - Vector2(k, 0), pl + Vector2(k, 0)]), color, 0.7)
			_stroke(PackedVector2Array([pl - Vector2(0, k), pl + Vector2(0, k)]), color, 0.7)
			_circle(_p(0.56, 0.4), 0.02, color, 0.7)
			var cap := _p(0.44, 0.4)
			var sq := PackedVector2Array([cap + Vector2(-k, -k), cap + Vector2(k, -k), cap + Vector2(k, k),
					cap + Vector2(-k, k), cap + Vector2(-k, -k)])
			_stroke(sq, color, 0.7)
		_:
			_dpad(0.24, 0.4, 0.09)
			_face_buttons(0.76, 0.38)
			_stick(0.38, 0.56, 0.065)
			_stick(0.62, 0.56, 0.065)
			for i in 3:
				_dot(_p(0.46 + 0.04 * i, 0.24), 0.011, color if muted else LED_COLORS[i])


func _stick(x: float, y: float, r: float) -> void:
	_circle(_p(x, y), r, color)
	_circle(_p(x, y), r * 0.5, Color(color, color.a * 0.6), 0.6)


func _dpad(x: float, y: float, s: float) -> void:
	var c := _p(x, y)
	var l := s * _w
	var a := l * 0.34
	var pts := PackedVector2Array([
		c + Vector2(-a, -l), c + Vector2(a, -l), c + Vector2(a, -a), c + Vector2(l, -a),
		c + Vector2(l, a), c + Vector2(a, a), c + Vector2(a, l), c + Vector2(-a, l),
		c + Vector2(-a, a), c + Vector2(-l, a), c + Vector2(-l, -a), c + Vector2(-a, -a),
	])
	pts.append(pts[0])
	_fill(pts, Color(color, color.a * 0.15))
	_stroke(pts, color, 0.8)


func _face_buttons(x: float, y: float) -> void:
	var c := _p(x, y)
	var spread := _w * 0.068
	var r := 0.03
	var at := {"top": c + Vector2(0, -spread), "right": c + Vector2(spread, 0),
			"bottom": c + Vector2(0, spread), "left": c + Vector2(-spread, 0)}
	for side: String in at:
		var p: Vector2 = at[side]
		match kind:
			"xbox":
				var col: Color = color if muted else XBOX_COLORS[side]
				draw_circle(p, r * _w, Color(col, 0.3 * color.a))
				_circle(p, r, col, 0.7)
			"playstation":
				_circle(p, r, color, 0.6)
				_ps_shape(side, p, r * _w * 0.55, color if muted else PS_COLORS[side])
			"nintendo":
				_circle(p, r, color, 0.7)
				var font := UIStyle.bold_font()
				if font != null:
					var fs := int(maxf(8.0, r * _w * 1.5))
					var text: String = NINTENDO_LETTERS[side]
					var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
					draw_string(font, p + Vector2(-ts.x * 0.5, font.get_ascent(fs) * 0.5 - 1), text,
							HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			_:
				draw_circle(p, r * _w * 0.75, Color(color, color.a * 0.85))


func _ps_shape(side: String, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	match side:
		"top":
			for i in 4:
				var a := -PI * 0.5 + TAU * i / 3.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.1)
		"right":
			draw_arc(c, r, 0, TAU, 20, col, _sw * 0.6, true)
			return
		"bottom":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, _sw * 0.6, true)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, _sw * 0.6, true)
			return
		"left":
			var k := r * 0.85
			pts = PackedVector2Array([c + Vector2(-k, -k), c + Vector2(k, -k), c + Vector2(k, k), c + Vector2(-k, k), c + Vector2(-k, -k)])
	draw_polyline(pts, col, _sw * 0.6, true)


# --- keyboard ----------------------------------------------------------------

func _draw_keyboard() -> void:
	var a := _p(0.0, 0.1)
	var b := _p(1.0, 0.9)
	var body := NeonPanel.rounded_rect(Rect2(a, b - a), _w * 0.06, 4)
	body.append(body[0])
	_fill(body, Color(color, 0.06))
	_stroke(body, color)
	var key := 0.072
	var gap := 0.018
	var rows := [[10, 0.059, 0.2], [9, 0.104, 0.37], [8, 0.149, 0.54]]
	var lit := {"0,1": true, "1,0": true, "1,1": true, "1,2": true} # W, A, S, D
	var kh := key * _w / _h
	for ri in rows.size():
		var row: Array = rows[ri]
		for i in int(row[0]):
			var x: float = row[1] + i * (key + gap)
			var k := Rect2(_p(x, row[2]), Vector2(key * _w, kh * _h))
			var accent := lit.has("%d,%d" % [ri, i]) and not muted
			if accent:
				draw_rect(k, Color(UIStyle.CYAN, 0.35))
			_key(k, UIStyle.CYAN if accent else Color(color, color.a * 0.8))
	_key(Rect2(_p(0.27, 0.71), Vector2(0.46 * _w, kh * _h)), Color(color, color.a * 0.8))


func _key(r: Rect2, col: Color) -> void:
	var pts := NeonPanel.rounded_rect(r, _w * 0.012, 2)
	pts.append(pts[0])
	draw_polyline(pts, col, maxf(1.0, _sw * 0.5), true)


# --- drawing helpers ---------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x * _w, y * _h)


## Glow pass, then the bright line. `scale` thins detail strokes.
func _stroke(pts: PackedVector2Array, col: Color, scale: float = 1.0) -> void:
	draw_polyline(pts, Color(col, col.a * 0.16), _sw * scale * 4.0, true)
	draw_polyline(pts, col, _sw * scale, true)


func _circle(c: Vector2, r: float, col: Color, scale: float = 1.0) -> void:
	draw_arc(c, r * _w, 0, TAU, 28, Color(col, col.a * 0.16), _sw * scale * 4.0, true)
	draw_arc(c, r * _w, 0, TAU, 28, col, _sw * scale, true)


func _dot(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r * _w * 2.2, Color(col, col.a * 0.15))
	draw_circle(c, r * _w, col)


func _fill(pts: PackedVector2Array, col: Color) -> void:
	var poly := pts.slice(0, pts.size() - 1)
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return
	draw_colored_polygon(poly, col)


## Closed Catmull-Rom curve through `pts`.
static func _smooth(pts: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var p3: Vector2 = pts[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out
