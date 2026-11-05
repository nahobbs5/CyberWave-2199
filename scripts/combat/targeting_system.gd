class_name TargetingSystem
extends Node
## Automatic lock-on for targeted weapons (GDD 6.2).
##
## While a targeted weapon is selected, picks the best eligible opponent in a
## cone ahead (racers ahead in the race first, then nearest), and locks once
## it has held the same candidate for acquire_time. An established lock
## survives brief obstructions. Never targets its own car.

signal lock_acquired(target: VehicleController)
signal lock_lost

@export var max_range: float = 140.0
@export var cone_degrees: float = 40.0
@export var acquire_time: float = 0.4
## An established lock survives this long without line of sight.
@export var obstruction_grace: float = 0.6
## An established lock tolerates a wider cone and range before dropping.
@export var keep_margin: float = 1.3

## Current candidate (being acquired or locked), or null.
var candidate: VehicleController
var locked: bool = false
## 0..1 progress toward a lock (for the HUD).
var acquire_progress: float = 0.0

## Set by WeaponManager.
var racers: Array[VehicleController] = []
## Returns true if a vehicle may be targeted (e.g. not finished).
var is_eligible: Callable = func(_v: VehicleController) -> bool: return true
## Returns race distance for "ahead" priority.
var race_distance: Callable = func(_v: VehicleController) -> float: return 0.0

var _acquire: float = 0.0
var _blocked: float = 0.0
var _vehicle: VehicleController


func _ready() -> void:
	_vehicle = get_parent() as VehicleController


func get_target() -> VehicleController:
	return candidate if locked else null


func clear() -> void:
	var had_lock := locked
	candidate = null
	locked = false
	_acquire = 0.0
	_blocked = 0.0
	acquire_progress = 0.0
	if had_lock:
		lock_lost.emit()


## Called every physics frame by WeaponManager. active = a targeted weapon is
## selected and the car can use weapons.
func update(delta: float, active: bool) -> void:
	if not active or _vehicle == null:
		clear()
		return
	if locked:
		if _still_valid(candidate, delta):
			return
		clear()
	var best := find_best_candidate()
	if best == null:
		clear()
		return
	if best != candidate:
		candidate = best
		_acquire = 0.0
	_acquire += delta
	acquire_progress = clampf(_acquire / acquire_time, 0.0, 1.0)
	if _acquire >= acquire_time:
		locked = true
		_blocked = 0.0
		lock_acquired.emit(candidate)


## Best eligible opponent right now, ignoring acquisition time.
func find_best_candidate() -> VehicleController:
	var my_distance: float = race_distance.call(_vehicle)
	var best: VehicleController = null
	var best_ahead := false
	var best_range := INF
	for other in racers:
		if not _in_cone(other, max_range, cone_degrees) or not _has_line_of_sight(other):
			continue
		var ahead: bool = race_distance.call(other) > my_distance
		var dist := _vehicle.global_position.distance_to(other.global_position)
		# Racers ahead in the race take priority (GDD 6.2), then the nearest.
		if (ahead and not best_ahead) or (ahead == best_ahead and dist < best_range):
			best = other
			best_ahead = ahead
			best_range = dist
	return best


func _still_valid(target: VehicleController, delta: float) -> bool:
	if not _in_cone(target, max_range * keep_margin, cone_degrees * keep_margin):
		return false
	if _has_line_of_sight(target):
		_blocked = 0.0
		return true
	_blocked += delta
	return _blocked <= obstruction_grace


func _in_cone(other: VehicleController, max_dist: float, cone: float) -> bool:
	if other == null or other == _vehicle or not is_instance_valid(other):
		return false
	if not is_eligible.call(other):
		return false
	var to := other.global_position - _vehicle.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > max_dist or dist < 1.0:
		return false
	var forward := -_vehicle.global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to)) <= cone


func _has_line_of_sight(other: VehicleController) -> bool:
	var from := _vehicle.global_position + Vector3.UP * 0.8
	var to := other.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to, 1) # environment only
	return _vehicle.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
