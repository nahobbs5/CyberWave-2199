class_name RaceProgress
extends RefCounted
## One racer's lap and checkpoint state (GDD 14.2 LapTracker).
##
## Checkpoints must be crossed in order: only the expected gate counts, so
## skipped gates, reversing through gates and recovery teleports never add
## progress. Gate 0 is the start/finish line. Racers start on the grid behind
## it, so their first crossing starts lap 1 rather than completing a lap.

var vehicle: VehicleController
## RaceConfig.PLAYER_ID or the rival's roster index (stable across a Grand Prix).
var racer_id: int = RaceConfig.PLAYER_ID
var display_name: String
var color: Color
var is_player: bool
var grid_slot: int
var checkpoint_count: int
var total_laps: int

## 0 = has not crossed the start line yet; 1..total_laps while racing.
var lap: int = 0
var next_checkpoint: int = 0
## Valid gate crossings so far (including the first start-line crossing).
var checkpoints_passed: int = 0
## Out of the race: crossed the line, or was eliminated / classified.
var finished: bool = false
## Elimination mode: knocked out at a lap-midpoint checkpoint (also finished).
var eliminated: bool = false
var eliminated_lap: int = 0
var finish_time: float = -1.0
## 1 = winner. 0 until finished.
var finish_position: int = 0
## Live race position (1 = leading), updated by RaceManager.
var position: int = 0
## Distance raced, refreshed by RaceManager each frame (used for ordering).
var race_distance: float = 0.0
var lap_times: PackedFloat32Array = PackedFloat32Array()
var best_lap: float = -1.0

var _lap_start: float = 0.0


func _init(p_vehicle: VehicleController, p_name: String, p_color: Color, p_is_player: bool,
		p_grid_slot: int, p_checkpoint_count: int, p_total_laps: int) -> void:
	vehicle = p_vehicle
	display_name = p_name
	color = p_color
	is_player = p_is_player
	grid_slot = p_grid_slot
	checkpoint_count = p_checkpoint_count
	total_laps = p_total_laps
	position = p_grid_slot + 1


## Lap number to show on the HUD (1..total_laps).
func display_lap() -> int:
	return clampi(maxi(lap, 1), 1, total_laps)


## Handles a gate crossing. Returns &"" (ignored), &"checkpoint", &"start",
## &"lap" or &"finish".
func on_checkpoint(index: int, race_time: float) -> StringName:
	if finished or index != next_checkpoint:
		return &""
	checkpoints_passed += 1
	next_checkpoint = (index + 1) % checkpoint_count
	if index != 0:
		return &"checkpoint"
	if lap == 0:
		lap = 1
		_lap_start = 0.0 # lap 1 is timed from GO
		return &"start"
	var lap_time := race_time - _lap_start
	lap_times.append(lap_time)
	if best_lap < 0.0 or lap_time < best_lap:
		best_lap = lap_time
	_lap_start = race_time
	if lap >= total_laps:
		finished = true
		finish_time = race_time
		return &"finish"
	lap += 1
	return &"lap"


## Distance raced along the circuit, continuous across gates.
func compute_distance(track: TrackCircuit) -> float:
	var segment := track.length / float(checkpoint_count)
	var last := posmod(next_checkpoint - 1, checkpoint_count)
	var offset := track.get_offset_at(vehicle.global_position)
	var since := track.wrapped_delta(track.get_checkpoint_offset(last), offset)
	return float(checkpoints_passed) * segment + clampf(since, -segment, segment * 1.5)


## True when a is ahead of b in the standings.
static func is_ahead(a: RaceProgress, b: RaceProgress) -> bool:
	# Eliminated racers count as finished but always rank behind everyone still in.
	if a.eliminated != b.eliminated:
		return b.eliminated
	if a.finished != b.finished:
		return a.finished
	if a.finished:
		return a.finish_position < b.finish_position
	if not is_equal_approx(a.race_distance, b.race_distance):
		return a.race_distance > b.race_distance
	return a.grid_slot < b.grid_slot


static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
