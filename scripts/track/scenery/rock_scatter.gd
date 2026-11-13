class_name RockScatter
extends RefCounted
## Jagged rocks for a TrackScenery: a few rock meshes (subdivided
## icosahedra pushed out by noise, with some faces sheared flat so they read
## as broken stone, flat-shaded) scattered as MultiMesh instances in square
## chunks. Use a world-space material (triplanar), since every instance shares
## a mesh. Visual only.

const VARIANTS := 5
const CHUNK := 200.0

var scenery: TrackScenery
var material: Material
var _meshes: Array[ArrayMesh] = []
## "variant@cx,cz" -> Array of Transform3D
var _placed: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _count: int = 0


func _init(p_scenery: TrackScenery, p_material: Material, seed_value: int = 5) -> void:
	scenery = p_scenery
	material = p_material
	_rng.seed = seed_value
	for v in VARIANTS:
		_meshes.append(_build_rock(seed_value * 31 + v))


## A rock centred at `pos` (track-local) with this size (x, y, z extents).
func place(pos: Vector3, size: Vector3, yaw: float = INF) -> void:
	var y := _rng.randf() * TAU if yaw == INF else yaw
	var basis := Basis(Vector3.UP, y).rotated(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2)).scaled(size * 0.5)
	var key := "%d@%d,%d" % [_rng.randi_range(0, VARIANTS - 1), int(floor(pos.x / CHUNK)), int(floor(pos.z / CHUNK))]
	if not _placed.has(key):
		_placed[key] = []
	(_placed[key] as Array).append(Transform3D(basis, pos))
	_count += 1


func count() -> int:
	return _count


func commit() -> void:
	for key: String in _placed:
		var v := int(key.get_slice("@", 0))
		var list: Array = _placed[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[v]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rocks_" + key.replace("@", "_").replace(",", "_")
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.visibility_range_end = 450.0
		scenery.add_node(mmi)
	_placed.clear()


## Unit-ish rock (radius about 1): an icosahedron subdivided twice, each
## vertex pushed in or out by noise, then a couple of random planes cut
## through it (vertices beyond a plane are flattened onto it).
func _build_rock(seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t := (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = []
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append((v as Vector3).normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
			[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for level in 2:
		var cache := {}
		var next: Array = []
		for f: Array in faces:
			var m: Array[int] = []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var k := Vector2i(mini(a, b), maxi(a, b))
				if not cache.has(k):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					cache[k] = verts.size() - 1
				m.append(cache[k])
			next.append([f[0], m[0], m[2]])
			next.append([f[1], m[1], m[0]])
			next.append([f[2], m[2], m[1]])
			next.append([m[0], m[1], m[2]])
		faces = next
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + noise.get_noise_3dv(v) * 0.35)
	# Sheared faces: flatten everything past a few random planes.
	for c in rng.randi_range(2, 4):
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var d := rng.randf_range(0.55, 0.85)
		for i in verts.size():
			var over := verts[i].dot(n) - d
			if over > 0.0:
				verts[i] -= n * over
	# Flat bottom so it sits on the ground.
	for i in verts.size():
		verts[i].y = maxf(verts[i].y, -0.6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c) / 3.0) < 0.0:
			n = -n
			var tmp := b
			b = c
			c = tmp
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()
