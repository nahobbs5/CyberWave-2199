class_name BambooBuilder
extends RefCounted
## Procedural bamboo grove for a TrackScenery (Arashiyama). A few culm
## meshes are built once (tall, jointed stems, bare below and leafy only in
## their top third), then scattered as MultiMesh instances in square chunks,
## so tens of thousands of culms cost a few draw calls and off-screen chunks
## are culled. The same builder makes the grove floor (ferns, sasa), the
## bristly crest on the brushwood (shibagaki) fences, and thick bamboo rails.
## Visual only.
##
## Culm kinds:
## - "straight": stands nearly upright, crown leaning a little.
## - "arch": leans in toward local -Z over its top 40%, so a row of them
##   along a road edge brings its crowns together high over the road.
## - "dead": a straw-coloured culm with no leaves (one variant snapped short).
## Each culm kind also has a cheaper "<kind>_lo" mesh (fewer sides, no
## twigs, fewer and larger leaf cards) for culms deep in the grove, which
## the camera on the road only sees from afar.
## Every instance gets its own tint (the textures are near-white).

const CULM_KINDS: Array[String] = ["straight", "arch", "dead"]
const VARIANTS := 3
## Instances further than this from the camera are hidden.
const VISIBLE_RANGE := 230.0
## Culms are grouped per kind and variant into square chunks this size (m).
const CHUNK := 120.0
## A culm texture tile covers one internode (m).
const INTERNODE := 0.9

## Shared generated textures and materials (built once per run).
static var _cache: Dictionary = {}

var scenery: TrackScenery
var culm_material: StandardMaterial3D
var leaf_material: StandardMaterial3D
var fern_material: StandardMaterial3D
var brush_material: StandardMaterial3D
var rail_material: StandardMaterial3D
## Shadows from the culms and canopy (the sun's dappled light on the road).
var cast_shadows: bool = true
## kind -> Array[ArrayMesh] (variants)
var _meshes: Dictionary = {}
## "kind:variant@cx,cz" -> Array of [Transform3D, Color]
var _placed: Dictionary = {}
## "cx,cz" -> SurfaceTool for the fence rails.
var _rails: Dictionary = {}
var _counts: Dictionary = {}
## kind ("culm", "spray", "fern", "sasa", "brush") -> PackedVector3Array of
## the track-local positions placed (MultiMesh transforms can't be read back
## under the headless renderer, so tests check these).
var _positions: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(p_scenery: TrackScenery, seed_value: int = 7) -> void:
	scenery = p_scenery
	_rng.seed = seed_value
	if _cache.is_empty():
		_cache["culm"] = _make_culm_material()
		_cache["leaf"] = _make_leaf_material()
		_cache["fern"] = _make_fern_material()
		_cache["brush"] = _make_brush_material()
		_cache["rail"] = _make_rail_material()
	culm_material = _cache["culm"]
	leaf_material = _cache["leaf"]
	fern_material = _cache["fern"]
	brush_material = _cache["brush"]
	rail_material = _cache["rail"]
	for kind in CULM_KINDS:
		var near: Array[ArrayMesh] = []
		var far: Array[ArrayMesh] = []
		for v in (2 if kind == "dead" else VARIANTS):
			near.append(_build_culm(kind, true, v))
			# Far culms are seen small: two variants are plenty.
			if v < 2:
				far.append(_build_culm(kind, false, v))
		_meshes[kind] = near
		_meshes[kind + "_lo"] = far
	_meshes["spray"] = [_build_spray()]
	_meshes["fern"] = [_build_fern()]
	_meshes["sasa"] = [_build_sasa()]
	_meshes["brush"] = [_build_brush()]


## Places one culm. pos is track-local on the ground; toward is the
## horizontal direction it leans (for "arch", the road). scale sizes the
## whole culm; thin makes a slimmer, shorter young culm; detail false uses
## the cheap far mesh. tint multiplies its colour.
func place_culm(kind: String, pos: Vector3, toward: Vector3, scale: float, tint: Color,
		thin: bool = false, detail: bool = true) -> void:
	var dir := Vector3(toward.x, 0, toward.z)
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	var s := Vector3(scale, scale, scale) * (Vector3(0.6, 0.78, 0.6) if thin else Vector3.ONE)
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP).scaled(s)
	var key := kind if detail or kind == "dead" else kind + "_lo"
	_add("%s:%d" % [key, _rng.randi_range(0, (_meshes[key] as Array).size() - 1)], Transform3D(basis, pos), tint)
	_record("culm", pos)


