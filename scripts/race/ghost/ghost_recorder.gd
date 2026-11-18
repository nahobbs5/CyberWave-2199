class_name GhostRecorder
extends Node
## Records a racer for Time Trial (GDD 2.5): samples its car's pose at
## GhostData.sample_hz from GO and logs every gate crossing, until its race
## is finished. RaceManager adds one for the player; the ghost bake tool
## uses it on the autopilot car. to_data() gives the GhostData.

var race: RaceManager
var racer: RaceProgress
var data := GhostData.new()
var _next_sample: float = 0.0
var _passed: int = 0
var _done: bool = false


func setup(p_race: RaceManager, p_racer: RaceProgress) -> void:
	race = p_race
	racer = p_racer
	data.track_name = race.config.track_name if race.config != null else ""
	data.vehicle_id = race.player_vehicle.id if racer == race.player and race.player_vehicle != null else ""
	data.color = racer.color
	process_physics_priority = 100 # after the car has moved this step


func is_done() -> bool:
	return _done


func _physics_process(_delta: float) -> void:
	_step()


## Takes this step's frame and gates. RaceManager also calls it the moment
## the racer finishes (before this node's own step), so the run is complete
## when the result is recorded.
func finalize() -> void:
	_step()


func _step() -> void:
	if race == null or racer == null or _done:
		return
	if race.state != RaceManager.State.RACING and race.state != RaceManager.State.FINISHED:
		return
	var t := race.race_time
	var car := racer.vehicle
	while racer.checkpoints_passed > _passed:
		_passed += 1
		if _passed > 1: # the first is the start line crossed on GO
			data.checkpoint_times.append(racer.finish_time if racer.finished and racer.checkpoints_passed == _passed else t)
	while t + 0.0005 >= _next_sample and is_instance_valid(car):
		data.add_frame(car.global_transform, car.forward_speed, car.steer_input, car.visual_yaw, car.is_boosting())
		_next_sample += 1.0 / data.sample_hz
	if racer.finished:
		_done = true
		data.recorded_time = racer.finish_time
		data.lap_times = racer.lap_times.duplicate()


## The run so far (finished: the whole run).
func to_data() -> GhostData:
	return data
