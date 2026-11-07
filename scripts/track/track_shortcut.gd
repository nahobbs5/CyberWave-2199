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

var curve: Curve3D
var length: float = 0.0
## Main-loop offsets where it leaves and rejoins.
var start_offset: float = 0.0
var end_offset: float = 0.0
## Main-loop distance it replaces.
var span: float = 0.0
var _speeds: PackedFloat32Array = PackedFloat32Array()


## Called by TrackCircuit after its own curve is built.
func build_route(track: TrackCircuit) -> void:
	curve = Curve3D.new()
	curve.bake_interval = 1.0
	var pts := control_points.duplicate()
	if pts.size() < 3:
		length = 0.0
		return
	start_offset = track.curve.get_closest_offset(pts[0])
	end_offset = track.curve.get_closest_offset(pts[pts.size() - 1])
	pts[0] = track.curve.sample_baked(start_offset)
	pts[pts.size() - 1] = track.curve.sample_baked(end_offset)
	# Leave and rejoin along the main road's direction for smooth junctions.
	var t0 := _main_tangent(track, start_offset)
	var t1 := _main_tangent(track, end_offset)
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


func is_valid() -> bool:
	return length > 0.0


## Distance along the shortcut nearest a point (track local space).
func local_offset(local_pos: Vector3) -> float:
	return curve.get_closest_offset(local_pos)


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