## Hangs one leaf-spray cluster (about 3 m across at scale 1) at xf.
func place_spray(xf: Transform3D, tint: Color) -> void:
	place_item("spray", xf, tint)


## Places a "spray", "fern" (rosette ~2 m across), "sasa" (dwarf bamboo
## clump ~1.4 m across) or "brush" (3 m of fence crest: local +X along the
## fence, +Z away from the road, standing on its origin).
func place_item(kind: String, xf: Transform3D, tint: Color) -> void:
	_add(kind + ":0", xf, tint)
	_record(kind, xf.origin)


## A thick bamboo pole from a to b (fence rails), jointed like the culms.
func add_pole(a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
	var mid := (a + b) * 0.5
	var key := "%d,%d" % [int(floor(mid.x / CHUNK)), int(floor(mid.z / CHUNK))]
	if not _rails.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_rails[key] = st
	var st: SurfaceTool = _rails[key]
	st.set_color(tint)
	_tube(st, PackedVector3Array([a, b]), radius, radius, 6, fposmod(a.x + a.z, 1.0))
	_record("pole", mid)


## Where the tip of a culm placed with place_culm() ends up, measured
## horizontally toward the lean (track-local metres).
static func tip_offset(kind: String, scale: float) -> float:
	return (18.5 * sin(deg_to_rad(12.0)) + 0.8 if kind == "arch" else 0.6) * scale


func culm_count() -> int:
	return item_count("culm")


func spray_count() -> int:
	return item_count("spray")


func item_count(kind: String) -> int:
	return int(_counts.get(kind, 0))


## Track-local positions of everything placed of a kind ("culm", "spray",
## "fern", "sasa", "brush", "pole": rail midpoints).
func positions(kind: String) -> PackedVector3Array:
	return _positions.get(kind, PackedVector3Array())


func _record(kind: String, pos: Vector3) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	if not _positions.has(kind):
		_positions[kind] = PackedVector3Array()
	(_positions[kind] as PackedVector3Array).append(pos)


## Builds the MultiMeshInstance3D chunks (and the rail meshes).
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
		mm.use_colors = true
		mm.mesh = (_meshes[kind] as Array)[v]
		mm.instance_count = list.size()
		for i in list.size():
			var entry: Array = list[i]
			mm.set_instance_transform(i, (entry[0] as Transform3D).translated(-centre))
			mm.set_instance_color(i, entry[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = _prefix(kind) + (key as String).replace(":", "_").replace("@", "_").replace(",", "_")
		mmi.multimesh = mm
		var ground_cover := kind in ["fern", "sasa", "brush"]
		var shadows := cast_shadows and not ground_cover
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = centre
		# Measured to the chunk centre: add half the chunk's diagonal.
		mmi.visibility_range_end = (110.0 if kind in ["fern", "sasa"] else VISIBLE_RANGE) + CHUNK * 0.71
		scenery.add_node(mmi)
	_placed.clear()
	for key in _rails:
		var st: SurfaceTool = _rails[key]
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "FenceRails_" + (key as String).replace(",", "_")
		mi.mesh = st.commit()
		mi.material_override = rail_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3.ZERO
		scenery.add_node(mi)
	_rails.clear()


static func _prefix(kind: String) -> String:
	match kind:
		"spray":
			return "Canopy_"
		"fern", "sasa":
			return "Undergrowth_"
		"brush":
			return "FenceBrush_"
	return "Bamboo_"


func _add(kind_variant: String, xf: Transform3D, tint: Color) -> void:
	var key := "%s@%d,%d" % [kind_variant, int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK))]
	if not _placed.has(key):
		_placed[key] = []
	(_placed[key] as Array).append([xf, tint])


# --- meshes --------------------------------------------------------------------------

## One culm: a rigid, nearly straight tube tilted from its base (toward
## local -Z: 9-15 degrees for "arch", 0-3 for the others), drooping a
## little only in its top 15% under the weight of the crown. The radius
## holds to 70% of the height, then tapers. UV v counts internodes from the
## ground, so the texture's node bands line up with the geometry: the
## detailed mesh swells a ridge at every node up to about 6 m (where the
## camera sees them close). Leaves grow only in the top 30%: at each node
## two branches stick out almost level, each holding a flat fan of leaf
## cards, so the foliage forms stacked, feathery layers, plus a crown of
## fans at the tip. The far mesh is plainer (fewer sides, no ridges, fewer
## and larger fans).
func _build_culm(kind: String, detail: bool, variant: int) -> ArrayMesh:
	var dead := kind == "dead"
	var snapped := dead and variant == 1
	var h := _rng.randf_range(15.0, 22.0)
	if snapped:
		h = _rng.randf_range(4.0, 8.0)
	var tilt := deg_to_rad(_rng.randf_range(0.0, 3.0))
	if kind == "arch":
		tilt = deg_to_rad(_rng.randf_range(9.0, 15.0))
	elif dead:
		tilt = deg_to_rad(_rng.randf_range(0.0, 5.0))
	var axis := Vector3(0, cos(tilt), -sin(tilt))
	var droop := 0.0 if dead else _rng.randf_range(0.3, 0.7) * (1.6 if kind == "arch" else 1.0)
	var r0 := _rng.randf_range(0.13, 0.18)
	var r_tip := r0 * (0.8 if snapped else 0.45)
	var radius_at := func(s: float) -> float:
		var t := s / h
		return r0 if t < 0.7 else lerpf(r0, r_tip, (t - 0.7) / 0.3)
	var point_at := func(s: float) -> Vector3:
		var t := s / h
		var p := axis * s
		if t > 0.85:
			var f := (t - 0.85) / 0.15
			p += Vector3(0, -droop * 0.3 * f * f, -droop * f * f)
		return p
	# Stem rings: plain rings every couple of metres, and a swelling ridge at
	# each node low down.
	var stations: Array[Vector2] = [] # (s, radius factor)
	var ridge_top := 6.0 if detail else -1.0
	var s := 0.0
	var node := 1
	while s < h:
		var next := node * INTERNODE
		if next >= h:
			break
		if next < ridge_top:
			stations.append(Vector2(next - 0.035, 1.0))
			stations.append(Vector2(next, 1.08))
			stations.append(Vector2(next + 0.035, 1.0))
		elif node % (2 if detail else 4) == 0 or next > h * 0.84:
			stations.append(Vector2(next, 1.0))
		s = next
		node += 1
	var path := PackedVector3Array([point_at.call(0.0)])
	var radii := PackedFloat32Array([r0])
	var vs := PackedFloat32Array([0.0])
	for st_: Vector2 in stations:
		path.append(point_at.call(st_.x))
		radii.append(float(radius_at.call(st_.x)) * st_.y)
		vs.append(st_.x / INTERNODE)
	path.append(point_at.call(h))
	radii.append(r_tip)
	vs.append(h / INTERNODE)
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube_r(stem, path, radii, vs, 8 if detail else 5)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not dead:
		# Branches at the nodes over the top 30%, turning round the stem.
		var turn := _rng.randf() * TAU
		var n := int(ceil(h * 0.7 / INTERNODE))
		var step := 1 if detail else 2
		while n * INTERNODE < h - 0.3:
			var at_s := n * INTERNODE
			var t := at_s / h
			var p: Vector3 = point_at.call(at_s)
			for pair in 2:
				var a := turn + pair * PI + _rng.randf_range(-0.4, 0.4)
				var level := Vector3(cos(a), 0, sin(a))
				var rise := deg_to_rad(_rng.randf_range(10.0, 25.0))
				var dir := (level * cos(rise) + Vector3.UP * sin(rise)).normalized()
				var reach := _rng.randf_range(1.0, 2.0) * (1.25 - (t - 0.7) * 1.5)
				var end := p + dir * reach
				if detail:
					_tube(stem, PackedVector3Array([p, end]), 0.02, 0.008, 3, 0.0)
					for k in 3:
						var fan := level.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
						_card(leaves, p.lerp(end, 0.35 + 0.32 * k), fan, Vector3.UP, _rng.randf_range(1.0, 1.4), 0.18)
				else:
					_card(leaves, p.lerp(end, 0.5), level, Vector3.UP, _rng.randf_range(1.9, 2.4), 0.2)
			turn += 2.4 # successive nodes branch in new directions
			n += step
		# A crown of fans at the tip, angled out and a little down.
		var tip: Vector3 = point_at.call(h)
		var crown := 5 if detail else 3
		for k in crown:
			var a := TAU * k / crown + _rng.randf_range(-0.3, 0.3)
			var o := Vector3(cos(a), -0.2, sin(a)).normalized()
			_card(leaves, tip, o, Vector3.UP, _rng.randf_range(1.2, 1.6) if detail else _rng.randf_range(2.0, 2.4), 0.35)
	var mesh := ArrayMesh.new()
	stem.generate_tangents()
	stem.commit(mesh)
	mesh.surface_set_material(0, culm_material)
	if not dead:
		leaves.commit(mesh)
		mesh.surface_set_material(1, leaf_material)
	return mesh


## Canopy cluster: leaf cards in a flattened ball about 3 m across.
func _build_spray() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 16:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 1.3)
		var c := Vector3(cos(a) * r, _rng.randf_range(-0.4, 0.4), sin(a) * r)
		var out := Vector3(cos(a + _rng.randf_range(-0.6, 0.6)), _rng.randf_range(-0.6, -0.1), sin(a + _rng.randf_range(-0.6, 0.6))).normalized()
		var up := Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(-0.3, 0.3)).normalized()
		_card(st, c, out, up, _rng.randf_range(1.3, 1.9))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, leaf_material)
	return mesh


