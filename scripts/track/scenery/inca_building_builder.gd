class_name IncaBuildingBuilder
extends RefCounted
## Inca stone buildings (Choquequirao, Machu Picchu): fieldstone walls set in
## mortar, tall triangular gable ends, rows of small trapezoidal windows with
## stone lintels, trapezoidal doorways, and either no roof (ruins, as the
## sites are today) or a steep thatched one. Built in a local frame: X along
## the building's length, Z across it, Y up, origin at the middle of the floor.

var scenery: TrackScenery
var stone_key: String
var lintel_key: String
var thatch_key: String
var rubble_key: String
var beam_key: String
var rng := RandomNumberGenerator.new()

## Counts and footprints for tests: [Transform3D, Vector2(length, depth)].
var houses: int = 0
var roofed: int = 0
var ruined: int = 0
var footprints: Array = []

const WALL := 0.7


func _init(p_scenery: TrackScenery, p_stone: String, p_lintel: String, p_thatch: String, p_rubble: String,
		p_beam: String, seed_value: int = 11) -> void:
	scenery = p_scenery
	stone_key = p_stone
	lintel_key = p_lintel
	thatch_key = p_thatch
	rubble_key = p_rubble
	beam_key = p_beam
	rng.seed = seed_value


## A gabled house. opts: roof (bool), ruin (bool), windows (int per long
## side), door_side (1 front +Z, -1 back -Z, 0 none), wall_h, gable (rise).
func house(xf: Transform3D, length: float, depth: float, opts: Dictionary = {}) -> void:
	var wall_h: float = opts.get("wall_h", 3.6)
	var rise: float = opts.get("gable", depth * 0.55)
	var roof: bool = opts.get("roof", false)
	var ruin: bool = opts.get("ruin", false) and not roof
	var windows: int = opts.get("windows", maxi(1, int(length / 2.8) - 1))
	var door_side: int = opts.get("door_side", 1)
	var hl := length * 0.5
	var hd := depth * 0.5
	# Long walls (front +Z, back -Z) with windows; the door replaces the
	# middle window on one side.
	for side in [-1, 1]:
		var wall_xf := xf * Transform3D(Basis(), Vector3(0, 0, side * (hd - WALL * 0.5)))
		var top := wall_h
		if ruin and side == -1:
			top = wall_h * rng.randf_range(0.45, 0.75)
		_long_wall(wall_xf, length, top, windows, door_side == side)
	# Gable ends (X ends), the full width so the corners close.
	for end in [-1, 1]:
		var gx := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(end * (hl - WALL * 0.5), 0, 0))
		var peak := wall_h + rise
		if ruin and end == 1:
			# A broken gable: the point has fallen.
			peak = wall_h + rise * rng.randf_range(0.0, 0.5)
			scenery.add_prism(stone_key, PackedVector2Array([Vector2(-hd, 0), Vector2(hd, 0), Vector2(hd, wall_h),
					Vector2(0.15 * hd, peak), Vector2(-hd, wall_h)]), WALL, gx)
		else:
			scenery.add_prism(stone_key, PackedVector2Array([Vector2(-hd, 0), Vector2(hd, 0), Vector2(hd, wall_h),
					Vector2(0, peak), Vector2(-hd, wall_h)]), WALL, gx)
		# A small window high in the gable, as in the photos.
		if peak > wall_h + 1.2:
			scenery.add_box(lintel_key, Vector3(1.0, 0.22, WALL + 0.06), gx.translated_local(Vector3(0, wall_h + 0.95, 0)))
	if roof:
		_thatch(xf, length, depth, wall_h, rise)
	if ruin:
		_rubble(xf * Transform3D(Basis(), Vector3(rng.randf_range(-hl * 0.5, hl * 0.5), 0, -hd - 1.2)), 2.2)
	houses += 1
	if roof:
		roofed += 1
	if ruin:
		ruined += 1
	footprints.append([xf, Vector2(length, depth)])


