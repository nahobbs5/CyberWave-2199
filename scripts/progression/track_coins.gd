class_name TrackCoins
extends Node3D
## Track coins (GDD 9.2): collected automatically on contact by the player,
## worth one coin each, respawn every lap, at most 30 per race, never lost
## when hit. Placed near the racing line (track.coin_offsets, with a small
## sideways offset each) so collecting them is a small detour, not a big one,
## plus any bonus coins along shortcuts.
## AI cars don't take them.

signal coin_collected(total: int)
## Any collecting car took a coin (split screen: each human counts their own).
signal coin_collected_by(vehicle: VehicleController, total: int)

const MAX_PER_RACE := 30

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


## `spawn` false (split screen): no coins on the track at all.
func setup(track: TrackCircuit, line: RacingLine, player: VehicleController, spawn: bool = true) -> void:
	_player = player
	if not spawn:
		collecting = false
		return
	_material = WeaponManager.glow_material(Color(1.0, 0.8, 0.2), 1.6)
	_material.metallic = 1.0
	_material.roughness = 0.2
	for i in track.coin_offsets.size():
		var offset := track.coin_offsets[i]
		var side := track.coin_laterals[i] if i < track.coin_laterals.size() else 0.0
		var lateral := clampf(line.lateral_at(offset) + side, -track.road_width * 0.5 + 1.5, track.road_width * 0.5 - 1.5)
		var coin := _make_coin()
		coin.transform = track.get_safe_transform(offset, lateral, 1.0)
		add_child(coin)
		coin.body_entered.connect(_on_body_entered.bind(coin))
		_coins.append(coin)
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
	for coin in _coins:
		_set_active(coin, true)


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
