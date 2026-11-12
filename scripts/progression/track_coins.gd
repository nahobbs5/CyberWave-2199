class_name TrackCoins
extends Node3D
## Track coins (GDD 9.2): collected automatically on contact by the player,
## worth one coin each, respawn every lap, at most 30 per race, never lost
## when hit. Single player only. The track sets how many there are
## (track.coin_offsets.size()); every lap they move to a new random layout:
## small clusters of 1-3 coins in one lane, spread round the lap, clear of the
## start, the crate rows and any road columns (scatter_spots()). Bonus coins
## along shortcuts stay put.
## AI cars don't take them.

signal coin_collected(total: int)
## Any collecting car took a coin (split screen: each human counts their own).
signal coin_collected_by(vehicle: VehicleController, total: int)

const MAX_PER_RACE := 30
## Random layout: no coins this far past the start line (they'd pop in right
## in front of you as a lap starts) or this far before it (the grid).
const CLEAR_AFTER_START := 80.0
const CLEAR_BEFORE_START := 30.0
## Spacing of the coins in a cluster, and how far they keep from crate rows
## and the road edge.
const CLUSTER_GAP := 10.0
const CRATE_CLEARANCE := 12.0
const EDGE_MARGIN := 2.5
const COLUMN_MARGIN := 2.5

## >= 0: seed the layouts (tests).
static var seed_override: int = -1

## Coins collected this race.
var collected: int = 0
## Off once the player's race is over (the autopilot doesn't collect).
var collecting: bool = true

var _player: VehicleController
## Other collecting cars (split screen: players 2-4) -> coins this race.
## Player 1's count is `collected`.
var _counts: Dictionary = {}
## Cars whose race is over.
var _stopped: Dictionary = {}
var _coins: Array[Area3D] = []
var _spin: float = 0.0
var _material: StandardMaterial3D
var _track: TrackCircuit
## The main-loop coins (moved every lap); shortcut coins aren't in here.
var _loop_coins: Array[Area3D] = []
var _rng := RandomNumberGenerator.new()


## `spawn` false (split screen): no coins on the track at all.
func setup(track: TrackCircuit, line: RacingLine, player: VehicleController, spawn: bool = true) -> void:
	_player = player
	if not spawn:
		collecting = false
		return
	_material = WeaponManager.glow_material(Color(1.0, 0.8, 0.2), 1.6)
	_material.metallic = 1.0
	_material.roughness = 0.2
	_track = track
	if seed_override >= 0:
		_rng.seed = seed_override
	else:
		_rng.randomize()
	for i in track.coin_offsets.size():
		var coin := _make_coin()
		add_child(coin)
		coin.body_entered.connect(_on_body_entered.bind(coin))
		_coins.append(coin)
		_loop_coins.append(coin)
	_scatter()
	# Bonus coins along shortcuts (GDD 8.8 "additional coins").
	for sc in track.shortcuts:
		for d in sc.coin_distances:
			var coin := _make_coin()
			var tangent := sc.tangent_at(d)
			coin.transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), track.to_global(sc.point_at(d)) + Vector3.UP * 1.0)
			add_child(coin)
			coin.body_entered.connect(_on_body_entered.bind(coin))
			_coins.append(coin)


## Split screen: another human's car collects too.
func add_collector(car: VehicleController) -> void:
	_counts[car] = 0


## That car's race is over (the autopilot doesn't collect).
func stop_collecting(car: VehicleController) -> void:
	_stopped[car] = true


func collected_by(car: VehicleController) -> int:
	return collected if car == _player else int(_counts.get(car, 0))


func available_count() -> int:
	return _coins.filter(func(c: Area3D) -> bool: return c.visible).size()


## Every coin comes back when the player starts a new lap (until the cap).
func respawn() -> void:
	if _counts.is_empty() and collected >= MAX_PER_RACE:
		return
	_scatter()
	for coin in _coins:
		_set_active(coin, true)


## Moves the main-loop coins to a fresh random layout.
func _scatter() -> void:
	if _track == null or _loop_coins.is_empty():
		return
	var spots := scatter_spots(_track, _loop_coins.size(), _rng)
	for i in _loop_coins.size():
		_loop_coins[i].transform = _track.get_safe_transform(spots[i].x, spots[i].y, 1.0)


## `count` random coin spots (x = track offset, y = lateral): clusters of 1-3
## coins CLUSTER_GAP apart in one lane, one cluster per equal slice of the lap
## (so they spread out and never overlap), kept off the start, the crate rows,
## the road edges and any road columns.
static func scatter_spots(track: TrackCircuit, count: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var spots := PackedVector2Array()
	if count <= 0 or track.length <= 0.0:
		return spots
	var sizes: Array[int] = []
	var left := count
	while left > 0:
		var n := mini(left, rng.randi_range(1, 3))
		sizes.append(n)
		left -= n
	var span := maxf(track.length - CLEAR_AFTER_START - CLEAR_BEFORE_START, 1.0)
	var slice := span / sizes.size()
	var half := track.road_width * 0.5 - EDGE_MARGIN
	for k in sizes.size():
		var run := (sizes[k] - 1) * CLUSTER_GAP
		var start := k * slice + rng.randf_range(0.0, maxf(slice - run, 0.0))
		var lateral := rng.randf_range(-half, half)
		for j in sizes[k]:
			var along := clampf(start + j * CLUSTER_GAP, 0.0, span)
			var offset := track.wrap_offset(track.start_line_offset + CLEAR_AFTER_START + along)
			offset = _clear_of_crates(track, offset)
			var lat := clampf(track.dodge_columns(offset, lateral, COLUMN_MARGIN), -half, half)
			spots.append(Vector2(offset, lat))
	return spots


## Slides an offset forward past any crate row it's too close to.
static func _clear_of_crates(track: TrackCircuit, offset: float) -> float:
	for row in track.crate_row_offsets:
		var d := track.wrapped_delta(row, offset)
		if absf(d) < CRATE_CLEARANCE:
			offset = track.wrap_offset(row + CRATE_CLEARANCE)
	return offset


func coins() -> Array[Area3D]:
	return _coins


func _make_coin() -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # vehicles
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	shape.shape = sphere
	area.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.12
	cyl.radial_segments = 20
	cyl.rings = 1
	mesh.mesh = cyl
	mesh.material_override = _material
	mesh.rotation.x = PI * 0.5
	area.add_child(mesh)
	return area


func _set_active(coin: Area3D, active: bool) -> void:
	coin.visible = active
	coin.set_deferred("monitoring", active)


func _on_body_entered(body: Node3D, coin: Area3D) -> void:
	var is_player := body == _player
	if not (is_player or _counts.has(body)) or _stopped.has(body) or not coin.visible:
		return
	if is_player and not collecting:
		return
	var total := collected_by(body as VehicleController)
	if total >= MAX_PER_RACE:
		return
	total += 1
	_set_active(coin, false)
	if is_player:
		collected = total
		coin_collected.emit(collected)
	else:
		_counts[body] = total
	coin_collected_by.emit(body, total)
	# One collector: the coins are all gone once the cap is reached.
	if _counts.is_empty() and total >= MAX_PER_RACE:
		for c in _coins:
			_set_active(c, false)


func _process(delta: float) -> void:
	_spin += delta * 3.0
	for coin in _coins:
		if coin.visible:
			coin.rotation.y = _spin
