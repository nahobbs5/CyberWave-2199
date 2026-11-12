class_name OverdriveController
extends Node
## Overdrive Protocol (docs/Cyberwave_2199_Advanced_Weapons.md §2): the kart
## lifts off and flies itself along the course, then lands on a safe stretch
## of road. Lives on the car (VehicleController.overdrive), made on first use.
##
##   ACTIVATING  0.3 s  energy floods the kart, thruster pods slide out
##   ASCENDING   0.6 s  rises to the track's flight height
##   FLIGHT      ~5 s   automated flight along the road centre at 2x top speed
##   DESCENDING  0.6 s  drops onto a validated landing spot
##
## The route is the main road's centre line by distance, so the car never
## leaves the course, and it stays inside the checkpoint gates (6 m tall), so
## every gate still counts in order. While flying the car is untouchable (the
## "overdrive" buff), can't be steered, nudges nearby cars aside, and the
## recovery system leaves it alone. Landing waits for road that's clear of
## cars and jump ramps; with none for 150 m it lands through a recovery.

signal state_changed(state: State)
## The car is back on the road.
signal landed

enum State { NORMAL, ACTIVATING, ASCENDING, FLIGHT, DESCENDING }

const HOLOGRAM_SHADER := preload("res://assets/shaders/hologram.gdshader")
const CYAN := Color(0.0, 0.9, 1.0)
## Height of a car standing on the road (as get_safe_transform uses).
const GROUND_HEIGHT := 0.9

@export var activate_time: float = 0.3
@export var ascend_time: float = 0.6
@export var flight_time: float = 5.0
@export var descend_time: float = 0.6
## Flight speed as a multiple of the car's top speed.
@export var speed_factor: float = 2.0
## Cars closer than this (sideways) get nudged out of the way.
@export var push_radius: float = 3.5
@export var push_strength: float = 6.0
## Distance flown past the end of flight_time looking for a landing spot.
@export var max_extra_distance: float = 150.0
## Landing needs this much clear road around the touchdown point.
@export var landing_clearance: float = 7.0
## Keep landings this far from jump ramps.
@export var ramp_clearance: float = 25.0

var vehicle: VehicleController
var track: TrackCircuit
var state: State = State.NORMAL
var state_time: float = 0.0
## Distance along the main road the flight is at (not wrapped).
var route_offset: float = 0.0
var speed: float = 0.0
## Metres flown since flight_time ran out, hunting a landing spot.
var extra_distance: float = 0.0

var _start_transform: Transform3D
var _start_speed: float = 0.0
var _land_height: float = GROUND_HEIGHT
var _pushed: Dictionary = {}
var _pods: Array[Node3D] = []
var _flames: Array[CPUParticles3D] = []
var _sheen: ShaderMaterial
var _meshes: Array[GeometryInstance3D] = []
var _audio: AudioStreamPlayer

static var _engine_stream: AudioStreamWAV


## The car's controller, made on first use.
static func for_vehicle(car: VehicleController) -> OverdriveController:
	if car.overdrive == null:
		car.overdrive = OverdriveController.new()
		car.overdrive.name = "Overdrive"
		car.overdrive.vehicle = car
		car.add_child(car.overdrive)
	return car.overdrive


func is_active() -> bool:
	return state != State.NORMAL


## Total planned time (the landing may run a little longer).
func planned_time() -> float:
	return activate_time + ascend_time + flight_time + descend_time


## Takes off. Refused while already flying or mid-recovery.
func activate(p_track: TrackCircuit) -> bool:
	if p_track == null or vehicle == null or is_active() or vehicle.recovery.is_busy():
		return false
	track = p_track
	vehicle.drift.cancel("overdrive")
	vehicle.clear_boost()
	if vehicle.status != null:
		vehicle.status.apply_buff(&"overdrive", planned_time() + 1.0)
	route_offset = track.get_offset_at(vehicle.global_position)
	_start_transform = vehicle.global_transform
	_start_speed = maxf(vehicle.forward_speed, 0.0)
	speed = _start_speed
	extra_distance = 0.0
	_pushed.clear()
	_build_visuals()
	_enter(State.ACTIVATING)
	_step(0.0)
	return true


## Ends the flight at once, wherever the car is (elimination, race reset).
func cancel() -> void:
	if not is_active():
		return
	vehicle.end_flight(0.0)
	_finish()


func _exit_tree() -> void:
	cancel()


func _physics_process(delta: float) -> void:
	if not is_active():
		return
	state_time += delta
	match state:
		State.ACTIVATING:
			if state_time >= activate_time:
				_enter(State.ASCENDING)
		State.ASCENDING:
			if state_time >= ascend_time:
				_enter(State.FLIGHT)
		State.FLIGHT:
			if state_time >= flight_time:
				var landing := _find_landing()
				if landing:
					_enter(State.DESCENDING)
				elif extra_distance > max_extra_distance:
					_land_by_recovery()
					return
		State.DESCENDING:
			if state_time >= descend_time:
				_touch_down()
				return
	_step(delta)
	_push_aside(delta)
	_update_visuals()


