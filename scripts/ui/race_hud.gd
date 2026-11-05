class_name RaceHUD
extends CanvasLayer
## Race information (GDD 11.5): position, lap, race timer, live standings,
## READY / SET / GO, wrong-way warning, results screen, and (with weapons on)
## two weapon slots, target lock, incoming-attack warning, active effects and
## hit feedback. Mode extras: Elimination info (GDD 11.6) and Grand Prix
## points / standings on the results screen (GDD 11.7). Speed and drift
## charge come from PrototypeHUD underneath.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)
const INFO_BELOW_SLOTS := Vector2(20, 96)
const INFO_TOP := Vector2(20, 16)

var race: RaceManager

var _position_label: Label
var _lap_label: Label
var _time_label: Label
var _standings_label: Label
var _center_label: Label
var _wrong_way_label: Label
var _results_panel: PanelContainer
var _results_grid: GridContainer
var _results_title: Label
var _standings_box: VBoxContainer
var _championship_grid: GridContainer
var _continue_button: Button
var _menu_button: Button
## Results buttons wake up after a moment, so a racer still mashing the
## weapon / accept button at the line doesn't skip the results.
var _buttons_delay: float = 0.0
var _mode_label: Label
var _elim_label: Label
var _feed_label: Label
var _feed_time: float = 0.0
var _center_time: float = 0.0
var _results_refresh: float = 0.0

var _combat_box: HBoxContainer
var _info_box: VBoxContainer
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _lock_label: Label
var _status_label: Label
var _incoming_label: Label
var _combat_notice: Label
var _combat_notice_time: float = 0.0
var _cue_player: AudioStreamPlayer
var _tones: Dictionary = {}
var _was_incoming: bool = false


func _ready() -> void:
	_build()


func setup(manager: RaceManager) -> void:
	race = manager
	race.countdown_tick.connect(_on_countdown_tick)
	race.lap_completed.connect(_on_lap_completed)
	race.player_finished.connect(_on_player_finished)
	race.racer_eliminated.connect(_on_racer_eliminated)
	race.racer_qualified.connect(_on_racer_qualified)
	_mode_label.text = _mode_text()
	_elim_label.visible = race.elimination != null
	_combat_box.visible = race.combat_enabled()
	_info_box.position = INFO_BELOW_SLOTS if race.combat_enabled() else INFO_TOP
	if race.combat_enabled():
		race.weapon_manager.hit_resolved.connect(_on_hit_resolved)
		# After hit_resolved, so "LOST ..." replaces the plain hit notice.
		race.weapon_manager.item_lost.connect(_on_item_lost)
		race.weapon_manager.weapon_collected.connect(_on_weapon_collected)


func is_incoming_visible() -> bool:
	return _incoming_label.visible


func get_slot_text(slot: int) -> String:
	return _slot_labels[slot].text


func is_results_visible() -> bool:
	return _results_panel.visible


func get_center_text() -> String:
	return _center_label.text if _center_label.visible else ""


func get_results_title() -> String:
	return _results_title.text


func get_continue_text() -> String:
	return _continue_button.text


func get_elimination_text() -> String:
	return _elim_label.text if _elim_label.visible else ""


func get_standings_text() -> String:
	return _standings_label.text


func _active_count() -> int:
	return race.racers.filter(func(r: RaceProgress) -> bool: return not r.eliminated).size()


func get_feed_text() -> String:
	return _feed_label.text if _feed_label.visible else ""


