class_name PrototypeHUD
extends CanvasLayer
## Driving HUD shared by free drive and races: the speed + drift panel
## (bottom left) and short notices (drift lost, recovered, camera, boosts).
## No controls on screen: they're in the pause menu. Free drive also shows
## its camera / lap timer; in races RaceHUD handles laps, so show_lap_info is
## turned off there.

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

var speed_panel: SpeedDriftPanel

@onready var _info_label: Label = %InfoLabel
@onready var _notice_label: Label = %NoticeLabel


func _ready() -> void:
	speed_panel = SpeedDriftPanel.new()
	add_child(speed_panel)
	_notice_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_notice_label.add_theme_constant_override("outline_size", 6)


func setup(vehicle: VehicleController, camera: ChaseCamera, track: TrackCircuit) -> void:
	_vehicle = vehicle
	_camera = camera
	_track = track
	speed_panel.setup(vehicle)
	add_child(PhysicsDebugOverlay.new(vehicle))
	# In races RaceHUD's SLIPSTREAM banner shows the boost; free drive gets a notice.
	vehicle.slipstream_boost.connect(func() -> void:
		if show_lap_info:
			_show_notice("SLIPSTREAM!", Slipstream.BOOST_COLOR))
	if vehicle.trick != null:
		vehicle.trick.trick_started.connect(func() -> void: _show_notice("TRICK!", UIStyle.MAGENTA))
		vehicle.trick.trick_landed.connect(func() -> void: _show_notice("TRICK BOOST!", VehicleTrick.BOOST_COLOR))
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

	var lap_time := _race_clock - _lap_start_time if _lap_start_time >= 0.0 else 0.0
	# In races the top-left corner belongs to RaceHUD (weapon slots, race info);
	# camera changes still show the centred notice.
	_info_label.visible = show_lap_info
	if show_lap_info:
		_info_label.text = "Camera: %s\nLap %d   %s\nLast %s   Best %s" % [
		_camera.get_profile().display_name, _lap_count + 1, _fmt(lap_time), _fmt(_last_lap_time), _fmt(_best_lap_time)]

	if _notice_time > 0.0:
		_notice_time -= delta
		_notice_label.visible = _notice_time > 0.0
		_notice_label.modulate.a = clampf(_notice_time / 0.4, 0.0, 1.0)


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
		_show_notice("%s BOOST!" % DriftController.LEVEL_NAMES[level].to_upper(), DriftController.LEVEL_COLORS[level])


func _on_drift_cancelled(reason: String) -> void:
	_show_notice("Drift lost (%s)" % reason)


func _show_notice(text: String, color: Color = Color.WHITE) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override("font_color", color)
	_notice_label.visible = true
	_notice_time = 1.6


static func _fmt(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
