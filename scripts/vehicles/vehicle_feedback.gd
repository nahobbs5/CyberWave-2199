class_name VehicleFeedback
extends Node3D
## Placeholder drift and boost feedback (GDD 4.3): coloured undercarriage glow
## and wheel sparks per charge level, exhaust flames during boosts, and
## generated audio tones for each level, drift end and boost.
## Replace with real particles and sounds in Phase 6.

@export var spark_flicker_speed: float = 30.0

var _vehicle: VehicleController
var _drift: DriftController
var _spark_material: StandardMaterial3D
var _flame_material: StandardMaterial3D
var _tones: Dictionary = {}
var _time: float = 0.0

@onready var _glow: OmniLight3D = $UnderGlow
@onready var _sparks: Array[MeshInstance3D] = [$SparkL, $SparkR]
@onready var _flames: Array[MeshInstance3D] = [$FlameL, $FlameR]
@onready var _cue_player: AudioStreamPlayer = $CuePlayer
@onready var _boost_player: AudioStreamPlayer = $BoostPlayer


func _ready() -> void:
	_vehicle = get_parent() as VehicleController
	# Siblings are ready before the vehicle, so fetch the node directly.
	_drift = _vehicle.get_node("DriftController") as DriftController
	_spark_material = _emissive(DriftController.LEVEL_COLORS[0])
	_flame_material = _emissive(Color(1.0, 0.5, 0.1))
	for spark in _sparks:
		spark.material_override = _spark_material
		spark.visible = false
	for flame in _flames:
		flame.material_override = _flame_material
		flame.visible = false
	_glow.visible = false

	_tones = {
		"level_1": _make_tone(660.0, 0.14),
		"level_2": _make_tone(880.0, 0.16),
		"level_3": _make_tone(1175.0, 0.22),
		"drift_end": _make_tone(330.0, 0.08, 0.25),
		"boost": _make_tone(0.0, 0.35, 0.35, true),
	}

	var drift := _drift
	drift.drift_started.connect(_on_drift_started)
	drift.charge_level_changed.connect(_on_charge_level_changed)
	drift.drift_ended.connect(_on_drift_ended)
	drift.drift_cancelled.connect(_on_drift_cancelled)
	_vehicle.boost_started.connect(_on_boost_started)


func _process(delta: float) -> void:
	_time += delta
	var drift := _drift
	var drifting := drift.is_drifting()
	for spark in _sparks:
		spark.visible = drifting and drift.is_charging
		var flicker := 0.7 + 0.3 * sin(_time * spark_flicker_speed + spark.position.x)
		spark.scale = Vector3.ONE * flicker * (1.0 + 0.35 * drift.level)

	_glow.visible = drifting and drift.level > 0
	if _glow.visible:
		_glow.light_energy = 2.0 + float(drift.level)

	var boosting := _vehicle.is_boosting()
	for flame in _flames:
		flame.visible = boosting
		if boosting:
			var length := 0.8 + 0.4 * float(_vehicle.boost_level) + 0.2 * sin(_time * 40.0)
			flame.scale = Vector3(1.0, length, 1.0)


func _set_level_color(level: int) -> void:
	var color := DriftController.LEVEL_COLORS[level]
	_spark_material.albedo_color = color
	_spark_material.emission = color
	_glow.light_color = color


func _on_drift_started(_direction: int) -> void:
	_set_level_color(0)


func _on_charge_level_changed(level: int) -> void:
	_set_level_color(level)
	_play(_cue_player, "level_%d" % level)


func _on_drift_ended(_level: int, boosted: bool) -> void:
	if not boosted:
		_play(_cue_player, "drift_end")


func _on_drift_cancelled(_reason: String) -> void:
	_play(_cue_player, "drift_end")


func _on_boost_started(level: int) -> void:
	var color: Color = DriftController.LEVEL_COLORS[clampi(level, 0, 3)]
	_flame_material.albedo_color = color
	_flame_material.emission = color
	_play(_boost_player, "boost")


func _play(player: AudioStreamPlayer, tone: String) -> void:
	if _tones.has(tone):
		player.stream = _tones[tone]
		player.play()


static func _emissive(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	return mat


## Builds a short 16-bit mono tone (or noise burst when noise is true).
static func _make_tone(frequency: float, duration: float, volume: float = 0.3, noise: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var attack := minf(1.0, t / 0.01)
		var release := 1.0 - float(i) / count
		var sample := randf_range(-1.0, 1.0) * release if noise else sin(TAU * frequency * t)
		data.encode_s16(i * 2, int(clampf(sample * attack * release * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