## Fern rosette: nine fronds arching out and down from the centre, about
## 2 m across and 0.6 m tall.
func _build_fern() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 9
	for k in fronds:
		var a := TAU * k / fronds + _rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(a), 0, sin(a))
		var across := Vector3(-out.z, 0, out.x)
		var length := _rng.randf_range(0.8, 1.1)
		var rise := _rng.randf_range(0.5, 0.75)
		var half_w := 0.2
		var segs := 5
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for i in segs + 1:
			var t := float(i) / segs
			# Up and out, then curling down at the tip.
			var p := out * length * t + Vector3(0, rise * sin(PI * 0.85 * t), 0)
			var w := half_w * (0.35 + 0.65 * sin(PI * minf(t * 1.2, 1.0)))
			var l := p - across * w + Vector3(0, w * 0.25, 0)
			var r := p + across * w + Vector3(0, w * 0.25, 0)
			if i > 0:
				var t0 := float(i - 1) / segs
				var n := (r - prev_l).cross(prev_r - prev_l).normalized()
				if n.y < 0.0:
					n = -n
				for v: Array in [[prev_l, Vector2(0, t0)], [prev_r, Vector2(1, t0)], [r, Vector2(1, t)],
						[prev_l, Vector2(0, t0)], [r, Vector2(1, t)], [l, Vector2(0, t)]]:
					st.set_normal(n)
					st.set_uv(v[1])
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, fern_material)
	return mesh


