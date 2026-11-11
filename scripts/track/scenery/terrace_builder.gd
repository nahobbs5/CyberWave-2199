class_name TerraceBuilder
extends RefCounted
## Stepped stone terraces along a road (Inca andenes): stone risers facing
## the road with grass treads between them, rising with distance from the
## road edge. Each side of the road builds out to the halfway line to the
## next road (or `limit`), so two lanes side by side share one terrace strip.
## Where the strip meets lower ground (a different profile on the other side)
## a stone face drops to it. Visual only.
##
## profile: func(section: int, d: float) -> float, the tread height d metres
##   beyond the road edge.
## breaks: func(section: int) -> PackedFloat32Array, the ascending distances
##   where the height steps up.
## section_of: func(offset: float) -> int, the profile for a road position.
## neighbour_section: func(local_pos: Vector3) -> int, the profile of the road
##   nearest a point (the far side of a strip).

var scenery: TrackScenery
var wall_key: String
var top_key: String
var profile: Callable
var breaks: Callable
var section_of: Callable
var neighbour_section: Callable
## Furthest a terrace reaches from the road edge (m).
var limit: float = 60.0
var spacing: float = 3.0

## Riser quads built (tests).
var riser_count: int = 0


func _init(p_scenery: TrackScenery, p_wall_key: String, p_top_key: String) -> void:
	scenery = p_scenery
	wall_key = p_wall_key
	top_key = p_top_key


## Terraces along both sides of a road. Shortcuts pass closed = false and a
## fixed section. Returns one entry per sample for placing things on the
## terraces: {offset, point, right, section, reach: {-1.0: m, 1.0: m}}.
func build_road(curve: Curve3D, half: float, closed: bool, fixed_section: int = -1) -> Array:
	var length := curve.get_baked_length()
	var count := maxi(2, int(length / spacing))
	var pts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var tangents: Array[Vector3] = []
	var secs: Array[int] = []
	for i in count + (0 if closed else 1):
		var d := length * float(i) / float(count)
		var a := curve.sample_baked(fmod(d - 1.0 + length, length) if closed else maxf(d - 1.0, 0.0))
		var b := curve.sample_baked(fmod(d + 1.0, length) if closed else minf(d + 1.0, length))
		var t := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var c := curve.sample_baked(d)
		pts.append(Vector3(c.x, 0.0, c.z))
		tangents.append(t)
		rights.append(t.cross(Vector3.UP).normalized())
		secs.append(fixed_section if fixed_section >= 0 else int(section_of.call(d)))
	var n := pts.size()
	var reach := {}
	for side in [-1.0, 1.0]:
		var tm := PackedFloat32Array()
		tm.resize(n)
		for i in n:
			tm[i] = _reach(pts[i], rights[i] * side, half)
		reach[side] = tm
		var last := n if closed else n - 1
		for i in last:
			var j := (i + 1) % n
			if secs[i] == secs[j]:
				_segment(pts[i], pts[j], rights[i] * side, rights[j] * side, half, tm[i], tm[j], secs[i])
			else:
				_cap(pts[j], rights[j] * side, tangents[j], half, tm[j], secs[i], secs[j])
	var out := []
	for i in n:
		out.append({"offset": length * float(i) / float(count), "point": pts[i], "right": rights[i],
				"tangent": tangents[i], "section": secs[i], "reach": {-1.0: reach[-1.0][i], 1.0: reach[1.0][i]}})
	return out


## How far (m beyond the edge) this road is still the nearest one along dir.
func _reach(c: Vector3, dir: Vector3, half: float) -> float:
	if _own(c, dir, half, limit):
		return limit
	var lo := 0.0
	var hi := limit
	for k in 8:
		var mid := (lo + hi) * 0.5
		if _own(c, dir, half, mid):
			lo = mid
		else:
			hi = mid
	return lo


func _own(c: Vector3, dir: Vector3, half: float, t: float) -> bool:
	return scenery.edge_distance(c + dir * (half + t)) >= t - 1.0


func _p(c: Vector3, dir: Vector3, half: float, d: float, y: float) -> Vector3:
	return c + dir * (half + d) + Vector3(0.0, y, 0.0)


func _segment(c0: Vector3, c1: Vector3, r0: Vector3, r1: Vector3, half: float, t0: float, t1: float, sec: int) -> void:
	var bp: PackedFloat32Array = breaks.call(sec)
	var top := 0.0
	for k in bp.size():
		var a: float = bp[k]
		if a >= t0 - 0.3 or a >= t1 - 0.3:
			break
		var nxt: float = bp[k + 1] if k + 1 < bp.size() else limit
		var lo: float = profile.call(sec, a - 0.01)
		var hi: float = profile.call(sec, a + 0.01)
		top = hi
		var behind := (_p(c0, r0, half, a + 1.0, (lo + hi) * 0.5) + _p(c1, r1, half, a + 1.0, (lo + hi) * 0.5)) * 0.5
		scenery.add_quad(wall_key, _p(c0, r0, half, a, lo), _p(c1, r1, half, a, lo), _p(c1, r1, half, a, hi), _p(c0, r0, half, a, hi), behind)
		riser_count += 1
		var b0 := minf(nxt, t0)
		var b1 := minf(nxt, t1)
		var below := (_p(c0, r0, half, (a + b0) * 0.5, hi - 1.0) + _p(c1, r1, half, (a + b1) * 0.5, hi - 1.0)) * 0.5
		scenery.add_quad(top_key, _p(c0, r0, half, a, hi), _p(c1, r1, half, a, hi), _p(c1, r1, half, b1, hi), _p(c0, r0, half, b0, hi), below)
	if top <= 0.0:
		return
	# The far edge of the strip: drop to whatever is lower beyond it.
	var low := 0.0
	if t0 >= limit - 0.01 and t1 >= limit - 0.01:
		low = maxf(0.0, top - 3.0)
	else:
		var probe := (_p(c0, r0, half, t0 + 2.0, 0.0) + _p(c1, r1, half, t1 + 2.0, 0.0)) * 0.5
		var other := int(neighbour_section.call(probe))
		low = float(profile.call(other, (t0 + t1) * 0.5))
	if top > low + 0.05:
		var toward := (_p(c0, r0, half, t0 - 1.0, top) + _p(c1, r1, half, t1 - 1.0, top)) * 0.5
		scenery.add_quad(wall_key, _p(c0, r0, half, t0, low), _p(c1, r1, half, t1, low), _p(c1, r1, half, t1, top), _p(c0, r0, half, t0, top), toward)


## End wall where the profile changes along the road (e.g. a village gate).
func _cap(c: Vector3, r: Vector3, tangent: Vector3, half: float, reach: float, before: int, after: int) -> void:
	var cuts := PackedFloat32Array([0.0])
	cuts.append_array(breaks.call(before))
	cuts.append_array(breaks.call(after))
	cuts.append(reach)
	cuts.sort()
	for k in cuts.size() - 1:
		var u := cuts[k]
		var v := minf(cuts[k + 1], reach)
		if v - u < 0.05:
			continue
		var m := (u + v) * 0.5
		var h0: float = profile.call(before, m)
		var h1: float = profile.call(after, m)
		if absf(h0 - h1) < 0.05:
			continue
		var lo := minf(h0, h1)
		var hi := maxf(h0, h1)
		var solid := c + tangent * (-1.0 if h0 > h1 else 1.0) + r * (half + m) + Vector3(0, (lo + hi) * 0.5, 0)
		scenery.add_quad(wall_key, _p(c, r, half, u, lo), _p(c, r, half, v, lo), _p(c, r, half, v, hi), _p(c, r, half, u, hi), solid)
