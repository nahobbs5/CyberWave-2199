class_name IceCaveBuilder
extends RefCounted
## Builds a glacier ice cave along a stretch of road (the main loop or a
## shortcut): one continuous, irregular shell of ice whose width, height and
## roughness can change smoothly along the route (dims(d) gives them), carved
## by two layers of noise into big swirling lobes and small scallops.
##
## Corner-aware like TunnelBuilder: shell pieces near the floor that would
## stand on another road (where a shortcut leaves or rejoins) are left out,
## and so is a stretch of the left wall where dims says "open_left" (a cave
## mouth to daylight). The roof is always closed over the road, and stays at
## least min_clear metres above it. Visual only: the track barriers collide.
##
## dims(d) returns a Dictionary: left_wall, right_wall (wall feet laterals),
## crown (roof height), rough (0..2 noise strength), key (material key),
## open_left (bool), open_h (height of the mouth opening).

const STEP := 3.0
## Points across the cross-section, right floor to left floor.
const SEGMENTS := 20

var scenery: TrackScenery
## null = the main loop.
var shortcut: TrackShortcut
## dims(d: float) -> Dictionary (see above).
var dims: Callable
## Called as on_roof(frame, from_lateral, to_lateral) for every section.
var on_roof: Callable
## Called as on_section(frame, profile: PackedVector2Array, d, dims) for every
## section, so the scenery can hang icicles from the real ceiling.
var on_section: Callable
## Lowest roof height over the road.
var min_clear: float = 9.0

var _noise_big := FastNoiseLite.new()
var _noise_small := FastNoiseLite.new()


func _init(p_scenery: TrackScenery, p_shortcut: TrackShortcut = null, seed_value: int = 2199) -> void:
	scenery = p_scenery
	shortcut = p_shortcut
	_noise_big.seed = seed_value
	_noise_big.frequency = 0.03
	_noise_big.fractal_octaves = 2
	_noise_small.seed = seed_value + 7
	_noise_small.frequency = 0.16
	_noise_small.fractal_octaves = 2


func half_width() -> float:
	return (shortcut.road_width if shortcut != null else scenery.track.road_width) * 0.5


func route_length() -> float:
	return shortcut.length if shortcut != null else scenery.track.length


## Frame (track-local) at a distance along the route: -Z forward, X right.
func frame(d: float) -> Transform3D:
	if shortcut == null:
		return scenery.at(d)
	var t := shortcut.tangent_at(d)
	return Transform3D(Basis.looking_at(t, Vector3.UP), shortcut.point_at(d))


## Builds the shell from from_d to to_d (the whole loop when they're equal on
## the main road).
func build(from_d: float, to_d: float) -> void:
	var span := _span(from_d, to_d)
	var n := maxi(1, int(ceil(span / STEP)))
	var step := span / n
	var h := half_width()
	var frames: Array[Transform3D] = []
	var profiles: Array[PackedVector2Array] = []
	var dim_list: Array[Dictionary] = []
	var ds: Array[float] = []
	for k in n + 1:
		var d := _at(from_d, step * k)
		var dm: Dictionary = dims.call(d)
		frames.append(frame(d))
		profiles.append(profile(d, dm, h))
		dim_list.append(dm)
		ds.append(d)
	# Which profile points are kept (near-floor points over another road, or
	# in a mouth opening, are dropped).
	var keep: Array[PackedByteArray] = []
	for k in n + 1:
		var row := PackedByteArray()
		row.resize(SEGMENTS + 1)
		var pr := profiles[k]
		var dm := dim_list[k]
		for i in SEGMENTS + 1:
			var p := pr[i]
			var ok := true
			if p.y < 14.0 and absf(p.x) > h + 1.0:
				var ground := frames[k] * Vector3(p.x, 0, 0)
				ok = scenery.edge_distance(ground) > (absf(p.x) - h) - 0.4
			if ok and p.x < 0.0 and bool(dm.get("open_left", false)) and p.y < float(dm.get("open_h", 18.0)):
				ok = false
			row[i] = 1 if ok else 0
		keep.append(row)
	for k in n:
		var f0 := frames[k]
		var f1 := frames[k + 1]
		var p0 := profiles[k]
		var p1 := profiles[k + 1]
		var key := String(dim_list[k].get("key", "ice"))
		var cx := (float(dim_list[k].get("right_wall", h + 10.0)) - float(dim_list[k].get("left_wall", h + 10.0))) * 0.5
		var axis := f0 * Vector3(cx, float(dim_list[k].get("crown", 15.0)) * 0.35, 0)
		for i in SEGMENTS:
			if keep[k][i] == 0 or keep[k][i + 1] == 0 or keep[k + 1][i] == 0 or keep[k + 1][i + 1] == 0:
				continue
			var a := f0 * Vector3(p0[i].x, p0[i].y, 0)
			var b := f0 * Vector3(p0[i + 1].x, p0[i + 1].y, 0)
			var c := f1 * Vector3(p1[i + 1].x, p1[i + 1].y, 0)
			var e := f1 * Vector3(p1[i].x, p1[i].y, 0)
			var centroid := (a + b + c + e) * 0.25
			scenery._quad(scenery._st(key, centroid), a, b, c, e, centroid * 2.0 - axis)
		var dm0 := dim_list[k]
		if on_roof.is_valid():
			on_roof.call(f0, -float(dm0.get("left_wall", h + 10.0)), float(dm0.get("right_wall", h + 10.0)))
		if on_section.is_valid():
			on_section.call(f0, p0, ds[k], dm0)