## Sasa: a knee-high clump of dwarf bamboo, upright leaf cards in a dome.
func _build_sasa() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 14:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 0.5)
		var c := Vector3(cos(a) * r, _rng.randf_range(0.5, 1.0), sin(a) * r)
		var out := Vector3(cos(a), _rng.randf_range(-0.2, 0.3), sin(a)).normalized()
		_card(st, c, out, Vector3.UP, _rng.randf_range(0.6, 0.9))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, leaf_material)
	return mesh


## Fence crest: 3 m of bristly brushwood above the fence wall. Three
## alpha-tested sheets (one upright, one leaning out, one leaning in) give
## it depth; the texture tiles every metre.
func _build_brush() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sheet: Array in [[0.0, 0.0, 0.95], [0.12, 0.32, 0.8], [-0.1, -0.12, 0.7]]:
		var z0: float = sheet[0]
		var z1: float = z0 + float(sheet[1])
		var top: float = sheet[2]
		var a := Vector3(-1.55, 0, z0)
		var b := Vector3(1.55, 0, z0)
		var c := Vector3(1.55, top, z1)
		var d := Vector3(-1.55, top, z1)
		var n := Vector3(0, float(sheet[1]), -top).normalized()
		n = Vector3(0, 0.35, -1).normalized() if n.length_squared() < 0.1 else n
		for v: Array in [[a, Vector2(0, 1)], [b, Vector2(3.1, 1)], [c, Vector2(3.1, 0)],
				[a, Vector2(0, 1)], [c, Vector2(3.1, 0)], [d, Vector2(0, 0)]]:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, brush_material)
	return mesh


