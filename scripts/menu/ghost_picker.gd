class_name GhostPicker
extends Control
## Time Trial (GDD 2.5): after picking a track, choose the ghost to race.
##   Rival      a locked car, beatable by a clean run in any starter car.
##              Beat it: the car is yours (unless it's a cup / Elimination car).
##   Expert     the same car, much faster. Shown once the rival is beaten.
##              Beat it: its signature paint / animated underglow.
##   Your Best  your own best run here (once you have one).
##   No Ghost   just the clock.
## Opens on the first ghost you haven't beaten. A dimmed overlay over the
## track screen; B / Esc closes it (TrackSelect forwards ui_cancel).

signal closed

var track: String = ""
## TimeTrialCatalog.Ghost per button, in order.
var kinds: Array[int] = []
var buttons: Array[NeonMenuButton] = []
var _panel: NeonPanel


func _init(p_track: String = "") -> void:
	track = p_track
	name = "GhostPicker"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build()
	var first := default_index()
	if first >= 0:
		buttons[first].grab_focus.call_deferred()


## The ghosts on offer for this track, by TimeTrialCatalog.Ghost.
static func options(p_track: String) -> Array[int]:
	var out: Array[int] = []
	var rec := PlayerProfile.get_profile().time_trial(p_track)
	if TimeTrialCatalog.load_ghost(p_track, TimeTrialCatalog.Ghost.RIVAL) != null:
		out.append(TimeTrialCatalog.Ghost.RIVAL)
	if bool(rec.get("rival", false)) and TimeTrialCatalog.load_ghost(p_track, TimeTrialCatalog.Ghost.EXPERT) != null:
		out.append(TimeTrialCatalog.Ghost.EXPERT)
	if TimeTrialCatalog.load_ghost(p_track, TimeTrialCatalog.Ghost.BEST) != null:
		out.append(TimeTrialCatalog.Ghost.BEST)
	out.append(TimeTrialCatalog.Ghost.NONE)
	return out


## Index into `kinds` the picker opens on: the first ghost not beaten yet.
func default_index() -> int:
	var rec := PlayerProfile.get_profile().time_trial(track)
	for i in kinds.size():
		match kinds[i]:
			TimeTrialCatalog.Ghost.RIVAL:
				if not bool(rec.get("rival", false)):
					return i
			TimeTrialCatalog.Ghost.EXPERT:
				if not bool(rec.get("expert", false)):
					return i
			_:
				return i
	return 0 if not kinds.is_empty() else -1


## Races ghost `kind` on this track.
func choose(kind: int) -> void:
	GameSession.start_time_trial(get_tree(), track, kind)


func close() -> void:
	closed.emit()
	queue_free()


## Button text per ghost ("Rival  ·  Empyrean S  ·  2:41.300").
func option_text(kind: int) -> String:
	var ghost := TimeTrialCatalog.load_ghost(track, kind) if kind != TimeTrialCatalog.Ghost.NONE else null
	var label := TimeTrialCatalog.GHOST_NAMES[kind]
	if ghost == null:
		return label
	var parts := PackedStringArray([label])
	if kind != TimeTrialCatalog.Ghost.BEST:
		parts.append(VehicleCatalog.by_id(ghost.vehicle_id).display_name)
	parts.append(RaceProgress.format_time(ghost.finish_time()))
	return "  ·  ".join(parts)


func option_info(kind: int) -> String:
	var rec := PlayerProfile.get_profile().time_trial(track)
	match kind:
		TimeTrialCatalog.Ghost.RIVAL:
			if bool(rec.get("rival", false)):
				return "BEATEN"
			return "Beat it to unlock the car" if UnlockCatalog.time_trial_unlocks(TimeTrialCatalog.rival_vehicle(track)) \
					else "Beat it to face the expert"
		TimeTrialCatalog.Ghost.EXPERT:
			if bool(rec.get("expert", false)):
				return "BEATEN"
			var reward := CosmeticCatalog.by_id(TimeTrialCatalog.expert_reward(track))
			return "Beat it for %s" % (reward.display_name if reward != null else "%d coins" % TimeTrialCatalog.EXPERT_COINS)
		TimeTrialCatalog.Ghost.BEST:
			return "Your fastest run here"
	return "Just you and the clock"


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = NeonPanel.new(22, UIStyle.GOLD, UIStyle.MAGENTA)
	_panel.custom_minimum_size = Vector2(700, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var heading := UIStyle.heading("CHOOSE YOUR GHOST", 34, UIStyle.GOLD)
	heading.add_theme_font_override("font", UIStyle.slanted_font(true))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var sub := UIStyle.stat("%s  ·  %d laps  ·  1 Triple Nitro" % [track.to_upper(), TimeTrialCatalog.LAPS], 18, UIStyle.CYAN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	kinds = options(track)
	for kind in kinds:
		var b := NeonMenuButton.new(option_text(kind), _icon(kind), option_info(kind))
		b.font_size = 24
		b.custom_minimum_size = Vector2(640, 54)
		b.pressed.connect(choose.bind(kind))
		box.add_child(b)
		buttons.append(b)
		var note := UIStyle.stat(option_info(kind), 15, UIStyle.GOLD if option_info(kind) == "BEATEN" else UIStyle.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(note)
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_neighbor_left = NodePath(".")
		buttons[i].focus_neighbor_right = NodePath(".")


static func _icon(kind: int) -> String:
	match kind:
		TimeTrialCatalog.Ghost.RIVAL:
			return "car"
		TimeTrialCatalog.Ghost.EXPERT:
			return "trophy"
		TimeTrialCatalog.Ghost.BEST:
			return "person"
	return "stopwatch"
