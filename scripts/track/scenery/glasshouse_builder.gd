class_name GlasshouseBuilder
extends RefCounted
## Victorian iron-and-glass greenhouse parts for a TrackScenery (Parque
## Quinta Normal): barrel-vaulted wings along a stretch of road, ribbed domes
## (with an upper drum, an open lantern, a gallery and an exterior staircase),
## and welded wire-mesh walls and fences. Glass panes are partly missing or
## yellowed with age. Corner-aware: posts that would stand on a road are left
## out (so roads pass through openings), and a span is skipped where its
## posts can't stand. Visual only; the track barriers do the colliding.
##
## Material keys expected on the scenery: iron, glass, glass_old. The wire
## mesh is its own alpha-tested material (mesh_material()), built here.

## Wire mesh: one texture tile is this many metres square.
const MESH_TILE := 1.0

var s: TrackScenery
var rng := RandomNumberGenerator.new()
## Chunk -> SurfaceTool for wire-mesh panels (they need UVs, so they're not
## in the scenery's batches).
var _mesh_tools: Dictionary = {}
## Track-local XZ cells (ROOF_CELL m) that have a glass roof over them.
var roof_cells: Dictionary = {}

const ROOF_CELL := 4.0

static var _mesh_material: StandardMaterial3D


func _init(p_scenery: TrackScenery, seed_value: int = 11) -> void:
	s = p_scenery
	rng.seed = seed_value


## Welded square-grid wire mesh (alpha-tested), like the greenhouse walls.
static func mesh_material() -> StandardMaterial3D:
	if _mesh_material != null:
		return _mesh_material
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wire := Color(0.5, 0.53, 0.5, 1.0)
	# Four cells per tile each way (25 cm at a 1 m tile), 2-pixel wires.
	for i in size:
		for k in 4:
			for w in 2:
				img.set_pixel(i, (k * 16 + w) % size, wire)
				img.set_pixel((k * 16 + w) % size, i, wire)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mesh_material = m
	return m


func is_roofed(p: Vector3) -> bool:
	return roof_cells.has(Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL))))


# --- barrel-vaulted wings ----------------------------------------------------------

## A barrel-vaulted wing along `curve` from distance d0 to d1 (wrapping on a
## closed curve): iron posts and wire-mesh walls up to wall_h, then arched
## ribs (slightly flattened) every `spacing` metres with glass between them,
## purlins, and a railed catwalk along the ridge.
func barrel(curve: Curve3D, closed: bool, d0: float, d1: float, half_width: float, wall_h: float,
		spacing: float = 2.5, missing: float = 0.3, catwalk: bool = true) -> void:
	var length := curve.get_baked_length()
	if closed and d1 < d0:
		d1 += length
	var segs := 8
	var prev: Array = []
	var d := d0
	while d <= d1 + 0.01:
		var dd := fposmod(d, length) if closed else clampf(d, 0.0, length)
		var p := curve.sample_baked(dd)
		var q := curve.sample_baked(fposmod(dd + 1.0, length) if closed else minf(dd + 1.0, length))
		if q.distance_to(p) < 0.01:
			q = p - (curve.sample_baked(maxf(dd - 1.0, 0.0)) - p)
		var fwd := Vector3(q.x - p.x, 0.0, q.z - p.z).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var base_l := p - right * half_width
		var base_r := p + right * half_width
		if not s.clear(base_l, 0.25) or not s.clear(base_r, 0.25):
			prev = []
			d += spacing
			continue
		var arc: Array[Vector3] = []
		for k in segs + 1:
			var a := PI * float(k) / segs
			arc.append(p - right * half_width * cos(a) + Vector3.UP * (wall_h + half_width * 0.85 * sin(a)))
		_rib(base_l, base_r, arc, wall_h)
		_mark_roof(p, right, half_width)
		if not prev.is_empty():
			_bay(prev, [base_l, base_r, arc], wall_h, missing, p + Vector3.UP * wall_h, catwalk)
		prev = [base_l, base_r, arc]
		d += spacing


