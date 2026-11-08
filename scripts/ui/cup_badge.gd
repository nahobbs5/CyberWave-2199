class_name CupBadge
extends Control
## A cup's badge on the cup screen, Mario Kart style, drawn in code: a round
## medallion with a bright gradient in the cup's colours, a thick gold rim,
## the cup's map in the middle and a glossy shine. The selected badge grows a
## little and pulses with a soft glow. "random" shows a big question mark.
## Locked cups are grey with a padlock.

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

var _grow: float = 0.0
var _time: float = 0.0


func _init(p_emblem: String = "", p_locked: bool = false, side: float = 150.0) -> void:
	emblem = p_emblem
	locked = p_locked
	custom_minimum_size = Vector2.ONE * side
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var target := 1.0 if selected else 0.0
	var before := _grow
	_grow = move_toward(_grow, target, delta * 6.0)
	_time += delta
	if selected or _grow != before:
		queue_redraw()


func _draw() -> void:
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
