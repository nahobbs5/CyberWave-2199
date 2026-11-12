class_name HunterKillerDrone
extends Node3D
## Hunter-Killer Drone (docs/Cyberwave_2199_Advanced_Weapons.md §1): locks on
## to the race leader at launch and keeps that racer as its target even if
## they lose the lead. It flies along the road (above the centre line, by
## distance, so it passes everyone else and never cuts through scenery) at
## 1.8x the target's top speed. Close behind, it holds a red reticle over the
## target for 1.2 s, then dives and discharges: a 1.5 s spin-out. A Firewall
## doesn't help: the only escape is firing a Nitro in the last DODGE_WINDOW s
## of the warning or during the dive, which makes it miss. It waits while the target is mid-recovery or flying an
## Overdrive, and burns out after 12 s or when the target finishes.

enum Phase { CRUISE, WARNING, DIVE, MISS }

const CRUISE_HEIGHT := 3.0
## Distance along the track at which it closes in and warns the target.
const HOMING_DISTANCE := 35.0
const WARNING_TIME := 1.2
const HIT_RANGE := 2.2
## A Nitro fired this close to the dive (or during it) dodges the drone.
const DODGE_WINDOW := 0.4
## How long a dodged drone flies on before it fizzles.
const MISS_TIME := 0.5
## Where it hovers while the target can't be hit (m behind, m up).
const WAIT_BEHIND := 12.0
const BODY_COLOR := Color(0.035, 0.035, 0.045)
const EYE_COLOR := Color(1.0, 0.12, 0.08)
const BLAST_COLOR := Color(0.65, 0.85, 1.0)

var manager: WeaponManager
var shooter: VehicleController
var weapon: WeaponData
## The racer it hunts (locked at launch).
var target: VehicleController
var phase: Phase = Phase.CRUISE
## Seconds left of the warning.
var warning_left: float = 0.0

var _age: float = 0.0
## Where a dodged drone slams in, and how long until it does.
var _miss_point: Vector3
var _miss_left: float = 0.0
## Distance along the main road (not wrapped).
var _route: float = 0.0
var _reticle: MeshInstance3D
var _beam: MeshInstance3D
var _audio: AudioStreamPlayer3D
## Lock-on beeps on the target while it warns (stopped when the drone hits,
## gives up or burns out).
var _warn_sfx: AudioStreamPlayer3D

static var _whine: AudioStreamWAV


## True while the reticle is up over the target.
func is_warning() -> bool:
	return phase == Phase.WARNING


## Dodged and fizzling out: no longer a threat.
func is_spent() -> bool:
	return phase == Phase.MISS


## A Nitro fired now dodges it: the last DODGE_WINDOW s of the warning, or the dive.
func in_dodge_window() -> bool:
	return phase == Phase.DIVE or (phase == Phase.WARNING and warning_left <= DODGE_WINDOW)


func _ready() -> void:
	add_to_group(&"hunter_drones")
	_build_body()
	_route = manager.track.get_offset_at(global_position)
	if _whine == null:
		_whine = _make_whine()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _whine
	_audio.bus = &"SFX"
	_audio.unit_size = 12.0
	_audio.volume_db = -4.0
	add_child(_audio)
	_audio.play()
	CombatSfx.play_on(shooter, CombatSfx.HK_LAUNCH, "HkLaunch")
	manager.weapon_used.connect(_on_weapon_used)


func _on_weapon_used(user: VehicleController, used: WeaponData) -> void:
	if user == target and used.kind == WeaponData.Kind.SELF_BOOST and in_dodge_window():
		_dodged()


## The target's Nitro outran the dive: overshoot into the road where they were.
func _dodged() -> void:
	phase = Phase.MISS
	_stop_warning_sound()
	_miss_point = target.global_position
	_miss_left = MISS_TIME
	manager.hit_resolved.emit(target, weapon, shooter, &"dodge")


