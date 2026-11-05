class_name ChainLinkFence
extends RefCounted
## Damaged chain-link fencing along a polyline (track-local points on the
## ground): rusty posts, sagging mesh panels (procedural alpha-tested texture,
## no asset needed), some panels missing or fallen, barbed wire on top.

static var _material: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _material != null:
		return _material
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Diamond mesh: two diagonal wires per tile.
	for i in size:
		for w in 2:
			var a := (i + w) % size
			img.set_pixel(i, a, Color(0.55, 0.52, 0.48, 1))
			img.set_pixel(i, (size - 1 - i + w) % size, Color(0.55, 0.52, 0.48, 1))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_material = m
	return m


static func build(scenery: TrackScenery, points: PackedVector3Array, post_key: String, height: float = 2.6,
		spacing: float = 3.0) -> void:
	var rng := scenery.rng
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts: Array[Vector3] = []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / spacing))
		for k in n:
			posts.append(a.lerp(b, float(k) / n))
	posts.append(points[points.size() - 1])
	var u := 0.0
	for i in posts.size() - 1:
		var a := posts[i]
		var b := posts[i + 1]
		if not scenery.clear(a, 0.3) or not scenery.clear(b, 0.3):
			continue
		var lean_a := rng.randf_range(-0.12, 0.12)
		scenery.add_box(post_key, Vector3(0.1, height, 0.1),
				Transform3D(Basis(Vector3.FORWARD, lean_a), a + Vector3(0, height * 0.5, 0)))
		var roll := rng.randf()
		var len := a.distance_to(b)
		if roll < 0.12:
			continue # panel gone
		var top_a := a + Vector3(sin(lean_a) * height, height * cos(lean_a), 0)
		var top_b := b + Vector3(0, height, 0)
		var sag := rng.randf_range(0.0, 0.5)
		var bottom_a := a + Vector3(0, 0.1, 0)
		var bottom_b := b + Vector3(0, 0.1, 0)
		if roll < 0.2:
			# Fallen flat into the weeds.
			var side := (b - a).cross(Vector3.UP).normalized() * height
			top_a = bottom_a + side
			top_b = bottom_b + side
			top_a.y = 0.15
			top_b.y = 0.15
		else:
			top_a.y -= sag
			top_b.y -= sag * rng.randf()
		_quad(st, bottom_a, bottom_b, top_b, top_a, u, u + len / 1.5, 0.0, height / 1.5)
		u += len / 1.5
		if roll > 0.75:
			scenery.add_box(post_key, Vector3(0.03, 0.03, len), Transform3D(Basis.looking_at((top_b - top_a).normalized(), Vector3.UP), (top_a + top_b) * 0.5 + Vector3(0, 0.25, 0)))
	scenery.add_mesh_instance(st.commit(), material(), "ChainLink")


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
	var n := (b - a).cross(d - a).normalized()
	var verts := [[a, Vector2(u0, v1)], [b, Vector2(u1, v1)], [c, Vector2(u1, v0)], [a, Vector2(u0, v1)], [c, Vector2(u1, v0)], [d, Vector2(u0, v0)]]
	for v in verts:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])