func _path_point(path: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (path.size() - 1)
	var i := mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - i)


## A leaf card: a quad hanging out from `at` along `out`, its top edge
## toward `up`, `size` metres long. The texture's twig is at the top-left.
func _card(st: SurfaceTool, at: Vector3, out: Vector3, up: Vector3, size: float, droop: float = 0.55) -> void:
	var across := out.cross(up).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	var down := across.cross(out).normalized()
	# The card droops: it runs out and down from the twig.
	var dir := (out + down * droop).normalized()
	var width := size * 0.6
	var a := at - across * width * 0.5
	var b := at + across * width * 0.5
	var c := b + dir * size
	var d := a + dir * size
	var n := across.cross(dir).normalized()
	if n.y < 0.0:
		n = -n
	for v: Array in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c, Vector2(1, 1)], [a, Vector2(0, 0)], [c, Vector2(1, 1)], [d, Vector2(0, 1)]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Tapered tube with parallel-transported rings; u wraps around, v counts
## internodes along the length (starting at v0).
func _tube(st: SurfaceTool, path: PackedVector3Array, r0: float, r1: float, sides: int, v0: float) -> void:
	var n := path.size()
	var radii := PackedFloat32Array()
	var vs := PackedFloat32Array()
	var length := 0.0
	for i in n:
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		vs.append(v0 + length / INTERNODE)
		radii.append(lerpf(r0, r1, pow(float(i) / (n - 1), 1.3)))
	_tube_r(st, path, radii, vs, sides)


## Tube through `path` with a radius and a texture v per point.
func _tube_r(st: SurfaceTool, path: PackedVector3Array, radii: PackedFloat32Array, vs: PackedFloat32Array, sides: int) -> void:
	var n := path.size()
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var tangent := (path[1] - path[0]).normalized()
	var side := tangent.cross(Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP).normalized()
	for i in n:
		var t_next := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		side = (side - t_next * side.dot(t_next)).normalized()
		tangent = t_next
		var up := tangent.cross(side).normalized()
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * k / sides
			var dir := side * cos(a) + up * sin(a)
			ring.append(path[i] + dir * radii[i])
			nr.append(dir)
		rings.append(ring)
		normals.append(nr)
	for i in n - 1:
		for k in sides:
			for q: Array in [[i, k], [i + 1, k], [i, k + 1], [i, k + 1], [i + 1, k], [i + 1, k + 1]]:
				st.set_normal(normals[q[0]][q[1]])
				st.set_uv(Vector2(float(q[1]) / sides, vs[q[0]]))
				st.add_vertex(rings[q[0]][q[1]])


# --- materials and generated textures ----------------------------------------------------

