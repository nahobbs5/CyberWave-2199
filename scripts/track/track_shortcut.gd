@tool
class_name TrackShortcut
extends Node3D
## An alternate route (GDD 8.8) that leaves the main loop and rejoins it
## further on. Add it as a child of a TrackCircuit; the circuit builds its
## road and barriers, opens the main barriers where the two meet, and copies
## any checkpoint gates the shortcut bypasses onto it, so lap progression
## stays valid on either route.
##
## Positions on the shortcut map to the main loop proportionally (start ->
## end offset), so race positions, recovery and AI all keep working. The
## first and last control points are snapped onto the main centre line.

## Route in the track's local space, in driving order (at least 3 points).
@export var control_points: PackedVector3Array = PackedVector3Array()
@export var road_width: float = 11.0
## AI never go faster than this on the shortcut (m/s); corners lower it more.
@export var speed_limit: float = 32.0
## Base chance an AI takes it (scaled by difficulty and personality).
@export_range(0.0, 1.0) var ai_chance: float = 0.5
## Extra coins along the shortcut, as distances from its start (GDD 8.8).
@export var coin_distances: PackedFloat32Array = PackedFloat32Array()
@export var display_name: String = "Shortcut"
## Stretches with no barrier (on an elevated track you can fall off):
## (from distance, to distance along the shortcut, side -1 left / +1 right).
@export var open_edges: PackedVector3Array = PackedVector3Array()
## Breaks in the road that cars jump (a ramp before each one): (from, to)
## distances along the shortcut with no road, collider or barriers, and
## nothing counts as on-road there (Overdrive won't land in one).
@export var gaps: PackedVector2Array = PackedVector2Array()
## AI hold at least this speed (m/s) over the 80 m before each gap and
## across it, so they clear the jump. 0 = no floor.
@export var min_speed: float = 0.0
@export_group("Branch")
## A full alternate route rather than a shortcut (GDD 8.8a, Chefchaouen's
## forks): AI follow its own racing line (BranchLine) and choose it by
## traffic as well as by chance, a recovery on it respawns on it, the
## minimap draws it like the main loop, and it may carry item rows.
@export var is_branch: bool = false
## Where its ends meet the main road, metres right (+) or left (-) of the
## main centre line: each route gets its own lane into and out of a merge.
@export var start_lateral: float = 0.0
@export var end_lateral: float = 0.0
## (from, to) distances where the road surface isn't drawn (the collider
## still is): stairs drawn by the scenery sit over a smooth ramp there.
@export var hidden_surface: PackedVector2Array = PackedVector2Array()
## Weapon crate rows (distances along it) and their laterals.
@export var crate_distances: PackedFloat32Array = PackedFloat32Array()
@export var crate_laterals: PackedFloat32Array = PackedFloat32Array([-3.0, 0.0, 3.0])
@export_group("")
const GAP_RUN_UP := 80.0

var curve: Curve3D
var length: float = 0.0
## Main-loop offsets where it leaves and rejoins.
var start_offset: float = 0.0
var end_offset: float = 0.0
## Main-loop distance it replaces.
var span: float = 0.0
var _speeds: PackedFloat32Array = PackedFloat32Array()


## Called by TrackCircuit after its own curve is built.
## Mirror races (TrackCircuit.set_reversed): the same road driven the other
## way. Reverses the control points, swaps and mirrors the junction lanes,
## remaps every distance-keyed list (d -> length - d) and rebuilds the route
## (start and end offsets swap). The track adds a take-off ramp for each gap.
func reverse_route(track: TrackCircuit, on: bool) -> void:
	if on:
		_forward = {}
		for key in FLIPPED_SETTINGS:
			_forward[key] = get(key)
		_flip_settings()
	elif not _forward.is_empty():
		for key in FLIPPED_SETTINGS:
			set(key, _forward[key])
	build_route(track)


## Settings reverse_route() remaps (restored exactly when turned back).
const FLIPPED_SETTINGS: Array[String] = ["control_points", "start_lateral", "end_lateral",
		"coin_distances", "crate_distances", "crate_laterals", "gaps", "hidden_surface", "open_edges"]
## The forward settings, kept while reversed.
var _forward: Dictionary = {}


func _flip_settings() -> void:
	var old_length := length
	var pts := PackedVector3Array()
	for i in range(control_points.size() - 1, -1, -1):
		pts.append(control_points[i])
	control_points = pts
	var lanes := Vector2(start_lateral, end_lateral)
	start_lateral = -lanes.y
	end_lateral = -lanes.x
	coin_distances = _flip_list(coin_distances, old_length)
	crate_distances = _flip_list(crate_distances, old_length)
	var lats := PackedFloat32Array()
	for x in crate_laterals:
		lats.append(-x)
	crate_laterals = lats
	gaps = _flip_ranges(gaps, old_length)
	hidden_surface = _flip_ranges(hidden_surface, old_length)
	var edges := PackedVector3Array()
	for e in open_edges:
		edges.append(Vector3(old_length - e.y, old_length - e.x, -e.z))
	open_edges = edges