## A straight wing from a to b (both on the ground), for wings away from roads.
func barrel_line(a: Vector3, b: Vector3, half_width: float, wall_h: float, spacing: float = 2.5,
		missing: float = 0.3) -> void:
	var c := Curve3D.new()
	c.add_point(a)
	c.add_point(b)
	barrel(c, false, 0.0, a.distance_to(b), half_width, wall_h, spacing, missing, false)


func _rib(base_l: Vector3, base_r: Vector3, arc: Array[Vector3], wall_h: float) -> void:
	for base in [base_l, base_r]:
		s.add_box("iron", Vector3(0.2, wall_h, 0.2), Transform3D(Basis.IDENTITY, base + Vector3.UP * wall_h * 0.5))
	for k in arc.size() - 1:
		_beam(arc[k], arc[k + 1], 0.16, 0.26)


## Between two ribs: mesh walls and rails each side, glass panes on the vault,
## purlins, and the ridge catwalk.
func _bay(a: Array, b: Array, wall_h: float, missing: float, inside: Vector3, catwalk: bool) -> void:
	for side in 2:
		var p0: Vector3 = a[side]
		var p1: Vector3 = b[side]
		mesh_panel(p0, p1, 0.0, wall_h)
		_beam(p0 + Vector3.UP * wall_h, p1 + Vector3.UP * wall_h, 0.14, 0.14)
	var arc_a: Array = a[2]
	var arc_b: Array = b[2]
	for k in arc_a.size() - 1:
		var roll := rng.randf()
		if roll >= missing:
			var key := "glass_old" if roll < missing + 0.14 else "glass"
			var c: Vector3 = (arc_a[k] + arc_b[k + 1]) * 0.5
			s._quad(s._st(key, c), arc_a[k], arc_a[k + 1], arc_b[k + 1], arc_b[k], inside)
		if k % 4 == 2:
			_beam(arc_a[k], arc_b[k], 0.08, 0.1)
	if catwalk:
		var top_a: Vector3 = arc_a[arc_a.size() / 2] + Vector3.UP * 0.2
		var top_b: Vector3 = arc_b[arc_b.size() / 2] + Vector3.UP * 0.2
		_beam(top_a, top_b, 1.2, 0.08)
		for side in [-1.0, 1.0]:
			var off: Vector3 = (top_b - top_a).cross(Vector3.UP).normalized() * 0.6 * side
			_beam(top_a + off + Vector3.UP * 1.0, top_b + off + Vector3.UP * 1.0, 0.05, 0.05)


func _mark_roof(p: Vector3, right: Vector3, half_width: float) -> void:
	var w := -half_width
	while w <= half_width:
		var c := p + right * w
		roof_cells[Vector2i(int(floor(c.x / ROOF_CELL)), int(floor(c.z / ROOF_CELL)))] = true
		w += ROOF_CELL * 0.5


# --- domes ------------------------------------------------------------------------

