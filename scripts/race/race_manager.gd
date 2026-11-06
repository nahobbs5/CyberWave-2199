class_name RaceManager
extends Node3D
## Runs one race (GDD 2, 14.2 RaceManager / GridManager / PositionTracker).
##
## Settings come from a RaceConfig (mode select screen or Grand Prix), or from
## this node's exports when the scene is run directly. Modes:
##   Versus       the player's race ends when they cross the line.
##   Grand Prix   at the player's finish, everyone still racing is classified
##                by current position, points are recorded and the
##                championship is saved; the next grid follows this order.
##   Elimination  EliminationTracker knocks out racers at lap midpoints; the
##                first across the line wins and the other finalist is second.
## Spawns the starting grid (seven AI rivals in slots 1-7, the player last),
## runs the READY / SET / GO countdown with all controls locked, routes
## checkpoint crossings to each racer's RaceProgress, keeps live positions,
## and ends the player's race when they finish. AI keep racing afterwards so
## the results fill in; the player's car switches to autopilot.

signal state_changed(state: State)
## "READY", "SET" or "GO".
signal countdown_tick(text: String)
signal lap_completed(racer: RaceProgress)
signal racer_finished(racer: RaceProgress)
signal player_finished(racer: RaceProgress)
signal racer_eliminated(racer: RaceProgress)
## Elimination: a racer crossed the elimination gate in a qualifying place.
signal racer_qualified(racer: RaceProgress, spots_left: int)
## Grand Prix: this race's result was recorded (and saved).
signal championship_updated(championship: Championship)
## The player's coins and records for this race were granted and saved.
signal rewards_granted(summary: Dictionary)

