class_name CupBadge
extends Control
## A cup's badge on the cup screen, Mario Kart style, drawn in code: a round
## medallion with a bright gradient in the cup's colours, a thick gold rim,
## the cup's map in the middle and a glossy shine. The selected badge grows a
## little and pulses with a soft glow. "random" shows a big question mark.
## Locked cups are grey with a padlock.
## Card mode (a title given): the cup screen's rounded card after
## "reference files/Cyberwave 2199_ Europe Cup Grand Prix.png": the cup's
## colours top to bottom, a faint checker, the white map between gold
## laurels and the name underneath. Selected: gold edge, a soft pulse, a
## little bigger, and a pointer under the card towards the panel.

## Room left under a card for the selected pointer.
const POINTER := 20.0

const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.62, 0.42, 0.06)
## Inner and outer gradient colours per emblem.
const COLORS := {
	"usa": [Color(0.86, 0.2, 0.25), Color(0.1, 0.16, 0.5)],
	"europe": [Color(0.22, 0.45, 0.95), Color(0.05, 0.1, 0.42)],
	"asia": [Color(1.0, 0.45, 0.2), Color(0.6, 0.06, 0.1)],
	"south_america": [Color(0.3, 0.8, 0.3), Color(0.05, 0.38, 0.2)],
	"random": [Color(0.75, 0.4, 1.0), Color(0.28, 0.06, 0.48)],
}

var emblem: String = ""
var locked: bool = false
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## Card mode: the name drawn on the card ("" = round medallion).
var title: String = ""

var _grow: float = 0.0
var _time: float = 0.0