## A ribbed iron-and-glass dome on a circular mesh-walled base: wall posts
## round the rim (left out where a road passes, so the roads go through
## openings), a ring beam, meridian ribs and latitude rings, glass panes
## (some missing), then an upper drum, a small second dome and an open
## lantern with a finial. gallery: a railed walkway round the top of the
## main dome with an exterior staircase climbing to it (picture 3).
func dome(center: Vector3, radius: float, wall_h: float, rise: float, ribs: int = 48,
		missing: float = 0.28, gallery: bool = true) -> void:
	var top_r := radius * 0.3
	# Base wall: posts, mesh, rails, ring beam.
	var posts: Array = []
	for i in ribs:
		var ang := TAU * float(i) / ribs
		var p := center + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		posts.append(p if s.clear(p, 0.4) else null)
	for i in ribs:
		var p0: Variant = posts[i]
		var p1: Variant = posts[(i + 1) % ribs]
		var a0 := center + Vector3(cos(TAU * i / ribs) * radius, 0.0, sin(TAU * i / ribs) * radius)
		var a1 := center + Vector3(cos(TAU * (i + 1) / ribs) * radius, 0.0, sin(TAU * (i + 1) / ribs) * radius)
		_beam(a0 + Vector3.UP * wall_h, a1 + Vector3.UP * wall_h, 0.3, 0.4)
		if p0 != null:
			s.add_box("iron", Vector3(0.3, wall_h, 0.3), Transform3D(Basis.IDENTITY, (p0 as Vector3) + Vector3.UP * wall_h * 0.5))
		if p0 != null and p1 != null:
			mesh_panel(p0, p1, 0.0, wall_h)
			_beam((p0 as Vector3) + Vector3.UP * 1.2, (p1 as Vector3) + Vector3.UP * 1.2, 0.1, 0.1)
		else:
			# An opening: a lintel of mesh above the road.
			mesh_panel(a0, a1, wall_h - 2.0, wall_h)
	# Dome shell: latitude rows from the ring beam up to the drum.
	var rows := 7
	var shell: Array = []
	for k in rows + 1:
		var t := float(k) / rows
		var th := lerpf(0.0, acos(top_r / radius), t)
		var ring: Array[Vector3] = []
		for i in ribs:
			var ang := TAU * float(i) / ribs
			ring.append(center + Vector3(cos(ang) * radius * cos(th), wall_h + rise * sin(th), sin(ang) * radius * cos(th)))
		shell.append(ring)
	var inside := center + Vector3.UP * wall_h
	for k in rows:
		var r0: Array = shell[k]
		var r1: Array = shell[k + 1]
		for i in ribs:
			var j := (i + 1) % ribs
			_beam(r0[i], r1[i], 0.18, 0.28) # meridian rib
			if k > 0:
				_beam(r0[i], r0[j], 0.1, 0.14) # latitude ring
			var roll := rng.randf()
			if roll >= missing:
				var key := "glass_old" if roll < missing + 0.14 else "glass"
				var c: Vector3 = (r0[i] + r1[j]) * 0.5
				s._quad(s._st(key, c), r0[i], r0[j], r1[j], r1[i], inside)
	var top_y := wall_h + rise * sin(acos(top_r / radius))
	var top_c := center + Vector3.UP * top_y
	_ring(top_c, top_r, 0.3, 0.35, ribs / 2)
	# Upper drum, second small dome, open lantern and finial.
	var drum_h := maxf(2.5, rise * 0.18)
	var n2 := maxi(12, ribs / 3)
	for i in n2:
		var ang := TAU * float(i) / n2
		var p := top_c + Vector3(cos(ang) * top_r, 0.0, sin(ang) * top_r)
		_beam(p, p + Vector3.UP * drum_h, 0.14, 0.14)
		var q := top_c + Vector3(cos(TAU * (i + 1) / n2) * top_r, 0.0, sin(TAU * (i + 1) / n2) * top_r)
		mesh_panel(p, q, 0.0, drum_h)
	_ring(top_c + Vector3.UP * drum_h, top_r, 0.2, 0.25, n2)
	var cap_c := top_c + Vector3.UP * drum_h
	var cap_rise := top_r * 0.55
	for i in n2:
		var ang := TAU * float(i) / n2
		var prev := cap_c + Vector3(cos(ang) * top_r, 0.0, sin(ang) * top_r)
		for k in range(1, 5):
			var th := PI * 0.5 * float(k) / 4.0
			var r := top_r * cos(th)
			var pt := cap_c + Vector3(cos(ang) * r, cap_rise * sin(th), sin(ang) * r)
			_beam(prev, pt, 0.1, 0.12)
			prev = pt
	var lantern_c := cap_c + Vector3.UP * cap_rise
	var lr := top_r * 0.35
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := lantern_c + Vector3(cos(ang) * lr, 0.0, sin(ang) * lr)
		_beam(p, p + Vector3.UP * 2.6, 0.08, 0.08)
	_ring(lantern_c + Vector3.UP * 2.6, lr, 0.1, 0.1, 8)
	_ring(lantern_c + Vector3.UP * 1.3, lr, 0.06, 0.06, 8)
	s.add_cone("iron", lr, 1.6, Transform3D(Basis.IDENTITY, lantern_c + Vector3.UP * 2.6))
	_beam(lantern_c + Vector3.UP * 4.0, lantern_c + Vector3.UP * 9.0, 0.06, 0.06) # finial
	_mark_dome_roof(center, radius)
	if gallery:
		_gallery(center, radius, wall_h, rise, top_c, top_r, ribs)


