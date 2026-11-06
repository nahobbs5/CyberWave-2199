class_name RaceHUD
extends CanvasLayer
## Race HUD (GDD 11.5): builds the parts and feeds them from the race.
##   top left      RaceInfoPanel: position, lap, time, coins, Elimination info
##   left          StandingsPanel: compact live standings
##   top centre    HudAnnouncer: countdown, FINAL LAP!, NEW BEST LAP!, FINISH!, warnings
##   top right     ItemSlots: held items, lock-on, effects, combat notices
##   bottom right  Minimap
##   (bottom left  speed + drift, in PrototypeHUD underneath)
## plus the ResultsScreen when you finish, and placeholder audio cues.

const CYAN := UIStyle.CYAN
const MAGENTA := UIStyle.MAGENTA
## Ignore position changes this long after GO (the start shuffles a lot).
const POSITION_SETTLE := 3.0
## At most one "1ST PLACE!" this often.
const LEAD_COOLDOWN := 10.0

var race: RaceManager

var info: RaceInfoPanel
var standings: StandingsPanel
var announcer: HudAnnouncer
var items: ItemSlots
var results: ResultsScreen
var minimap: Minimap

# Kept for the existing tests.
var _coin_label: Label
var _slot_panels: Array[PanelContainer]
var _slot_names: Array[Label]
var _standings_label: Control
var _continue_button: Button
var _menu_button: Button

var _left_column: VBoxContainer
var _cue_player: AudioStreamPlayer
var _tones: Dictionary = {}
var _was_incoming: bool = false
var _last_position: int = 0
var _lead_cooldown: float = 0.0


func _ready() -> void:
	_build()


func setup(manager: RaceManager) -> void:
	race = manager
	race.countdown_tick.connect(_on_countdown_tick)
	race.lap_completed.connect(_on_lap_completed)
	race.player_finished.connect(_on_player_finished)
	race.racer_eliminated.connect(_on_racer_eliminated)
	race.racer_qualified.connect(_on_racer_qualified)
	race.coins.coin_collected.connect(_on_coin_collected)
	var trick := race.player.vehicle.trick if race.player != null else null
	if trick != null:
		trick.trick_started.connect(func() -> void: _play("trick"))
		trick.trick_landed.connect(func() -> void: _play("trick_land"))
	results.continue_pressed.connect(func() -> void: race.continue_after_results())
	results.menu_pressed.connect(func() -> void: race.quit_to_menu())
	info.mode_label.text = _mode_text()
	minimap.setup(race)
	info.elim_label.visible = race.elimination != null
	items.visible = race.combat_enabled()
	if race.combat_enabled():
		race.weapon_manager.hit_resolved.connect(_on_hit_resolved)
		# After hit_resolved, so "LOST ..." replaces the plain hit notice.
		race.weapon_manager.item_lost.connect(_on_item_lost)
		race.weapon_manager.weapon_collected.connect(_on_weapon_collected)


# --- queries (tests) ------------------------------------------------------------

func is_incoming_visible() -> bool:
	return announcer.incoming.visible


## Text description of a slot ("1  Firewall", "2  EMPTY", "1  Triple Nitro  x3").
func get_slot_text(slot: int) -> String:
	return items.slot_text[slot]


func get_slot_icon(slot: int) -> Texture2D:
	return items.icons[slot].texture


func is_results_visible() -> bool:
	return results.visible


func get_center_text() -> String:
	return announcer.get_text()


## The results screen's mode / track line ("VERSUS / TEST CIRCUIT", ...).
func get_results_title() -> String:
	return results.title.text


func get_results_placement() -> String:
	return "%s\n%s" % [results.placement.text, results.subtitle.text]


func get_continue_text() -> String:
	return results.continue_button.text


func get_elimination_text() -> String:
	return info.elim_label.text if info.elim_label.visible else ""


## One line per racer still in the race.
func get_standings_text() -> String:
	return standings.get_text()


func get_position_text() -> String:
	return info.get_position_text()


func get_feed_text() -> String:
	return announcer.feed.text if announcer.feed.visible else ""


func get_rewards_text() -> String:
	return results.get_rewards_text()


func _active_count() -> int:
	return race.racers.filter(func(r: RaceProgress) -> bool: return not r.eliminated).size()


