class_name RecoveryEffect
extends Node3D
## The look and sound of a recovery (docs/Recovery System.md §8-9), driven by
## VehicleRecovery's stages. Lives on the car; VehicleRecovery makes it the
## first time the car recovers.
##
## The car's own meshes fade out (GeometryInstance3D.transparency) under a
## hologram overlay (material_overlay, so paint overrides stay untouched)
## that flickers, grows scan lines and sweeps away bottom to top. Fragments
## burst out with a flash. At the recovery spot fragments converge, the
## hologram builds bottom to top with a grid "wireframe", then the solid body
## fades back in and the glow fades. A faint shimmer stays during the
## protection time. Everything else on the car (lights, smoke, shield, name
## tag) is hidden while the car is gone. Sounds are made in code and only
## play for human players.

const HOLOGRAM_SHADER := preload("res://assets/shaders/hologram.gdshader")
const CYAN := Color(0.0, 0.95, 1.0)
const SPLASH_COLOR := Color(0.75, 0.9, 1.0)
const EMBER_COLOR := Color(1.0, 0.45, 0.08)
## Car-local children that are never hidden (physics and logic).
const KEEP_VISIBLE := [&"Body", &"RecoveryEffect"]

static var _fragment_mesh: BoxMesh
static var _fragment_material: StandardMaterial3D
static var _sounds: Dictionary = {}

var recovery: VehicleRecovery
var vehicle: VehicleController
## The car's hologram material (one per car; shared by its meshes).
var material: ShaderMaterial

var _meshes: Array[GeometryInstance3D] = []
var _hidden_extras: Array[Node3D] = []
var _active: bool = false
var _burst: CPUParticles3D
var _converge: CPUParticles3D
var _splash: CPUParticles3D
## Glowing embers when a car hits lava.
var _embers: CPUParticles3D
var _flash: OmniLight3D
var _flash_tween: Tween
var _audio: Array[AudioStreamPlayer] = []
var _next_audio: int = 0


func setup(p_recovery: VehicleRecovery) -> void:
	recovery = p_recovery
	vehicle = recovery.vehicle
	material = ShaderMaterial.new()
	material.shader = HOLOGRAM_SHADER
	_burst = _make_particles(28, 0.45, false)
	_converge = _make_particles(28, 0.4, true)
	_splash = _make_splash()
	_embers = _make_embers()
	_flash = OmniLight3D.new()
	_flash.top_level = true
	_flash.light_color = CYAN
	_flash.omni_range = 9.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.volume_db = -6.0
		add_child(player)
		_audio.append(player)
	recovery.state_changed.connect(_on_state_changed)


func _on_state_changed(state: VehicleRecovery.State) -> void:
	match state:
		VehicleRecovery.State.DISINTEGRATING:
			_begin()
			if recovery.last_reason == "water":
				_emit_at(_splash, vehicle.global_position)
				_play("splash")
			elif recovery.last_reason == "lava":
				_emit_at(_embers, vehicle.global_position)
				_play("splash") # the same hiss reads as a sizzle
			_play("warning")
			_play("breakup")
		VehicleRecovery.State.TELEPORTING:
			_emit_at(_burst, vehicle.global_position + Vector3.UP * 0.6)
			_flash_at(vehicle.global_position + Vector3.UP)
			_set_car_visible(false)
			_play("pulse")
		VehicleRecovery.State.RECONSTRUCTING:
			_set_car_visible(true)
			_emit_at(_converge, recovery.target_transform.origin + Vector3.UP * 0.6)
			_play("shimmer")
		VehicleRecovery.State.PROTECTED:
			_play("confirm")
		VehicleRecovery.State.NORMAL:
			_end()
	_update_look()


func _process(_delta: float) -> void:
	if _active:
		_update_look()


