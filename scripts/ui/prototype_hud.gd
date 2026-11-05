class_name PrototypeHUD
extends CanvasLayer
## Minimal Phase 1 debug HUD: speed, drift charge, boost, camera, lap timer,
## recovery notices and a controls hint. Not the final race HUD (GDD 11.5).
## In races, RaceHUD handles laps, so show_lap_info is turned off there.

## Show the distance-based free-drive lap timer.
@export var show_lap_info: bool = true

var _vehicle: VehicleController
var _camera: ChaseCamera
var _track: TrackCircuit

var _lap_count: int = 0
var _lap_start_time: float = -1.0
var _last_lap_time: float = -1.0
var _best_lap_time: float = -1.0
var _race_clock: float = 0.0
var _notice_time: float = 0.0

@onready var _speed_label: Label = %SpeedLabel
@onready var _drift_label: Label = %DriftLabel
@onready var _drift_meter: DriftMeter = %DriftMeter
@onready var _info_label: Label = %InfoLabel
@onready var _notice_label: Label = %NoticeLabel


func setup(vehicle: VehicleController, camera: ChaseCamera, track: TrackCircuit) -> void:
	_vehicle = vehicle
	_camera = camera
	_track = track
	_drift_meter.drift = vehicle.drift
	vehicle.recovery.recovered.connect(_on_recovered)
	vehicle.drift.drift_ended.connect(_on_drift_ended)
	vehicle.drift.drift_cancelled.connect(_on_drift_cancelled)
	camera.profile_changed.connect(func(p: CameraProfile) -> void: _show_notice("Camera: " + p.display_name))


## Laps completed, measured from the start line using legitimate track progress.
func get_lap_count() -> int:
	return _lap_count


func _process(delta: float) -> void:
	if _vehicle == null:
		return
	_race_clock += delta
	if show_lap_info:
		_update_laps()

	_speed_label.text = "%d km/h" % roundi(absf(_vehicle.forward_speed) * 3.6)

	var drift := _vehicle.drift
	if _vehicle.is_boosting():
		_drift_label.text = "BOOST  %s" % DriftController.LEVEL_NAMES[_vehicle.boost_level].to_upper()
		_drift_label.modulate = DriftController.LEVEL_COLORS[_vehicle.boost_level]
	elif drift.is_drifting():
		_drift_label.text = "DRIFT %s  %.1fs  %s" % [
			"L" if drift.direction < 0 else "R", drift.charge_time, DriftController.LEVEL_NAMES[drift.level]]
		_drift_label.modulate = DriftController.LEVEL_COLORS[drift.level]
	else:
		_drift_label.text = "DRIFT  (hold Shift + A / D in a corner)"
		_drift_label.modulate = Color(1, 1, 1, 0.6)

	var lap_time := _race_clock - _lap_start_time if _lap_start_time >= 0.0 else 0.0
	if not show_lap_info:
		_info_label.text = "Camera: %s" % _camera.get_profile().display_name
	else:
		_info_label.text = "Camera: %s\nLap %d   %s\nLast %s   Best %s" % [
		_camera.get_profile().display_name, _lap_count + 1, _fmt(lap_time), _fmt(_last_lap_time), _fmt(_best_lap_time)]

	if _notice_time > 0.0:
		_notice_time -= delta
		_notice_label.visible = _notice_time > 0.0


func _update_laps() -> void:
	# total_progress starts at 0 on the spawn point, which is behind the line.
	var from_line := _vehicle.recovery.total_progress - _track.spawn_distance_behind_line
	if _lap_start_time < 0.0 and from_line >= 0.0:
		_lap_start_time = _race_clock
	var completed := maxi(0, floori(from_line / _track.length))
	if completed > _lap_count:
		_lap_count = completed
		_last_lap_time = _race_clock - _lap_start_time
		if _best_lap_time < 0.0 or _last_lap_time < _best_lap_time:
			_best_lap_time = _last_lap_time
		_lap_start_time = _race_clock
		_show_notice("Lap %d complete  %s" % [_lap_count, _fmt(_last_lap_time)])


func _on_recovered(reason: String) -> void:
	_show_notice("Recovered (%s)" % reason)


func _on_drift_ended(level: int, boosted: bool) -> void:
	if boosted:
		_show_notice("%s boost!" % DriftController.LEVEL_NAMES[level])


func _on_drift_cancelled(reason: String) -> void:
	_show_notice("Drift lost (%s)" % reason)


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = true
	_notice_time = 2.0


static func _fmt(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
