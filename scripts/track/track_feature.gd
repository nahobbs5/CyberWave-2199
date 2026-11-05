@tool
class_name TrackFeature
extends Node3D
## A shared track feature (GDD 8.7), placed by distance along the track.
## Add as a child of a TrackCircuit (or give it a shortcut name to sit on a
## shortcut). Kinds:
##   BOOST_PAD      flat strip: short speed burst for anyone driving over it
##   BOOST_RING     drive-through ring: a bigger burst
##   EMP_PUDDLE     electrified hazard: a 1 s EMP (a Firewall blocks it)
##   BREAKABLE      destructible barrier row: smashes on contact, costs some
##                  speed, rebuilds after a while (often guards a shortcut)
## Every kind is clearly marked and lit so it reads at speed (GDD 15.3).

enum Kind { BOOST_PAD, BOOST_RING, EMP_PUDDLE, BREAKABLE }

const PAD_COLOR := Color(0.0, 0.95, 1.0)
const RING_COLOR := Color(1.0, 0.2, 0.85)
const EMP_COLOR := Color(0.3, 0.55, 1.0)
const BARRIER_COLOR := Color(1.0, 0.75, 0.1)

@export var kind: Kind = Kind.BOOST_PAD:
	set(value):
		kind = value
		_rebuild_visuals()
## Distance along the main loop (or along the shortcut when on_shortcut is set).
@export var offset: float = 0.0
## If set (main road only), offset is measured from the road point nearest
## this layout position instead of from the start.
@export var anchor_point: Vector3 = Vector3.ZERO
## Metres right of the centre line.
@export var lateral: float = 0.0
## Name of a TrackShortcut sibling to place this on; empty = main road.
@export var on_shortcut: String = ""
## Width across the road (pads, puddles, barrier rows).
@export var width: float = 5.0
## Boost strength (pads and rings): extra top speed, duration, instant kick.
@export var boost_extra: float = 7.0
@export var boost_duration: float = 1.0
@export var boost_kick: float = 4.0
## Breakable barriers rebuild after this long.
@export var rebuild_time: float = 8.0
## Fraction of speed kept when smashing through a breakable barrier.
@export var smash_speed_kept: float = 0.85

## Times anything triggered it (tests / telemetry).
var triggered: int = 0

var _cooldowns: Dictionary = {}
var _broken_time: float = 0.0
var _visual: Node3D
var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	_rebuild_visuals()


## Called by the TrackCircuit once its curve (and shortcuts) are built.
func place_on_track(track: TrackCircuit) -> void:
	var xf: Transform3D
	var sc := track.get_node_or_null(on_shortcut) as TrackShortcut if on_shortcut != "" else null
	if sc != null and sc.is_valid():
		var tangent := sc.tangent_at(offset)
		var right := tangent.cross(Vector3.UP).normalized()
		xf = Transform3D(Basis.looking_at(tangent, Vector3.UP), sc.point_at(offset) + right * lateral)
	else:
		var d := offset
		if anchor_point != Vector3.ZERO:
			d += track.curve.get_closest_offset(anchor_point)
		xf = track.global_transform.affine_inverse() * track.get_safe_transform(d, lateral, 0.0)
	transform = xf
	_rebuild_visuals()


func is_broken() -> bool:
	return kind == Kind.BREAKABLE and _broken_time > 0.0


func _rebuild_visuals() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # vehicles
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		Kind.BOOST_PAD:
			box.size = Vector3(width, 2.0, 6.0)
			_pad_visual()
		Kind.BOOST_RING:
			box.size = Vector3(7.0, 7.0, 2.0)
			shape.position.y = 3.2
			_ring_visual()
		Kind.EMP_PUDDLE:
			box.size = Vector3(width, 2.0, width * 0.8)
			_puddle_visual()
		Kind.BREAKABLE:
			box.size = Vector3(width, 2.5, 1.6)
			shape.position.y = 1.0
			_barrier_visual()
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