## Collects the car's meshes and puts the hologram on them.
func _begin() -> void:
	_end()
	_active = true
	_meshes.clear()
	var body := vehicle.get_node_or_null("Body")
	if body != null:
		_collect_meshes(body)
	for child in vehicle.get_children():
		if child is RayCast3D:
			var pivot := (child as Node).get_node_or_null("Pivot")
			if pivot != null:
				_collect_meshes(pivot)
	for mesh in _meshes:
		# Text (the plate) just fades; the hologram would draw its quad.
		if not mesh is Label3D:
			mesh.material_overlay = material
	# Lights, smoke, shield and name tag go at once: they'd float in mid-air.
	_hidden_extras.clear()
	for child in vehicle.get_children():
		var node := child as Node3D
		if node == null or node is RayCast3D or node is CollisionShape3D or node.name in KEEP_VISIBLE:
			continue
		if node.visible:
			node.visible = false
			_hidden_extras.append(node)


## Puts the car back exactly as it was.
func _end() -> void:
	_active = false
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
			mesh.transparency = 0.0
	_meshes.clear()
	_set_car_visible(true)
	for node in _hidden_extras:
		if is_instance_valid(node):
			node.visible = true
	_hidden_extras.clear()


func _collect_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		_meshes.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_meshes(child)


func _set_car_visible(on: bool) -> void:
	var body := vehicle.get_node_or_null("Body") as Node3D
	if body != null:
		body.visible = on
	for child in vehicle.get_children():
		if child is RayCast3D:
			var pivot := (child as Node).get_node_or_null("Pivot") as Node3D
			if pivot != null:
				pivot.visible = on


## Sets the shader and fade for where the sequence is now (doc §8 timelines).
func _update_look() -> void:
	if not _active:
		return
	var u := 0.0
	var length := recovery._stage_length(recovery.state)
	if length > 0.0 and length < INF:
		u = clampf(recovery.state_time / length, 0.0, 1.0)
	var calm := 0.25 if GameSettings.reduced_flashing else 1.0
	var strength := 0.0
	var dissolve := 0.0
	var build := 1.0
	var wire := 0.0
	var flicker := 0.0
	var fade := 0.0
	match recovery.state:
		VehicleRecovery.State.DISINTEGRATING:
			# 0.0 flicker, 0.1 scan lines, 0.2 dissolving, 0.3 gone.
			strength = smoothstep(0.0, 0.35, u)
			flicker = calm
			wire = 0.4 * u
			dissolve = clampf((u - 0.55) / 0.45, 0.0, 1.0)
			fade = clampf((u - 0.4) / 0.6, 0.0, 1.0)
		VehicleRecovery.State.RECONSTRUCTING:
			# 0.0 outline, 0.15 wireframe, 0.3 solid forming, 0.45 glow fades.
			strength = 1.0 - 0.75 * smoothstep(0.85, 1.0, u)
			build = clampf(u / 0.6, 0.0, 1.0)
			wire = sin(clampf(u / 0.75, 0.0, 1.0) * PI)
			flicker = 0.3 * calm
			fade = 1.0 - clampf((u - 0.6) / 0.3, 0.0, 1.0)
		VehicleRecovery.State.PROTECTED:
			# A faint shimmer while other cars pass through.
			strength = 0.25 * (1.0 - u) * (0.75 + 0.25 * sin(recovery.state_time * 18.0))
			flicker = 0.15 * calm
		_:
			fade = 1.0
	var origin := vehicle.global_position
	material.set_shader_parameter(&"strength", strength)
	material.set_shader_parameter(&"dissolve", dissolve)
	material.set_shader_parameter(&"build", build)
	material.set_shader_parameter(&"wire", wire)
	material.set_shader_parameter(&"flicker", flicker)
	material.set_shader_parameter(&"base_y", origin.y - 0.45 * vehicle.visual_scale)
	material.set_shader_parameter(&"height", 1.6 * vehicle.visual_scale)
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.transparency = fade


# --- particles and flash -------------------------------------------------------

func _make_particles(amount: int, lifetime: float, converge: bool) -> CPUParticles3D:
	if _fragment_mesh == null:
		_fragment_mesh = BoxMesh.new()
		_fragment_mesh.size = Vector3.ONE * 0.12
		_fragment_material = StandardMaterial3D.new()
		_fragment_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fragment_material.albedo_color = CYAN
		_fragment_material.emission_enabled = true
		_fragment_material.emission = CYAN
		_fragment_material.emission_energy_multiplier = 3.0
		_fragment_mesh.material = _fragment_material
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.mesh = _fragment_mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	if converge:
		# Fragments drawn in from all round onto the car.
		p.emission_sphere_radius = 3.0
		p.radial_accel_min = -22.0
		p.radial_accel_max = -16.0
		p.damping_min = 4.0
		p.damping_max = 6.0
	else:
		# The car breaking up: fragments fly out and up.
		p.emission_sphere_radius = 1.2
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0.0, 2.0, 0.0)
		p.damping_min = 2.0
		p.damping_max = 4.0
	add_child(p)
	return p