func _mode_text() -> String:
	var config := race.config
	if race.championship != null:
		var c := race.championship
		# Set at the start, before this race is recorded.
		return "%s  -  RACE %d / %d: %s" % [c.gp.display_name.to_upper(), c.race_index + 1, c.race_count(),
				config.track_name]
	return "%s  -  %s" % [RaceConfig.MODE_NAMES[config.mode].to_upper(), config.track_name]


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	if p.eliminated:
		_position_label.text = "OUT  P%d" % p.finish_position
	else:
		_position_label.text = "POS %d / %d" % [p.position, _active_count()]
	_lap_label.text = "LAP %d / %d" % [p.display_lap(), race.total_laps]
	var shown_time := p.finish_time if p.finished else race.race_time
	_time_label.text = "TIME " + RaceProgress.format_time(shown_time)

	var lines: PackedStringArray = []
	for racer in race.get_standings():
		if racer.eliminated:
			continue
		var marker := ">" if racer.is_player else " "
		lines.append("%s%d  %s" % [marker, racer.position, racer.display_name])
	_standings_label.text = "\n".join(lines)
	if race.elimination != null:
		_update_elimination()
	if _feed_time > 0.0:
		_feed_time -= delta
		_feed_label.visible = _feed_time > 0.0

	_wrong_way_label.visible = race.wrong_way
	if _center_time > 0.0:
		_center_time -= delta
		_center_label.visible = _center_time > 0.0

	if race.combat_enabled():
		_update_combat(delta)

	if _results_panel.visible and _buttons_delay > 0.0:
		_buttons_delay -= delta
		if _buttons_delay <= 0.0:
			_continue_button.disabled = false
			_menu_button.disabled = false
			_continue_button.grab_focus()
	elif _results_panel.visible and get_viewport().gui_get_focus_owner() == null \
			and not get_tree().paused:
		_continue_button.grab_focus() # e.g. after closing the pause menu
	if _results_panel.visible:
		_results_refresh -= delta
		if _results_refresh <= 0.0:
			_results_refresh = 0.25
			_fill_results()


func _on_countdown_tick(text: String) -> void:
	_show_center(text, 1.0 if text != "GO" else 0.8, CYAN if text != "GO" else MAGENTA)


func _on_lap_completed(racer: RaceProgress) -> void:
	if not racer.is_player or racer.finished:
		return
	var last := racer.lap_times[racer.lap_times.size() - 1]
	var text := "FINAL LAP" if racer.lap == race.total_laps else "LAP %d" % racer.lap
	_show_center("%s\n%s" % [text, RaceProgress.format_time(last)], 1.5, CYAN)


func _on_player_finished(racer: RaceProgress) -> void:
	if racer.eliminated:
		_show_center("ELIMINATED", 2.5, Color(1.0, 0.25, 0.3))
	elif race.elimination != null and racer.finish_position == 1:
		_show_center("WINNER", 2.5, MAGENTA)
	else:
		_show_center("FINISH  P%d" % racer.finish_position, 2.0, MAGENTA)
	_results_title.text = _results_heading()
	var c := race.championship
	if c == null:
		_continue_button.text = "Race again"
	elif c.is_complete():
		_continue_button.text = "Back to mode select"
	else:
		_continue_button.text = "Next race: %s" % c.current_track_name()
	_menu_button.visible = c == null or not c.is_complete()
	_continue_button.disabled = true
	_menu_button.disabled = true
	_buttons_delay = 1.5
	_standings_box.visible = c != null
	_results_panel.visible = true
	_fill_results()


func _results_heading() -> String:
	var c := race.championship
	if c == null:
		return "ELIMINATION RESULTS" if race.elimination != null else "RESULTS"
	if c.is_complete():
		return "CHAMPIONSHIP FINAL  -  %s" % c.gp.display_name.to_upper()
	return "RACE %d / %d RESULTS  -  %s" % [c.race_index, c.race_count(), race.config.track_name]


func _on_racer_eliminated(racer: RaceProgress) -> void:
	if racer.is_player:
		return
	_feed_label.text = "%s ELIMINATED" % racer.display_name
	_feed_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.4))
	_feed_label.visible = true
	_feed_time = 2.5


func _on_racer_qualified(racer: RaceProgress, spots_left: int) -> void:
	if not racer.is_player:
		return
	var after := "last place taken" if spots_left == 0 else "%d left" % spots_left
	_show_center("QUALIFIED\n%s" % after, 1.5, CYAN)


