class_name BambooBuilder
extends RefCounted
## Procedural bamboo grove for a TrackScenery (Arashiyama). A few culm
## meshes are built once (tall, thin, jointed stems with leaf sprays on
## their upper half), then scattered as MultiMesh instances in square
## chunks, so tens of thousands of culms cost a few draw calls and
## off-screen chunks are culled. Separate leaf-spray clusters are hung
## overhead to close the canopy over the road. Visual only.
##
## Culm kinds:
## - "straight": stands nearly upright with a slight bow.
## - "arch": bows hard toward local -Z, so a row of them along a road edge
##   meets over the middle of the road.
## Every instance gets its own tint (young yellow-green to old grey-green).

const KINDS: Array[String] = ["straight", "arch"]
const VARIANTS := 3
## Instances further than this from the camera are hidden.
const VISIBLE_RANGE := 230.0
## Culms are grouped per kind and variant into square chunks this size (m).
const CHUNK := 120.0
## A culm texture tile covers one internode (m).
const INTERNODE := 0.8

var scenery: TrackScenery
var culm_material: StandardMaterial3D
var leaf_material: StandardMaterial3D
## Shadows from the culms and canopy (the sun's dappled light on the road).
var cast_shadows: bool = true
## kind -> Array[ArrayMesh] (variants)
var _meshes: Dictionary = {}
var _spray_mesh: ArrayMesh
## "kind:variant@cx,cz" -> Array of [Transform3D, Color]
var _placed: Dictionary = {}
var _culms: int = 0
var _sprays: int = 0
var _rng := RandomNumberGenerator.new()


func _init(p_scenery: TrackScenery, seed_value: int = 7) -> void:
	scenery = p_scenery
	_rng.seed = seed_value
	culm_material = _make_culm_material()
	leaf_material = _make_leaf_material()
	for kind in KINDS:
		var list: Array[ArrayMesh] = []
		for v in VARIANTS:
			list.append(_build_culm(kind))
		_meshes[kind] = list
	_spray_mesh = _build_spray()


## Places one culm. pos is track-local on the ground; toward is the
## horizontal direction it bows (for "arch", the road). scale sizes the
## whole culm; tint multiplies its colour.
func place_culm(kind: String, pos: Vector3, toward: Vector3, scale: float, tint: Color) -> void:
	var dir := Vector3(toward.x, 0, toward.z)
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP).scaled(Vector3(scale, scale, scale))
	_add("%s:%d" % [kind, _rng.randi_range(0, VARIANTS - 1)], Transform3D(basis, pos), tint)
	_culms += 1


## Hangs one leaf-spray cluster (about 4 m across at scale 1) at xf.
func place_spray(xf: Transform3D, tint: Color) -> void:
	_add("spray:0", xf, tint)
	_sprays += 1


## Where the tip of a culm placed with place_culm() ends up (track-local).
static func tip_offset(kind: String, scale: float) -> float:
	return (6.5 if kind == "arch" else 0.8) * scale


func culm_count() -> int:
	return _culms


func spray_count() -> int:
	return _sprays


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
		mm.use_colors = true
		mm.mesh = _spray_mesh if kind == "spray" else (_meshes[kind] as Array)[v]
		mm.instance_count = list.size()
		for i in list.size():
			var entry: Array = list[i]
			mm.set_instance_transform(i, (entry[0] as Transform3D).translated(-centre))
			mm.set_instance_color(i, entry[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ("Canopy_" if kind == "spray" else "Bamboo_") + (key as String).replace(":", "_").replace("@", "_").replace(",", "_")
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Measured to the chunk centre: add half the chunk's diagonal.
		mmi.visibility_range_end = VISIBLE_RANGE + CHUNK * 0.71
		scenery.add_node(mmi)
	_placed.clear()


func _add(kind_variant: String, xf: Transform3D, tint: Color) -> void:
	var key := "%s@%d,%d" % [kind_variant, int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK))]
	if not _placed.has(key):
		_placed[key] = []
	(_placed[key] as Array).append([xf, tint])


# --- meshes --------------------------------------------------------------------------

