class_name RaceIcons
extends RefCounted
## Line icons for the race setup and cup screens, drawn like NeonIcons
## (distance from q in 0..1 icon space; filled areas negative, holes large).
## texture(kind, px) makes a white texture, cached; tint with modulate.
##
## Kinds: robot, item_box, laurel, pin, pencil, gauge, rocket, wheel,
## checker, lock. Any other kind falls back to UIStyle.cached_icon.

const KINDS: Array[String] = ["robot", "item_box", "laurel", "pin", "pencil", "gauge", "rocket", "wheel",
		"checker", "lock"]
const FILL := -1.0
const HOLE := 1.0

static var _cache: Dictionary = {}


static func texture(kind: String, px: int) -> Texture2D:
	if not KINDS.has(kind):
		return UIStyle.cached_icon(kind, px)
	var key := "%s/%d" % [kind, px]
	if not _cache.has(key):
		var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
		var s := float(px)
		var w := maxf(s * 0.09, 1.2)
		for y in px:
			for x in px:
				var d := distance(kind, Vector2(x + 0.5, y + 0.5) / s) * s
				img.set_pixel(x, y, Color(1, 1, 1, clampf(w * 0.5 + 0.5 - d, 0.0, 1.0)))
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## A TextureRect with the icon at a fixed size.
static func rect(kind: String, px: int, color: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(kind, px)
	r.modulate = color
	r.custom_minimum_size = Vector2(px, px)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func distance(kind: String, q: Vector2) -> float:
	match kind:
		"robot":
			var head := q.x > 0.18 and q.x < 0.82 and q.y > 0.3 and q.y < 0.82
			var ears := (q.x > 0.06 and q.x < 0.18 and q.y > 0.46 and q.y < 0.66) \
					or (q.x > 0.82 and q.x < 0.94 and q.y > 0.46 and q.y < 0.66)
			var antenna := (absf(q.x - 0.5) < 0.04 and q.y > 0.14 and q.y < 0.3) or q.distance_to(Vector2(0.5, 0.12)) < 0.07
			if not (head or ears or antenna):
				return INF
			var eyes := q.distance_to(Vector2(0.37, 0.5)) < 0.08 or q.distance_to(Vector2(0.63, 0.5)) < 0.08
			var mouth := absf(q.y - 0.68) < 0.03 and q.x > 0.34 and q.x < 0.66
			return HOLE if eyes or mouth else FILL
		"item_box":
			var box := q.x > 0.1 and q.x < 0.9 and q.y > 0.1 and q.y < 0.9
			if not box:
				return INF
			# "?" cut out of the box.
			var r := q.distance_to(Vector2(0.5, 0.36))
			var a := atan2(q.y - 0.36, q.x - 0.5)
			var hook := absf(r - 0.15) < 0.055 and not (a > 1.7 and a < 2.95)
			var stem := absf(q.x - 0.5) < 0.055 and q.y > 0.48 and q.y < 0.62
			var dot := q.distance_to(Vector2(0.5, 0.74)) < 0.065
			return HOLE if hook or stem or dot else FILL
		"laurel":
			# Two branches curving up from the bottom, leaves pointing out.
			var c := Vector2(0.5, 0.46)
			var d := INF
			for side in [-1.0, 1.0]:
				var p := Vector2(0.5 + (q.x - 0.5) * side, q.y) # left branch space
				var rel := p - c
				var ang := atan2(rel.y, rel.x)
				if ang > 1.75 or ang < -2.2:
					d = minf(d, absf(rel.length() - 0.34))
				for k in 5:
					var t := 1.95 + k * 0.42 # bottom-left round to top-left
					var dir := Vector2(cos(t), sin(t))
					var tangent := Vector2(-dir.y, dir.x) # pointing up the branch
					var axis := (dir * 0.8 + tangent).normalized()
					var centre := c + dir * 0.34 + axis * 0.07
					var lp := p - centre
					var u := lp.dot(axis) / 0.1
					var v := lp.dot(Vector2(-axis.y, axis.x)) / 0.042
					if u * u + v * v < 1.0:
						return FILL
			if q.y > 0.78 and absf(q.x - 0.5) < 0.12 and absf(q.y - 0.84) < 0.04:
				return FILL
			return d
		"pin":
			var c := Vector2(0.5, 0.38)
			var r := q.distance_to(c)
			var body := r < 0.3 or NeonIcons._in(q, [0.24, 0.5, 0.76, 0.5, 0.5, 0.95])
			if not body:
				return INF
			return HOLE if r < 0.12 else FILL
		"pencil":
			if NeonIcons._in(q, [0.68, 0.1, 0.9, 0.32, 0.34, 0.88, 0.12, 0.66]):
				return HOLE if NeonIcons._in(q, [0.6, 0.18, 0.82, 0.4, 0.76, 0.46, 0.54, 0.24]) else FILL
			if NeonIcons._in(q, [0.12, 0.66, 0.34, 0.88, 0.06, 0.94]):
				return FILL
			return INF
		"gauge":
			var c := Vector2(0.5, 0.62)
			var r := q.distance_to(c)
			var a := atan2(q.y - c.y, q.x - c.x)
			var d := INF
			if a < 0.25 or a > PI - 0.25:
				d = absf(r - 0.4)
			d = minf(d, NeonIcons._segment(q, c, c + Vector2(cos(-0.7), sin(-0.7)) * 0.3))
			if r < 0.07:
				d = FILL
			return d
		"rocket":
			# Leaning up and right.
			var p := (q - Vector2(0.5, 0.5)).rotated(PI * 0.25) + Vector2(0.5, 0.5)
			var body := NeonIcons._in(p, [0.5, 0.04, 0.66, 0.26, 0.66, 0.7, 0.34, 0.7, 0.34, 0.26])
			var fins := NeonIcons._in(p, [0.34, 0.5, 0.2, 0.74, 0.34, 0.68]) or NeonIcons._in(p, [0.66, 0.5, 0.8, 0.74, 0.66, 0.68])
			var flame := NeonIcons._in(p, [0.4, 0.74, 0.6, 0.74, 0.5, 0.96])
			if body:
				return HOLE if p.distance_to(Vector2(0.5, 0.36)) < 0.07 else FILL
			return FILL if fins or flame else INF
		"wheel":
			var c := Vector2(0.5, 0.5)
			var r := q.distance_to(c)
			var d := absf(r - 0.4)
			d = minf(d, NeonIcons._lines(q, [[0.12, 0.5, 0.88, 0.5], [0.5, 0.5, 0.5, 0.88]]))
			if r < 0.11:
				d = FILL
			return d
		"checker":
			# A chequered flag on a pole.
			var d := NeonIcons._segment(q, Vector2(0.14, 0.08), Vector2(0.14, 0.94))
			if NeonIcons._in(q, [0.14, 0.1, 0.9, 0.1, 0.9, 0.58, 0.14, 0.58]):
				var cx := int(floor((q.x - 0.14) / 0.19))
				var cy := int(floor((q.y - 0.1) / 0.16))
				return FILL if (cx + cy) % 2 == 0 else maxf(d, 0.05)
			return d
		"lock":
			var d := INF
			var r := q.distance_to(Vector2(0.5, 0.42))
			if q.y < 0.46:
				d = absf(r - 0.2)
			if q.x > 0.2 and q.x < 0.8 and q.y > 0.44 and q.y < 0.9:
				var hole := q.distance_to(Vector2(0.5, 0.62)) < 0.06 or (absf(q.x - 0.5) < 0.03 and q.y > 0.62 and q.y < 0.76)
				return HOLE if hole else FILL
			return d
	return INF
