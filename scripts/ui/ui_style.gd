class_name UIStyle
extends RefCounted
## Shared neon styling for the code-built menus and HUD. Colours carry
## meaning: magenta = you / selection / drifting, cyan = boost / speed /
## navigation, gold = coins and rewards, orange-red = warnings and lost
## places, white = primary text, muted = secondary. Oxanium for headings and
## big numbers, Rajdhani (the theme's default font) for everything else.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)
const GOLD := Color(1.0, 0.82, 0.3)
const WARN := Color(1.0, 0.45, 0.2)
const DANGER := Color(1.0, 0.25, 0.3)
const TEXT := Color(1, 1, 1)
const MUTED := Color(0.75, 0.7, 0.85, 0.75)
const FAINT := Color(1, 1, 1, 0.5)
const BACKGROUND := Color(0.02, 0.01, 0.06, 0.92)
## Translucent purple for HUD panels over the track.
const PANEL_BG := Color(0.05, 0.02, 0.1, 0.62)
const PANEL_BORDER := Color(0.55, 0.3, 0.8, 0.55)
const RADIUS := 6
const PADDING := 12

const HEADING_FONT_PATH := "res://assets/fonts/Oxanium-Variable.ttf"
const BOLD_FONT_PATH := "res://assets/fonts/Rajdhani-Bold.ttf"

static var _heading_font: Font
static var _bold_font: Font


## Oxanium Bold (the variable font at weight 700).
static func heading_font() -> Font:
	if _heading_font == null:
		var base := load(HEADING_FONT_PATH) as FontFile
		if base == null:
			return null
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_heading_font = v
	return _heading_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load(BOLD_FONT_PATH) as Font
	return _bold_font


## Big numbers and headings (Oxanium).
static func heading(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	var font := heading_font()
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Stats and labels in Rajdhani Bold.
static func stat(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	var font := bold_font()
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Translucent HUD panel: dark purple, thin neon border.
static func hud_panel(border: Color = PANEL_BORDER, padding: int = PADDING) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box_style(PANEL_BG, border, padding))
	return p


static func box_style(bg: Color, border: Color, padding: int = PADDING, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(padding)
	return style


## Fades a screen or panel in (150-300 ms menu transitions).
static func fade_in(control: CanvasItem, seconds: float = 0.2) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var t := control.create_tween()
	t.tween_property(control, "modulate:a", 1.0, seconds)


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func panel(border: Color = MAGENTA) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", style)
	return p


## Standard menu button (secondary look: dark fill, outline on focus).
static func button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, false)


## Filled magenta button for the main action on a screen.
static func primary_button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, true)


## Outlined button for the alternative action.
static func secondary_button(text: String, on_pressed: Callable) -> Button:
	return _make_button(text, on_pressed, false)


static func _make_button(text: String, on_pressed: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 42)
	b.add_theme_font_size_override("font_size", 19)
	var font := bold_font()
	if font != null:
		b.add_theme_font_override("font", font)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		if primary:
			style.bg_color = MAGENTA.darkened(0.25) if state in ["normal", "disabled"] else MAGENTA
			style.border_color = Color.WHITE if state == "focus" else MAGENTA.lightened(0.2)
			style.set_border_width_all(3 if state == "focus" else 2)
			if state == "disabled":
				style.bg_color = Color(0.3, 0.12, 0.28, 0.9)
		else:
			style.bg_color = Color(0.06, 0.03, 0.14, 0.95) if state != "hover" else Color(0.12, 0.05, 0.25, 0.95)
			style.border_color = MAGENTA if state in ["focus", "pressed", "hover"] else Color(1, 1, 1, 0.25)
			style.set_border_width_all(3 if state == "focus" else 2)
		if state == "focus":
			# Focus ring: a soft glow outside the border.
			style.shadow_color = Color(MAGENTA, 0.45)
			style.shadow_size = 6
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.pressed.connect(on_pressed)
	# A short pop on hover / focus.
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(_pop.bind(b))
	b.focus_entered.connect(_pop.bind(b))
	return b


static func _pop(b: Button) -> void:
	if not b.is_inside_tree() or b.disabled:
		return
	b.scale = Vector2.ONE * 1.04
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE, 0.12)


## Focus chain for keyboard / gamepad navigation in a vertical list.
static func chain_focus(buttons: Array) -> void:
	for i in buttons.size():
		var b := buttons[i] as Control
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])