func _make_splash() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 24
	p.lifetime = 0.6
	p.local_coords = false
	var drop := SphereMesh.new()
	drop.radius = 0.08
	drop.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SPLASH_COLOR
	drop.material = mat
	p.mesh = drop
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	add_child(p)
	return p


## Lava: a fountain of glowing embers that float up and fade.
func _make_embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 40
	p.lifetime = 1.1
	p.local_coords = false
	var spark := SphereMesh.new()
	spark.radius = 0.07
	spark.height = 0.14
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = EMBER_COLOR
	mat.emission_enabled = true
	mat.emission = EMBER_COLOR
	mat.emission_energy_multiplier = 4.0
	spark.material = mat
	p.mesh = spark
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.4
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0.0, -3.0, 0.0)
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	add_child(p)
	return p


func _emit_at(particles: CPUParticles3D, where: Vector3) -> void:
	particles.global_position = where
	particles.restart()
	particles.emitting = true


func _flash_at(where: Vector3) -> void:
	_flash.global_position = where
	if _flash_tween != null:
		_flash_tween.kill()
	var peak := 2.0 if GameSettings.reduced_flashing else 6.0
	_flash.light_energy = peak
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "light_energy", 0.0, 0.2)


# --- sound ---------------------------------------------------------------------

func _play(sound: String) -> void:
	if not vehicle.is_player or _audio.is_empty() or not is_inside_tree():
		return
	var player := _audio[_next_audio]
	_next_audio = (_next_audio + 1) % _audio.size()
	player.stream = sound_stream(sound)
	player.play()


## One of the recovery sounds (made once, then shared):
## warning, breakup, pulse, shimmer, confirm, splash.
static func sound_stream(sound: String) -> AudioStreamWAV:
	if not _sounds.has(sound):
		_sounds[sound] = _synth(sound)
	return _sounds[sound]


static func _synth(sound: String) -> AudioStreamWAV:
	var rate := 22050
	var duration: float = {"warning": 0.14, "breakup": 0.3, "pulse": 0.35, "shimmer": 0.45,
			"confirm": 0.2, "splash": 0.35}.get(sound, 0.2)
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var held := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var u := float(i) / count
		var env := minf(1.0, t / 0.008) * (1.0 - u)
		var sample := 0.0
		match sound:
			"warning":
				# Two quick high blips.
				sample = sin(TAU * 1250.0 * t) * (1.0 if fmod(t, 0.07) < 0.045 else 0.0)
				env = minf(1.0, t / 0.004)
			"breakup":
				# Static that stutters, crushed to a few levels.
				if i % 6 == 0:
					held = rng.randf_range(-1.0, 1.0)
				var gate := 1.0 if fmod(t * 40.0 + sin(t * 90.0), 1.0) < 0.6 else 0.2
				sample = snappedf(held, 0.25) * gate * 0.8
			"pulse":
				# A low synthetic thump that drops in pitch.
				phase += TAU * lerpf(110.0, 45.0, u) / rate
				sample = sin(phase) * 1.4
			"shimmer":
				# A rising sweep with a fast tremolo.
				phase += TAU * lerpf(380.0, 1500.0, u * u) / rate
				sample = sin(phase) * (0.6 + 0.4 * sin(TAU * 32.0 * t))
				env = minf(1.0, u / 0.3) * (1.0 - smoothstep(0.75, 1.0, u))
			"confirm":
				# Two short rising notes.
				sample = sin(TAU * (880.0 if t < 0.09 else 1320.0) * t)
			"splash":
				# A soft burst of noise.
				held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.35)
				sample = held * 1.6
		data.encode_s16(i * 2, int(clampf(sample * env * 0.28, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