## A railed walkway round the top of the dome and an exterior staircase
## climbing the shell to it (and a lower gallery round the ring beam).
func _gallery(center: Vector3, radius: float, wall_h: float, rise: float, top_c: Vector3, top_r: float, ribs: int) -> void:
	var outer := top_r + 1.6
	var n := maxi(16, ribs / 2)
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var p0 := top_c + Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var p1 := top_c + Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		_beam(p0, p1, 1.6, 0.08) # deck
		_beam(p0 + Vector3.UP * 1.0, p1 + Vector3.UP * 1.0, 0.05, 0.05)
		_beam(p0, p0 + Vector3.UP * 1.0, 0.05, 0.05)
	# Lower gallery round the ring beam.
	var low := radius + 0.9
	for i in ribs:
		var a0 := TAU * float(i) / ribs
		var a1 := TAU * float(i + 1) / ribs
		var p0 := center + Vector3(cos(a0) * low, wall_h + 0.3, sin(a0) * low)
		var p1 := center + Vector3(cos(a1) * low, wall_h + 0.3, sin(a1) * low)
		_beam(p0 + Vector3.UP * 1.0, p1 + Vector3.UP * 1.0, 0.05, 0.05)
		if i % 2 == 0:
			_beam(p0, p0 + Vector3.UP * 1.0, 0.05, 0.05)
	# Exterior staircase up the shell on one side (steps on stringers).
	var ang := deg_to_rad(35.0)
	var steps := 34
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for k in steps + 1:
		var t := float(k) / steps
		var th := lerpf(0.0, acos(top_r / radius), t)
		var r := radius * cos(th) + 1.2
		var y := wall_h + rise * sin(th) + 0.4
		var tangent := Vector3(-sin(ang), 0.0, cos(ang))
		var c := center + Vector3(cos(ang) * r, y, sin(ang) * r)
		var l := c - tangent * 0.7
		var rr := c + tangent * 0.7
		s.add_box("iron", Vector3(1.4, 0.06, 0.35), Transform3D(Basis.looking_at(Vector3(cos(ang), 0, sin(ang)), Vector3.UP), c))
		if k > 0:
			_beam(prev_l, l, 0.06, 0.18)
			_beam(prev_r, rr, 0.06, 0.18)
			_beam(prev_l + Vector3.UP * 0.9, l + Vector3.UP * 0.9, 0.04, 0.04)
			_beam(prev_r + Vector3.UP * 0.9, rr + Vector3.UP * 0.9, 0.04, 0.04)
		prev_l = l
		prev_r = rr


func _mark_dome_roof(center: Vector3, radius: float) -> void:
	var r := -radius
	while r <= radius:
		var w := -radius
		while w <= radius:
			if Vector2(r, w).length() < radius:
				var c := center + Vector3(r, 0.0, w)
				roof_cells[Vector2i(int(floor(c.x / ROOF_CELL)), int(floor(c.z / ROOF_CELL)))] = true
			w += ROOF_CELL * 0.5
		r += ROOF_CELL * 0.5


