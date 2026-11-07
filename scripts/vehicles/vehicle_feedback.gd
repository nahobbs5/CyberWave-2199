class_name VehicleFeedback
extends Node3D
## Placeholder drift and boost feedback (GDD 4.3): coloured undercarriage glow
## and wheel sparks per charge level, exhaust flames during boosts, and
## generated audio tones for each level, drift end and boost, and water
## spray behind the rear wheels while the car is wet.
## Drift feel (Mario Kart style, visual only, physics untouched): a small hop
## when a drift starts, the body angled further into the slide (eased in and
## out), tyre smoke from the rear wheels while sliding, and a looping skid
## hiss for human players.
## Replace with real particles and sounds in Phase 6.

@export var spark_flicker_speed: float = 30.0
## Drift-entry hop: height (m, before the car's visual scale) and duration.
@export var hop_height: float = 0.25
@export var hop_time: float = 0.22
## Extra visible yaw into a drift (rad), plus a bit more when steering in.
@export var drift_yaw: float = 0.32
@export var drift_yaw_steer: float = 0.1
## How quickly the visible yaw eases in and out (per second).
@export var yaw_ease: float = 8.0

var _vehicle: VehicleController
var _drift: DriftController
var _spark_material: StandardMaterial3D
var _flame_material: StandardMaterial3D
var _tones: Dictionary = {}
var _time: float = 0.0
var _spray: Array[MeshInstance3D] = []
## Seconds into the current hop (>= hop_time when not hopping).
var _hop_t: float = 1.0
## Current visible drift yaw (rad) and hop height (m).
var body_yaw: float = 0.0
var body_hop: float = 0.0
## Tyre smoke emitters (rear wheels) and the skid loop.
var smoke: Array[CPUParticles3D] = []
var skid_player: AudioStreamPlayer

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
	_build_spray()
	_build_smoke()
	skid_player = AudioStreamPlayer.new()
	skid_player.name = "SkidPlayer"
	skid_player.bus = &"SFX"
	skid_player.stream = _make_noise_loop()
	skid_player.volume_db = -60.0
	add_child(skid_player)
	_cue_player.bus = &"SFX"
	_boost_player.bus = &"SFX"

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
	_vehicle.external_boost_started.connect(func(_label: String) -> void: _play(_boost_player, "boost"))


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

	_update_drift_body(delta, drifting)
	var sliding := drifting and _vehicle.grounded_wheels >= 2 and absf(_vehicle.lateral_speed) > 1.0
	for puff in smoke:
		puff.emitting = sliding
	_update_skid(delta, sliding)

	var wet := _vehicle.status != null and _vehicle.status.has(&"wet") and absf(_vehicle.forward_speed) > 6.0
	for spray in _spray:
		spray.visible = wet
		if wet:
			var size := clampf(absf(_vehicle.forward_speed) / 30.0, 0.4, 1.4)
			spray.scale = Vector3(size, size * (0.9 + 0.2 * sin(_time * 25.0 + spray.position.x)), size)

	var boosting := _vehicle.is_boosting()
	if boosting:
		_flame_material.albedo_color = _vehicle.boost_color
		_flame_material.emission = _vehicle.boost_color
	for flame in _flames:
		flame.visible = boosting
		if boosting:
			var length := 0.8 + 0.4 * float(_vehicle.boost_level) + 0.2 * sin(_time * 40.0)
			flame.scale = Vector3(1.0, length, 1.0)


## Hop on drift entry and the body angled into the slide. Only writes the
## body's height and yaw, and never while a ramp trick or a stun spin owns it.
func _update_drift_body(delta: float, drifting: bool) -> void:
	var target := 0.0
	if drifting:
		var into := clampf(_vehicle.steer_input * float(_drift.direction), -1.0, 1.0)
		target = -float(_drift.direction) * (drift_yaw + drift_yaw_steer * into)
	body_yaw = lerpf(body_yaw, target, 1.0 - exp(-yaw_ease * delta))
	if absf(body_yaw) < 0.001 and target == 0.0:
		body_yaw = 0.0
	_hop_t += delta
	var k := clampf(_hop_t / hop_time, 0.0, 1.0)
	body_hop = 4.0 * hop_height * _vehicle.visual_scale * k * (1.0 - k)
	var body := _vehicle.get_node_or_null("Body") as Node3D
	var owned := _vehicle.is_tricking() or (_vehicle.status != null and _vehicle.status.body_spin_active())
	if body == null or owned:
		_vehicle.visual_yaw = 0.0
		_vehicle.visual_hop = 0.0
		return
	body.position.y = _vehicle.body_base_y() + body_hop
	body.rotation.y = body_yaw
	_vehicle.visual_yaw = body_yaw
	_vehicle.visual_hop = body_hop


## Skid hiss for human players: fades in with the slide, louder per level.
func _update_skid(delta: float, sliding: bool) -> void:
	if not _vehicle.is_player:
		return
	var target_db := -16.0 + 2.0 * float(_drift.level) if sliding else -60.0
	skid_player.volume_db = lerpf(skid_player.volume_db, target_db, 1.0 - exp(-10.0 * delta))
	if sliding and not skid_player.playing:
		skid_player.play()
	elif not sliding and skid_player.playing and skid_player.volume_db < -50.0:
		skid_player.stop()


func _build_smoke() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.7, 0.84, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	# A soft round puff (radial fade), not a hard square.
	var puff_tex := GradientTexture2D.new()
	puff_tex.fill = GradientTexture2D.FILL_RADIAL
	puff_tex.fill_from = Vector2(0.5, 0.5)
	puff_tex.fill_to = Vector2(0.5, 0.0)
	puff_tex.width = 64
	puff_tex.height = 64
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	puff_tex.gradient = soft
	mat.albedo_texture = puff_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	for side in [-1.0, 1.0]:
		var puff := CPUParticles3D.new()
		puff.name = "Smoke%s" % ("L" if side < 0.0 else "R")
		puff.mesh = quad
		puff.amount = 24
		puff.lifetime = 0.6
		puff.emitting = false
		puff.local_coords = false
		puff.position = Vector3(side * 0.85, -0.45, 1.4)
		puff.direction = Vector3(0.0, 0.6, 1.0)
		puff.spread = 25.0
		puff.initial_velocity_min = 1.5
		puff.initial_velocity_max = 3.0
		puff.gravity = Vector3(0.0, 0.8, 0.0)
		puff.damping_min = 1.5
		puff.damping_max = 2.5
		puff.scale_amount_curve = grow
		puff.color_ramp = fade
		add_child(puff)
		smoke.append(puff)


## A soft looping hiss (filtered noise) for the skid sound.
static func _make_noise_loop(duration: float = 0.5) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	var low := 0.0
	for i in count:
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.35) # take the harsh top off
		data.encode_s16(i * 2, int(clampf(low * 0.5, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


func _build_spray() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.45
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	for side in [-1.0, 1.0]:
		var spray := MeshInstance3D.new()
		spray.mesh = cone
		spray.material_override = mat
		spray.position = Vector3(side * 0.85, -0.45, 1.9)
		spray.rotation.x = -1.2 # fanning up and back from the tyre
		spray.visible = false
		add_child(spray)
		_spray.append(spray)


func _set_level_color(level: int) -> void:
	var color := DriftController.LEVEL_COLORS[level]
	_spark_material.albedo_color = color
	_spark_material.emission = color
	_glow.light_color = color


func _on_drift_started(_direction: int) -> void:
	_set_level_color(0)
	_hop_t = 0.0


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
	# Only the human player's car makes UI-style cues; AI cars would be a cacophony.
	if not _vehicle.is_player:
		return
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