## The leader for a launch by `user`: 1st place, or 2nd if `user` leads.
static func pick_target(race: RaceManager, user: VehicleController) -> VehicleController:
	for racer in race.get_standings():
		if racer.vehicle != user and not racer.finished and not racer.eliminated:
			return racer.vehicle
	return null


func _physics_process(delta: float) -> void:
	_age += delta
	if phase == Phase.MISS:
		_move_toward(_miss_point, 60.0, delta)
		_miss_left -= delta
		if _miss_left <= 0.0 or global_position.distance_to(_miss_point) < 0.5:
			manager.spawn_flash(global_position, BLAST_COLOR)
			manager.spawn_arc_burst(global_position, BLAST_COLOR)
			queue_free()
		else:
			_update_marks(delta)
		return
	if _age > weapon.lifetime or not _target_in_race():
		_burn_out()
		return
	var track := manager.track
	var top := target.stats.top_speed if target.stats != null else 40.0
	var speed := top * weapon.speed
	var available := manager.is_targetable(target) and not target.is_flying()
	var target_offset := track.get_offset_at(target.global_position)
	var gap := fposmod(target_offset - track.wrap_offset(_route), track.length)
	if gap > track.length * 0.9:
		gap -= track.length # just passed it
	match phase:
		Phase.CRUISE:
			# Fly the road; when the target can't be hit, hover behind it.
			var limit := gap - (WAIT_BEHIND if not available else 0.0)
			_route += clampf(speed * delta, 0.0, maxf(limit, 0.0)) if limit > 0.0 else 0.0
			var route := track.wrap_offset(_route)
			var goal := track.get_safe_transform(route, track.column_route_lateral(route), CRUISE_HEIGHT).origin
			_move_toward(goal, speed * 1.2, delta)
			if available and gap < HOMING_DISTANCE:
				phase = Phase.WARNING
				warning_left = WARNING_TIME
				_stop_warning_sound()
				_warn_sfx = CombatSfx.play_on(target, CombatSfx.HK_WARNING, "HkWarning")
		Phase.WARNING:
			if not available:
				phase = Phase.CRUISE
				_stop_warning_sound()
				_route = target_offset - WAIT_BEHIND
			else:
				var behind := -target.global_transform.basis.z
				behind.y = 0.0
				var goal := target.global_position - behind.normalized() * 7.0 + Vector3.UP * 3.5
				_move_toward(goal, maxf(speed, target.linear_velocity.length() + 15.0), delta)
				_route = track.get_offset_at(global_position)
				warning_left -= delta
				if warning_left <= 0.0:
					phase = Phase.DIVE
		Phase.DIVE:
			if not available:
				phase = Phase.CRUISE
				_stop_warning_sound()
				_route = target_offset - WAIT_BEHIND
			else:
				var aim := target.global_position + Vector3.UP * 0.6
				_move_toward(aim, maxf(speed * 1.3, target.linear_velocity.length() + 25.0), delta)
				if global_position.distance_to(aim) < HIT_RANGE:
					_detonate()
					return
	_update_marks(delta)


func _target_in_race() -> bool:
	if not is_instance_valid(target) or manager.race == null:
		return false
	var progress := manager.race.progress_of(target)
	return progress != null and not progress.finished and not progress.eliminated


func _move_toward(goal: Vector3, max_speed: float, delta: float) -> void:
	var to_goal := goal - global_position
	var step := minf(to_goal.length(), max_speed * delta)
	if to_goal.length() > 0.01:
		var dir := to_goal.normalized()
		global_position += dir * step
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.1:
			var want := Basis.looking_at(flat.normalized(), Vector3.UP)
			basis = basis.slerp(want, clampf(10.0 * delta, 0.0, 1.0)).orthonormalized()


func _detonate() -> void:
	manager.apply_hit(target, weapon, shooter)
	manager.spawn_flash(global_position, BLAST_COLOR)
	manager.spawn_arc_burst(target.global_position + Vector3.UP * 0.6, BLAST_COLOR)
	CombatSfx.play_on(target, CombatSfx.HK_EXPLOSION, "HkExplosion")
	queue_free()


