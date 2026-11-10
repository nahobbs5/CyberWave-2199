class_name StandingsPanel
extends PanelContainer
## Live standings under the race info, after the slipstream art: one slanted
## row per racer still in the race (place box, a shield emblem in the
## racer's colour, NAME), your row filled gold. In split screen the other
## players' names are in their colours. When there isn't room for everyone
## (big HUD scale on a small screen), it shows the rows around you, and
## hides itself when even three rows won't fit.

const ROW_HEIGHT := 28.0
const MIN_ROWS := 3

## Lowest screen y (in this panel's parent space) the panel may reach.
var bottom_limit: float = INF
## The racer highlighted as "you" (split screen: this view's player);
## null = every human.
var me_racer: RaceProgress

var _rows: Array[StandingRow] = []
var _lines: PackedStringArray = []


func _init() -> void:
	name = "Standings"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	add_theme_stylebox_override("panel", empty)
	custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	for i in 8:
		var row := StandingRow.new()
		box.add_child(row)
		_rows.append(row)


## One line per racer still in the race ("> 2  You"), whether shown or not.
func get_text() -> String:
	return "\n".join(_lines)


func refresh(race: RaceManager) -> void:
	var active: Array[RaceProgress] = []
	for racer in race.get_standings():
		if not racer.eliminated:
			active.append(racer)
	_lines.clear()
	var me := 0
	for i in active.size():
		var racer := active[i]
		_lines.append("%s%d  %s" % [">" if _is_me(racer) else " ", racer.position, racer.display_name])
		if _is_me(racer):
			me = i
	# How many rows fit above bottom_limit.
	var room := active.size()
	if bottom_limit < INF:
		room = floori((bottom_limit - position.y - 8.0) / ROW_HEIGHT)
	if room < MIN_ROWS:
		visible = false
		return
	visible = true
	var count := mini(room, active.size())
	var first := clampi(me - count / 2, 0, active.size() - count)
	for i in _rows.size():
		var row := _rows[i]
		if i >= count:
			row.visible = false
			continue
		var racer := active[first + i]
		row.visible = true
		var name_color := Color.WHITE
		if not _is_me(racer) and racer.is_player and race.is_multiplayer():
			name_color = SplitScreen.PLAYER_COLORS[race.player_slot(racer)] # the other players
		row.show_racer(racer.position, racer.display_name.to_upper(), racer.color, _is_me(racer), name_color)


func _is_me(racer: RaceProgress) -> bool:
	return racer == me_racer if me_racer != null else racer.is_player


## One standings line, drawn: place box, emblem, name.
class StandingRow extends Control:
	const GOLD_TOP := Color(1.0, 0.86, 0.25)
	const GOLD_BOTTOM := Color(0.98, 0.62, 0.06)
	const DARK := Color(0.08, 0.03, 0.12)

	var place: int = 0
	var racer_name: String = ""
	var emblem: Color = Color.WHITE
	var me: bool = false
	var name_color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(230, StandingsPanel.ROW_HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_racer(p_place: int, p_name: String, p_emblem: Color, p_me: bool, p_name_color: Color) -> void:
		if place == p_place and racer_name == p_name and me == p_me and emblem == p_emblem and name_color == p_name_color:
			return
		place = p_place
		racer_name = p_name
		emblem = p_emblem
		me = p_me
		name_color = p_name_color
		queue_redraw()

	func _draw() -> void:
		var h := size.y - 4.0
		var y0 := 2.0
		var s := h * 0.3
		var w := size.x
		# The bar.
		var bar := PackedVector2Array([Vector2(s, y0), Vector2(w, y0), Vector2(w - s, y0 + h), Vector2(0, y0 + h)])
		if me:
			var cols := PackedColorArray()
			for p in bar:
				cols.append(GOLD_TOP.lerp(GOLD_BOTTOM, (p.y - y0) / h))
			draw_polygon(bar, cols)
		else:
			var cols := PackedColorArray()
			for p in bar:
				cols.append(Color(0.05, 0.03, 0.14, 0.9).lerp(Color(0.05, 0.03, 0.14, 0.55), p.x / w))
			draw_polygon(bar, cols)
		# Place box.
		var box_w := 30.0
		var box := PackedVector2Array([Vector2(s, y0), Vector2(s + box_w, y0), Vector2(box_w, y0 + h), Vector2(0, y0 + h)])
		draw_colored_polygon(box, Color(0.75, 0.5, 0.0, 0.9) if me else Color(0.42, 0.22, 0.85, 0.95))
		var font := UIStyle.slanted_font(true)
		var fs := int(h * 0.72)
		var text := str(place)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := y0 + (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(s * 0.5 + (box_w - tw) * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				DARK if me else Color.WHITE)
		# Shield emblem in the racer's colour.
		var c := Vector2(box_w + 20.0, y0 + h * 0.5)
		var r := h * 0.42
		var shield := PackedVector2Array([c + Vector2(-r * 0.8, -r), c + Vector2(r * 0.8, -r), c + Vector2(r * 0.8, r * 0.1),
				c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1)])
		draw_colored_polygon(shield, Color(emblem.darkened(0.55), 0.95))
		var outline := shield.duplicate()
		outline.append(shield[0])
		draw_polyline(outline, emblem.lightened(0.2), 1.6, true)
		draw_circle(c + Vector2(0, -r * 0.1), r * 0.32, emblem)
		# Name.
		var name_font := UIStyle.slanted_font(false)
		var nfs := int(h * 0.68)
		var nbase := y0 + (h + name_font.get_ascent(nfs) - name_font.get_descent(nfs)) * 0.5
		draw_string(name_font, Vector2(c.x + r + 10.0, nbase), racer_name, HORIZONTAL_ALIGNMENT_LEFT,
				w - c.x - r - 20.0, nfs, DARK if me else name_color)