## Culm skin, one internode per tile (row 0 sits just above a node, the
## last row just below the next). Near-white so the instance tint gives the
## hue, with a faint lengthwise grain. At the node: a dark band split over
## both ends of the tile, a bright raised ring just above it, and a white
## powdery band about 10 cm tall just below it. Strong contrast, so the
## nodes still read when mipmapped far away. A matching normal map raises
## the ring.
static func _culm_image() -> Array[Image]:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var bump := PackedFloat32Array()
	bump.resize(h)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var grain := PackedFloat32Array()
	for x in w:
		grain.append(rng.randf_range(0.96, 1.0))
	for y in h:
		var hb := 0.0
		if y < 5:
			hb = -0.5
		elif y < 14:
			hb = 1.0 - absf(y - 9.5) / 4.5
		elif y >= h - 4:
			hb = -0.5
		bump[y] = hb
	for x in w:
		var a := TAU * x / w
		for y in h:
			var m := noise.get_noise_3d(cos(a) * 6.0, sin(a) * 6.0, y * 0.3)
			var c := Color(0.94, 0.97, 0.9) * grain[x]
			c = c.darkened(0.05 * (m * 0.5 + 0.5))
			# A soft sheen band down the middle of each internode.
			c = c.lightened(0.05 * sin(PI * float(y) / h))
			if y < 5 or y >= h - 4:
				c = Color(0.22, 0.25, 0.15) # the node band
			elif y < 14:
				c = c.lerp(Color(1.0, 1.0, 0.92), 0.6 * bump[y]) # the raised ring
			elif y > h - 40:
				# Waxy white powder just below the next node.
				var f := float(y - (h - 40)) / 36.0
				c = c.lerp(Color(1.0, 1.0, 1.0), 0.85 * smoothstep(0.0, 0.35, f))
			img.set_pixel(x, y, c)
	var normal := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var dh := (bump[(y + 1) % h] - bump[(y - 1 + h) % h]) * 0.5
		var n := Vector3(0, -dh * 3.0, 1).normalized()
		var col := Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		for x in w:
			normal.set_pixel(x, y, col)
	img.generate_mipmaps()
	normal.generate_mipmaps()
	return [img, normal]


static func _make_culm_material() -> StandardMaterial3D:
	var imgs := _culm_image()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(imgs[0])
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(imgs[1])
	m.normal_scale = 1.0
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.3
	m.metallic_specular = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Fence rails: the culm skin; add_pole() tints it straw (old, dried bamboo).
static func _make_rail_material() -> StandardMaterial3D:
	var m := (_cache["culm"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.roughness = 0.5
	return m


## Leaf fan texture. The card hangs from its top edge (v = 0), so a twig
## runs down from the top centre, and at three or four points along it a
## group of three to six long, slender, sharply pointed leaves (about 8:1)
## splay out like fingers. Lit-side yellow-greens with darker leaves
## overlapping. Alpha-tested, lit from behind so the sun glows through.
static func _make_leaf_material() -> StandardMaterial3D:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Transparent pixels carry leaf colour so mipmaps don't darken the edges.
	img.fill(Color(0.4, 0.58, 0.2, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	var top := Vector2(size * 0.5, 0)
	var bottom := Vector2(size * 0.5 + rng.randf_range(-40.0, 40.0), size * 0.62)
	_line(img, top, bottom, 3.0, Color(0.42, 0.45, 0.2, 1.0))
	var groups := 4
	for g in groups:
		var base := top.lerp(bottom, 0.18 + 0.82 * g / (groups - 1.0))
		var count := rng.randi_range(3, 6)
		# Lower groups splay wider; the last is the tip of the fan.
		var spread := deg_to_rad(lerpf(110.0, 55.0, float(g) / (groups - 1)))
		for k in count:
			var f := (float(k) / maxf(count - 1, 1)) - 0.5
			var ang := PI * 0.5 + f * spread + deg_to_rad(rng.randf_range(-8.0, 8.0))
			var length := rng.randf_range(170.0, 240.0)
			var width := length / rng.randf_range(7.0, 9.0)
			var shade := Color(0.46, 0.66, 0.2).lerp(Color(0.62, 0.76, 0.28), rng.randf())
			if rng.randf() < 0.35:
				shade = Color(0.24, 0.42, 0.13).lerp(Color(0.32, 0.5, 0.16), rng.randf())
			_leaf(img, base, Vector2(cos(ang), sin(ang)), length, width, shade, rng.randf() < 0.12)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	m.backlight_enabled = true
	m.backlight = Color(0.5, 0.6, 0.18)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## A slender lanceolate leaf from `base` along `dir`: a short stalk, widest
## about a fifth of the way, then a long straight taper to a sharp point,
## with a lighter midrib.
static func _leaf(img: Image, base: Vector2, dir: Vector2, length: float, width: float, shade: Color, yellow: bool) -> void:
	var size := img.get_width()
	var across := Vector2(-dir.y, dir.x)
	var steps := int(length * 1.5)
	for s in steps:
		var t := float(s) / steps
		var half := width * 0.5 * (smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.2, 1.0, t) * 0.97))
		var centre := base + dir * (t * length)
		var hw := int(ceil(half))
		var col := shade
		if yellow and t > 0.75:
			col = shade.lerp(Color(0.78, 0.72, 0.32), (t - 0.75) / 0.25)
		for o in range(-hw * 2, hw * 2 + 1):
			var off := o * 0.5
			if absf(off) > half:
				continue
			var p := centre + across * off
			var px := int(p.x)
			var py := int(p.y)
			if px < 0 or py < 0 or px >= size or py >= size:
				continue
			var edge := absf(off) / maxf(half, 0.5)
			var c := col.lightened(0.2) if absf(off) < 0.75 else col.darkened(0.12 * edge)
			img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))


