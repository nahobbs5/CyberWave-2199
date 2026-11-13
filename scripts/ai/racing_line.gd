class_name RacingLine
extends RefCounted
## Precomputed AI racing line for a TrackCircuit (GDD 14.2 RacingLineManager).
##
## The line is stored as a lateral offset from the centre line at evenly
## spaced samples. It is relaxed toward minimum curvature (each point moves
## toward the position that makes its bend match its neighbours'), which
## spreads every turn over the whole corner as an outside-inside-outside path
## while staying inside the road. From its curvature we derive a safe speed per
## sample (with a braking pass before corners) and the corners worth drifting.

## Turn rate (rad/s) a corner must need at racing speed to be worth drifting.
## A drift always yaws at least ~0.8 rad/s, so much gentler corners would pull
## the car to the inside.
const DRIFT_MIN_YAW := 0.6
## A zone must last this many seconds at line speed (Cyan needs 1 s of sliding).
const DRIFT_MIN_SECONDS := 1.25

var track: TrackCircuit
var spacing: float = 3.0
var count: int = 0
## Max distance the line may sit from the centre (metres).
var limit: float = 0.0
## Metres right of centre at each sample.
var lateral: PackedFloat32Array = PackedFloat32Array()
var points: PackedVector3Array = PackedVector3Array()
## Signed curvature at each sample (+ = left turn).
var curvature: PackedFloat32Array = PackedFloat32Array()
## Safe speed at each sample (m/s), including braking before corners.
var speeds: PackedFloat32Array = PackedFloat32Array()
## Each zone: x = start offset, y = end offset (may wrap), z = drift direction
## (-1 left, +1 right).
var drift_zones: Array[Vector3] = []

## Room the line leaves round a road column (car half width plus slack).
const COLUMN_MARGIN := 2.6

var _centers: PackedVector3Array = PackedVector3Array()
## Per sample beside a road column: the side kept (+1 right, -1 left, 0 none)
## and the lateral the line must stay right of / left of.
var _col_side := PackedFloat32Array()
var _col_min := PackedFloat32Array()
var _col_max := PackedFloat32Array()
var _rights: PackedVector3Array = PackedVector3Array()


## With `source`, reuses that line's path (the slow relaxation) and only
## works out speeds and drift zones for `stats`; see for_stats().
func _init(p_track: TrackCircuit, stats: VehicleStats, edge_margin: float = 2.4,
		p_spacing: float = 3.0, iterations: int = 300, source: RacingLine = null) -> void:
	track = p_track
	if source != null:
		count = source.count
		spacing = source.spacing
		limit = source.limit
		lateral = source.lateral
		points = source.points
		curvature = source.curvature
		_centers = source._centers
		_rights = source._rights
	else:
		count = maxi(16, int(track.length / p_spacing))
		spacing = track.length / float(count)
		limit = track.road_width * 0.5 - edge_margin
		_sample_track()
		if not track.column_spots.is_empty():
			# Road columns: relax freely first, then pass each column on
			# the side that free line takes and relax again round them.
			_relax(iterations / 2)
			_find_column_gaps()
		_relax(iterations)
		_compute_curvature()
	_compute_speeds(stats)
	_find_drift_zones()


## The same path with speeds and drift zones for another car's stats (cheap:
## no relaxation). Packed arrays are copy-on-write, so the path is shared.
func for_stats(stats: VehicleStats) -> RacingLine:
	return RacingLine.new(track, stats, 0.0, spacing, 0, self)


# --- Queries -----------------------------------------------------------------

## Point on the line at a track offset, shifted by extra metres (clamped to the road).
func point_at(offset: float, extra_lateral: float = 0.0) -> Vector3:
	var lat := clampf(lateral_at(offset) + extra_lateral, -limit, limit)
	var o := track.wrap_offset(offset)
	if track.sloped:
		# On the banked surface (the line's laterals are measured across it).
		return track.to_global(track.surface_point(o, lat))
	var right := track.get_tangent_at(o).cross(Vector3.UP).normalized()
	return track.get_center_at(o) + right * lat