enum State { GRID, COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_WORDS: Array[String] = ["READY", "SET", "GO"]
const COUNTDOWN_SOUND := preload("res://sounds/freesound_community-short-beep-countdown-81121.mp3")
const COUNTDOWN_SOUND_OFFSET := 1.0

## Overrides the exports below. Null = GameSession.current, else the exports.
@export var config: RaceConfig
@export var car_scene: PackedScene
@export var rival_roster: RivalRoster
@export var difficulty: AIDifficulty
@export_range(1, 9) var total_laps: int = 3
## 0 = pole position. The GDD starts the player last (slot 7 of 8).
@export_range(0, 7) var player_grid_slot: int = 7
@export var player_color: Color = Color(0.1, 0.12, 0.22)
## Seconds per countdown word.
@export var countdown_step: float = 1.0
@export var auto_start: bool = true
## Weapons and crates on or off (GDD 2.1 race setting).
@export var weapons_enabled: bool = true
## Lets the AI drive the player's car too (headless tests, attract mode).
@export var player_uses_autopilot: bool = false
@export var random_seed: int = 2199

var state: State = State.GRID
## Seconds since GO.
var race_time: float = 0.0
var racers: Array[RaceProgress] = []
var player: RaceProgress
var line: RacingLine
## VehicleStats -> RacingLine (see line_for()).
var _lines_by_stats: Dictionary = {}
## Player is driving against the track direction.
var wrong_way: bool = false
## Elimination mode only.
var elimination: EliminationTracker
## Grand Prix only.
var championship: Championship
## The player's vehicle (GDD 5.1).
var player_vehicle: VehicleData
var coins: TrackCoins
## Filled in when the player's race ends: reward lines, coin totals,
## personal bests and newly affordable cosmetics (GDD 11.7).
var reward_summary: Dictionary = {}

var _by_vehicle: Dictionary = {}
var _countdown_time: float = 0.0
var countdown_sound: AudioStreamPlayer
var _countdown_index: int = -1
var _finish_count: int = 0
var _wrong_way_time: float = 0.0
var _player_done: bool = false

@onready var track: TrackCircuit = $TestCircuit
@onready var camera: ChaseCamera = $ChaseCamera
@onready var prototype_hud: PrototypeHUD = $PrototypeHUD
@onready var race_hud: RaceHUD = $RaceHUD
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")


func _ready() -> void:
	InputSetup.ensure_actions()
	countdown_sound = AudioStreamPlayer.new()
	countdown_sound.name = "CountdownSound"
	countdown_sound.stream = COUNTDOWN_SOUND
	countdown_sound.bus = &"SFX"
	add_child(countdown_sound)
	_apply_config()
	var race_music := TrackCatalog.music(config.track_name)
	if race_music == "":
		Music.stop(get_tree())
	else:
		Music.play(get_tree(), race_music)
		# Restart keeps the same track playing, so drop any final-lap speed-up.
		Music.set_speed(get_tree(), 1.0)
	track.checkpoint_crossed.connect(_on_checkpoint_crossed)
	_spawn_grid()
	coins = TrackCoins.new()
	coins.name = "TrackCoins"
	add_child(coins)
	coins.setup(track, line, player.vehicle)
	if config.is_elimination():
		elimination = EliminationTracker.new(racers, track.checkpoint_count / 2)
		_build_elimination_gate()
	if weapons_enabled and weapon_manager != null:
		weapon_manager.setup(self)
		for racer in racers:
			_attach_ai_combat(racer)
	camera.set_target(player.vehicle)
	prototype_hud.setup(player.vehicle, camera, track)
	race_hud.setup(self)
	HudScaler.apply(race_hud, GameSettings.hud_scale)
	HudScaler.apply(prototype_hud, GameSettings.hud_scale)
	if GameSettings.motion_blur:
		var blur := SpeedBlur.new()
		blur.name = "SpeedBlur"
		blur.vehicle = player.vehicle
		add_child(blur)
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(self)
	if auto_start:
		start_countdown()


func start_countdown() -> void:
	_countdown_time = 0.0
	_countdown_index = -1
	# The clip beeps every second, four times; skip the first so the last
	# three land on READY, SET and GO.
	countdown_sound.play(COUNTDOWN_SOUND_OFFSET)
	_set_state(State.COUNTDOWN)


func get_standings() -> Array[RaceProgress]:
	var sorted := racers.duplicate()
	sorted.sort_custom(RaceProgress.is_ahead)
	return sorted


func progress_of(vehicle: VehicleController) -> RaceProgress:
	return _by_vehicle.get(vehicle)


func get_vehicles() -> Array[VehicleController]:
	var vehicles: Array[VehicleController] = []
	for racer in racers:
		vehicles.append(racer.vehicle)
	return vehicles


func combat_enabled() -> bool:
	return weapons_enabled and weapon_manager != null and weapon_manager.race != null


func get_ai(racer: RaceProgress) -> AIController:
	return racer.vehicle.get_node_or_null("AIController") as AIController


func mode() -> RaceConfig.Mode:
	return config.mode


## Restarting a Grand Prix race after its result was saved isn't allowed.
func can_restart() -> bool:
	return not (championship != null and _player_done)


func restart() -> void:
	if can_restart():
		GameSession.start_race(get_tree(), config)


## Results screen "continue": next Grand Prix race, back to the menu after
## the final one, or race again in the other modes.
func continue_after_results() -> void:
	if championship == null:
		GameSession.start_race(get_tree(), config)
	elif championship.is_complete():
		GameSession.to_main_menu(get_tree())
	else:
		GameSession.start_race(get_tree(), championship.make_race_config())


func quit_to_menu() -> void:
	GameSession.to_main_menu(get_tree())


func _apply_config() -> void:
	if config == null:
		config = GameSession.current
	if config == null:
		config = RaceConfig.new()
		config.difficulty = difficulty
		config.total_laps = total_laps
		config.weapons_enabled = weapons_enabled
	if config.difficulty != null:
		difficulty = config.difficulty
	weapons_enabled = config.weapons_enabled
	# The elimination schedule is built around three laps (GDD 2.3).
	total_laps = 3 if config.is_elimination() else config.total_laps
	championship = config.championship if config.mode == RaceConfig.Mode.GRAND_PRIX else null
	var vehicle_id := config.vehicle_id
	if championship != null:
		vehicle_id = championship.vehicle_id
	if vehicle_id == "":
		vehicle_id = PlayerProfile.get_profile().selected_vehicle
	player_vehicle = VehicleCatalog.by_id(vehicle_id)
	if config.track_scene != null and config.track_scene.resource_path != track.scene_file_path:
		var old := track
		track = config.track_scene.instantiate() as TrackCircuit
		remove_child(old)
		old.free()
		add_child(track)
		move_child(track, 0)


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_update_countdown(delta)
		State.RACING, State.FINISHED:
			race_time += delta
			_update_positions()
			_update_rubber_band()
			_update_wrong_way(delta)


# --- grid ----------------------------------------------------------------------

func _spawn_grid() -> void:
	var stats := _probe_stats()
	line = RacingLine.new(track, stats)
	_lines_by_stats.clear()
	_lines_by_stats[stats] = line
	var rivals: Array[RacerProfile] = []
	if rival_roster != null:
		rivals = rival_roster.rivals
	var vehicles: Array[VehicleController] = []
	var grid := _grid_order()
	for slot in grid.size():
		var car := car_scene.instantiate() as VehicleController
		var id := grid[slot]
		var is_player := id == RaceConfig.PLAYER_ID
		var profile: RacerProfile = null
		if not is_player:
			profile = rivals[id] if id < rivals.size() else RacerProfile.new()
		car.name = "Player" if is_player else "AI%d" % (id + 1)
		var rival_vehicle: VehicleData = null
		if is_player and player_vehicle != null:
			car.stats = player_vehicle.stats
		elif not is_player:
			rival_vehicle = _rival_vehicle(id)
			car.stats = rival_vehicle.stats
		car.is_player = is_player
		car.player_controlled = is_player and not player_uses_autopilot
		add_child(car)
		car.global_transform = track.get_grid_transform(slot)
		car.recovery.set_track(track, track.get_grid_offset(slot))
		car.input_enabled = false
		var color := player_color if is_player else profile.color
		if is_player:
			var p := PlayerProfile.get_profile()
			VehicleCosmetics.apply(car, player_vehicle, p.loadout_for(player_vehicle.id), p.plate_text)
		else:
			# Rivals drive the car rolled for this series (real model and
			# stats), painted in their own colour, with their own plate.
			VehicleCosmetics.apply_model(car, rival_vehicle)
			car.set_body_color(color)
			var plate := profile.plate_text
			if config != null and id >= 0 and id < config.rival_plates.size():
				plate = config.rival_plates[id]
			VehicleCosmetics.add_plate(car, plate, null)
		var racer_name := "You" if is_player else profile.display_name
		var progress := RaceProgress.new(car, racer_name, color, is_player, slot,
				track.checkpoint_count, total_laps)
		progress.racer_id = id
		racers.append(progress)
		_by_vehicle[car] = progress
		vehicles.append(car)
		if is_player:
			player = progress
			if player_uses_autopilot:
				_attach_ai(car, RacerProfile.new(), slot)
		else:
			_attach_ai(car, profile, slot)
			_add_name_tag(car, racer_name, color)
	for racer in racers:
		var ai := get_ai(racer)
		if ai != null:
			ai.racers = vehicles


## Racer ids by grid slot: the config's order, else rivals in roster order
## with the player in player_grid_slot.
func _grid_order() -> Array[int]:
	if config.grid_order.size() == 8:
		return config.grid_order
	var grid: Array[int] = []
	var rival := 0
	for slot in 8:
		if slot == player_grid_slot:
			grid.append(RaceConfig.PLAYER_ID)
		else:
			grid.append(rival)
			rival += 1
	return grid


## The series' car for a rival (roster index), else the V8 Specter.
func _rival_vehicle(id: int) -> VehicleData:
	var vehicle: VehicleData = null
	if config != null and id >= 0 and id < config.rival_vehicles.size():
		vehicle = VehicleCatalog.by_id(config.rival_vehicles[id])
	return vehicle if vehicle != null else VehicleCatalog.by_id(PlayerProfile.DEFAULT_VEHICLE)


## The racing line with speeds for these stats (one per car model, sharing
## the base line's path).
func line_for(stats: VehicleStats) -> RacingLine:
	if stats == null:
		return line
	if not _lines_by_stats.has(stats):
		_lines_by_stats[stats] = line.for_stats(stats)
	return _lines_by_stats[stats]


func _probe_stats() -> VehicleStats:
	var probe := car_scene.instantiate() as VehicleController
	var stats := probe.stats
	probe.free()
	return stats if stats != null else VehicleStats.new()


func _attach_ai(car: VehicleController, profile: RacerProfile, slot: int) -> AIController:
	var ai := AIController.new()
	ai.name = "AIController"
	car.add_child(ai)
	ai.setup(car, track, line_for(car.stats), profile, difficulty, random_seed + slot * 7919)
	return ai


func _attach_ai_combat(racer: RaceProgress) -> void:
	var ai := get_ai(racer)
	if ai == null or racer.vehicle.get_node_or_null("AICombat") != null:
		return
	var combat := AICombat.new()
	combat.name = "AICombat"
	racer.vehicle.add_child(combat)
	combat.setup(racer.vehicle, weapon_manager, line_for(racer.vehicle.stats), ai.profile, difficulty,
			random_seed + racer.grid_slot * 104729)


func _add_name_tag(car: VehicleController, text: String, color: Color) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 1.7, 0.0)
	tag.pixel_size = 0.008
	tag.font_size = 40
	tag.outline_size = 10
	tag.modulate = color.lightened(0.3)
	car.add_child(tag)