static func _line(img: Image, a: Vector2, b: Vector2, width: float, c: Color, wrap: bool = false) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var length := a.distance_to(b)
	var steps := int(length * 1.5) + 1
	var hw := width * 0.5
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for oy in range(-int(ceil(hw)), int(ceil(hw)) + 1):
			for ox in range(-int(ceil(hw)), int(ceil(hw)) + 1):
				if Vector2(ox, oy).length() > hw + 0.25:
					continue
				var px := int(p.x) + ox
				var py := int(p.y) + oy
				if wrap:
					px = posmod(px, w)
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				img.set_pixel(px, py, c)


## Fern frond texture: a rachis down the middle (v = 0 at the base) with
## alternating pinnae angled toward the tip, longest a third of the way out.
static func _make_fern_material() -> StandardMaterial3D:
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.42, 0.14, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	_line(img, Vector2(w * 0.5, 0), Vector2(w * 0.5, h - 4), 2.5, Color(0.3, 0.4, 0.14, 1.0))
	var y := 10.0
	var side := 1.0
	while y < h - 8:
		var t := y / h
		var reach := (w * 0.47) * sin(PI * minf(t * 1.25 + 0.12, 1.0))
		var base := Vector2(w * 0.5, y)
		var tip := base + Vector2(side * reach, reach * 0.35)
		var shade := Color(0.2, 0.42, 0.12).lerp(Color(0.38, 0.6, 0.2), rng.randf())
		# Each pinna is a slim leaf from the rachis.
		var steps := int(reach) + 1
		for s in steps:
			var f := float(s) / steps
			var p := base.lerp(tip, f)
			var half := 3.6 * (1.0 - f * 0.8)
			_line(img, p - Vector2(0, half), p + Vector2(0, half), 1.6, Color(shade.r, shade.g, shade.b, 1.0))
		y += rng.randf_range(5.0, 7.0)
		side = -side
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	m.backlight_enabled = true
	m.backlight = Color(0.3, 0.4, 0.1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Brushwood crest texture (tiles sideways, 1 m wide): dense golden twigs
## standing up from a solid base, leaning this way and that, with ragged
## tips at different heights.
static func _make_brush_material() -> StandardMaterial3D:
	var w := 256
	var h := 192
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.62, 0.48, 0.3, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1213
	for y in range(h - 40, h):
		for x in w:
			var c := Color(0.55, 0.42, 0.26).lerp(Color(0.72, 0.58, 0.36), rng.randf())
			img.set_pixel(x, y, c)
	for k in 520:
		var x := rng.randf() * w
		var top := h * rng.randf_range(0.0, 0.75)
		if rng.randf() < 0.35:
			top = h * rng.randf_range(0.0, 0.25) # a few stragglers stand tallest
		var lean := rng.randf_range(-0.35, 0.35) * (h - top)
		var c := Color(0.6, 0.46, 0.27).lerp(Color(0.86, 0.72, 0.46), rng.randf())
		if rng.randf() < 0.2:
			c = Color(0.36, 0.27, 0.17)
		_line(img, Vector2(x, h - 1), Vector2(x + lean, top), rng.randf_range(1.0, 2.2), c, true)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.backlight_enabled = true
	m.backlight = Color(0.35, 0.25, 0.1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