func lateral_at(offset: float) -> float:
	var f := track.wrap_offset(offset) / spacing
	var i0 := int(f) % count
	var i1 := (i0 + 1) % count
	return lerpf(lateral[i0], lateral[i1], f - floorf(f))


func speed_at(offset: float) -> float:
	var f := track.wrap_offset(offset) / spacing
	var i0 := int(f) % count
	var i1 := (i0 + 1) % count
	return lerpf(speeds[i0], speeds[i1], f - floorf(f))


func curvature_at(offset: float) -> float:
	return curvature[int(track.wrap_offset(offset) / spacing) % count]


## Index of the drift zone containing offset, or -1.
func drift_zone_at(offset: float) -> int:
	var o := track.wrap_offset(offset)
	for i in drift_zones.size():
		var zone := drift_zones[i]
		var into := fposmod(o - zone.x, track.length)
		var zone_length := fposmod(zone.y - zone.x, track.length)
		if into <= zone_length:
			return i
	return -1


# --- Build -------------------------------------------------------------------

func _sample_track() -> void:
	_centers.resize(count)
	_rights.resize(count)
	lateral.resize(count)
	points.resize(count)
	for i in count:
		var offset := float(i) * spacing
		_centers[i] = track.get_center_at(offset)
		_rights[i] = track.get_tangent_at(offset).cross(Vector3.UP).normalized()
		lateral[i] = 0.0


## For each sample level with a road column, the gap the line keeps to.
func _find_column_gaps() -> void:
	_col_side = PackedFloat32Array()
	_col_min = PackedFloat32Array()
	_col_max = PackedFloat32Array()
	if track.column_spots.is_empty():
		return
	_col_side.resize(count)
	_col_min.resize(count)
	_col_max.resize(count)
	_col_min.fill(INF)
	_col_max.fill(INF)
	for c in track.column_spots:
		var reach := c.z + COLUMN_MARGIN
		var free := lateral_at(c.x)
		var side := 1.0 if free >= c.y else -1.0
		if absf(free - c.y) < 0.3:
			side = 1.0 if track.column_route_lateral(c.x) >= c.y else -1.0
		var i0 := int(floorf((c.x - reach) / spacing))
		var i1 := int(ceilf((c.x + reach) / spacing))
		for j in range(i0, i1 + 1):
			var i := posmod(j, count)
			_col_side[i] = side
			if side > 0.0:
				_col_min[i] = c.y + reach if _col_min[i] == INF else maxf(_col_min[i], c.y + reach)
				_col_max[i] = INF
			else:
				_col_max[i] = c.y - reach if _col_max[i] == INF else minf(_col_max[i], c.y - reach)
				_col_min[i] = -INF
	for i in count:
		if _col_side[i] > 0.0:
			lateral[i] = clampf(maxf(lateral[i], _col_min[i]), -limit, limit)
		elif _col_side[i] < 0.0:
			lateral[i] = clampf(minf(lateral[i], _col_max[i]), -limit, limit)


func _relax(iterations: int) -> void:
	# Pass 1, shortest path: pull each point toward its neighbours' midpoint.
	# This cuts corners (outside-inside-outside) but leaves sharp apex kinks.
	for _it in iterations:
		for i in count:
			var mid := (_point(i - 1) + _point(i + 1)) * 0.5
			_move_toward(i, mid, 0.6)
	# Pass 2, fairing: minimum-curvature (biharmonic) target, zero change in
	# bend across i-2..i+2. Rounds the kinks into longer, steadier arcs.
	for _it in iterations:
		for i in count:
			var target := (4.0 * (_point(i - 1) + _point(i + 1)) - (_point(i - 2) + _point(i + 2))) / 6.0
			_move_toward(i, target, 0.5)
	for i in count:
		points[i] = _point(i)