func _ring(c: Vector3, r: float, w: float, h: float, n: int) -> void:
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		_beam(c + Vector3(cos(a0) * r, 0.0, sin(a0) * r), c + Vector3(cos(a1) * r, 0.0, sin(a1) * r), w, h)


# --- wire mesh ------------------------------------------------------------------------

## A wire-mesh fence along a polyline (track-local, on the ground): iron posts
## every other panel (panels `spacing` metres wide) and mesh panels from h0
## to h1, with a top rail. Segments whose posts can't stand (on a
## road) are left out; `skip` (a Callable taking a point) leaves out others.
func fence(points: PackedVector3Array, h0: float, h1: float, spacing: float = 3.0, skip: Callable = Callable()) -> void:
	var posts: Array[Vector3] = []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / spacing))
		for k in n:
			posts.append(a.lerp(b, float(k) / n))
	if points.size() > 0:
		posts.append(points[points.size() - 1])
	for i in posts.size() - 1:
		var a := posts[i]
		var b := posts[i + 1]
		if skip.is_valid() and (skip.call(a) or skip.call(b)):
			continue
		mesh_panel(a, b, h0, h1)
		if i % 2 == 0:
			# A post every other panel, with the top rail over the next two.
			s.add_box("iron", Vector3(0.12, h1 + 0.25, 0.12), Transform3D(Basis.IDENTITY, a + Vector3.UP * (h1 + 0.25) * 0.5))
			var c := b if i + 2 >= posts.size() else posts[i + 2]
			_beam(a + Vector3.UP * h1, c + Vector3.UP * h1, 0.07, 0.07)


## A vertical wire-mesh panel between two ground points, from h0 to h1.
func mesh_panel(a: Vector3, b: Vector3, h0: float, h1: float) -> void:
	var key := Vector2i(int(floor(a.x / TrackScenery.CHUNK)), int(floor(a.z / TrackScenery.CHUNK)))
	if not _mesh_tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_mesh_tools[key] = st
	var st: SurfaceTool = _mesh_tools[key]
	var len := Vector2(b.x - a.x, b.z - a.z).length()
	# Continuous texture along the wall: u from world position.
	var u0 := (a.x + a.z) / MESH_TILE
	var u1 := u0 + len / MESH_TILE
	var v0 := h0 / MESH_TILE
	var v1 := h1 / MESH_TILE
	var p0 := Vector3(a.x, a.y + h0, a.z)
	var p1 := Vector3(b.x, b.y + h0, b.z)
	var p2 := Vector3(b.x, b.y + h1, b.z)
	var p3 := Vector3(a.x, a.y + h1, a.z)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var verts := [[p0, Vector2(u0, v1)], [p1, Vector2(u1, v1)], [p2, Vector2(u1, v0)],
			[p0, Vector2(u0, v1)], [p2, Vector2(u1, v0)], [p3, Vector2(u0, v0)]]
	for v in verts:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Builds the wire-mesh instances (call once, after everything is placed).
func commit() -> void:
	for key in _mesh_tools:
		s.add_mesh_instance((_mesh_tools[key] as SurfaceTool).commit(), mesh_material(), "WireMesh")
	_mesh_tools.clear()


# --- helpers ------------------------------------------------------------------------

## An iron beam from a to b, w wide and h deep: four sides, no end caps
## (they're never seen at these sizes), so 24 vertices instead of 36.
func _beam(a: Vector3, b: Vector3, w: float, h: float) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.01:
		return
	var fwd := dir / len
	var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(fwd, up)
	var x := basis.x * w * 0.5
	var y := basis.y * h * 0.5
	var mid := (a + b) * 0.5
	var st := s._st("iron", mid)
	var corners := [x + y, -x + y, -x - y, x - y]
	for i in 4:
		var c0: Vector3 = corners[i]
		var c1: Vector3 = corners[(i + 1) % 4]
		s._quad(st, a + c0, a + c1, b + c1, b + c0, mid)
