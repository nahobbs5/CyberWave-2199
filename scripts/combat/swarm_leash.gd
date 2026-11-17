class_name SwarmLeash
extends Node3D
## Swarm Bots clinging to a leashed car (GDD 6.3): bots crawl over the
## bodywork and three glowing tethers trail back to a dragging anchor, like
## the car is on a leash. Child of the car; frees itself once the car's
## "leash" status ends.

const NODE_NAME := "SwarmLeash"
const BOTS := 12
const TETHERS := 3
## How far behind the car the anchor drags (m, before visual scale).
const ANCHOR_BACK := 4.0

var color: Color = Color(1.0, 0.6, 0.2)

var _car: VehicleController
var _bots: Array[MeshInstance3D] = []
var _tethers: Array[MeshInstance3D] = []
var _anchor: MeshInstance3D
var _phases: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
## The anchor's wobble, lagging behind the car.
var _sway: Vector3 = Vector3.ZERO


## Puts a fresh leash on `car` (replacing an old one).
static func attach(car: VehicleController, leash_color: Color) -> SwarmLeash:
	var old := car.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()
	var leash := SwarmLeash.new()
	leash.name = NODE_NAME
	leash.color = leash_color
	car.add_child(leash)
	return leash


func _ready() -> void:
	_car = get_parent() as VehicleController
	var s := _car.visual_scale if _car != null else 1.0
	var mat := WeaponManager.glow_material(color, 2.5)
	var mesh := SwarmBots.bot_mesh()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in BOTS:
		var bot := MeshInstance3D.new()
		bot.mesh = mesh
		bot.material_override = mat
		bot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bot)
		_bots.append(bot)
		_phases.append(rng.randf() * TAU)
	var tether_mat := WeaponManager.glow_material(color, 3.0)
	tether_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tether_mat.albedo_color = Color(color, 0.7)
	for i in TETHERS:
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, 1.0)
		line.mesh = box
		line.material_override = tether_mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_tethers.append(line)
	_anchor = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.3
	orb.height = 0.6
	_anchor.mesh = orb
	_anchor.material_override = WeaponManager.glow_material(color, 3.0)
	_anchor.position = Vector3(0.0, 0.4, ANCHOR_BACK * s)
	add_child(_anchor)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(0.0, 0.8 * s, 0.0)
	add_child(light)
	_update(0.0)


func _process(delta: float) -> void:
	if _car == null or _car.status == null or not _car.status.has(&"leash"):
		queue_free()
		return
	_time += delta
	_update(delta)


func _update(delta: float) -> void:
	var s := _car.visual_scale if _car != null else 1.0
	var calm := GameSettings.reduced_flashing
	var t := _time * (0.4 if calm else 1.0)
	# Bots crawl over the roof, sides and tail.
	var corners: Array[Vector3] = []
	for i in _bots.size():
		var p := _phases[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := sin(t * 1.7 + p) * 1.6
		var pos := Vector3(side * (0.75 + 0.1 * sin(t * 5.0 + p)), 0.55 + 0.25 * sin(t * 3.0 + p * 2.0), along) * s
		_bots[i].position = pos
		_bots[i].rotation = Vector3(t * 4.0 + p, t * 6.0 + p, 0.0)
		if i < _tethers.size():
			corners.append(Vector3((float(i) - 1.0) * 0.6, 0.5, 1.9) * s)
	# The anchor lags and swings behind like something heavy being dragged.
	var target_sway := Vector3(sin(t * 2.3) * 0.6, absf(sin(t * 3.1)) * 0.3, 0.0) * s
	_sway = _sway.lerp(target_sway, clampf(delta * 4.0, 0.0, 1.0)) if delta > 0.0 else target_sway
	_anchor.position = Vector3(0.0, 0.4 * s, ANCHOR_BACK * s) + _sway
	for i in _tethers.size():
		var from: Vector3 = corners[i]
		var to := _anchor.position
		var line := _tethers[i]
		var length := from.distance_to(to)
		line.position = (from + to) * 0.5
		line.scale = Vector3(1.0, 1.0, maxf(length, 0.01))
		var dir := (to - from).normalized()
		if absf(dir.dot(Vector3.UP)) < 0.99:
			line.basis = Basis.looking_at(dir, Vector3.UP).scaled(Vector3(1.0, 1.0, maxf(length, 0.01)))