## One culm: a tapered six-sided tube along a bowed path (UV v counts
## internodes, so the texture draws the joints), with leaf sprays on short
## side twigs over its upper half.
func _build_culm(kind: String) -> ArrayMesh:
	var h := _rng.randf_range(17.0, 22.0)
	var bend := _rng.randf_range(5.0, 7.5) if kind == "arch" else _rng.randf_range(0.2, 1.4)
	var drift := _rng.randf_range(-0.6, 0.6)
	var path := PackedVector3Array()
	var count := 11
	for i in count:
		var t := float(i) / (count - 1)
		# Upright at the base, bowing more and more toward the top.
		path.append(Vector3(drift * t * t, h * t * (1.0 - 0.12 * t * t * (bend / 7.0)), -bend * pow(t, 2.2)))
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(stem, path, _rng.randf_range(0.1, 0.13), 0.035, 6)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sprays from 45% of the height up, alternating sides, denser at the top.
	var along := 0.45
	var side := 1.0
	while along < 1.0:
		var p := _path_point(path, along)
		var tangent := (_path_point(path, minf(along + 0.02, 1.0)) - _path_point(path, maxf(along - 0.02, 0.0))).normalized()
		var out := tangent.cross(Vector3.FORWARD if kind != "arch" else Vector3.RIGHT).normalized() * side
		if out.length_squared() < 0.1:
			out = Vector3.RIGHT * side
		var yaw := _rng.randf_range(-0.9, 0.9)
		out = out.rotated(tangent, yaw)
		var size := _rng.randf_range(1.6, 2.4) * (0.8 + along * 0.4)
		_card(leaves, p + out * 0.3, out, tangent, size)
		along += _rng.randf_range(0.045, 0.07) * (1.3 - along * 0.5)
		side = -side
	# A crown of sprays at the tip, drooping.
	var tip := path[count - 1]
	for k in 4:
		var a := TAU * k / 4.0 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), -0.35, sin(a)).normalized()
		_card(leaves, tip + out * 0.4, out, Vector3(0, 1, -bend * 0.08).normalized(), _rng.randf_range(2.0, 2.6))
	var mesh := ArrayMesh.new()
	stem.generate_tangents()
	stem.commit(mesh)
	mesh.surface_set_material(0, culm_material)
	leaves.commit(mesh)
	mesh.surface_set_material(1, leaf_material)
	return mesh


## Canopy cluster: a dozen leaf cards in a flattened ball about 4 m across.
func _build_spray() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 1.6)
		var c := Vector3(cos(a) * r, _rng.randf_range(-0.5, 0.5), sin(a) * r)
		var out := Vector3(cos(a + _rng.randf_range(-0.6, 0.6)), _rng.randf_range(-0.6, -0.1), sin(a + _rng.randf_range(-0.6, 0.6))).normalized()
		var up := Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(-0.3, 0.3)).normalized()
		_card(st, c, out, up, _rng.randf_range(2.0, 2.8))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, leaf_material)
	return mesh


func _path_point(path: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (path.size() - 1)
	var i := mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - i)


## A leaf card: a quad hanging out from `at` along `out`, its top edge
## toward `up`, `size` metres long. The texture's twig is at the top-left.
func _card(st: SurfaceTool, at: Vector3, out: Vector3, up: Vector3, size: float) -> void:
	var across := out.cross(up).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	var down := across.cross(out).normalized()
	# The card droops: it runs out and down from the twig.
	var dir := (out + down * 0.55).normalized()
	var width := size * 0.55
	var a := at - across * width * 0.5
	var b := at + across * width * 0.5
	var c := b + dir * size
	var d := a + dir * size
	var n := across.cross(dir).normalized()
	if n.y < 0.0:
		n = -n
	for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c, Vector2(1, 1)], [a, Vector2(0, 0)], [c, Vector2(1, 1)], [d, Vector2(0, 1)]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Tapered tube with parallel-transported rings; u wraps around, v counts
