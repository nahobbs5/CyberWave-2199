class_name SetupWidgets
extends RefCounted
## Pieces of the neon race setup and cup screens ("reference files/Neon
## Versus Race Setup UI.png" and "Cyberwave 2199_ Europe Cup Grand
## Prix.png"): setting rows (icon, label, stepper or toggle), the gold
## header banner, the big gold action button and a coin pill in the
## top-right corner.

const GOLD_TOP := Color(1.0, 0.86, 0.25)
const GOLD_BOTTOM := Color(0.98, 0.62, 0.06)
const DARK_TEXT := Color(0.08, 0.03, 0.12)


## A rounded dark row: icon, label, then `control` on the right. The row's
## edge turns gold while the control has focus.
static func setting_row(icon_kind: String, text: String, control: Control) -> SettingRow:
	var row := SettingRow.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	row.add_child(box)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(40, 0)
	holder.add_child(RaceIcons.rect(icon_kind, 32))
	box.add_child(holder)
	var l := UIStyle.label(text, 22)
	l.add_theme_font_override("font", UIStyle.slanted_font(false))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(l)
	box.add_child(control)
	row.control = control
	control.focus_entered.connect(row.queue_redraw)
	control.focus_exited.connect(row.queue_redraw)
	return row


## Gold banner across the top of a panel: art (a laurel, or a cup's trophy)
## and dark slanted lettering. Returns the banner; its Label is "Text".
static func gold_banner(text: String, art: Control = null) -> GoldBanner:
	var banner := GoldBanner.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	banner.add_child(box)
	if art == null:
		art = RaceIcons.rect("laurel", 52, Color(0.55, 0.36, 0.02))
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var l := UIStyle.stat(text, 36, DARK_TEXT)
	l.name = "Text"
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	banner.label = l
	return banner


## The big gold slanted button ("NEXT: PICK A TRACK", "START GRAND PRIX").
static func gold_action(text: String, on_pressed: Callable) -> GoldAction:
	var b := GoldAction.new(text, "flags")
	b.font_size = 32
	b.custom_minimum_size = Vector2(460, 70)
	b.pressed.connect(on_pressed)
	return b


## The coin pill, anchored to `parent`'s top-right corner.
static func add_coin_pill(parent: Control, coins: int) -> PanelContainer:
	var pill := UIStyle.coin_pill(24)
	pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -32
	pill.offset_top = 16
	(pill.find_child("Count", true, false) as Label).text = "%d Coins" % coins
	parent.add_child(pill)
	return pill


## A bar like the title's, slanted at both ends, deep blue to clear, with a
## cyan top edge (the cup panel's "EUROPE CUP" header).
static func title_bar(text: String, size: int = 40) -> SlantBar:
	var bar := SlantBar.new()
	var l := UIStyle.stat(text, size, Color.WHITE)
	l.name = "Text"
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	bar.add_child(l)
	bar.label = l
	return bar


class SettingRow extends MarginContainer:
	var control: Control

	func _init() -> void:
		add_theme_constant_override("margin_left", 16)
		add_theme_constant_override("margin_right", 8)
		add_theme_constant_override("margin_top", 5)
		add_theme_constant_override("margin_bottom", 5)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(size.y * 0.5))
		style.bg_color = Color(0.1, 0.1, 0.3, 0.88)
		style.border_color = Color(0.35, 0.45, 1.0, 0.75)
		style.set_border_width_all(2)
		if control != null and control.has_focus():
			style.bg_color = Color(0.16, 0.12, 0.36, 0.95)
			style.border_color = SetupWidgets.GOLD_TOP
			style.shadow_color = Color(SetupWidgets.GOLD_TOP, 0.3)
			style.shadow_size = 7
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		# Glassy band along the top.
		draw_line(Vector2(size.y * 0.5, 4), Vector2(size.x - size.y * 0.5, 4), Color(1, 1, 1, 0.07), 2.0)


class GoldBanner extends MarginContainer:
	var label: Label

	func _init() -> void:
		add_theme_constant_override("margin_left", 30)
		add_theme_constant_override("margin_right", 48)
		add_theme_constant_override("margin_top", 6)
		add_theme_constant_override("margin_bottom", 6)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var r := 16.0
		# Rounded top-left, square bottom, slanted right end.
		var pts := PackedVector2Array()
		for i in 7:
			var a := PI + PI * 0.5 * i / 6.0
			pts.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
		pts.append(Vector2(size.x - h * 0.35 - 10, 0))
		pts.append(Vector2(size.x - h * 0.35, 6))
		pts.append(Vector2(size.x, h))
		pts.append(Vector2(0, h))
		var cols := PackedColorArray()
		for p in pts:
			cols.append(SetupWidgets.GOLD_TOP.lerp(SetupWidgets.GOLD_BOTTOM, p.y / h))
		draw_polygon(pts, cols)
		draw_line(Vector2(r, 3), Vector2(size.x - h * 0.35 - 12, 3), Color(1, 1, 0.85, 0.6), 2.0)
		draw_line(Vector2(0, h - 1), Vector2(size.x, h - 1), Color(0.7, 0.4, 0.0, 0.8), 2.0)


class GoldAction extends NeonMenuButton:
	var _time: float = 0.0

	func _init(label_text: String = "", kind: String = "") -> void:
		super(label_text, kind, "")
		lit_override = true

	func _process(delta: float) -> void:
		var tint := Color(0.55, 0.55, 0.6, 0.8) if disabled else Color.WHITE
		if modulate != tint:
			modulate = tint
			queue_redraw() # the ">>" shows only while enabled
		if has_focus():
			_time += delta
			queue_redraw()

	func _draw() -> void:
		if has_focus():
			# White pulse around the focused button.
			var h := size.y
			var slant := h * 0.42
			var pts := PackedVector2Array([Vector2(slant - 4, -4), Vector2(size.x + 4, -4),
					Vector2(size.x - slant + 4, h + 4), Vector2(-4, h + 4), Vector2(slant - 4, -4)])
			var a := 0.45 + 0.25 * sin(_time * 5.0)
			draw_polyline(pts, Color(1, 1, 1, a * 0.4), 12.0, true)
			draw_polyline(pts, Color(1, 1, 1, a), 3.0, true)
		super()


class SlantBar extends MarginContainer:
	var label: Label

	func _init() -> void:
		add_theme_constant_override("margin_left", 22)
		add_theme_constant_override("margin_right", 60)
		add_theme_constant_override("margin_top", 2)
		add_theme_constant_override("margin_bottom", 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.35
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h)])
		var cols := PackedColorArray()
		for p in pts:
			var t := p.x / maxf(size.x, 1.0)
			cols.append(Color(0.1, 0.2, 0.7, 0.85).lerp(Color(0.1, 0.15, 0.5, 0.0), t * t))
		draw_polygon(pts, cols)
		draw_line(Vector2(s, 1), Vector2(size.x * 0.85, 1), Color(UIStyle.CYAN, 0.7), 2.0)
