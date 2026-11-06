class_name TreeBuilder
extends RefCounted
## Procedural forest for a TrackScenery. A handful of tree meshes are built
## once (lofted bark tubes along a 3D path, plus foliage clumps), then
## scattered as MultiMesh instances in 200 m chunks, so thousands of trees
## cost a few draw calls and off-screen chunks are culled. Visual only.
##
## Kinds:
## - "crooked": Hoia Baciu's bent pines. The trunk leaves the ground
##   sideways, curls up in a J/S bend, then rises tall and straight to a
##   high, sparse canopy.
## - "pine": a tall straight pine with a high canopy (misty pine forest).
## - "bare": a twisted leafless deciduous tree with forked branches.
## - "snag": a broken dead trunk.

const KINDS: Array[String] = ["crooked", "pine", "bare", "snag"]
const VARIANTS := 2
## Instances further than this from the camera are hidden (fog hides them).
const VISIBLE_RANGE := 300.0
## Trees are grouped per kind and variant into square chunks this size (m).
const CHUNK := 200.0

var scenery: TrackScenery
var bark_key: String
var foliage_key: String
## kind -> Array[ArrayMesh] (variants)
var _meshes: Dictionary = {}
## "kind:variant@cx,cz" -> Array[Transform3D]
var _placed: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(p_scenery: TrackScenery, p_bark_key: String, p_foliage_key: String, seed_value: int = 7) -> void:
	scenery = p_scenery
	bark_key = p_bark_key
	foliage_key = p_foliage_key
	_rng.seed = seed_value
	for kind in KINDS:
		var list: Array[ArrayMesh] = []
		for v in VARIANTS:
			list.append(_build_mesh(kind))
		_meshes[kind] = list


## Places one tree. xf is track-local: origin on the ground, -Z the
## direction a crooked tree's base points.
func place(kind: String, xf: Transform3D) -> void:
	var v := _rng.randi_range(0, VARIANTS - 1)
	var key := "%s:%d@%d,%d" % [kind, v, int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK))]
	if not _placed.has(key):
		_placed[key] = []
	(_placed[key] as Array).append(xf)


## Number of trees placed so far.
func count() -> int:
	var n := 0
	for key in _placed:
		n += (_placed[key] as Array).size()
	return n


## Builds the MultiMeshInstance3D chunks.
func commit() -> void:
	for key in _placed:
		var kind := (key as String).get_slice(":", 0)
		var v := int((key as String).get_slice(":", 1).get_slice("@", 0))
		var list: Array = _placed[key]
		# The node sits at the chunk centre so its visibility range (measured
		# from the node origin) works; instances are relative to it.
		var cell := (key as String).get_slice("@", 1)
		var centre := Vector3((int(cell.get_slice(",", 0)) + 0.5) * CHUNK, 0, (int(cell.get_slice(",", 1)) + 0.5) * CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = (_meshes[kind] as Array)[v]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, (list[i] as Transform3D).translated(-centre))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees_" + (key as String).replace(":", "_").replace("@", "_").replace(",", "_")
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Measured to the chunk centre: add half the chunk's diagonal.
		mmi.visibility_range_end = VISIBLE_RANGE + CHUNK * 0.71
		scenery.add_node(mmi)
	_placed.clear()


# --- mesh building -----------------------------------------------------------------

