class_name NeonIcons
extends RefCounted
## Line icons for the Settings and Credits screens, in the same style as
## UIStyle's start-menu icons: distance(kind, q) gives the distance from q
## (0..1 icon space) to the icon's strokes; filled areas return a negative
## distance and holes a large one. UIStyle.icon_texture / cached_icon call
## this for any kind it doesn't draw itself, so use those to get a texture.
##
## Kinds: monitor, speaker, gamepad, hud, blur, camera, bolt, note, wave,
## accelerate, brake, arrow_left, arrow_right, drift, crosshair, ramp, slot1,
## slot2, look_back, reset, pause, clapper, layers, palette, fonts, and the
## garage's brush, stripes, rim, plate, burst (underglow), exhaust.

const FILL := -1.0
const HOLE := 1.0


static func distance(kind: String, q: Vector2) -> float:
	match kind:
		"monitor":
			return minf(_rect_outline(q, Vector2(0.1, 0.16), Vector2(0.9, 0.68)),
					_lines(q, [[0.5, 0.68, 0.5, 0.84], [0.3, 0.86, 0.7, 0.86]]))
		"speaker":
			var d := FILL if _in(q, [0.06, 0.37, 0.28, 0.37, 0.52, 0.14, 0.52, 0.86, 0.28, 0.63, 0.06, 0.63]) else INF
			var a := atan2(q.y - 0.5, q.x - 0.5)
			if absf(a) < 0.9:
				var r := q.distance_to(Vector2(0.5, 0.5))
				d = minf(d, minf(absf(r - 0.2), absf(r - 0.36)))
			return d
		"gamepad":
			var body := (q.x > 0.24 and q.x < 0.76 and q.y > 0.28 and q.y < 0.62) \
					or q.distance_to(Vector2(0.24, 0.5)) < 0.2 or q.distance_to(Vector2(0.76, 0.5)) < 0.2 \
					or q.distance_to(Vector2(0.18, 0.66)) < 0.13 or q.distance_to(Vector2(0.82, 0.66)) < 0.13
			if not body:
				return INF
			var dpad := (absf(q.x - 0.27) < 0.035 and absf(q.y - 0.46) < 0.1) or (absf(q.y - 0.46) < 0.035 and absf(q.x - 0.27) < 0.1)
			var buttons := q.distance_to(Vector2(0.68, 0.42)) < 0.05 or q.distance_to(Vector2(0.78, 0.52)) < 0.05
			return HOLE if dpad or buttons else FILL
		"hud":
			var d := _rect_outline(q, Vector2(0.04, 0.2), Vector2(0.96, 0.8))
			# H, U, D.
			d = minf(d, _lines(q, [[0.17, 0.35, 0.17, 0.65], [0.33, 0.35, 0.33, 0.65], [0.17, 0.5, 0.33, 0.5]]))
			d = minf(d, _poly(q, [0.42, 0.35, 0.42, 0.65, 0.58, 0.65, 0.58, 0.35]))
			d = minf(d, _poly(q, [0.67, 0.35, 0.67, 0.65, 0.76, 0.65, 0.84, 0.57, 0.84, 0.43, 0.76, 0.35, 0.67, 0.35]))
			return d
		"blur":
			var d := _lines(q, [[0.06, 0.32, 0.44, 0.32], [0.02, 0.5, 0.36, 0.5], [0.1, 0.68, 0.44, 0.68]])
			if _in(q, [0.5, 0.26, 0.74, 0.26, 0.95, 0.5, 0.74, 0.74, 0.5, 0.74, 0.62, 0.5]):
				d = FILL
			return d
		"camera":
			var body := (q.x > 0.06 and q.x < 0.94 and q.y > 0.3 and q.y < 0.84) \
					or _in(q, [0.32, 0.31, 0.38, 0.18, 0.62, 0.18, 0.68, 0.31])
			if not body:
				return INF
			var r := q.distance_to(Vector2(0.5, 0.57))
			return HOLE if r > 0.1 and r < 0.2 else FILL
		"bolt":
			return FILL if _in(q, [0.6, 0.02, 0.18, 0.56, 0.46, 0.56, 0.36, 0.98, 0.82, 0.4, 0.54, 0.4]) else INF
		"note":
			if q.distance_to(Vector2(0.3, 0.76)) < 0.14 or q.distance_to(Vector2(0.74, 0.66)) < 0.14 \
					or _in(q, [0.39, 0.18, 0.88, 0.06, 0.88, 0.22, 0.39, 0.34]):
				return FILL
			return _lines(q, [[0.41, 0.24, 0.41, 0.76], [0.85, 0.12, 0.85, 0.66]])
		"wave":
			var heights := [0.16, 0.36, 0.62, 0.42, 0.8, 0.42, 0.62, 0.36, 0.16]
			var d := INF
			for i in heights.size():
				var x := 0.1 + i * 0.1
				d = minf(d, _segment(q, Vector2(x, 0.5 - heights[i] * 0.5), Vector2(x, 0.5 + heights[i] * 0.5)))
			return d
		"accelerate":
			return minf(_poly(q, [0.16, 0.18, 0.46, 0.5, 0.16, 0.82]), _poly(q, [0.5, 0.18, 0.8, 0.5, 0.5, 0.82]))
		"brake":
			return minf(_poly(q, [0.18, 0.16, 0.5, 0.44, 0.82, 0.16]), _poly(q, [0.18, 0.52, 0.5, 0.8, 0.82, 0.52]))
		"arrow_left", "arrow_right":
			var p := q if kind == "arrow_left" else Vector2(1.0 - q.x, q.y)
			if _in(p, [0.08, 0.5, 0.46, 0.16, 0.46, 0.84]):
				return FILL
			return _segment(p, Vector2(0.44, 0.5), Vector2(0.92, 0.5))
		"drift":
			var d := INF
			for x0 in [0.06, 0.56]:
				var x1: float = x0 + 0.36
				d = minf(d, _poly(q, [x1, 0.22, x0, 0.22, x0, 0.5, x1, 0.5, x1, 0.78, x0, 0.78]))
			return d
		"crosshair":
			if q.distance_to(Vector2(0.5, 0.5)) < 0.07:
				return FILL
			return minf(absf(q.distance_to(Vector2(0.5, 0.5)) - 0.3),
					_lines(q, [[0.5, 0.04, 0.5, 0.3], [0.5, 0.7, 0.5, 0.96], [0.04, 0.5, 0.3, 0.5], [0.7, 0.5, 0.96, 0.5]]))
		"ramp":
			if _in(q, [0.04, 0.88, 0.96, 0.88, 0.96, 0.46]):
				return FILL
			return _poly(q, [0.08, 0.6, 0.62, 0.2, 0.42, 0.2, 0.62, 0.2, 0.62, 0.38])
		"slot1", "slot2":
			var d := _rect_outline(q, Vector2(0.1, 0.12), Vector2(0.9, 0.88))
			if kind == "slot1":
				d = minf(d, _poly(q, [0.4, 0.34, 0.54, 0.26, 0.54, 0.74]))
			else:
				d = minf(d, _poly(q, [0.36, 0.34, 0.44, 0.26, 0.58, 0.26, 0.65, 0.34, 0.63, 0.45, 0.36, 0.73, 0.66, 0.73]))
			return d
		"look_back":
			return absf(_segment(q, Vector2(0.28, 0.5), Vector2(0.72, 0.5)) - 0.22)
		"reset":
			var a := atan2(q.y - 0.5, q.x - 0.5)
			var d := INF
			if not (a > -1.45 and a < -0.35):
				d = absf(q.distance_to(Vector2(0.5, 0.5)) - 0.32)
			if _in(q, [0.44, 0.04, 0.74, 0.18, 0.44, 0.34]):
				d = FILL
			return d
		"pause":
			var bar := q.y > 0.14 and q.y < 0.86 and ((q.x > 0.22 and q.x < 0.4) or (q.x > 0.6 and q.x < 0.78))
			return FILL if bar else INF
		"clapper":
			if q.x > 0.08 and q.x < 0.92 and q.y > 0.44 and q.y < 0.88:
				return FILL
			# Striped clapstick, tilted up.
			var p := (q - Vector2(0.08, 0.38)).rotated(0.22)
			if p.x > 0.0 and p.x < 0.86 and p.y > -0.17 and p.y < -0.02:
				return HOLE if fposmod(p.x + p.y, 0.2) < 0.08 else FILL
			return INF
		"layers":
			var d := _poly(q, [0.5, 0.12, 0.92, 0.32, 0.5, 0.52, 0.08, 0.32, 0.5, 0.12])
			d = minf(d, _poly(q, [0.08, 0.5, 0.5, 0.7, 0.92, 0.5]))
			return minf(d, _poly(q, [0.08, 0.68, 0.5, 0.88, 0.92, 0.68]))
		"palette":
			if q.distance_to(Vector2(0.5, 0.5)) > 0.44:
				return INF
			for hole in [Vector2(0.3, 0.38), Vector2(0.48, 0.24), Vector2(0.68, 0.32), Vector2(0.28, 0.6)]:
				if q.distance_to(hole) < 0.075:
					return HOLE
			return HOLE if q.distance_to(Vector2(0.64, 0.68)) < 0.12 else FILL
		"fonts":
			var d := _poly(q, [0.04, 0.8, 0.26, 0.2, 0.48, 0.8])
			d = minf(d, _segment(q, Vector2(0.13, 0.58), Vector2(0.39, 0.58)))
			d = minf(d, absf(q.distance_to(Vector2(0.74, 0.64)) - 0.15))
			return minf(d, _segment(q, Vector2(0.89, 0.44), Vector2(0.89, 0.8)))
		"brush":
			# Handle up-right, bristles down-left, a drip under the tip.
			var p := (q - Vector2(0.5, 0.5)).rotated(PI * 0.25)
			if absf(p.x) < 0.075 and p.y > -0.48 and p.y < 0.02:
				return FILL
			if absf(p.x) < 0.14 and p.y > 0.06 and p.y < 0.24:
				return FILL
			if p.y >= 0.24 and p.y < 0.42 and absf(p.x) < 0.14 * (1.0 - (p.y - 0.24) / 0.22):
				return FILL
			return INF
		"stripes":
			return minf(_poly(q, [0.06, 0.86, 0.32, 0.14, 0.58, 0.86]), _poly(q, [0.42, 0.86, 0.68, 0.14, 0.94, 0.86]))
		"rim":
			var r := q.distance_to(Vector2(0.5, 0.5))
			var d := minf(absf(r - 0.4), absf(r - 0.12))
			for i in 5:
				var a := TAU * i / 5.0 - PI * 0.5
				d = minf(d, _segment(q, Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.12,
						Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.4))
			return d
		"plate":
			var d := _rect_outline(q, Vector2(0.04, 0.22), Vector2(0.96, 0.78))
			# P, L, A, T, E in small strokes.
			d = minf(d, _poly(q, [0.13, 0.66, 0.13, 0.34, 0.24, 0.34, 0.24, 0.5, 0.13, 0.5]))
			d = minf(d, _poly(q, [0.3, 0.34, 0.3, 0.66, 0.4, 0.66]))
			d = minf(d, _poly(q, [0.44, 0.66, 0.5, 0.34, 0.56, 0.66]))
			d = minf(d, _lines(q, [[0.6, 0.34, 0.72, 0.34], [0.66, 0.34, 0.66, 0.66]]))
			return minf(d, _poly(q, [0.87, 0.34, 0.77, 0.34, 0.77, 0.66, 0.87, 0.66]))
		"burst":
			var c := Vector2(0.5, 0.42)
			if q.distance_to(c) < 0.13:
				return FILL
			var d := _segment(q, Vector2(0.06, 0.86), Vector2(0.94, 0.86))
			for i in 8:
				var a := TAU * i / 8.0
				var dir := Vector2(cos(a), sin(a))
				d = minf(d, _segment(q, c + dir * 0.22, c + dir * 0.36))
			return d
		"exhaust":
			# Twin pipes seen from the side with a puff.
			var d := INF
			for y in [0.4, 0.62]:
				d = minf(d, _rect_outline(q, Vector2(0.3, y - 0.08), Vector2(0.92, y + 0.08)))
				d = minf(d, absf(Vector2((q.x - 0.3) * 2.0, q.y - y).length() - 0.08) * 0.5)
			return minf(d, absf(q.distance_to(Vector2(0.14, 0.32)) - 0.1))
	return INF


static func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Distance to separate segments, each [x0, y0, x1, y1].
static func _lines(q: Vector2, segs: Array) -> float:
	var d := INF
	for s in segs:
		d = minf(d, _segment(q, Vector2(s[0], s[1]), Vector2(s[2], s[3])))
	return d


## Distance to an open polyline given as flat x, y pairs.
static func _poly(q: Vector2, xy: Array) -> float:
	var d := INF
	for i in range(0, xy.size() - 2, 2):
		d = minf(d, _segment(q, Vector2(xy[i], xy[i + 1]), Vector2(xy[i + 2], xy[i + 3])))
	return d


static func _rect_outline(q: Vector2, a: Vector2, b: Vector2) -> float:
	return _poly(q, [a.x, a.y, b.x, a.y, b.x, b.y, a.x, b.y, a.x, a.y])


## Point in a filled polygon given as flat x, y pairs.
static func _in(q: Vector2, xy: Array) -> bool:
	var pts := PackedVector2Array()
	for i in range(0, xy.size(), 2):
		pts.append(Vector2(xy[i], xy[i + 1]))
	return Geometry2D.is_point_in_polygon(q, pts)