## Moves the car one step along the route.
func _step(delta: float) -> void:
	var top := vehicle.stats.top_speed
	var target_speed := top * speed_factor
	match state:
		State.ACTIVATING:
			speed = lerpf(_start_speed, maxf(_start_speed, top), state_time / maxf(activate_time, 0.01))
		State.ASCENDING:
			speed = lerpf(maxf(_start_speed, top), target_speed, smoothstep(0.0, 1.0, state_time / maxf(ascend_time, 0.01)))
		State.FLIGHT:
			speed = target_speed
		State.DESCENDING:
			speed = lerpf(target_speed, top, state_time / maxf(descend_time, 0.01))
	route_offset += speed * delta
	if state == State.FLIGHT and state_time >= flight_time:
		extra_distance += speed * delta
	var cruise := track.flight_height_at(route_offset)
	var height := GROUND_HEIGHT
	match state:
		State.ASCENDING:
			height = lerpf(GROUND_HEIGHT, cruise, smoothstep(0.0, 1.0, state_time / maxf(ascend_time, 0.01)))
		State.FLIGHT:
			height = cruise
		State.DESCENDING:
			height = lerpf(_land_height, GROUND_HEIGHT, smoothstep(0.0, 1.0, state_time / maxf(descend_time, 0.01)))
	var route := track.wrap_offset(route_offset)
	var xf := track.get_safe_transform(route, track.column_route_lateral(route), height)
	if state == State.ACTIVATING:
		# Ease off the spot the car was on (another lane, a shortcut) onto the route.
		var t := smoothstep(0.0, 1.0, state_time / maxf(activate_time, 0.01))
		var from := Quaternion(_start_transform.basis.orthonormalized())
		var to := Quaternion(xf.basis.orthonormalized())
		xf = Transform3D(Basis(from.slerp(to, t)), _start_transform.origin.lerp(xf.origin, t))
	var forward := -xf.basis.z
	vehicle.fly_to(xf, forward * speed)


## Picks the touchdown point a little ahead; true if it's safe.
func _find_landing() -> bool:
	var touch_offset := route_offset + speed * descend_time
	var touch := track.wrap_offset(touch_offset)
	var xf := track.get_safe_transform(touch, track.column_route_lateral(touch), GROUND_HEIGHT)
	if not track.is_on_road(xf.origin) or _near_ramp(touch_offset):
		return false
	for node in vehicle.get_tree().get_nodes_in_group(VehicleController.GROUP):
		var other := node as VehicleController
		if other != null and other != vehicle and other.global_position.distance_to(xf.origin) < landing_clearance:
			return false
	_land_height = track.flight_height_at(route_offset)
	return true


func _near_ramp(offset: float) -> bool:
	for child in track.get_children():
		var feature := child as TrackFeature
		if feature == null or feature.kind != TrackFeature.Kind.JUMP_RAMP or feature.on_shortcut != "":
			continue
		var at := track.get_offset_at(feature.global_position)
		if absf(track.wrapped_delta(offset, at)) < ramp_clearance:
			return true
	return false


func _touch_down() -> void:
	vehicle.end_flight(vehicle.stats.top_speed)
	_finish()
	landed.emit()


## Nowhere safe to land: hand over to the recovery system.
func _land_by_recovery() -> void:
	vehicle.end_flight(0.0)
	_finish()
	vehicle.recovery.request_recovery("overdrive")
	landed.emit()


func _finish() -> void:
	if vehicle.status != null:
		vehicle.status.remove(&"overdrive")
	_clear_visuals()
	_enter(State.NORMAL)