# --- race flow -----------------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


func _update_countdown(delta: float) -> void:
	var index := int(_countdown_time / countdown_step)
	_countdown_time += delta
	if index == _countdown_index:
		return
	_countdown_index = index
	if index < COUNTDOWN_WORDS.size():
		countdown_tick.emit(COUNTDOWN_WORDS[index])
	if index >= COUNTDOWN_WORDS.size() - 1:
		_start_race()


func _start_race() -> void:
	race_time = 0.0
	for racer in racers:
		racer.vehicle.input_enabled = true
	_set_state(State.RACING)


func _on_checkpoint_crossed(index: int, body: Node3D) -> void:
	if state != State.RACING and state != State.FINISHED:
		return
	var racer: RaceProgress = _by_vehicle.get(body)
	if racer == null:
		return
	match racer.on_checkpoint(index, race_time):
		&"checkpoint":
			if elimination != null:
				var out := elimination.on_crossing(racer, index)
				if elimination.just_qualified:
					racer_qualified.emit(racer, elimination.just_spots_left)
				_eliminate(out)
		&"lap":
			lap_completed.emit(racer)
			if racer.is_player:
				coins.respawn() # track coins come back every lap (GDD 9.2)
				if total_laps > 1 and racer.lap == total_laps:
					Music.set_speed(get_tree(), Music.FINAL_LAP_SPEED) # final lap: music 15% faster
		&"finish":
			lap_completed.emit(racer)
			_finish_count += 1
			racer.finish_position = _finish_count
			racer_finished.emit(racer)
			# Elimination: the first finalist across the line wins; the race is over.
			if elimination != null and _finish_count == 1:
				_classify_remaining()
			if racer.is_player:
				_on_player_finished()