func _update_elimination() -> void:
	var tracker := race.elimination
	var active := tracker.active_racers().size()
	var text := "ACTIVE  %d / %d" % [active, race.racers.size()]
	if not tracker.is_done() and not race.player.finished:
		text += "\nELIMINATION  LAP %d MIDPOINT" % tracker.next_event_lap()
		var places := EliminationTracker.SCHEDULE[tracker.event]
		text += "\n%d of %d places left" % [tracker.spots_left(), places]
		if tracker.has_qualified(race.player):
			text += "  -  you're through"
		elif race.player.lap <= tracker.next_event_lap():
			var track := race.track
			var gate := track.get_checkpoint_offset(tracker.gate_index)
			var to_gate := fposmod(track.wrapped_delta(track.get_offset_at(race.player.vehicle.global_position), gate), track.length)
			text += "  -  %d m" % roundi(to_gate)
	elif tracker.is_done() and not race.player.finished:
		text += "\nFINAL TWO  -  first across the line wins"
	_elim_label.text = text


func _show_center(text: String, seconds: float, color: Color) -> void:
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_label.visible = true
	_center_time = seconds


func _fill_results() -> void:
	for child in _results_grid.get_children():
		child.queue_free()
	var c := race.championship
	var last_column := "PTS" if c != null else "BEST LAP"
	for header in ["POS", "RACER", "TIME", last_column]:
		_results_grid.add_child(_cell(header, CYAN, 16))
	for racer in race.get_standings():
		var color := Color.WHITE if not racer.is_player else MAGENTA
		var time_text := "Lap %d" % racer.display_lap()
		if racer.eliminated:
			time_text = "OUT  lap %d" % racer.eliminated_lap
		elif racer.finished:
			# Classified without crossing the line (GP at your finish, Elimination runner-up).
			time_text = RaceProgress.format_time(racer.finish_time) if racer.finish_time >= 0.0 else "classified"
		var last := RaceProgress.format_time(racer.best_lap)
		if c != null and not c.results.is_empty():
			last = "+%d" % c.points_in_race(c.results.size() - 1, racer.racer_id)
		_results_grid.add_child(_cell(str(racer.position), color, 18))
		_results_grid.add_child(_cell(racer.display_name, color, 18))
		_results_grid.add_child(_cell(time_text, color, 18))
		_results_grid.add_child(_cell(last, color, 18))
	if c != null:
		_fill_championship(c)


func _fill_championship(c: Championship) -> void:
	for child in _championship_grid.get_children():
		child.queue_free()
	for header in ["", "STANDINGS", "PTS"]:
		_championship_grid.add_child(_cell(header, CYAN, 16))
	var ranking := c.standings()
	for i in ranking.size():
		var id := ranking[i]
		var color := MAGENTA if id == RaceConfig.PLAYER_ID else Color.WHITE
		if i == 0 and c.is_complete():
			color = Color(1.0, 0.85, 0.3)
		_championship_grid.add_child(_cell(str(i + 1), color, 18))
		_championship_grid.add_child(_cell(_name_of(id), color, 18))
		_championship_grid.add_child(_cell(str(c.points.get(id, 0)), color, 18))


func _name_of(id: int) -> String:
	for racer in race.racers:
		if racer.racer_id == id:
			return racer.display_name
	return "?"


# --- combat --------------------------------------------------------------------

func _update_combat(delta: float) -> void:
	var car := race.player.vehicle
	var inventory := car.inventory
	for i in ItemInventory.SLOT_COUNT:
		var weapon := inventory.slots[i]
		var is_selected := i == inventory.selected
		var weapon_text := "EMPTY"
		if weapon != null:
			weapon_text = weapon.display_name
			if weapon.charges > 1:
				weapon_text += "  x%d" % inventory.charges[i]
		_slot_labels[i].text = "%d  %s" % [i + 1, weapon_text]
		_slot_labels[i].add_theme_color_override("font_color",
				weapon.color if weapon != null else Color(1, 1, 1, 0.3))
		var style := _slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = (MAGENTA if is_selected else Color(1, 1, 1, 0.15))
		style.bg_color = Color(0.02, 0.01, 0.06, 0.8 if weapon != null else 0.35)

	var targeting := car.targeting
	var current := inventory.current()
	if current != null and current.targeted and targeting != null and targeting.candidate != null:
		var progress := race.progress_of(targeting.candidate)
		var who := progress.display_name if progress != null else "?"
		_lock_label.text = ("LOCKED  %s" % who) if targeting.locked else ("locking %s..." % who)
		_lock_label.add_theme_color_override("font_color", MAGENTA if targeting.locked else Color(1, 1, 1, 0.7))
	elif current != null and current.targeted:
		_lock_label.text = "no target"
		_lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	else:
		_lock_label.text = ""

	var effects: PackedStringArray = []
	if car.status != null:
		for effect in car.status.active_effects():
			effects.append("%s %.1fs" % [String(effect).to_upper(), car.status.time_left(effect)])
		if car.status.is_protected():
			effects.append("PROTECTED")
	_status_label.text = "  ".join(effects)

	var incoming := race.weapon_manager.is_incoming(car) and not race.player.finished
	_incoming_label.visible = incoming and int(Time.get_ticks_msec() / 150) % 2 == 0
	if incoming and not _was_incoming:
		_play("incoming")
	_was_incoming = incoming

	if _combat_notice_time > 0.0:
		_combat_notice_time -= delta
		_combat_notice.visible = _combat_notice_time > 0.0


