class_name DriftController
extends Node
## Q/E drift state and boost charge (GDD 4).
##
## The vehicle calls update() every physics step. Charge only builds while the
## car is grounded and actually sliding sideways. Releasing the drift button
## ends the drift and returns the earned boost level for the vehicle to apply.

signal drift_started(direction: int)
signal charge_level_changed(level: int)
## boosted is true when the drift earned at least Cyan and a boost will fire.
signal drift_ended(level: int, boosted: bool)
## Emitted when a drift is cut short (collision, too slow, too long airborne).
signal drift_cancelled(reason: String)

const LEVEL_NONE := 0
const LEVEL_CYAN := 1
const LEVEL_MAGENTA := 2
const LEVEL_GOLD := 3
const LEVEL_NAMES: Array[String] = ["None", "Cyan", "Magenta", "Gold"]
const LEVEL_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.8),
	Color(0.0, 0.95, 1.0),
	Color(1.0, 0.15, 0.85),
	Color(1.0, 0.78, 0.15),
]

## Seconds of valid drifting needed for Cyan, Magenta and Gold (GDD 4.2).
@export var level_thresholds: PackedFloat32Array = PackedFloat32Array([1.0, 2.5, 4.0])
## Leaving the ground pauses charging; staying airborne longer than this ends the drift.
@export var max_airborne_time: float = 1.5
## The drift is lost if forward speed falls below drift_min_speed times this.
@export_range(0.0, 1.0) var min_speed_ratio: float = 0.6

## -1 = drifting left, +1 = drifting right, 0 = not drifting.
var direction: int = 0
## Seconds of valid drifting accumulated in the current drift.
var charge_time: float = 0.0
var level: int = LEVEL_NONE
## True when charge increased during the last update (useful for effects/HUD).
var is_charging: bool = false

var _air_time: float = 0.0


func is_drifting() -> bool:
	return direction != 0


func level_for_time(seconds: float) -> int:
	var result := LEVEL_NONE
	for i in level_thresholds.size():
		if seconds >= level_thresholds[i]:
			result = i + 1
	return result


## Advances the drift. Returns the boost level to fire this step (0 = none).
func update(delta: float, left_held: bool, right_held: bool, grounded: bool,
		forward_speed: float, lateral_speed: float, stats: VehicleStats) -> int:
	is_charging = false
	if direction == 0:
		if grounded and forward_speed >= stats.drift_min_speed and left_held != right_held:
			_start(-1 if left_held else 1)
		return LEVEL_NONE

	var held := left_held if direction < 0 else right_held
	if not held:
		return _finish()

	if forward_speed < stats.drift_min_speed * min_speed_ratio:
		cancel("too slow")
		return LEVEL_NONE

	if not grounded:
		_air_time += delta
		if _air_time > max_airborne_time:
			cancel("airborne")
		return LEVEL_NONE
	_air_time = 0.0

	if absf(lateral_speed) >= stats.drift_min_lateral_speed:
		is_charging = true
		charge_time += delta
		var new_level := level_for_time(charge_time)
		if new_level != level:
			level = new_level
			charge_level_changed.emit(level)
	return LEVEL_NONE


## Ends the drift without a boost.
func cancel(reason: String) -> void:
	if direction == 0:
		return
	_reset()
	drift_cancelled.emit(reason)


func _start(dir: int) -> void:
	direction = dir
	charge_time = 0.0
	level = LEVEL_NONE
	_air_time = 0.0
	drift_started.emit(dir)


func _finish() -> int:
	var earned := level
	_reset()
	drift_ended.emit(earned, earned > LEVEL_NONE)
	return earned


func _reset() -> void:
	direction = 0
	charge_time = 0.0
	level = LEVEL_NONE
	_air_time = 0.0
	is_charging = false