func _mat(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation.z = rot_z
	mi.material_override = mat
	_visual.add_child(mi)
	return mi


func _pad_visual() -> void:
	_box(Vector3(width, 0.04, 6.0), Vector3(0, 0.05, 0), _mat(Color(0.05, 0.05, 0.1), 0.0))
	var glow := _mat(PAD_COLOR, 4.0)
	# Three chevrons pointing forward (-Z).
	for i in 3:
		for arm in [-1.0, 1.0]:
			var bar := _box(Vector3(width * 0.42, 0.06, 0.35), Vector3(arm * width * 0.19, 0.08, -1.6 + i * 1.5), glow)
			bar.rotation.y = arm * 0.55
	_light = _add_light(PAD_COLOR, 2.5, 7.0, Vector3(0, 1.0, 0))


func _ring_visual() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.3
	torus.outer_radius = 3.8
	torus.rings = 32
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position.y = 3.6
	ring.material_override = _mat(RING_COLOR, 4.5)
	_visual.add_child(ring)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.4, 0.6, 0.4), Vector3(side * 3.6, 0.3, 0), _mat(Color(0.1, 0.1, 0.14), 0.0))
	_light = _add_light(RING_COLOR, 3.0, 12.0, Vector3(0, 3.6, 0))


func _puddle_visual() -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width * 0.5
	cyl.bottom_radius = width * 0.5
	cyl.height = 0.03
	cyl.radial_segments = 24
	disc.mesh = cyl
	disc.scale = Vector3(1, 1, 0.8)
	disc.position.y = 0.05
	disc.material_override = _mat(EMP_COLOR, 2.5)
	_visual.add_child(disc)
	# Warning posts so the hazard is visible before you reach it.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.15, 1.2, 0.15), Vector3(side * (width * 0.5 + 0.4), 0.6, 0), _mat(EMP_COLOR, 3.0))
	_light = _add_light(EMP_COLOR, 3.0, 8.0, Vector3(0, 0.8, 0))


func _barrier_visual() -> void:
	var yellow := _mat(BARRIER_COLOR, 0.6)
	var black := _mat(Color(0.05, 0.05, 0.06), 0.0)
	var blocks := int(width / 1.6)
	for i in blocks:
		var x := (float(i) - (blocks - 1) * 0.5) * 1.6
		_box(Vector3(1.4, 1.0, 0.6), Vector3(x, 0.5, 0), yellow if i % 2 == 0 else black)
		_box(Vector3(1.42, 0.12, 0.62), Vector3(x, 0.85, 0), black if i % 2 == 0 else yellow)
	_light = _add_light(BARRIER_COLOR, 1.5, 6.0, Vector3(0, 1.5, 0))


func _add_light(color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = pos
	_visual.add_child(light)
	return light


func _on_body_entered(body: Node3D) -> void:
	var car := body as VehicleController
	if car == null or _cooldowns.get(car, 0.0) > 0.0:
		return
	match kind:
		Kind.BOOST_PAD:
			car.start_external_boost(boost_extra, boost_duration, boost_kick, "Boost pad", PAD_COLOR)
		Kind.BOOST_RING:
			car.start_external_boost(boost_extra, boost_duration, boost_kick, "Boost ring", RING_COLOR)
		Kind.EMP_PUDDLE:
			if car.status == null or not car.status.apply_attack(&"emp", 1.0):
				return
		Kind.BREAKABLE:
			if is_broken():
				return
			car.scrub_speed(smash_speed_kept)
			_smash()
	_cooldowns[car] = 1.5
	triggered += 1


func _smash() -> void:
	_broken_time = rebuild_time
	for child in _visual.get_children():
		if child is MeshInstance3D:
			var block := child as MeshInstance3D
			var tween := create_tween()
			var fly := Vector3(randf_range(-2.0, 2.0), randf_range(1.5, 3.0), randf_range(-4.0, -1.0))
			tween.tween_property(block, "position", block.position + fly, 0.35)
			tween.parallel().tween_property(block, "scale", Vector3.ONE * 0.2, 0.35)
			tween.tween_callback(func() -> void: block.visible = false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for car in _cooldowns.keys():
		_cooldowns[car] -= delta
		if _cooldowns[car] <= 0.0:
			_cooldowns.erase(car)
	if _broken_time > 0.0:
		_broken_time -= delta
		if _broken_time <= 0.0:
			_rebuild_visuals()


func _process(delta: float) -> void:
	if _light == null or Engine.is_editor_hint():
		return
	_time += delta
	if kind == Kind.EMP_PUDDLE and not GameSettings.reduced_flashing:
		_light.light_energy = 2.0 + 1.5 * absf(sin(_time * 9.0))