func _init(p_emblem: String = "", p_locked: bool = false, side: float = 150.0, p_title: String = "",
		card_size: Vector2 = Vector2.ZERO) -> void:
	emblem = p_emblem
	locked = p_locked
	title = p_title
	custom_minimum_size = Vector2.ONE * side if title == "" else card_size + Vector2(0, POINTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var target := 1.0 if selected else 0.0
	var before := _grow
	_grow = move_toward(_grow, target, delta * 6.0)
	_time += delta
	if selected or _grow != before:
		queue_redraw()


func _draw() -> void:
	if title != "":
		_draw_card()
		return
	var side := minf(size.x, size.y)
	var c := size * 0.5
	var r := side * 0.4 * (1.0 + 0.12 * _grow)
	var cols: Array = COLORS.get(emblem, COLORS["random"])
	var inner: Color = cols[0]
	var outer: Color = cols[1]
	if locked:
		inner = Color(0.5, 0.5, 0.55)
		outer = Color(0.22, 0.22, 0.26)
	# Glow behind the selected badge.
	if _grow > 0.0:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var glow := Color(GOLD, 0.0)
		for k in 6:
			glow.a = (0.1 - k * 0.014) * _grow * (0.7 + 0.3 * pulse)
			draw_circle(c, r * (1.12 + k * 0.05), glow)
	# Drop shadow, then the gradient disc (concentric circles, outer to inner).
	draw_circle(c + Vector2(0, r * 0.06), r * 1.04, Color(0, 0, 0, 0.35))
	var rings := 14
	for k in rings:
		var t := float(k) / (rings - 1)
		draw_circle(c - Vector2(0, r * 0.12 * t), r * (1.0 - 0.75 * t), outer.lerp(inner, t))
	# Emblem.
	var box := Rect2(c - Vector2(r, r) * 0.68, Vector2(r, r) * 1.36)
	if emblem == "random":
		var font := ThemeDB.fallback_font
		var fs := int(r * 1.2)
		var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := c + Vector2(-text_size.x * 0.5, text_size.y * 0.32)
		draw_string_outline(font, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(r * 0.08), GOLD_DARK)
		draw_string(font, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	else:
		var fill := Color(1, 1, 1, 0.94) if not locked else Color(0.82, 0.82, 0.86)
		TrophyIcon.draw_emblem(self, emblem, box, fill, GOLD_DARK if not locked else Color(0.35, 0.35, 0.4), maxf(1.0, r * 0.025), locked)
	# Shine across the top.
	var shine := PackedVector2Array()
	for k in 13:
		var a := lerpf(PI * 1.15, PI * 1.85, k / 12.0)
		shine.append(c + Vector2(cos(a), sin(a)) * r * 0.86)
	for k in 13:
		var a := lerpf(PI * 1.85, PI * 1.15, k / 12.0)
		shine.append(c + Vector2(cos(a) * 0.86, sin(a) * 0.55) * r * 0.86 + Vector2(0, -r * 0.05))
	draw_colored_polygon(shine, Color(1, 1, 1, 0.16))
	# Thick gold rim (brighter when selected), with a dark inner line.
	var rim := GOLD if not locked else Color(0.62, 0.62, 0.66)
	rim = rim.lerp(Color(1.0, 0.95, 0.7), 0.4 * _grow)
	draw_arc(c, r, 0.0, TAU, 64, GOLD_DARK if not locked else Color(0.3, 0.3, 0.34), r * 0.14, true)
	draw_arc(c, r, 0.0, TAU, 64, rim, r * 0.09, true)
	draw_arc(c, r * 0.93, 0.0, TAU, 64, Color(0, 0, 0, 0.35), r * 0.02, true)
	if locked:
		var lc := c + Vector2(0, r * 0.15)
		draw_arc(lc - Vector2(0, r * 0.12), r * 0.16, PI, TAU, 16, Color(0.95, 0.95, 1.0), r * 0.06, true)
		draw_rect(Rect2(lc - Vector2(r * 0.22, r * 0.12), Vector2(r * 0.44, r * 0.34)), Color(0.95, 0.95, 1.0))


func _draw_card() -> void:
	var cols: Array = COLORS.get(emblem, COLORS["random"])
	var top: Color = (cols[0] as Color).lightened(0.05)
	var bottom: Color = (cols[1] as Color)
	if emblem == "usa":
		top = Color(0.85, 0.15, 0.4)
		bottom = Color(0.32, 0.06, 0.38)
	if locked:
		top = Color(0.42, 0.42, 0.46)
		bottom = Color(0.16, 0.16, 0.19)
	var card := Rect2(Vector2.ZERO, Vector2(size.x, size.y - POINTER)).grow(-6.0)
	var grow := 1.0 + 0.05 * _grow
	var centre := card.get_center()
	draw_set_transform(centre * (1.0 - grow), 0.0, Vector2.ONE * grow)
	var radius := 18.0
	var pts := NeonPanel.rounded_rect(card, radius)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	# Glow behind the selected card.
	if _grow > 0.0:
		var ring := pts.duplicate()
		ring.append(pts[0])
		for k in 4:
			draw_polyline(ring, Color(GOLD, (0.16 - k * 0.035) * _grow * (0.7 + 0.3 * pulse)), 8.0 + k * 8.0, true)
	var fill := PackedColorArray()
	for p in pts:
		fill.append(top.lerp(bottom, (p.y - card.position.y) / card.size.y))
	draw_polygon(pts, fill)
	# Faint slanted checker across the lower half.
	var cell := card.size.y * 0.1
	var y0 := card.position.y + card.size.y * 0.55
	var rows := int((card.end.y - radius * 0.6 - y0) / cell)
	for r in rows:
		var x := card.position.x + radius * 0.5 + (r % 2) * cell
		while x + cell * 1.4 < card.end.x - radius * 0.5:
			var y := y0 + r * cell
			draw_colored_polygon(PackedVector2Array([Vector2(x + cell * 0.3, y), Vector2(x + cell * 1.3, y),
					Vector2(x + cell, y + cell), Vector2(x, y + cell)]), Color(1, 1, 1, 0.06))
			x += cell * 2.0
	# Shine across the top.
	draw_rect(Rect2(card.position + Vector2(radius, 3), Vector2(card.size.x - radius * 2.0, 2)), Color(1, 1, 1, 0.18))

	# Laurels, with the map (or a padlock / "?") between them.
	var art_h := card.size.y * 0.58
	var art := Rect2(Vector2(centre.x - art_h * 0.62, card.position.y + card.size.y * 0.05), Vector2(art_h * 1.24, art_h))
	var laurel := RaceIcons.texture("laurel", int(art_h))
	var laurel_col := Color(1.0, 0.78, 0.2) if not locked else Color(0.62, 0.62, 0.66)
	draw_texture_rect(laurel, Rect2(Vector2(centre.x - art_h * 0.62, art.position.y), Vector2(art_h * 1.24, art_h)), false, laurel_col)
	var inner := Rect2(art.position + art.size * Vector2(0.22, 0.14), art.size * Vector2(0.56, 0.62))
	if locked:
		var lock_px := int(inner.size.y * 0.95)
		draw_texture_rect(RaceIcons.texture("lock", lock_px),
				Rect2(inner.get_center() - Vector2.ONE * lock_px * 0.5, Vector2.ONE * lock_px), false, Color(0.92, 0.92, 0.96))
	elif emblem == "random":
		_draw_centered_text("?", inner.get_center() + Vector2(0, inner.size.y * 0.3), int(inner.size.y * 1.1), Color.WHITE)
	else:
		TrophyIcon.draw_emblem(self, emblem, inner, Color(1, 1, 1, 0.96), Color(1, 1, 1, 0.0), 0.0, false)

	# The name, one or two lines.
	var words := title.split(" ")
	var lines: PackedStringArray = [title]
	if words.size() > 1:
		lines = [" ".join(words.slice(0, words.size() - 1)), words[words.size() - 1]]
	var fs := int(clampf(card.size.y * 0.15, 14.0, 30.0))
	var font := UIStyle.slanted_font(true)
	var longest := 0.0
	for l in lines:
		longest = maxf(longest, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	if longest > card.size.x - 24.0:
		fs = int(fs * (card.size.x - 24.0) / longest)
	var line_h := fs * 0.95
	var base := card.end.y - card.size.y * 0.08 - line_h * (lines.size() - 1)
	for i in lines.size():
		_draw_centered_text(lines[i], Vector2(centre.x, base + i * line_h), fs,
				Color.WHITE if not locked else Color(0.85, 0.85, 0.88))

	# The edge: the cup's colour, or gold (thicker, pulsing) when selected.
	var ring := pts.duplicate()
	ring.append(pts[0])
	var edge := top.lightened(0.35) if not locked else Color(0.6, 0.6, 0.65)
	edge = edge.lerp(Color(1.0, 0.86, 0.3), _grow)
	draw_polyline(ring, Color(edge, 0.3), 7.0, true)
	draw_polyline(ring, edge, 2.5 + 2.5 * _grow, true)
	if _grow > 0.0:
		draw_polyline(ring, Color(1, 1, 0.85, 0.5 * _grow * pulse), 1.5, true)
	draw_set_transform(Vector2.ZERO)
	# Pointer under the selected card.
	if _grow > 0.0:
		var tip := Vector2(centre.x, size.y - 2.0)
		var w := 16.0 * _grow
		var tri := PackedVector2Array([Vector2(tip.x - w, card.end.y * grow - centre.y * (grow - 1.0) - 1.0),
				Vector2(tip.x + w, card.end.y * grow - centre.y * (grow - 1.0) - 1.0), tip])
		draw_colored_polygon(tri, Color(1.0, 0.82, 0.25, _grow))


func _draw_centered_text(text: String, baseline_centre: Vector2, fs: int, color: Color) -> void:
	var font := UIStyle.slanted_font(true)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := baseline_centre - Vector2(w * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), Color(0.06, 0.02, 0.12, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