## Full-screen dark background for menu screens.
static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.008, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Screen title on the left, coin balance on the right. Returns the coin label.
static func header(parent: Container, title: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(heading(title, 34, MAGENTA))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var coins := label("", 22, Color(1.0, 0.82, 0.3))
	row.add_child(coins)
	return coins


## Horizontal bar for a 1-10 stat rating.
static func stat_bar(rating: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.value = rating
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = MAGENTA
	fill.set_corner_radius_all(2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


# --- garage-style pieces -----------------------------------------------------

const LOGO_PATH := "res://assets/logo/Cyberwave 2199 Neon Cityscape.png"
const LOGO_SHADER_PATH := "res://assets/logo/logo_blend.gdshader"


## The Cyberwave logo with its black background blended away.
static func logo(size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(LOGO_PATH) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := ShaderMaterial.new()
	blend.shader = load(LOGO_SHADER_PATH) as Shader
	rect.material = blend
	return rect


## Logo on the left, screen title, coin pill on the right. Returns the
## label inside the pill (set its text to the coin count).
static func top_bar(parent: Container, title: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	row.add_child(logo(Vector2(190, 62)))
	var heading_label := heading(title, 30, MAGENTA)
	heading_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(heading_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pill := PanelContainer.new()
	var pill_style := box_style(Color(0.06, 0.03, 0.1, 0.95), GOLD, 0, 2)
	pill_style.set_corner_radius_all(20)
	pill_style.content_margin_left = 14
	pill_style.content_margin_right = 18
	pill_style.content_margin_top = 6
	pill_style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pill)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	pill.add_child(inner)
	inner.add_child(CoinIcon.new(22.0))
	var coins := stat("", 22, GOLD)
	inner.add_child(coins)
	return coins


## A left-hand list entry (garage categories): magenta-filled when selected,
## dark with a faint outline otherwise. Call again to change the look.
static func style_list_tab(b: Button, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.content_margin_left = 18
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		if selected:
			style.bg_color = Color(MAGENTA.darkened(0.45), 0.95) if state != "hover" else Color(MAGENTA.darkened(0.3), 0.95)
			style.border_color = MAGENTA
			style.set_border_width_all(2)
			style.shadow_color = Color(MAGENTA, 0.35)
			style.shadow_size = 6
		else:
			style.bg_color = Color(0.06, 0.03, 0.12, 0.9) if state != "hover" else Color(0.12, 0.05, 0.22, 0.95)
			style.border_color = MAGENTA if state in ["focus", "hover"] else Color(1, 1, 1, 0.18)
			style.set_border_width_all(2 if state == "focus" else 1)
		if state == "focus":
			style.border_color = Color.WHITE if selected else MAGENTA
		b.add_theme_stylebox_override(state, style)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)


## Small row button in the item list. kind: "buy" (gold), "equip",
## "equipped" (cyan, disabled look) or "plain".
static func row_action(text: String, kind: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(124, 34)
	b.add_theme_font_size_override("font_size", 16)
	var font := bold_font()
	if font != null:
		b.add_theme_font_override("font", font)
	var accent: Color = {"buy": GOLD, "equip": MAGENTA, "equipped": CYAN}.get(kind, Color(1, 1, 1, 0.3))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		style.bg_color = Color(0.07, 0.04, 0.12, 0.95) if state != "hover" else Color(0.14, 0.07, 0.24, 0.95)
		if kind == "equipped":
			style.bg_color = Color(CYAN, 0.12)
		style.border_color = accent if state != "normal" or kind == "equipped" else Color(accent, 0.55)
		if kind == "buy" and state == "disabled":
			style.border_color = Color(1, 1, 1, 0.15)
		style.set_border_width_all(2)
		if state == "focus":
			style.border_color = Color.WHITE
			style.shadow_color = Color(accent, 0.45)
			style.shadow_size = 5
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", CYAN if kind == "equipped" else Color(1, 1, 1, 0.35))
	if kind == "buy":
		b.icon = coin_texture()
		b.expand_icon = false
	b.pressed.connect(on_pressed)
	return b


static var _coin_texture: Texture2D


## A small gold coin as a texture (for button icons).
static func coin_texture() -> Texture2D:
	if _coin_texture == null:
		var n := 18
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n, n) * 0.5
		var gold := Color(1.0, 0.8, 0.2)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				var col := Color(0, 0, 0, 0)
				if d < c.x:
					col = gold.darkened(0.35)
				if d < c.x - 1.5:
					col = gold
				if absf(d - c.x * 0.5) < 0.8:
					col = gold.darkened(0.3)
				img.set_pixel(x, y, col)
		_coin_texture = ImageTexture.create_from_image(img)
	return _coin_texture


## The garage's big right-hand panel: dark purple fill, magenta-violet edge.
static func section_panel(padding: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var style := box_style(Color(0.035, 0.018, 0.08, 0.94), Color(0.6, 0.3, 0.9, 0.55), padding, 1)
	style.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", style)
	return p


## Small line icons drawn into an image (fonts lack these glyphs):
## "check" (a tick) or "info" (a ringed i).
static func icon_texture(kind: String, size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	var c := Vector2(s, s) * 0.5
	var w := maxf(s * 0.09, 1.2)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := INF
			match kind:
				"check":
					d = minf(_segment_distance(p, Vector2(0.15, 0.52) * s, Vector2(0.4, 0.78) * s),
							_segment_distance(p, Vector2(0.4, 0.78) * s, Vector2(0.88, 0.22) * s))
				"info":
					d = absf(p.distance_to(c) - (s * 0.5 - w))
					d = minf(d, _segment_distance(p, Vector2(0.5, 0.45) * s, Vector2(0.5, 0.74) * s))
					d = minf(d, p.distance_to(Vector2(0.5, 0.29) * s) - w * 0.4)
			var a := clampf(w * 0.5 + 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, color.a * a))
	return ImageTexture.create_from_image(img)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