func _mode_text() -> String:
	var config := race.config
	if race.championship != null:
		var c := race.championship
		# Set at the start, before this race is recorded.
		return "%s  -  RACE %d / %d: %s" % [c.gp.display_name.to_upper(), c.race_index + 1, c.race_count(),
				config.track_name]
	return "%s  -  %s" % [RaceConfig.MODE_NAMES[config.mode].to_upper(), config.track_name]


# --- per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	info.show_position(p.finish_position if p.eliminated else p.position, _active_count(), p.eliminated)
	info.lap_value.text = "%d / %d" % [p.display_lap(), race.total_laps]
	var shown_time := p.finish_time if p.finished else race.race_time
	info.time_value.text = RaceProgress.format_time(shown_time)
	info.coin_label.text = str(race.coins.collected)
	_track_position(delta)

	# Standings may not reach the speed panel (bottom left, in PrototypeHUD).
	standings.bottom_limit = _speed_panel_top() - _left_column.position.y - 8.0
	standings.refresh(race)
	if race.elimination != null:
		_update_elimination()

	announcer.wrong_way.visible = race.wrong_way
	if race.combat_enabled():
		items.refresh(race, delta)
		var incoming := race.weapon_manager.is_incoming(p.vehicle) and not p.finished
		# Reduced flashing (GDD 11.9): a steady warning instead of a blinking one.
		var blink_on := GameSettings.reduced_flashing or int(Time.get_ticks_msec() / 150) % 2 == 0
		announcer.incoming.visible = incoming and blink_on
		if incoming and not _was_incoming:
			_play("incoming")
		_was_incoming = incoming


## Top of the speed / drift panel, in this HUD's layout space.
func _speed_panel_top() -> float:
	var hud := race.prototype_hud
	if hud == null or hud.speed_panel == null:
		return INF
	# Both layers use the same HUD scale and layout size, so their global
	# (pre-layer-transform) coordinates match.
	return hud.speed_panel.get_global_rect().position.y


## Pulse the position on overtakes; "1ST PLACE!" on taking the lead.
func _track_position(delta: float) -> void:
	_lead_cooldown -= delta
	var p := race.player
	if race.state != RaceManager.State.RACING or p.finished or p.eliminated:
		_last_position = p.position
		return
	if race.race_time < POSITION_SETTLE or _last_position == 0:
		_last_position = p.position
		return
	if p.position != _last_position:
		info.position_changed(p.position < _last_position)
		if p.position == 1 and p.lap >= 2 and _lead_cooldown <= 0.0:
			announcer.announce("1ST PLACE!", 1.2, UIStyle.GOLD)
			_lead_cooldown = LEAD_COOLDOWN
		_last_position = p.position


# --- race events ------------------------------------------------------------------

func _on_countdown_tick(text: String) -> void:
	announcer.announce(text, 1.0 if text != "GO" else 0.8, CYAN if text != "GO" else MAGENTA)


func _on_lap_completed(racer: RaceProgress) -> void:
	if not racer.is_player or racer.finished:
		return
	var last := racer.lap_times[racer.lap_times.size() - 1]
	var best_so_far := racer.lap_times.size() >= 2
	for i in racer.lap_times.size() - 1:
		best_so_far = best_so_far and last < racer.lap_times[i]
	var lap_line := ("NEW BEST LAP!  " if best_so_far else "LAP  ") + RaceProgress.format_time(last)
	if racer.lap == race.total_laps:
		announcer.announce("FINAL LAP!", 1.8, MAGENTA, lap_line)
	elif best_so_far:
		announcer.announce("NEW BEST LAP!", 1.5, UIStyle.GOLD, RaceProgress.format_time(last))
	else:
		announcer.announce("LAP %d" % racer.lap, 1.5, CYAN, RaceProgress.format_time(last))


func _on_player_finished(racer: RaceProgress) -> void:
	if racer.eliminated:
		announcer.announce("ELIMINATED", 2.5, UIStyle.DANGER)
	elif race.elimination != null and racer.finish_position == 1:
		announcer.announce("WINNER!", 2.5, UIStyle.GOLD)
	else:
		announcer.announce("FINISH!", 2.0, MAGENTA, "%s PLACE" % ResultsScreen.ordinal(racer.finish_position))
	results.open(race)


func _on_coin_collected(total: int) -> void:
	info.coin_collected()
	_play("coin")
	if total >= TrackCoins.MAX_PER_RACE:
		items.show_notice("COIN LIMIT REACHED", UIStyle.GOLD)