func _exit_tree() -> void:
	_stop_warning_sound()


func _stop_warning_sound() -> void:
	if is_instance_valid(_warn_sfx):
		_warn_sfx.queue_free()
	_warn_sfx = null


func _burn_out() -> void:
	manager.spawn_flash(global_position, EYE_COLOR)
	queue_free()


# --- look and sound ------------------------------------------------------------

func _build_body() -> void:
	var matte := StandardMaterial3D.new()
	matte.albedo_color = BODY_COLOR
	matte.roughness = 0.85
	matte.metallic = 0.3
	# Triangular hull, nose forward (-Z).
	var hull := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.8, 0.45)
	hull.mesh = prism
	hull.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	hull.material_override = matte
	add_child(hull)
	# Swept stabilisers.
	for side: float in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.1, 0.06, 0.45)
		fin.mesh = box
		fin.material_override = matte
		fin.position = Vector3(side * 0.9, 0.12, 0.55)
		fin.rotation = Vector3(0.0, side * 0.5, side * 0.35)
		add_child(fin)
		var tip := MeshInstance3D.new()
		var light_box := BoxMesh.new()
		light_box.size = Vector3(0.12, 0.08, 0.12)
		tip.mesh = light_box
		tip.material_override = WeaponManager.glow_material(EYE_COLOR, 3.0)
		tip.position = Vector3(side * 1.4, 0.2, 0.75)
		add_child(tip)
	# Red tracking eye.
	var eye := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	eye.mesh = sphere
	eye.material_override = WeaponManager.glow_material(EYE_COLOR, 6.0)
	eye.position = Vector3(0.0, 0.18, -0.25)
	add_child(eye)
	var light := OmniLight3D.new()
	light.light_color = EYE_COLOR
	light.light_energy = 2.0
	light.omni_range = 6.0
	add_child(light)
	# Warning marks (shown while it warns): a reticle over the target and a beam.
	_reticle = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.35
	ring.outer_radius = 1.85
	_reticle.mesh = ring
	var reticle_mat := WeaponManager.glow_material(EYE_COLOR, 4.0)
	reticle_mat.no_depth_test = true
	_reticle.material_override = reticle_mat
	_reticle.top_level = true
	_reticle.visible = false
	add_child(_reticle)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	_beam.mesh = cyl
	_beam.material_override = WeaponManager.glow_material(EYE_COLOR, 3.0)
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func _update_marks(delta: float) -> void:
	var warn := phase == Phase.WARNING
	_reticle.visible = warn
	_beam.visible = warn or phase == Phase.DIVE
	if warn:
		var t := 1.0 - warning_left / WARNING_TIME
		_reticle.global_position = target.global_position + Vector3.UP * 3.0
		_reticle.rotation = Vector3(0.0, _age * 4.0, 0.0)
		_reticle.scale = Vector3.ONE * lerpf(1.6, 0.8, t)
	if _beam.visible:
		var from := global_position
		var to := target.global_position + Vector3.UP * 0.6
		var length := from.distance_to(to)
		if length > 0.1:
			var mid := (from + to) * 0.5
			var dir := (to - from) / length
			var side := dir.cross(Vector3.UP)
			if side.length() < 0.01:
				side = Vector3.RIGHT
			var b := Basis(side.normalized(), dir, side.normalized().cross(dir)).orthonormalized()
			_beam.global_transform = Transform3D(b.scaled_local(Vector3(1.0, length, 1.0)), mid)
	if _audio != null:
		_audio.pitch_scale = 1.6 if warn or phase == Phase.DIVE else 1.0


## A turbine whine (loops).
static func _make_whine() -> AudioStreamWAV:
	var rate := 22050
	var count := rate / 2
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var sample := sin(TAU * 620.0 * t) * 0.5 + sin(TAU * 1244.0 * t) * 0.3 + sin(TAU * 90.0 * t) * 0.3
		data.encode_s16(i * 2, int(clampf(sample * 0.25, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
