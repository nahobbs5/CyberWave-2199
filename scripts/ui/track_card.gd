class_name TrackCard
extends Button
## A race card on the cup screens, after "reference files/Cyberwave 2199_
## Europe Cup Grand Prix.png": a screenshot of the track (rounded, darkened
## towards the bottom), a magenta race-number tab, the name and a pin +
## location along the bottom, and a neon edge (gold when focused).
## The screenshot is assets/ui/tracks/<scene file name>.png; without one the
## card shows the track's outline instead. A small outline ("Thumbnail")
## always sits in the top-right corner as a mini map.
## TrackCard.random() makes the Versus RANDOM card.

const PHOTO_DIR := "res://assets/ui/tracks/"
const RADIUS := 14.0
const PHOTO_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(300.0, 200.0);
uniform vec2 tex_size = vec2(640.0, 360.0);
uniform float radius = 14.0;
uniform float dim = 1.0;
void fragment() {
	// Cover the card (crop the long side), round the corners, shade the bottom.
	float rs = rect_size.x / rect_size.y;
	float ts = tex_size.x / tex_size.y;
	vec2 uv = UV;
	if (ts > rs) {
		uv.x = 0.5 + (UV.x - 0.5) * rs / ts;
	} else {
		uv.y = 0.5 + (UV.y - 0.5) * ts / rs;
	}
	vec4 c = texture(TEXTURE, uv);
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	c.rgb *= mix(1.0, 0.22, smoothstep(0.42, 1.0, UV.y)) * dim;
	COLOR = c;
}
"""

static var _shader: Shader

var track: String = ""
## Race number in its cup (1-based; 0 for RANDOM).
var number: int = 0
## The screenshot (null when the track has none).
var photo: TextureRect
var thumbnail: TrackThumbnail
var name_label: Label
var location_label: Label
## Versus: best time line ("" in Grand Prix).
var best_label: Label

var _photo_material: ShaderMaterial


## The screenshot's path for a track scene, or "" if there isn't one.
static func photo_path(scene_path: String) -> String:
	var path := PHOTO_DIR + scene_path.get_file().get_basename() + ".png"
	return path if ResourceLoader.exists(path) else ""


static func random(note: String, enabled: bool) -> TrackCard:
	var card := TrackCard.new()
	card.name = "Track_Random"
	card.disabled = not enabled
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var art := CupBadge.new("random", false, 96.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	card.name_label = card._title("RANDOM", 26)
	box.add_child(card.name_label)
	var sub := UIStyle.stat(note, 17, UIStyle.CYAN)
	sub.add_theme_font_override("font", UIStyle.slanted_font(false))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)
	card.add_child(_Frame.new(card))
	return card


## A card for race `index` of `cup`. show_best: the best-time line (Versus).
static func for_race(cup: GrandPrixData, index: int, show_best: bool, laps: int) -> TrackCard:
	var card := TrackCard.new()
	card.track = cup.track_names[index]
	card.number = index + 1
	card.name = "Track_%s" % card.track.replace(" ", "")
	card.disabled = not cup.is_track_built(index)
	var scene := cup.track_scenes[index] if index < cup.track_scenes.size() else TrackCatalog.scene_path(card.track)
	var shot := photo_path(scene) if not card.disabled else ""
	if shot != "":
		card._add_photo(load(shot) as Texture2D)
	card.thumbnail = TrackThumbnail.new(scene, Vector2(84, 56) if shot != "" else Vector2(220, 100))
	card.thumbnail.name = "Thumbnail"
	if shot != "":
		card.thumbnail.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		card.thumbnail.offset_left = -84 - 10
		card.thumbnail.offset_right = -10
		card.thumbnail.offset_top = 10
		card.thumbnail.offset_bottom = 10 + 56
		card.thumbnail.modulate = Color(1, 1, 1, 0.85)
	else:
		card.thumbnail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		card.thumbnail.offset_left = -110
		card.thumbnail.offset_right = 110
		card.thumbnail.offset_top = 16
		card.thumbnail.offset_bottom = 116
	card.add_child(card.thumbnail)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_bottom = -10
	box.offset_top = -10
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	card.name_label = card._title(card.track.to_upper() if not card.disabled else "COMING SOON", 24)
	box.add_child(card.name_label)
	var where := cup.locations[index] if index < cup.locations.size() else TrackCatalog.location(card.track)
	var loc_row := HBoxContainer.new()
	loc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loc_row.add_theme_constant_override("separation", 6)
	loc_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(loc_row)
	if where != "":
		loc_row.add_child(RaceIcons.rect("pin", 18))
	card.location_label = UIStyle.label(where if not card.disabled else "Still being built", 18, Color(1, 1, 1, 0.92))
	card.location_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	card.location_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	card.location_label.add_theme_constant_override("outline_size", 4)
	loc_row.add_child(card.location_label)
	if show_best and not card.disabled and not GameSession.split_screen:
		var best := PlayerProfile.get_profile().best_for(card.track, laps)
		var text := "Best (%d laps): %s" % [laps, RaceProgress.format_time(float(best.race))] if best.has("race") else "No time yet"
		card.best_label = UIStyle.stat(text, 15, UIStyle.CYAN)
		card.best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.best_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		card.best_label.add_theme_constant_override("outline_size", 4)
		box.add_child(card.best_label)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := NeonWidgets.Checker.new(Color(UIStyle.MAGENTA, 0.85), 2, false)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	corner.offset_left = 8
	corner.offset_right = 8 + 60
	corner.offset_top = -30
	corner.offset_bottom = -8
	card.add_child(corner)
	card.add_child(_Frame.new(card))
	return card


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(280, 196)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func() -> void:
		if not disabled and focus_mode != Control.FOCUS_NONE:
			grab_focus())
	resized.connect(_on_resized)


## Shown, not picked (Grand Prix races the whole cup).
func set_display_only() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func has_photo() -> bool:
	return photo != null


func _add_photo(tex: Texture2D) -> void:
	if tex == null:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PHOTO_SHADER
	photo = TextureRect.new()
	photo.name = "Photo"
	photo.texture = tex
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_SCALE
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_material = ShaderMaterial.new()
	_photo_material.shader = _shader
	_photo_material.set_shader_parameter("tex_size", tex.get_size())
	_photo_material.set_shader_parameter("radius", RADIUS)
	_photo_material.set_shader_parameter("dim", 0.45 if disabled else 1.0)
	photo.material = _photo_material
	add_child(photo)


func _on_resized() -> void:
	if _photo_material != null:
		_photo_material.set_shader_parameter("rect_size", size)
	queue_redraw()


func _title(text: String, fs: int) -> Label:
	var l := UIStyle.stat(text, fs, Color.WHITE)
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _draw() -> void:
	# Behind everything: a dark rounded fill (all a card without a photo has).
	var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), RADIUS)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(0.1, 0.04, 0.22, 0.95).lerp(Color(0.03, 0.01, 0.08, 0.95), p.y / maxf(size.y, 1.0)))
	draw_polygon(pts, cols)


## Drawn over the card's children: the neon edge and the number tab.
class _Frame extends Control:
	var card: TrackCard

	func _init(p_card: TrackCard) -> void:
		card = p_card
		name = "Frame"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.focus_entered.connect(queue_redraw)
		card.focus_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := NeonPanel.rounded_rect(Rect2(Vector2.ZERO, size), TrackCard.RADIUS)
		pts.append(pts[0])
		var focused := card.has_focus()
		var edge := Color(0.95, 0.3, 0.9) if not card.disabled else Color(0.5, 0.45, 0.6)
		if focused:
			edge = Color(1.0, 0.86, 0.3)
		draw_polyline(pts, Color(edge, 0.25), 10.0 if focused else 7.0, true)
		draw_polyline(pts, edge, 3.5 if focused else 2.5, true)
		if focused:
			draw_polyline(pts, Color(1, 1, 0.9, 0.7), 1.2, true)
		if card.number <= 0:
			return
		# Number tab, top-left: a magenta parallelogram.
		var h := 40.0
		var w := 58.0
		var tab := PackedVector2Array([Vector2(TrackCard.RADIUS * 0.5, 2), Vector2(w + 14, 2), Vector2(w, h),
				Vector2(2, h), Vector2(2, TrackCard.RADIUS * 0.5)])
		draw_colored_polygon(tab, UIStyle.MAGENTA if not card.disabled else Color(0.45, 0.4, 0.5))
		draw_polyline(tab + PackedVector2Array([tab[0]]), Color(1, 0.7, 0.95, 0.8), 1.5, true)
		var font := UIStyle.slanted_font(true)
		var fs := 30
		var t := str(card.number)
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var baseline := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string_outline(font, Vector2((w + 4 - tw) * 0.5, baseline), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4,
				Color(0.2, 0.0, 0.2, 0.8))
		draw_string(font, Vector2((w + 4 - tw) * 0.5, baseline), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