## Gives everyone still racing a final position in their current order.
func _classify_remaining() -> void:
	_update_positions()
	for racer in get_standings():
		if racer.finished:
			continue
		_finish_count += 1
		racer.finished = true
		racer.finish_position = _finish_count
		racer_finished.emit(racer)
		if racer.is_player:
			_on_player_finished()


func _eliminate(out: Array[RaceProgress]) -> void:
	if out.is_empty():
		return
	_update_positions()
	out.sort_custom(func(a: RaceProgress, b: RaceProgress) -> bool: return a.race_distance > b.race_distance)
	var remaining := elimination.active_racers().size() - out.size()
	for i in out.size():
		var racer := out[i]
		racer.eliminated = true
		racer.eliminated_lap = racer.lap
		racer.finished = true
		racer.finish_position = remaining + 1 + i
		_remove_vehicle(racer.vehicle)
		racer_eliminated.emit(racer)
	if player.eliminated and not _player_done:
		var leader := get_standings()[0].vehicle
		camera.set_target(leader)
		_on_player_finished()


## Eliminated cars stop colliding with active racers at once, then shrink
## away and are parked out of sight (GDD 2.3).
func _remove_vehicle(car: VehicleController) -> void:
	car.collision_layer = 0
	car.collision_mask = 1
	car.input_enabled = false
	car.player_controlled = false
	var ai := car.get_node_or_null("AIController") as AIController
	if ai != null:
		ai.enabled = false
	var combat := car.get_node_or_null("AICombat")
	if combat != null:
		combat.set_physics_process(false)
	if car.inventory != null:
		car.inventory.clear()
	if car.targeting != null:
		car.targeting.clear()
	if car.status != null:
		car.status.clear_all()
	if weapon_manager != null and combat_enabled():
		weapon_manager.spawn_flash(car.global_position + Vector3.UP, Color(1.0, 0.2, 0.3))
	var tween := create_tween()
	var body := car.get_node_or_null("Body") as Node3D
	if body != null:
		tween.tween_property(body, "scale", Vector3.ONE * 0.05, 0.6)
	else:
		tween.tween_interval(0.6)
	tween.tween_callback(_park_vehicle.bind(car))


func _park_vehicle(car: VehicleController) -> void:
	car.visible = false
	car.freeze = true
	car.global_position = Vector3(0.0, -500.0, 0.0)
	car.process_mode = Node.PROCESS_MODE_DISABLED