## A long wall along local X with `count` trapezoidal windows (sill 1.3 m).
func _long_wall(xf: Transform3D, length: float, top: float, count: int, door: bool) -> void:
	var hl := length * 0.5
	var sill := 1.3
	var win_top := 2.2
	var wb := 0.36 # half width at the sill
	var wt := 0.26 # half width at the top (trapezoid)
	if top <= win_top + 0.3:
		# Too low for windows (a fallen wall): a plain stub.
		scenery.add_box(stone_key, Vector3(length, top, WALL), xf.translated_local(Vector3(0, top * 0.5, 0)))
		return
	var xs: Array[float] = []
	for i in count:
		xs.append(-hl + length * (i + 1.0) / (count + 1.0))
	var door_i := int(count / 2.0) if door else -1
	# Below the sills (except at the doorway) and above the lintels the wall
	# is solid.
	var spans: Array = [[-hl, hl]]
	if door_i >= 0:
		spans = [[-hl, xs[door_i] - 0.58], [xs[door_i] + 0.58, hl]]
	for sp in spans:
		var w: float = sp[1] - sp[0]
		scenery.add_box(stone_key, Vector3(w, sill, WALL), xf.translated_local(Vector3((sp[0] + sp[1]) * 0.5, sill * 0.5, 0)))
	scenery.add_box(stone_key, Vector3(length, top - win_top, WALL), xf.translated_local(Vector3(0, (win_top + top) * 0.5, 0)))
	# Piers between openings: trapezoids whose sides follow the jambs.
	var edges: Array = [[-hl, -hl]]
	for i in xs.size():
		var bw := wb
		var tw := wt
		if i == door_i:
			bw = 0.56
			tw = 0.46
		edges.append([xs[i] - bw, xs[i] - tw])
		edges.append([xs[i] + bw, xs[i] + tw])
	edges.append([hl, hl])
	for k in range(0, edges.size(), 2):
		var l: Array = edges[k]
		var r: Array = edges[k + 1]
		scenery.add_prism(stone_key, PackedVector2Array([Vector2(l[0], sill), Vector2(r[0], sill), Vector2(r[1], win_top),
				Vector2(l[1], win_top)]), WALL, xf)
	for i in xs.size():
		scenery.add_box(lintel_key, Vector3((0.46 if i == door_i else wt) * 2.0 + 0.5, 0.24, WALL + 0.08),
				xf.translated_local(Vector3(xs[i], win_top + 0.12, 0)))


func _thatch(xf: Transform3D, length: float, depth: float, wall_h: float, rise: float) -> void:
	var hd := depth * 0.5
	var slope := atan2(rise, hd)
	var run := sqrt(hd * hd + rise * rise) + 0.8
	for side in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, side * slope)
		var centre := Vector3(0, wall_h + rise * 0.5 + 0.1, side * hd * 0.5)
		var slab := xf * Transform3D(b, centre)
		scenery.add_box(thatch_key, Vector3(length + 1.0, 0.45, run), slab.translated_local(Vector3(0, 0, side * 0.35)))
	# Ridge pole.
	scenery.add_box(beam_key, Vector3(length + 1.2, 0.3, 0.3), xf.translated_local(Vector3(0, wall_h + rise + 0.25, 0)))


## A heap of fallen stones around a point (local origin on the ground).
func _rubble(xf: Transform3D, radius: float) -> void:
	for i in rng.randi_range(7, 12):
		var a := rng.randf() * TAU
		var r := rng.randf() * radius
		var s := Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.2, 0.45), rng.randf_range(0.35, 0.7))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		scenery.add_box(rubble_key, s, xf * Transform3D(b, Vector3(cos(a) * r, s.y * 0.4 + (radius - r) * 0.15, sin(a) * r)))


## Loose rubble anywhere (track-local ground point).
func rubble(pos: Vector3, radius: float) -> void:
	_rubble(Transform3D(Basis(), pos), radius)


## A qolqa (storehouse): small, square-ish, two rows of tiny windows.
func qolqa(xf: Transform3D, length: float = 7.0, depth: float = 4.6) -> void:
	house(xf, length, depth, {"wall_h": 3.8, "gable": 2.2, "windows": 2, "door_side": 1, "roof": rng.randf() < 0.35})


## The great hall (kallanka) on the plaza: long, tall, a doorway in the
## middle of each long side and a row of windows high up.
func great_hall(xf: Transform3D, length: float, depth: float) -> void:
	house(xf, length, depth, {"wall_h": 5.2, "gable": depth * 0.62, "windows": 7, "door_side": 1, "roof": false})


## A stepped platform (usnu) on the plaza: tiers of dressed stone.
func usnu(pos: Vector3, base: float, tiers: int = 3, tier_h: float = 1.1) -> void:
	for t in tiers:
		var w := base - t * base / (tiers + 1.0)
		scenery.add_box(lintel_key if t == tiers - 1 else stone_key, Vector3(w, tier_h, w),
				Transform3D(Basis(), pos + Vector3(0, tier_h * (t + 0.5), 0)))
	footprints.append([Transform3D(Basis(), pos), Vector2(base, base)])