func _on_weapon_collected(vehicle: VehicleController, weapon: WeaponData) -> void:
	if vehicle == race.player.vehicle:
		_show_combat_notice("+ %s" % weapon.display_name, weapon.color)
		_play("pickup")


func _on_hit_resolved(target: VehicleController, weapon: WeaponData, shooter: VehicleController,
		blocked_by: StringName) -> void:
	var player := race.player.vehicle
	var target_name := race.progress_of(target).display_name
	if target == player:
		if blocked_by == &"shield":
			_show_combat_notice("FIREWALL BLOCKED %s" % weapon.display_name.to_upper(), Color(1.0, 0.55, 0.15))
			_play("blocked")
		elif blocked_by == &"":
			_show_combat_notice("%s!" % weapon.display_name.to_upper(), Color(1.0, 0.3, 0.3))
			_play("hurt")
	elif shooter == player:
		if blocked_by == &"":
			_show_combat_notice("HIT  %s" % target_name, weapon.color)
			_play("hit")
		else:
			_show_combat_notice("BLOCKED by %s" % target_name, Color(1, 1, 1, 0.8))


func _on_item_lost(target: VehicleController, lost: WeaponData, by_weapon: WeaponData,
		shooter: VehicleController) -> void:
	var player := race.player.vehicle
	if target == player:
		_show_combat_notice("%s!  LOST %s" % [by_weapon.display_name.to_upper(), lost.display_name], lost.color)
	elif shooter == player:
		_show_combat_notice("HIT  %s  -  stripped %s" % [race.progress_of(target).display_name, lost.display_name],
				by_weapon.color)


func _play(tone: String) -> void:
	if _tones.has(tone):
		_cue_player.stream = _tones[tone]
		_cue_player.play()


func _show_combat_notice(text: String, color: Color) -> void:
	_combat_notice.text = text
	_combat_notice.add_theme_color_override("font_color", color)
	_combat_notice.visible = true
	_combat_notice_time = 1.6


# --- layout ----------------------------------------------------------------------

