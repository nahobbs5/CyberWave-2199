class_name StandingsPanel
extends PanelContainer
## Compact live standings under the race info: one dim row per racer still
## in the race, your row bright magenta. When there isn't room for everyone
## (big HUD scale on a small screen), it shows the rows around you, and
## hides itself when even three rows won't fit.

const ROW_HEIGHT := 21.0
const MIN_ROWS := 3

## Lowest screen y (in this panel's parent space) the panel may reach.
var bottom_limit: float = INF
## The racer highlighted as "you" (split screen: this view's player);
## null = every human.
var me_racer: RaceProgress

var _rows: Array[Label] = []
var _lines: PackedStringArray = []


func _init() -> void:
	name = "Standings"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIStyle.box_style(Color(UIStyle.PANEL_BG, 0.4), Color(UIStyle.PANEL_BORDER, 0.25), 8))
	custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	for i in 8:
		var row := UIStyle.stat("", 16, UIStyle.MUTED)
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.add_theme_constant_override("outline_size", 4)
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
		room = floori((bottom_limit - position.y - 16.0) / ROW_HEIGHT)
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
		row.text = "%d   %s" % [racer.position, racer.display_name]
		var color := UIStyle.MUTED
		if _is_me(racer):
			color = UIStyle.MAGENTA if not race.is_multiplayer() else SplitScreen.PLAYER_COLORS[race.player_slot(racer)]
		elif racer.is_player:
			color = Color(SplitScreen.PLAYER_COLORS[race.player_slot(racer)], 0.75) # the other players
		row.add_theme_color_override("font_color", color)
		row.add_theme_font_size_override("font_size", 17 if _is_me(racer) else 16)


func _is_me(racer: RaceProgress) -> bool:
	return racer == me_racer if me_racer != null else racer.is_player