func _enter(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	state_changed.emit(new_state)


## Shoves cars under or beside the flight path out of the way (no damage).
func _push_aside(delta: float) -> void:
	for car in _pushed.keys():
		_pushed[car] -= delta
		if _pushed[car] <= 0.0:
			_pushed.erase(car)
	var me := vehicle.global_position
	var fwd := -vehicle.global_transform.basis.z
	for node in vehicle.get_tree().get_nodes_in_group(VehicleController.GROUP):
		var other := node as VehicleController
		if other == null or other == vehicle or other.is_flying() or _pushed.has(other) or other.freeze:
			continue
		var d := other.global_position - me
		var flat := Vector3(d.x, 0.0, d.z)
		if flat.length() > push_radius or d.y > 1.0 or d.y < -6.0:
			continue
		var side := flat - fwd * flat.dot(fwd)
		if side.length() < 0.1:
			side = fwd.cross(Vector3.UP)
		other.apply_central_impulse(side.normalized() * push_strength * other.mass)
		_pushed[other] = 0.5


# --- look and sound ------------------------------------------------------------

func _build_visuals() -> void:
	_clear_visuals()
	var scale := vehicle.visual_scale
	var glow := WeaponManager.glow_material(CYAN, 4.0)
	for side: float in [-1.0, 1.0]:
		var pod := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.16
		capsule.height = 1.3
		pod.mesh = capsule
		pod.material_override = glow
		pod.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		pod.position = Vector3(side * 0.7 * scale, 0.35 * scale, 0.5 * scale)
		pod.scale = Vector3.ONE * 0.01
		vehicle.add_child(pod)
		_pods.append(pod)
		var flame := CPUParticles3D.new()
		flame.amount = 40
		flame.lifetime = 0.25
		flame.local_coords = false
		var bead := SphereMesh.new()
		bead.radius = 0.12
		bead.height = 0.24
		bead.material = glow
		flame.mesh = bead
		flame.direction = Vector3(0, 0, 1)
		flame.spread = 8.0
		flame.gravity = Vector3.ZERO
		flame.initial_velocity_min = 8.0
		flame.initial_velocity_max = 12.0
		var shrink := Curve.new()
		shrink.add_point(Vector2(0.0, 1.0))
		shrink.add_point(Vector2(1.0, 0.0))
		flame.scale_amount_curve = shrink
		# On the car (not the turned pod) so "backwards" is the car's +Z.
		flame.position = Vector3(side * 0.7 * scale, 0.35 * scale, 1.15 * scale)
		flame.emitting = false
		vehicle.add_child(flame)
		_flames.append(flame)
	# Cyan energy over the bodywork (the recovery hologram, gently).
	_sheen = ShaderMaterial.new()
	_sheen.shader = HOLOGRAM_SHADER
	_sheen.set_shader_parameter(&"wire", 0.25)
	_meshes.clear()
	var body := vehicle.get_node_or_null("Body")
	if body != null:
		_collect_meshes(body)
	for mesh in _meshes:
		mesh.material_overlay = _sheen
	if vehicle.is_player:
		if _engine_stream == null:
			_engine_stream = _make_engine_loop()
		_audio = AudioStreamPlayer.new()
		_audio.bus = &"SFX"
		_audio.stream = _engine_stream
		_audio.volume_db = -10.0
		add_child(_audio)
		_audio.play()


func _collect_meshes(node: Node) -> void:
	if node is GeometryInstance3D and not node is Label3D:
		_meshes.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_meshes(child)


func _update_visuals() -> void:
	var grow := 1.0
	var strength := 0.35
	match state:
		State.ACTIVATING:
			grow = state_time / maxf(activate_time, 0.01)
			strength = 0.9 * grow
		State.DESCENDING:
			grow = 1.0 - 0.6 * state_time / maxf(descend_time, 0.01)
			strength = 0.35 * (1.0 - state_time / maxf(descend_time, 0.01))
	for pod in _pods:
		pod.scale = Vector3.ONE * maxf(0.01, grow) * vehicle.visual_scale
	for flame in _flames:
		flame.emitting = state == State.ASCENDING or state == State.FLIGHT
	if _sheen != null:
		_sheen.set_shader_parameter(&"strength", strength)
		_sheen.set_shader_parameter(&"base_y", vehicle.global_position.y - 0.45 * vehicle.visual_scale)
		_sheen.set_shader_parameter(&"height", 1.6 * vehicle.visual_scale)
	if _audio != null:
		_audio.pitch_scale = clampf(0.7 + speed / maxf(vehicle.stats.top_speed * speed_factor, 1.0) * 0.8, 0.5, 2.0)


func _clear_visuals() -> void:
	for pod in _pods:
		if is_instance_valid(pod):
			pod.queue_free()
	_pods.clear()
	for flame in _flames:
		if is_instance_valid(flame):
			flame.queue_free()
	_flames.clear()
	for mesh in _meshes:
		if is_instance_valid(mesh) and mesh.material_overlay == _sheen:
			mesh.material_overlay = null
	_meshes.clear()
	_sheen = null
	if _audio != null:
		_audio.queue_free()
		_audio = null


## A looping jet hum: two detuned saws and a little noise.
static func _make_engine_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate # one second
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	for i in count:
		var t := float(i) / rate
		var a := fmod(t * 110.0, 1.0) * 2.0 - 1.0
		var b := fmod(t * 111.0, 1.0) * 2.0 - 1.0
		var hiss := rng.randf_range(-1.0, 1.0) * 0.25
		var sample := (a + b) * 0.35 + hiss
		data.encode_s16(i * 2, int(clampf(sample * 0.3, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
