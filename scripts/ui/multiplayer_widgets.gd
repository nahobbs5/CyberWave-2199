class_name MultiplayerWidgets
extends RefCounted
## Pieces shared by the neon split-screen screens (connect controllers,
## choose cars): the title frame with its subtitle bar and STEP n OF 3
## badge, side chevrons, the hint box and fading lines.


## Builds the screen frame on `screen`: NeonScreenLayout ("MULTIPLAYER"),
## the magenta subtitle bar under the title and the step badge top right.
## Content starts below the subtitle.
static func frame(screen: Control, subtitle: String, step: int) -> NeonScreenLayout:
	var layout := NeonScreenLayout.new("MULTIPLAYER", "gamepad")
	screen.add_child(layout)
	layout.back_button.focus_mode = Control.FOCUS_NONE # driven per device, not by focus
	layout.content.offset_top = 128
	layout.content.offset_bottom = -100
	var pill := SubtitlePill.new(subtitle)
	screen.add_child(pill)
	var title_row := layout.title_label.get_parent() as Control
	var place := func() -> void:
		var icon := title_row.get_child(2) as Control
		pill.position = title_row.position + Vector2(icon.position.x - 14, title_row.size.y - 4)
	title_row.resized.connect(place)
	place.call_deferred()
	var steps := StepPill.new("STEP %d OF 3" % step)
	steps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	steps.offset_left = -232
	steps.offset_right = -32
	steps.offset_top = 22
	steps.offset_bottom = 70
	screen.add_child(steps)
	screen.add_child(SideChevrons.new())
	return layout


## The gold "Next: ..." button, bottom right (driven per device: no focus).
static func next_button(text: String, on_pressed: Callable) -> NeonMenuButton:
	var b := SetupWidgets.GoldAction.new(text, "")
	b.font_size = 30
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	# The offsets set the size; NeonMenuButton's 500 px minimum would push
	# the right end (and its ">>") off the screen.
	b.custom_minimum_size = Vector2(240, 58)
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.offset_left = -34 - 470
	b.offset_right = -34
	b.offset_top = -86
	b.offset_bottom = -20
	return b


## Magenta slanted bar with spaced-out lettering, under the screen title.
class SubtitlePill extends Control:
	var text: String

	func _init(label_text: String) -> void:
		text = " ".join(label_text.split(""))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(540, 36)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.45
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h)])
		var cols := PackedColorArray()
		for p in pts:
			cols.append(UIStyle.MAGENTA.lerp(Color(0.85, 0.1, 0.75), p.x / size.x))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(UIStyle.MAGENTA, 0.3), 8.0, true)
		draw_polygon(pts, cols)
		var font := UIStyle.slanted_font(true)
		var fs := 20
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## "STEP 1 OF 3" in a slanted cyan outline.
class StepPill extends Control:
	var text: String

	func _init(label_text: String) -> void:
		text = label_text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.3
		var r := 10.0
		var pts := PackedVector2Array([Vector2(s + r, 0), Vector2(size.x - r, 0), Vector2(size.x, r),
				Vector2(size.x - s, h - r), Vector2(size.x - s - r, h), Vector2(r, h), Vector2(0, h - r), Vector2(s, r), Vector2(s + r, 0)])
		draw_colored_polygon(pts.slice(0, pts.size() - 1), Color(0.03, 0.04, 0.14, 0.85))
		draw_polyline(pts, Color(UIStyle.CYAN, 0.2), 9.0, true)
		draw_polyline(pts, UIStyle.CYAN, 2.5, true)
		var font := UIStyle.slanted_font(true)
		var fs := 22
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Magenta ">>>" at the left edge and "<<<" at the right, level with the
## bottom of the cards.
class SideChevrons extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y * 0.655
		for side in [-1.0, 1.0]:
			for k in 3:
				var x: float = (14.0 + k * 13.0) if side < 0 else (size.x - 14.0 - k * 13.0)
				var tip: float = x + 12.0 * -side
				var pts := PackedVector2Array([Vector2(x, y - 20), Vector2(tip, y), Vector2(x, y + 20)])
				var a := 1.0 - 0.22 * (2 - k)
				draw_polyline(pts, Color(UIStyle.MAGENTA, 0.2 * a), 14.0, true)
				draw_polyline(pts, Color(1.0, 0.45, 0.9, a), 5.0, true)


## A line that fades out away from the "Controllers found" label.
class FadeLine extends Control:
	var fade_left: bool

	func _init(fades_to_left: bool) -> void:
		fade_left = fades_to_left
		custom_minimum_size = Vector2(0, 4)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps := 30
		for i in steps:
			var t := float(i) / steps
			var a := t if fade_left else 1.0 - t
			draw_rect(Rect2(size.x * t, 1, size.x / steps + 1, 2), Color(UIStyle.MAGENTA.lerp(Color(0.5, 0.4, 1.0), 0.4), 0.8 * a))


## Rounded cyan outline around the hint line.
class InfoBox extends MarginContainer:
	func _init() -> void:
		add_theme_constant_override("margin_left", 28)
		add_theme_constant_override("margin_right", 34)
		add_theme_constant_override("margin_top", 10)
		add_theme_constant_override("margin_bottom", 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size.y * 0.25
		var r := size.y * 0.4
		var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), r)
		# Lean it like the other neon bars.
		for i in pts.size():
			pts[i].x += (0.5 - pts[i].y / size.y) * s
		draw_colored_polygon(pts, Color(0.03, 0.04, 0.14, 0.82))
		pts.append(pts[0])
		draw_polyline(pts, Color(UIStyle.CYAN, 0.18), 10.0, true)
		draw_polyline(pts, Color(0.3, 0.85, 1.0), 2.5, true)


## A circled "i".
class InfoGlyph extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.5, true)
		draw_circle(c + Vector2(0, -8), 2.6, Color.WHITE)
		draw_rect(Rect2(c + Vector2(-2, -3), Vector2(4, 13)), Color.WHITE)
