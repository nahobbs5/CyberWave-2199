class_name SlipstreamBanner
extends Control
## "SLIPSTREAM" plate at the bottom centre while the followed car's
## slipstream boost runs (after the slipstream art): a slanted dark plate
## with cyan lettering and cyan chevron stripes either side. Fades in and
## out with the boost.

const COLOR := Color(0.25, 0.92, 1.0)

var vehicle: VehicleController
## 0..1 (tests: > 0 while shown).
var alpha: float = 0.0


func _init() -> void:
	name = "SlipstreamBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -170.0
	offset_right = 170.0
	offset_top = -74.0
	offset_bottom = -22.0
	modulate.a = 0.0
	visible = false


func is_shown() -> bool:
	return visible and alpha > 0.0


func _process(delta: float) -> void:
	var want := 1.0 if is_instance_valid(vehicle) and vehicle.is_slipstream_boosting() else 0.0
	alpha = move_toward(alpha, want, delta * (8.0 if want > alpha else 4.0))
	modulate.a = alpha
	visible = alpha > 0.0
	if visible and not GameSettings.reduced_flashing:
		queue_redraw()


func _draw() -> void:
	var h := size.y
	var w := size.x
	var s := h * 0.35
	var stripe_w := 64.0
	# Chevron stripes either side, sweeping by.
	var t := 0.0 if GameSettings.reduced_flashing else fposmod(Time.get_ticks_msec() / 400.0, 1.0)
	for side in [-1.0, 1.0]:
		for k in 3:
			var a := 0.9 - 0.25 * k
			var x0: float = (stripe_w - 16.0 - k * 20.0 - t * 6.0) if side < 0 else (w - stripe_w + 4.0 + k * 20.0 + t * 6.0)
			var lean: float = s * 0.6 * -side
			var pts := PackedVector2Array([Vector2(x0 + lean, h * 0.2), Vector2(x0 + 12.0 + lean, h * 0.2),
					Vector2(x0 + 12.0 - lean, h * 0.8), Vector2(x0 - lean, h * 0.8)])
			draw_colored_polygon(pts, Color(COLOR, a))
	# The plate.
	var px0 := stripe_w + 8.0
	var px1 := w - stripe_w - 8.0
	var plate := PackedVector2Array([Vector2(px0 + s, 0), Vector2(px1, 0), Vector2(px1 - s, h), Vector2(px0, h)])
	draw_colored_polygon(plate, Color(0.04, 0.02, 0.12, 0.85))
	var outline := plate.duplicate()
	outline.append(plate[0])
	draw_polyline(outline, Color(COLOR, 0.25), 9.0, true)
	draw_polyline(outline, Color(COLOR, 0.9), 2.0, true)
	var font := UIStyle.slanted_font(true)
	var fs := int(h * 0.6)
	var text := "SLIPSTREAM"
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var pos := Vector2((w - tw) * 0.5, base)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(COLOR, 0.25))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR)
