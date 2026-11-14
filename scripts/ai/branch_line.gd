class_name BranchLine
extends RefCounted
## AI racing line along a branch route (TrackShortcut.is_branch, GDD 8.8a):
## the same two-pass relaxation as RacingLine (shortest path, then minimum
## curvature) along the open route, with both ends pinned to the branch's
## centre (its entry and exit lanes), and per-car corner speeds with a
## braking pass. Paths are cached per branch; speeds per car stats.

const SPACING := 3.0
const EDGE_MARGIN := 2.2
const ITERATIONS := 300
## Samples at each end held on the centre (the lanes into and out of the merge).
const PINNED := 4

var shortcut: TrackShortcut
var count: int = 0
var limit: float = 0.0
var lateral: PackedFloat32Array = PackedFloat32Array()
var curvature: PackedFloat32Array = PackedFloat32Array()
var speeds: PackedFloat32Array = PackedFloat32Array()

var _centers: PackedVector3Array = PackedVector3Array()
var _rights: PackedVector3Array = PackedVector3Array()

## shortcut instance id -> [route length, BranchLine with the relaxed path].
static var _paths: Dictionary = {}
## "id:stats id" -> BranchLine with speeds for those stats.
static var _lines: Dictionary = {}


## The line for a branch with speeds for these stats (cached).
static func for_branch(sc: TrackShortcut, stats: VehicleStats) -> BranchLine:
	var id := sc.get_instance_id()
	var cached: Array = _paths.get(id, [])
	if cached.is_empty() or not is_equal_approx(float(cached[0]), sc.length):
		var base := BranchLine.new(sc)
		base._relax()
		base._compute_curvature()
		_paths[id] = [sc.length, base]
		for key in _lines.keys():
			if String(key).begins_with("%d:" % id):
				_lines.erase(key)
		cached = _paths[id]
	var key := "%d:%d" % [id, stats.get_instance_id() if stats != null else 0]
	if not _lines.has(key):
		var line := (cached[1] as BranchLine)._copy()
		line._compute_speeds(stats if stats != null else VehicleStats.new())
		_lines[key] = line
	return _lines[key]


func _init(sc: TrackShortcut) -> void:
	shortcut = sc
	count = maxi(4, int(sc.length / SPACING) + 1)
	limit = maxf(0.0, sc.road_width * 0.5 - EDGE_MARGIN)
	_centers.resize(count)
	_rights.resize(count)
	lateral.resize(count)
	for i in count:
		var d := _distance(i)
		_centers[i] = sc.point_at(d)
		var t := sc.tangent_at(d)
		_rights[i] = Vector3(t.x, 0.0, t.z).normalized().cross(Vector3.UP).normalized()
		lateral[i] = 0.0


func _copy() -> BranchLine:
	var c := BranchLine.new(shortcut)
	c.lateral = lateral
	c.curvature = curvature
	return c


func _distance(i: int) -> float:
	return minf(float(i) * SPACING, shortcut.length)


# --- Queries (distances along the branch) -------------------------------------

## Track-local point on the line, shifted by extra metres (kept on the road).
func point_at(distance: float, extra_lateral: float = 0.0) -> Vector3:
	var d := clampf(distance, 0.0, shortcut.length)
	var lat := clampf(lateral_at(d) + extra_lateral, -limit, limit)
	var t := shortcut.tangent_at(d)
	var right := Vector3(t.x, 0.0, t.z).normalized().cross(Vector3.UP).normalized()
	return shortcut.point_at(d) + right * lat


func lateral_at(distance: float) -> float:
	var f := clampf(distance / SPACING, 0.0, float(count - 1))
	var i0 := mini(int(f), count - 1)
	var i1 := mini(i0 + 1, count - 1)
	return lerpf(lateral[i0], lateral[i1], f - float(i0))


func speed_at(distance: float) -> float:
	var f := clampf(distance / SPACING, 0.0, float(count - 1))
	var i0 := mini(int(f), count - 1)
	var i1 := mini(i0 + 1, count - 1)
	return lerpf(speeds[i0], speeds[i1], f - float(i0))


# --- Build ----------------------------------------------------------------------

func _point(i: int) -> Vector3:
	var j := clampi(i, 0, count - 1)
	return _centers[j] + _rights[j] * lateral[j]


func _move_toward(i: int, target: Vector3, weight: float) -> void:
	if i < PINNED or i >= count - PINNED:
		return
	var want := (target - _centers[i]).dot(_rights[i])
	lateral[i] = clampf(lerpf(lateral[i], want, weight), -limit, limit)


func _relax() -> void:
	for _it in ITERATIONS:
		for i in range(1, count - 1):
			_move_toward(i, (_point(i - 1) + _point(i + 1)) * 0.5, 0.6)
	for _it in ITERATIONS:
		for i in range(2, count - 2):
			var target := (4.0 * (_point(i - 1) + _point(i + 1)) - (_point(i - 2) + _point(i + 2))) / 6.0
			_move_toward(i, target, 0.5)


func _compute_curvature() -> void:
	curvature.resize(count)
	var k := 3
	for i in count:
		var a := _point(i - k)
		var b := _point(i)
		var c := _point(i + k)
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var bc := Vector2(c.x - b.x, c.z - b.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var cross := ab.x * bc.y - ab.y * bc.x
		var denom := ab.length() * bc.length() * ac.length()
		curvature[i] = (-2.0 * cross / denom) if denom > 0.0001 else 0.0


## Same corner-speed rule as RacingLine._compute_speeds, with a braking pass
## (open route: the far end runs at full speed into the merge).
func _compute_speeds(stats: VehicleStats) -> void:
	speeds.resize(count)
	var h := stats.handling * 0.85
	var falloff := 1.0 - stats.high_speed_steer_factor
	var top := stats.top_speed
	for i in count:
		var k := 0.0
		for d in range(-2, 3):
			k = maxf(k, absf(curvature[clampi(i + d, 0, count - 1)]))
		if k < 0.0005:
			speeds[i] = top
			continue
		var radius := 1.0 / k
		speeds[i] = minf(top, radius * h / (1.0 + radius * h * falloff / top))
	var decel := stats.brake_deceleration * 0.4
	for n in range(1, count):
		var i := count - 1 - n
		speeds[i] = minf(speeds[i], sqrt(speeds[i + 1] * speeds[i + 1] + 2.0 * decel * SPACING))