func _build_mesh(kind: String) -> ArrayMesh:
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_leaves := false
	match kind:
		"crooked":
			var reach := _rng.randf_range(2.2, 3.4)
			var lift := _rng.randf_range(0.6, 1.2)
			var h := _rng.randf_range(18.0, 24.0)
			var r := _rng.randf_range(0.32, 0.42)
			# Rises a little, lies over sideways (-Z), curls up past vertical,
			# leans back a touch (the S), then climbs straight.
			var path := PackedVector3Array([
				Vector3(0, 0, 0), Vector3(0, 0.35, -0.2), Vector3(0, 0.6, -0.9), Vector3(0, 0.7, -1.8),
				Vector3(0, 0.75 + lift * 0.2, -reach), Vector3(0, 1.3 + lift * 0.4, -reach - 0.9),
				Vector3(0, 2.3 + lift * 0.5, -reach - 1.2), Vector3(0, 3.5 + lift * 0.5, -reach - 0.9),
				Vector3(0, 5.0 + lift, -reach - 0.45), Vector3(0, 7.5 + lift, -reach - 0.3),
				Vector3(0.1, h * 0.6, -reach - 0.25), Vector3(0.15, h, -reach - 0.2)])
			_tube(bark, path, r * 1.15, r * 0.35, 8)
			_canopy(leaves, Vector3(0.15, h, -reach - 0.2), h * 0.18, 4)
			has_leaves = true
		"pine":
			var h := _rng.randf_range(20.0, 27.0)
			var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			var path := PackedVector3Array()
			for i in 6:
				var t := i / 5.0
				path.append(Vector3(0, h * t, 0) + lean * t * t)
			_tube(bark, path, _rng.randf_range(0.3, 0.42), 0.1, 7)
			_canopy(leaves, Vector3(0, h, 0) + lean, h * 0.2, 4)
			has_leaves = true
		"bare":
			var h := _rng.randf_range(9.0, 14.0)
			var path := PackedVector3Array()
			var p := Vector3.ZERO
			for i in 6:
				path.append(p)
				p += Vector3(_rng.randf_range(-0.6, 0.6), h / 5.0, _rng.randf_range(-0.6, 0.6))
			_tube(bark, path, _rng.randf_range(0.28, 0.38), 0.08, 7)
			# Forked, crooked branches reaching up and out, with twigs.
			for b in _rng.randi_range(4, 6):
				var start := path[_rng.randi_range(2, 4)]
				var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.2), _rng.randf_range(-1, 1)).normalized()
				var branch := PackedVector3Array([start])
				var q := start
				for k in 3:
					dir = (dir + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.1, 0.3), _rng.randf_range(-0.5, 0.5))).normalized()
					q += dir * _rng.randf_range(1.2, 2.2)
					branch.append(q)
				_tube(bark, branch, 0.12, 0.03, 5)
				var twig := PackedVector3Array([branch[2], branch[2] + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.6, 1.4), _rng.randf_range(-1, 1))])
				_tube(bark, twig, 0.05, 0.015, 4)
		"snag":
			var h := _rng.randf_range(4.0, 8.0)
			var tilt := Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
			var path := PackedVector3Array([Vector3.ZERO, Vector3(0, h * 0.5, 0) + tilt * 0.3, Vector3(0, h, 0) + tilt])
			_tube(bark, path, _rng.randf_range(0.35, 0.5), 0.2, 7)
			# A jagged break at the top.
			_tube(bark, PackedVector3Array([Vector3(0, h, 0) + tilt, Vector3(0.15, h + 1.2, 0.1) + tilt]), 0.2, 0.0, 4)
	var mesh := ArrayMesh.new()
	bark.generate_tangents()
	bark.commit(mesh)
	mesh.surface_set_material(0, scenery.get_material(bark_key))
	if has_leaves:
		leaves.commit(mesh)
		mesh.surface_set_material(1, scenery.get_material(foliage_key))
	return mesh


## A tapered tube along a path (parallel-transported rings).
func _tube(st: SurfaceTool, path: PackedVector3Array, r0: float, r1: float, sides: int) -> void:
	var n := path.size()
	if n < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var tangent := (path[1] - path[0]).normalized()
	var side := tangent.cross(Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	for i in n:
		var t_next := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		# Parallel transport keeps the rings from twisting.
		side = (side - t_next * side.dot(t_next)).normalized()
		tangent = t_next
		var up := tangent.cross(side).normalized()
		var r := lerpf(r0, r1, float(i) / (n - 1))
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			var dir := side * cos(a) + up * sin(a)
			ring.append(path[i] + dir * r)
			nr.append(dir)
		rings.append(ring)
		normals.append(nr)
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			_vert(st, rings[i][k], normals[i][k])
			_vert(st, rings[i + 1][k], normals[i + 1][k])
			_vert(st, rings[i][k2], normals[i][k2])
			_vert(st, rings[i][k2], normals[i][k2])
			_vert(st, rings[i + 1][k], normals[i + 1][k])
			_vert(st, rings[i + 1][k2], normals[i + 1][k2])


## Sparse, high canopy: a few dark, flattened needle clumps around the top.
func _canopy(st: SurfaceTool, top: Vector3, spread: float, clumps: int) -> void:
	for c in clumps:
		var ang := TAU * c / clumps + _rng.randf_range(-0.4, 0.4)
		var out := spread * _rng.randf_range(0.2, 0.75) if c > 0 else 0.0
		var centre := top + Vector3(cos(ang) * out, -_rng.randf_range(0.0, spread * 0.9), sin(ang) * out)
		var radii := Vector3(spread * _rng.randf_range(0.45, 0.7), spread * _rng.randf_range(0.22, 0.35), spread * _rng.randf_range(0.45, 0.7))
		_blob(st, centre, radii)


func _blob(st: SurfaceTool, c: Vector3, radii: Vector3) -> void:
	var rings := 3
	var segs := 6
	var pts: Array[PackedVector3Array] = []
	for i in rings + 1:
		var phi := PI * i / rings
		var row := PackedVector3Array()
		for k in segs:
			var th := TAU * k / segs
			row.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)))
		pts.append(row)
	for i in rings:
		for k in segs:
			var k2 := (k + 1) % segs
			var a := pts[i][k]
			var b := pts[i + 1][k]
			var cc := pts[i][k2]
			var d := pts[i + 1][k2]
			for v in [a, cc, b, cc, d, b]:
				_vert(st, c + (v as Vector3) * radii, v as Vector3)


func _vert(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(p.x + p.z, p.y) * 0.5)
	st.add_vertex(p)
