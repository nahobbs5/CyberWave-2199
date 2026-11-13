extends SceneTree
## Finds scenery geometry inside the space a car drives through: any part of
## a scenery mesh over the road (within the road's half width minus a margin)
## between just above the surface and CLEAR_HEIGHT. Flat tracks only (road at
## track-local y = 0). Prints clusters by route and offset. Run:
##   TRACK=res://scenes/tracks/catacombs_descent.tscn godot --headless -s res://tests/tools/clearance_probe.gd

const CLEAR_HEIGHT := 2.8
## Headroom report: lowest geometry over the road up to this height.
const HEADROOM_TOP := 12.0
const LOW := 0.08
const EDGE_MARGIN := 0.4
const CELL := 4.0
## Triangles are sampled every this many metres along their edges and inside.
const SAMPLE := 0.5

var _grid := {}
var _headroom := {}
var _columns := PackedVector3Array()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_environment("TRACK")
	var track := (load(path) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	for i in 600:
		await process_frame
		var sc := track.get_node_or_null("Scenery")
		if sc == null or sc.get_child_count() > 0:
			break
	for i in 200:
		await process_frame
	_columns = track.road_columns
	# Route samples: [route name, distance, point, half width].
	var half := track.road_width * 0.5 - EDGE_MARGIN
	var d := 0.0
	while d < track.length:
		_add(["main", d, track.to_local(track.get_center_at(d)), half])
		d += 1.0
	for sc in track.shortcuts:
		d = 0.0
		while d <= sc.length:
			_add([sc.name, d, sc.point_at(d), sc.road_width * 0.5 - EDGE_MARGIN])
			d += 1.0
	var hits := {}
	var inv := track.global_transform.affine_inverse()
	var meshes := track.get_node("Scenery").find_children("*", "MeshInstance3D", true, false)
	var tris := 0
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := idx.size() if not idx.is_empty() else verts.size()
			var t := 0
			while t + 2 < count:
				var a := xf * verts[idx[t] if not idx.is_empty() else t]
				var b := xf * verts[idx[t + 1] if not idx.is_empty() else t + 1]
				var c := xf * verts[idx[t + 2] if not idx.is_empty() else t + 2]
				t += 3
				tris += 1
				if minf(a.y, minf(b.y, c.y)) > HEADROOM_TOP or maxf(a.y, maxf(b.y, c.y)) < LOW:
					continue
				_test_triangle(a, b, c, mi, hits)
	print("scanned %d meshes, %d triangles" % [meshes.size(), tris])
	var rows := []
	for k in _headroom:
		rows.append([(_headroom[k] as Array)[0], k, _headroom[k]])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	print("LOWEST HEADROOM (route @ m: height, lateral, node):")
	for r in rows.slice(0, 25):
		print("  %s @ %d: %.2f m, lateral %.1f, %s" % [r[1][0], r[1][1], r[0], r[2][1], r[2][2]])
	var keys := hits.keys()
	keys.sort()
	print("CLEARANCE %s: %d spots" % [path.get_file(), keys.size()])
	for k in keys:
		var h: Array = hits[k]
		print("  %s @ %d m: lowest %.2f m, lateral %.1f, node %s, at %s" % [k[0], k[1], h[0], h[1], h[2], h[3]])
	quit()


## Road columns (Kilwa's hall) stand on the road on purpose: x, z, half side.
func _in_column(p: Vector3) -> bool:
	for c in _columns:
		if absf(p.x - c.x) < c.z + 0.6 and absf(p.z - c.y) < c.z + 0.6:
			return true
	return false


func _add(sample: Array) -> void:
	var p: Vector3 = sample[2]
	var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	if not _grid.has(key):
		_grid[key] = []
	(_grid[key] as Array).append(sample)


func _nearest(p: Vector3) -> Array:
	var best: Array = []
	var best_d := INF
	var k := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for s: Array in _grid.get(Vector2i(k.x + dx, k.y + dz), []):
				var q: Vector3 = s[2]
				var dd := Vector2(p.x - q.x, p.z - q.z).length_squared()
				if dd < best_d:
					best_d = dd
					best = s
	return best


func _test_triangle(a: Vector3, b: Vector3, c: Vector3, mi: MeshInstance3D, hits: Dictionary) -> void:
	var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
	var n := clampi(ceili(longest / SAMPLE), 1, 60)
	for i in n + 1:
		for j in n + 1 - i:
			var u := float(i) / n
			var v := float(j) / n
			var p := a + (b - a) * u + (c - a) * v
			if p.y < LOW or p.y > HEADROOM_TOP:
				continue
			if _in_column(p):
				continue
			var s := _nearest(p)
			if s.is_empty():
				continue
			var q: Vector3 = s[2]
			var lateral := Vector2(p.x - q.x, p.z - q.z).length()
			if lateral > float(s[3]):
				continue
			var key := [String(s[0]), int(float(s[1]) / 5.0) * 5]
			if not _headroom.has(key) or p.y < (_headroom[key] as Array)[0]:
				_headroom[key] = [p.y, lateral, String(mi.get_path()).get_file()]
			if p.y > CLEAR_HEIGHT:
				continue
			if not hits.has(key) or p.y < (hits[key] as Array)[0]:
				hits[key] = [p.y, lateral, String(mi.get_path()).get_file(), p.snapped(Vector3.ONE * 0.1)]