## Cross-section at route distance d: right floor -> roof -> left floor, in
## the frame's lateral (x) / height (y) plane.
func profile(d: float, dm: Dictionary, h: float) -> PackedVector2Array:
	var wl := float(dm.get("left_wall", h + 10.0))
	var wr := float(dm.get("right_wall", h + 10.0))
	var crown := float(dm.get("crown", 15.0))
	var rough := float(dm.get("rough", 1.0))
	var c := (wr - wl) * 0.5
	var a := (wr + wl) * 0.5
	var centre := Vector2(c, crown * 0.3)
	var out := PackedVector2Array()
	var u := _loop_coords(d)
	for i in SEGMENTS + 1:
		var theta := PI * i / SEGMENTS
		var s := sin(theta)
		var p := Vector2(c + a * cos(theta), crown * pow(s, 0.5))
		if i == 0 or i == SEGMENTS:
			p.y = -0.3
		else:
			# Big lobes and small scallops push the ice in and out.
			var big := _noise_big.get_noise_3d(u.x, u.y, theta * 18.0)
			var small := _noise_small.get_noise_3d(u.x * 1.0, u.y * 1.0, theta * 30.0)
			var amount := rough * (big * minf(a, crown) * 0.22 + small * 1.1)
			p += (p - centre).normalized() * amount
			# Keep the floor-level walls off the road and the roof high above it.
			if absf(p.x) < h + 3.0:
				p.y = maxf(p.y, min_clear + absf(small) * 1.5)
			if p.y < 6.0 and absf(p.x) < h + 2.5:
				p.x = signf(p.x if p.x != 0.0 else 1.0) * (h + 2.5)
		out.append(p)
	return out


# --- internals -----------------------------------------------------------------------

## Noise coordinates for a route distance. The main loop maps onto a circle
## so the shell joins up seamlessly where the lap wraps.
func _loop_coords(d: float) -> Vector2:
	if shortcut != null:
		return Vector2(d, 500.0)
	var r := route_length() / TAU
	var t := d / route_length() * TAU
	return Vector2(cos(t) * r, sin(t) * r)


func _span(from_d: float, to_d: float) -> float:
	if shortcut != null:
		return clampf(to_d - from_d, 0.0, shortcut.length)
	var s := fposmod(to_d - from_d, scenery.track.length)
	return s if s > 0.0 else scenery.track.length


func _at(from_d: float, along: float) -> float:
	if shortcut != null:
		return clampf(from_d + along, 0.0, shortcut.length)
	return scenery.track.wrap_offset(from_d + along)
