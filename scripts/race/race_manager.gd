class_name RaceManager
extends Node3D
## Runs one race (GDD 2.1, 14.2 RaceManager / GridManager / PositionTracker).
##
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

enum State { GRID, COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_WORDS: Array[String] = ["READY", "SET", "GO"]

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
## Lets the AI drive the player's car too (headless tests, attract mode).
@export var player_uses_autopilot: bool = false
@export var random_seed: int = 2199

var state: State = State.GRID
## Seconds since GO.
var race_time: float = 0.0
var racers: Array[RaceProgress] = []
var player: RaceProgress
var line: RacingLine
## Player is driving against the track direction.
var wrong_way: bool = false

var _by_vehicle: Dictionary = {}
var _countdown_time: float = 0.0
var _countdown_index: int = -1
var _finish_count: int = 0
var _wrong_way_time: float = 0.0

@onready var track: TrackCircuit = $TestCircuit
@onready var camera: ChaseCamera = $ChaseCamera
@onready var prototype_hud: PrototypeHUD = $PrototypeHUD
@onready var race_hud: RaceHUD = $RaceHUD


func _ready() -> void:
	InputSetup.ensure_actions()
	track.checkpoint_crossed.connect(_on_checkpoint_crossed)
	_spawn_grid()
	camera.set_target(player.vehicle)
	prototype_hud.setup(player.vehicle, camera, track)
	race_hud.setup(self)
	if auto_start:
		start_countdown()


func start_countdown() -> void:
	_countdown_time = 0.0
	_countdown_index = -1
	_set_state(State.COUNTDOWN)


func get_standings() -> Array[RaceProgress]:
	var sorted := racers.duplicate()
	sorted.sort_custom(RaceProgress.is_ahead)
	return sorted


func get_ai(racer: RaceProgress) -> AIController:
	return racer.vehicle.get_node_or_null("AIController") as AIController


func _unhandled_input(event: InputEvent) -> void:
	if state == State.FINISHED and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


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
	var rivals: Array[RacerProfile] = []
	if rival_roster != null:
		rivals = rival_roster.rivals
	var vehicles: Array[VehicleController] = []
	var rival_index := 0
	for slot in 8:
		var car := car_scene.instantiate() as VehicleController
		var is_player := slot == player_grid_slot
		var profile: RacerProfile = null
		if not is_player:
			profile = rivals[rival_index] if rival_index < rivals.size() else RacerProfile.new()
			rival_index += 1
		car.name = "Player" if is_player else "AI%d" % rival_index
		car.is_player = is_player
		car.player_controlled = is_player and not player_uses_autopilot
		add_child(car)
		car.global_transform = track.get_grid_transform(slot)
		car.recovery.set_track(track, track.get_grid_offset(slot))
		car.input_enabled = false
		var color := player_color if is_player else profile.color
		car.set_body_color(color)
		var racer_name := "You" if is_player else profile.display_name
		var progress := RaceProgress.new(car, racer_name, color, is_player, slot,
				track.checkpoint_count, total_laps)
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


func _all_vehicles() -> Array[VehicleController]:
	var vehicles: Array[VehicleController] = []
	for racer in racers:
		vehicles.append(racer.vehicle)
	return vehicles


func _probe_stats() -> VehicleStats:
	var probe := car_scene.instantiate() as VehicleController
	var stats := probe.stats
	probe.free()
	return stats if stats != null else VehicleStats.new()


func _attach_ai(car: VehicleController, profile: RacerProfile, slot: int) -> AIController:
	var ai := AIController.new()
	ai.name = "AIController"
	car.add_child(ai)
	ai.setup(car, track, line, profile, difficulty, random_seed + slot * 7919)
	return ai


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
		&"lap":
			lap_completed.emit(racer)
		&"finish":
			lap_completed.emit(racer)
			_finish_count += 1
			racer.finish_position = _finish_count
			racer_finished.emit(racer)
			if racer.is_player:
				_on_player_finished()


func _on_player_finished() -> void:
	_update_positions()
	if get_ai(player) == null:
		# Hand the car to the autopilot so it keeps driving through the results.
		var autopilot := _attach_ai(player.vehicle, RacerProfile.new(), player.grid_slot)
		autopilot.racers = _all_vehicles()
	_set_state(State.FINISHED)
	player_finished.emit(player)


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
	var tangent := track.get_tangent_at(track.get_offset_at(car.global_position))
	var heading := -car.global_transform.basis.z
	var backwards := car.linear_velocity.dot(tangent) < -3.0 and heading.dot(tangent) < -0.3
	_wrong_way_time = _wrong_way_time + delta if backwards else 0.0
	wrong_way = state == State.RACING and _wrong_way_time > 0.75