## internodes along the length.
func _tube(st: SurfaceTool, path: PackedVector3Array, r0: float, r1: float, sides: int) -> void:
	var n := path.size()
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var vs := PackedFloat32Array()
	var length := 0.0
	var tangent := (path[1] - path[0]).normalized()
	var side := tangent.cross(Vector3.FORWARD).normalized()
	for i in n:
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		vs.append(length / INTERNODE)
		var t_next := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		side = (side - t_next * side.dot(t_next)).normalized()
		tangent = t_next
		var up := tangent.cross(side).normalized()
		var r := lerpf(r0, r1, pow(float(i) / (n - 1), 1.5))
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * k / sides
			var dir := side * cos(a) + up * sin(a)
			ring.append(path[i] + dir * r)
			nr.append(dir)
		rings.append(ring)
		normals.append(nr)
	for i in n - 1:
		for k in sides:
			var quad := [[i, k], [i + 1, k], [i, k + 1], [i, k + 1], [i + 1, k], [i + 1, k + 1]]
			for q in quad:
				st.set_normal(normals[q[0]][q[1]])
				st.set_uv(Vector2(float(q[1]) / sides, vs[q[0]]))
				st.add_vertex(rings[q[0]][q[1]])


# --- materials and generated textures ----------------------------------------------------

## Culm skin: one internode per tile. Pale, faintly streaked green (the
## instance tint gives the real colour) with a raised joint ring, a dark
## line at the joint and a powdery white band just below it.
func _make_culm_material() -> StandardMaterial3D:
	var w := 32
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for x in w:
		var streak := 0.92 + 0.08 * sin(x * 1.7) * sin(x * 0.45)
		for y in h:
			var v := float(y) / h
			var c := Color(0.86, 0.93, 0.72) * streak
			# Slight sheen gradient along each internode.
			c = c.lightened(0.06 * sin(v * PI))
			if y < 3:
				c = Color(0.48, 0.5, 0.36) # the joint line
			elif y < 7:
				c = Color(0.95, 0.97, 0.86) # the raised ring
			elif y > h - 12:
				c = c.lerp(Color(0.95, 0.97, 0.94), 0.5 * (y - (h - 12)) / 12.0) # waxy bloom below the next joint
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Leaf spray texture: a twig from the top-left corner with narrow,
## pointed bamboo leaves fanning out and down. Alpha-tested, lit from
## behind so the sun glows through the canopy.
func _make_leaf_material() -> StandardMaterial3D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	# The twig runs diagonally from the top-left toward the bottom-right.
	for k in 26:
		var t := rng.randf_range(0.05, 0.95)
		var base := Vector2(lerpf(20.0, 200.0, t), lerpf(16.0, 190.0, t * t))
		var ang := deg_to_rad(rng.randf_range(40.0, 130.0))
		var length := rng.randf_range(55.0, 95.0)
		var width := rng.randf_range(6.0, 10.0)
		var shade := Color(0.55, 0.8, 0.3).lerp(Color(0.25, 0.5, 0.18), rng.randf())
		_leaf(img, base, Vector2(cos(ang), sin(ang)), length, width, shade)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.7
	m.backlight_enabled = true
	m.backlight = Color(0.35, 0.45, 0.12)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## A narrow pointed leaf from `base` along `dir`, with a lighter midrib.
func _leaf(img: Image, base: Vector2, dir: Vector2, length: float, width: float, shade: Color) -> void:
	var size := img.get_width()
	var across := Vector2(-dir.y, dir.x)
	var steps := int(length)
	for s in steps:
		var t := float(s) / steps
		# Widest a third of the way along, tapering to a long point.
		var half := width * 0.5 * sin(PI * pow(t, 0.7)) * (1.0 - t * 0.3)
		var centre := base + dir * s
		var hw := int(ceil(half))
		for o in range(-hw, hw + 1):
			var p := centre + across * o
			var px := int(p.x)
			var py := int(p.y)
			if px < 0 or py < 0 or px >= size or py >= size:
				continue
			var edge := absf(o) / maxf(half, 0.5)
			var c := shade.lightened(0.18) if absf(o) < 0.8 else shade.darkened(0.15 * edge)
			img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