static func _flip_list(values: PackedFloat32Array, total: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(values.size() - 1, -1, -1):
		out.append(total - values[i])
	return out


static func _flip_ranges(ranges: PackedVector2Array, total: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(ranges.size() - 1, -1, -1):
		out.append(Vector2(total - ranges[i].y, total - ranges[i].x))
	return out


func build_route(track: TrackCircuit) -> void:
	curve = Curve3D.new()
	curve.bake_interval = 1.0
	var pts := control_points.duplicate()
	if pts.size() < 3:
		length = 0.0
		return
	start_offset = track.curve.get_closest_offset(pts[0])
	end_offset = track.curve.get_closest_offset(pts[pts.size() - 1])
	# Leave and rejoin along the main road's direction for smooth junctions,
	# in a lane start_lateral / end_lateral off the main centre line.
	var t0 := _main_tangent(track, start_offset)
	var t1 := _main_tangent(track, end_offset)
	pts[0] = track.curve.sample_baked(start_offset) + _flat_right(t0) * start_lateral
	pts[pts.size() - 1] = track.curve.sample_baked(end_offset) + _flat_right(t1) * end_lateral
	var n := pts.size()
	for i in n:
		var p := pts[i]
		var handle: Vector3
		if i == 0:
			handle = t0 * (pts[1] - p).length() * 0.4
		elif i == n - 1:
			handle = t1 * (p - pts[n - 2]).length() * 0.4
		else:
			handle = (pts[i + 1] - pts[i - 1]) / 6.0
		curve.add_point(p, -handle, handle)
	length = curve.get_baked_length()
	span = fposmod(end_offset - start_offset, track.length)
	_compute_speeds()


static func _flat_right(tangent: Vector3) -> Vector3:
	return Vector3(tangent.x, 0.0, tangent.z).normalized().cross(Vector3.UP).normalized()


## Track-local transform on the route: `distance` along it, `lateral`
## metres right of its centre, `height` above the road, facing along it and
## pitched with its slope (no banking on shortcuts).
func safe_transform(distance: float, lateral: float = 0.0, height: float = 0.9) -> Transform3D:
	var d := clampf(distance, 0.0, length)
	var fwd := point_at(minf(d + 1.0, length)) - point_at(maxf(d - 1.0, 0.0))
	if fwd.length_squared() < 0.000001:
		fwd = tangent_at(d)
	fwd = fwd.normalized()
	var right := _flat_right(fwd)
	var up := right.cross(fwd).normalized()
	var basis := Basis(right, up, -fwd)
	return Transform3D(basis, point_at(d) + right * lateral + up * height)


## True if the road surface isn't drawn at this distance (stairs over it).
func surface_hidden(distance: float) -> bool:
	for r in hidden_surface:
		if distance >= r.x and distance <= r.y:
			return true
	return false


func is_valid() -> bool:
	return length > 0.0


## Distance along the shortcut nearest a point (track local space).
func local_offset(local_pos: Vector3) -> float:
	return curve.get_closest_offset(local_pos)


## True if a distance along the shortcut falls inside a gap.
func in_gap(distance: float) -> bool:
	for g in gaps:
		if distance > g.x and distance < g.y:
			return true
	return false


func lateral_distance(local_pos: Vector3) -> float:
	var closest := curve.get_closest_point(local_pos)
	return Vector2(local_pos.x - closest.x, local_pos.z - closest.z).length()


## Main-loop offset equivalent to a distance along the shortcut.
func to_main_offset(distance: float) -> float:
	return start_offset + clampf(distance / maxf(length, 0.001), 0.0, 1.0) * span


## Distance along the shortcut matching a main-loop offset inside its span.
func from_main_offset(track: TrackCircuit, main_offset: float) -> float:
	var into := fposmod(main_offset - start_offset, track.length)
	return into / maxf(span, 0.001) * length


func contains_main_offset(track: TrackCircuit, main_offset: float) -> bool:
	var into := fposmod(main_offset - start_offset, track.length)
	return into > 0.0 and into < span


func point_at(distance: float) -> Vector3:
	return curve.sample_baked(clampf(distance, 0.0, length))


func tangent_at(distance: float) -> Vector3:
	var a := curve.sample_baked(clampf(distance - 1.0, 0.0, length))
	var b := curve.sample_baked(clampf(distance + 1.0, 0.0, length))
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD


## Safe AI speed at a distance along (from the curvature, capped).
func speed_at(distance: float) -> float:
	if _speeds.is_empty():
		return speed_limit
	var i := clampi(int(distance / 3.0), 0, _speeds.size() - 1)
	return _speeds[i]


func _main_tangent(track: TrackCircuit, offset: float) -> Vector3:
	var a := track.curve.sample_baked(track.wrap_offset(offset - 1.0))
	var b := track.curve.sample_baked(track.wrap_offset(offset + 1.0))
	return Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()


func _compute_speeds() -> void:
	var count := maxi(2, int(length / 3.0) + 1)
	_speeds.resize(count)
	for i in count:
		var d := float(i) * 3.0
		var t0 := tangent_at(d - 6.0)
		var t1 := tangent_at(d + 6.0)
		var curvature := t0.angle_to(t1) / 12.0
		# Same rule of thumb as the racing line: lateral grip of about 14 m/s².
		var v := sqrt(14.0 / maxf(curvature, 0.0001))
		_speeds[i] = minf(v, speed_limit)
	# Brake ahead of slow parts.
	for i in range(count - 2, -1, -1):
		_speeds[i] = minf(_speeds[i], sqrt(_speeds[i + 1] * _speeds[i + 1] + 2.0 * 12.0 * 3.0))
	# Full commitment into a jump.
	if min_speed > 0.0:
		for i in count:
			var d := float(i) * 3.0
			for g in gaps:
				if d > g.x - GAP_RUN_UP and d < g.y + 6.0:
					_speeds[i] = maxf(_speeds[i], min_speed)