func _build() -> void:
	# Race info sits below the weapon slots (moved up when weapons are off).
	_info_box = VBoxContainer.new()
	_info_box.position = INFO_BELOW_SLOTS
	add_child(_info_box)
	_mode_label = _label(13, Color(1, 1, 1, 0.6))
	_position_label = _label(34, Color.WHITE)
	_lap_label = _label(22, CYAN)
	_time_label = _label(22, Color.WHITE)
	_elim_label = _label(16, Color(1.0, 0.45, 0.5))
	_elim_label.visible = false
	_standings_label = _label(15, Color(1, 1, 1, 0.8))
	for label in [_mode_label, _position_label, _lap_label, _time_label, _elim_label, _standings_label]:
		_info_box.add_child(label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stack)
	_center_label = _label(64, CYAN)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.visible = false
	stack.add_child(_center_label)
	_wrong_way_label = _label(40, Color(1.0, 0.25, 0.25))
	_wrong_way_label.text = "WRONG WAY"
	_wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrong_way_label.visible = false
	stack.add_child(_wrong_way_label)
	_feed_label = _label(26, Color.WHITE)
	_feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feed_label.visible = false
	stack.add_child(_feed_label)

	_results_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.06, 0.88)
	style.border_color = MAGENTA
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(6)
	_results_panel.add_theme_stylebox_override("panel", style)
	_results_panel.visible = false
	stack.add_child(_results_panel)
	var results_box := VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 10)
	_results_panel.add_child(results_box)
	_results_title = _label(28, MAGENTA)
	_results_title.text = "RESULTS"
	results_box.add_child(_results_title)
	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 48)
	results_box.add_child(tables)
	_results_grid = GridContainer.new()
	_results_grid.columns = 4
	_results_grid.add_theme_constant_override("h_separation", 28)
	tables.add_child(_results_grid)
	# Grand Prix only: cumulative standings beside the race result.
	_standings_box = VBoxContainer.new()
	_standings_box.visible = false
	tables.add_child(_standings_box)
	_championship_grid = GridContainer.new()
	_championship_grid.columns = 3
	_championship_grid.add_theme_constant_override("h_separation", 20)
	_standings_box.add_child(_championship_grid)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	results_box.add_child(buttons)
	_continue_button = UIStyle.button("Race again", func() -> void: race.continue_after_results())
	_menu_button = UIStyle.button("Quit to mode select", func() -> void: race.quit_to_menu())
	buttons.add_child(_continue_button)
	buttons.add_child(_menu_button)
	var hint := _label(13, Color(1, 1, 1, 0.5))
	hint.text = "Enter / gamepad A: select    Esc / Start: pause menu"
	results_box.add_child(hint)

	_incoming_label = _label(30, Color(1.0, 0.25, 0.25))
	_incoming_label.text = "!! INCOMING !!"
	_incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_incoming_label.visible = false
	stack.add_child(_incoming_label)
	stack.move_child(_incoming_label, 0)

	# Weapon slots, top left. The bottom-right corner is kept clear for the
	# minimap (GDD 11.5).
	_combat_box = HBoxContainer.new()
	_combat_box.position = Vector2(20, 16)
	_combat_box.add_theme_constant_override("separation", 16)
	add_child(_combat_box)
	var slots_column := VBoxContainer.new()
	slots_column.add_theme_constant_override("separation", 2)
	_combat_box.add_child(slots_column)
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	slots_column.add_child(slots_row)
	for i in ItemInventory.SLOT_COUNT:
		var panel := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.set_border_width_all(2)
		slot_style.set_content_margin_all(10)
		slot_style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", slot_style)
		panel.custom_minimum_size = Vector2(130, 46)
		var slot_label := _label(16, Color.WHITE)
		slot_label.text = "%d  EMPTY" % (i + 1)
		panel.add_child(slot_label)
		slots_row.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(slot_label)
	var weapon_hint := _label(13, Color(1, 1, 1, 0.5))
	weapon_hint.text = "1 / 2 select    Space fire"
	slots_column.add_child(weapon_hint)
	# Lock, active effects and hit notices beside the slots.
	var combat_info := VBoxContainer.new()
	combat_info.add_theme_constant_override("separation", 0)
	_combat_box.add_child(combat_info)
	_lock_label = _label(17, MAGENTA)
	combat_info.add_child(_lock_label)
	_status_label = _label(15, Color(1.0, 0.85, 0.3))
	combat_info.add_child(_status_label)
	_combat_notice = _label(20, Color.WHITE)
	_combat_notice.visible = false
	combat_info.add_child(_combat_notice)
	_combat_box.visible = false

	# Placeholder audio cues (GDD 12: important events are audible too).
	_cue_player = AudioStreamPlayer.new()
	_cue_player.volume_db = -8.0
	add_child(_cue_player)
	_tones = {
		"pickup": VehicleFeedback._make_tone(990.0, 0.09),
		"hit": VehicleFeedback._make_tone(1320.0, 0.12),
		"hurt": VehicleFeedback._make_tone(0.0, 0.3, 0.35, true),
		"blocked": VehicleFeedback._make_tone(520.0, 0.15),
		"incoming": VehicleFeedback._make_tone(740.0, 0.25),
	}


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _cell(text: String, color: Color, size: int) -> Label:
	var label := _label(size, color)
	label.text = text
	return label