func _move_toward(i: int, target: Vector3, weight: float) -> void:
	var want := (target - _centers[i]).dot(_rights[i])
	var lat := clampf(lerpf(lateral[i], want, weight), -limit, limit)
	if not _col_side.is_empty() and _col_side[i] != 0.0:
		# Never through a road column: stay in the gap the line started in.
		if _col_side[i] > 0.0:
			lat = maxf(lat, _col_min[i])
		else:
			lat = minf(lat, _col_max[i])
	lateral[i] = lat


func _point(i: int) -> Vector3:
	var j := posmod(i, count)
	return _centers[j] + _rights[j] * lateral[j]


func _compute_curvature() -> void:
	curvature.resize(count)
	var k := 3 # compare points ~9 m apart for a stable radius
	for i in count:
		var a := points[posmod(i - k, count)]
		var b := points[i]
		var c := points[posmod(i + k, count)]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var bc := Vector2(c.x - b.x, c.z - b.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var cross := ab.x * bc.y - ab.y * bc.x
		var denom := ab.length() * bc.length() * ac.length()
		# Circumradius formula: 1/R = 2|cross| / (|ab||bc||ac|).
		# In x/z, a negative cross is a left turn (y is up, forward is -z).
		curvature[i] = (-2.0 * cross / denom) if denom > 0.0001 else 0.0


func _compute_speeds(stats: VehicleStats) -> void:
	speeds.resize(count)
	# Use 85% of the car's yaw rate so the AI has steering in reserve.
	var h := stats.handling * 0.85
	var falloff := 1.0 - stats.high_speed_steer_factor
	var top := stats.top_speed
	for i in count:
		# Look at the tightest curvature nearby so speed drops before the apex.
		var k := 0.0
		for d in range(-2, 3):
			k = maxf(k, absf(curvature[posmod(i + d, count)]))
		if k < 0.0005:
			speeds[i] = top
			continue
		var radius := 1.0 / k
		# Solve v = R * h * (1 - falloff * v / top) for v.
		speeds[i] = minf(top, radius * h / (1.0 + radius * h * falloff / top))
	# Backward pass: be slow enough to brake into every corner.
	# Plan on well under full braking so the AI has margin to react.
	var decel := stats.brake_deceleration * 0.4
	for _pass in 2:
		for n in count:
			var i := count - 1 - n
			var next_speed := speeds[(i + 1) % count]
			speeds[i] = minf(speeds[i], sqrt(next_speed * next_speed + 2.0 * decel * spacing))


func _find_drift_zones() -> void:
	drift_zones.clear()
	# Smoothed signed turn rate needed at each sample.
	var need := PackedFloat32Array()
	need.resize(count)
	for i in count:
		var k := 0.0
		for d in range(-3, 4):
			k += curvature[posmod(i + d, count)]
		need[i] = speeds[i] * k / 7.0
	# Start scanning from a sample that is not in a corner, so no zone is split
	# at the loop seam.
	var start := 0
	for i in count:
		if absf(need[i]) < DRIFT_MIN_YAW * 0.5:
			start = i
			break
	var run_start := -1
	var run_sign := 0.0
	var run_speed := 0.0
	for n in count + 1:
		var i := (start + n) % count
		var in_zone := absf(need[i]) >= DRIFT_MIN_YAW and (run_start < 0 or signf(need[i]) == run_sign)
		if in_zone:
			if run_start < 0:
				run_start = n
				run_sign = signf(need[i])
				run_speed = 0.0
			run_speed += speeds[i]
			continue
		if run_start >= 0:
			var samples := n - run_start
			var avg_speed := run_speed / float(samples)
			if float(samples) * spacing >= avg_speed * DRIFT_MIN_SECONDS:
				var start_offset := float((start + run_start) % count) * spacing
				var end_offset := float((start + n) % count) * spacing
				# Left turn (+ curvature) = drift left (-1).
				drift_zones.append(Vector3(start_offset, end_offset, -run_sign))
			run_start = -1