## Placeholder marker over the elimination checkpoint.
func _build_elimination_gate() -> void:
	var gate := Node3D.new()
	gate.name = "EliminationGate"
	add_child(gate)
	var offset := track.get_checkpoint_offset(elimination.gate_index)
	var half := track.road_width * 0.5 + 0.8
	var mat := WeaponManager.glow_material(Color(1.0, 0.15, 0.3), 3.0)
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 9.0, 0.8)
		pillar.mesh = box
		pillar.material_override = mat
		pillar.transform = track.get_safe_transform(offset, side * half, 4.5)
		gate.add_child(pillar)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(half * 2.0 + 0.8, 0.8, 0.8)
	bar.mesh = bar_mesh
	bar.material_override = mat
	bar.transform = track.get_safe_transform(offset, 0.0, 9.0)
	gate.add_child(bar)
	var label := Label3D.new()
	label.text = "ELIMINATION"
	label.font_size = 160
	label.pixel_size = 0.02
	label.outline_size = 24
	label.modulate = Color(1.0, 0.3, 0.4)
	label.transform = track.get_safe_transform(offset, 0.0, 10.6)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	gate.add_child(label)


func _on_player_finished() -> void:
	if _player_done:
		return
	_player_done = true
	coins.collecting = false
	_update_positions()
	var reward := {}
	if championship != null:
		reward = _record_championship()
	else:
		reward = RaceRewards.compute(player.finish_position, not player.eliminated, coins.collected)
	_grant_rewards(reward)
	if player.eliminated:
		_set_state(State.FINISHED)
		player_finished.emit(player)
		return
	if get_ai(player) == null:
		# Hand the car to the autopilot so it keeps driving through the results.
		var autopilot := _attach_ai(player.vehicle, RacerProfile.new(), player.grid_slot)
		autopilot.racers = get_vehicles()
	_set_state(State.FINISHED)
	player_finished.emit(player)


## Grand Prix: classify the field at the player's finish, award points and
## save before the next race (GDD 2.2). The coins for this race are written
## into the championship save first, so a crash can lose them but never pay
## them twice (GDD 13.2). Returns the race's reward.
func _record_championship() -> Dictionary:
	_classify_remaining()
	var order: Array[int] = []
	for racer in get_standings():
		order.append(racer.racer_id)
	championship.record_race(order)
	var won := championship.is_complete() and championship.standings()[0] == RaceConfig.PLAYER_ID
	var reward := RaceRewards.compute(player.finish_position, true, coins.collected, won)
	championship.coins_awarded += int(reward.total)
	if championship.is_complete():
		var ranking := championship.standings()
		PlayerProfile.get_profile().record_grand_prix(championship.gp.id,
				ranking.find(RaceConfig.PLAYER_ID) + 1, int(championship.points.get(RaceConfig.PLAYER_ID, 0)))
		Championship.clear_save()
	else:
		championship.save()
	championship_updated.emit(championship)
	return reward


## Pays out the race's coins and records personal bests (GDD 9.3, 11.7).
func _grant_rewards(reward: Dictionary) -> void:
	var profile := PlayerProfile.get_profile()
	var before := profile.coins
	profile.add_coins(int(reward.total))
	var bests := {"race": false, "lap": false}
	if not player.eliminated and player.finish_time > 0.0:
		bests = profile.record_race_time(config.track_name, total_laps, player.finish_time, player.best_lap)
	profile.save()
	reward_summary = {
		"lines": reward.lines,
		"total": reward.total,
		"coins_before": before,
		"coins_after": profile.coins,
		"track_coins": coins.collected,
		"best_race": bests.race,
		"best_lap": bests.lap,
		"affordable": profile.newly_affordable(before),
	}
	rewards_granted.emit(reward_summary)


func _update_positions() -> void:
	for racer in racers:
		if not racer.finished:
			racer.race_distance = racer.compute_distance(track)
	var standings := get_standings()
	for i in standings.size():
		standings[i].position = i + 1


func _update_rubber_band() -> void:
	for racer in racers:
		var ai := get_ai(racer)
		if ai == null or racer.is_player:
			continue
		if state == State.FINISHED or difficulty == null:
			ai.speed_scale = 1.0
			continue
		var gap := player.race_distance - racer.race_distance
		ai.speed_scale = 1.0 + clampf(gap / 200.0, -1.0, 1.0) * difficulty.rubber_band


func _update_wrong_way(delta: float) -> void:
	var car := player.vehicle
	var tangent := track.get_direction_at(car.global_position) # follows shortcuts
	var heading := -car.global_transform.basis.z
	var backwards := car.linear_velocity.dot(tangent) < -3.0 and heading.dot(tangent) < -0.3
	_wrong_way_time = _wrong_way_time + delta if backwards else 0.0
	wrong_way = state == State.RACING and _wrong_way_time > 0.75