func _on_racer_eliminated(racer: RaceProgress) -> void:
	if racer.is_player:
		return
	announcer.show_feed("%s ELIMINATED" % racer.display_name, Color(1.0, 0.35, 0.4))


func _on_racer_qualified(racer: RaceProgress, spots_left: int) -> void:
	if not racer.is_player:
		return
	var after := "last place taken" if spots_left == 0 else "%d left" % spots_left
	announcer.announce("QUALIFIED", 1.5, CYAN, after)


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
	info.elim_label.text = text


# --- combat events ----------------------------------------------------------------

func _on_weapon_collected(vehicle: VehicleController, weapon: WeaponData) -> void:
	if vehicle == race.player.vehicle:
		items.show_notice("+ %s" % weapon.display_name, weapon.color)
		_play("pickup")


func _on_hit_resolved(target: VehicleController, weapon: WeaponData, shooter: VehicleController,
		blocked_by: StringName) -> void:
	var player := race.player.vehicle
	var target_name := race.progress_of(target).display_name
	if target == player:
		if blocked_by == &"shield":
			items.show_notice("FIREWALL BLOCKED %s" % weapon.display_name.to_upper(), UIStyle.WARN)
			_play("blocked")
		elif blocked_by == &"":
			items.show_notice("%s!" % weapon.display_name.to_upper(), UIStyle.DANGER)
			_play("hurt")
	elif shooter == player:
		if blocked_by == &"":
			items.show_notice("HIT  %s" % target_name, weapon.color)
			_play("hit")
		else:
			items.show_notice("BLOCKED by %s" % target_name, Color(1, 1, 1, 0.8))


func _on_item_lost(target: VehicleController, lost: WeaponData, by_weapon: WeaponData,
		shooter: VehicleController) -> void:
	var player := race.player.vehicle
	if target == player:
		items.show_notice("%s!  LOST %s" % [by_weapon.display_name.to_upper(), lost.display_name], lost.color)
	elif shooter == player:
		items.show_notice("HIT  %s  -  stripped %s" % [race.progress_of(target).display_name, lost.display_name],
				by_weapon.color)


func _play(tone: String) -> void:
	if _tones.has(tone):
		_cue_player.stream = _tones[tone]
		_cue_player.play()


# --- layout ----------------------------------------------------------------------

func _build() -> void:
	# Left column: race info, then the compact standings.
	_left_column = VBoxContainer.new()
	_left_column.name = "LeftColumn"
	_left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_column.position = Vector2(20, 16)
	_left_column.add_theme_constant_override("separation", 8)
	add_child(_left_column)
	info = RaceInfoPanel.new()
	_left_column.add_child(info)
	standings = StandingsPanel.new()
	_left_column.add_child(standings)

	announcer = HudAnnouncer.new()
	add_child(announcer)

	items = ItemSlots.new()
	items.visible = false
	add_child(items)

	# Minimap, bottom right (GDD 11.5).
	var map_anchor := Control.new()
	map_anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_anchor)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.position = -Minimap.MAP_SIZE - Vector2(20, 20)
	map_anchor.add_child(minimap)

	results = ResultsScreen.new()
	add_child(results)

	_coin_label = info.coin_label
	_slot_panels = items.panels
	_slot_names = items.names
	_standings_label = standings
	_continue_button = results.continue_button
	_menu_button = results.menu_button

	# Placeholder audio cues (GDD 12: important events are audible too).
	_cue_player = AudioStreamPlayer.new()
	_cue_player.volume_db = -8.0
	_cue_player.bus = &"SFX"
	add_child(_cue_player)
	_tones = {
		"pickup": VehicleFeedback._make_tone(990.0, 0.09),
		"hit": VehicleFeedback._make_tone(1320.0, 0.12),
		"hurt": VehicleFeedback._make_tone(0.0, 0.3, 0.35, true),
		"blocked": VehicleFeedback._make_tone(520.0, 0.15),
		"incoming": VehicleFeedback._make_tone(740.0, 0.25),
		"coin": VehicleFeedback._make_tone(1568.0, 0.06, 0.22),
		"trick": VehicleFeedback._make_tone(880.0, 0.08, 0.2),
		"trick_land": VehicleFeedback._make_tone(1760.0, 0.12, 0.25),
	}
