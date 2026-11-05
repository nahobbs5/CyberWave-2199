@tool
class_name TrackScenery
extends Node3D
## Base for a track's procedural set dressing (Phase 6 environments). Add a
## subclass as a child of the TrackCircuit; it builds when the track does
## (place_on_track) and in the editor too.
##
## Geometry goes through add_box / add_cyl / add_cone / add_mesh_tris into
## batches merged by material, so a whole city is a handful of draw calls.
## Scenery is visual only: the barriers keep cars on the road. Use clear() to
## skip anything that would overlap a road.

## Changing this rerolls the random dressing.
@export var random_seed: int = 2199

var track: TrackCircuit
var rng := RandomNumberGenerator.new()

var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _root: Node3D


func place_on_track(p_track: TrackCircuit) -> void:
	track = p_track
	rng.seed = random_seed
	for child in get_children():
		child.queue_free()
	_batches.clear()
	_materials.clear()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)
	build()
	_commit()


## Subclasses dress the track here.
func build() -> void:
	pass


# --- placement helpers ---------------------------------------------------------

## Transform (track-local) at a distance along the main road, lateral metres right.
func at(offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	return track.global_transform.affine_inverse() * track.get_safe_transform(offset, lateral, height)


## True if a disc at a track-local point is clear of every road and barrier.
func clear(local_pos: Vector3, radius: float) -> bool:
	var world := track.to_global(local_pos)
	return track.get_lateral_distance(world) > track.road_width * 0.5 + track.barrier_thickness + 1.0 + radius


## Clear test for a rectangle footprint (checks centre, corners and edge midpoints).
func clear_rect(xf: Transform3D, size_x: float, size_z: float) -> bool:
	var hx := size_x * 0.5
	var hz := size_z * 0.5
	for p in [Vector3.ZERO, Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
			Vector3(hx, 0, 0), Vector3(-hx, 0, 0), Vector3(0, 0, hz), Vector3(0, 0, -hz)]:
		if not clear(xf * p, 0.5):
			return false
	return true


func xform(pos: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


# --- materials -----------------------------------------------------------------

## Registers a material under a key (call before adding geometry with it).
func material(key: String, color: Color, emission: float = 0.0, metallic: float = 0.0,
		roughness: float = 0.8, transparent: bool = false) -> void:
	if _materials.has(key):
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m


func _st(key: String) -> SurfaceTool:
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
	return _batches[key]


# --- geometry ------------------------------------------------------------------

func add_box(key: String, size: Vector3, xf: Transform3D) -> void:
	var st := _st(key)
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], xf.origin)


## Vertical cylinder standing on xf.origin.
func add_cyl(key: String, radius: float, height: float, xf: Transform3D, segments: int = 10,
		top_radius: float = -1.0) -> void:
	var st := _st(key)
	var r2 := radius if top_radius < 0.0 else top_radius
	var c := xf * Vector3(0, height * 0.5, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var b0 := xf * Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var b1 := xf * Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var t0 := xf * Vector3(cos(a0) * r2, height, sin(a0) * r2)
		var t1 := xf * Vector3(cos(a1) * r2, height, sin(a1) * r2)
		_quad(st, b0, b1, t1, t0, c)
		if r2 > 0.001:
			_tri(st, xf * Vector3(0, height, 0), t0, t1, c)


func add_cone(key: String, radius: float, height: float, xf: Transform3D, segments: int = 8) -> void:
	add_cyl(key, radius, height, xf, segments, 0.0)


## Square pyramid standing on xf.origin.
func add_pyramid(key: String, half_base: float, height: float, xf: Transform3D) -> void:
	var st := _st(key)
	var top := xf * Vector3(0, height, 0)
	var c := xf * Vector3(0, height * 0.3, 0)
	var b := [xf * Vector3(-half_base, 0, -half_base), xf * Vector3(half_base, 0, -half_base),
			xf * Vector3(half_base, 0, half_base), xf * Vector3(-half_base, 0, half_base)]
	for i in 4:
		_tri(st, b[i], b[(i + 1) % 4], top, c)


func add_sphere(key: String, radius: float, xf: Transform3D, rings: int = 6, segments: int = 10) -> void:
	var st := _st(key)
	for r in rings:
		var p0 := PI * r / rings
		var p1 := PI * (r + 1) / rings
		for sgm in segments:
			var a0 := TAU * sgm / segments
			var a1 := TAU * (sgm + 1) / segments
			var v := func(p: float, a: float) -> Vector3: return xf * Vector3(sin(p) * cos(a) * radius, cos(p) * radius, sin(p) * sin(a) * radius)
			_quad(st, v.call(p0, a0), v.call(p0, a1), v.call(p1, a1), v.call(p1, a0), xf.origin)


## Flat quad (both sides visible): w x h in the local XY plane.
func add_panel(key: String, w: float, h: float, xf: Transform3D) -> void:
	var st := _st(key)
	var a := xf * Vector3(-w * 0.5, 0, 0)
	var b := xf * Vector3(w * 0.5, 0, 0)
	var c := xf * Vector3(w * 0.5, h, 0)
	var d := xf * Vector3(-w * 0.5, h, 0)
	_quad(st, a, b, c, d, xf * Vector3(0, h * 0.5, -1.0))


## Observation / Ferris wheel standing at `base`, turning in the YZ plane:
## rim segments, spokes, cabins, a hub and two A-frame legs.
func add_ferris_wheel(base: Vector3, radius: float, rim_key: String, frame_key: String,
		cabin_key: String, hub_key: String) -> void:
	var center := base + Vector3(0, radius + 8.0, 0)
	var segments := 36
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := center + Vector3(0, cos(a0) * radius, sin(a0) * radius)
		var p1 := center + Vector3(0, cos(a1) * radius, sin(a1) * radius)
		var seg := Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.RIGHT), (p0 + p1) * 0.5)
		add_box(rim_key, Vector3(1.2, 1.2, (p1 - p0).length()), seg)
		if i % 3 == 0:
			var spoke := Transform3D(Basis.looking_at((p0 - center).normalized(), Vector3.RIGHT), (center + p0) * 0.5)
			add_box(frame_key, Vector3(0.4, 0.4, radius), spoke)
			add_box(cabin_key, Vector3(3.0, 3.0, 4.0), xform(p0 + Vector3(2.5, -2.0, 0)))
	add_cyl(hub_key, 4.0, 6.0, xform(center + Vector3(-3, 0, 0)).rotated_local(Vector3.FORWARD, PI * 0.5), 10)
	for side in [-1.0, 1.0]:
		var foot := base + Vector3(0, 0, side * radius * 0.57)
		var dir := center - foot
		add_box(frame_key, Vector3(3.0, 3.0, dir.length()),
				Transform3D(Basis.looking_at(dir.normalized(), Vector3.RIGHT), (foot + center) * 0.5))


## Palm tree: leaning trunk and a crown of seven fronds.
func add_palm(pos: Vector3, h: float, trunk_key: String, leaf_key: String) -> void:
	var lean := rng.randf_range(-0.08, 0.08)
	var base := Transform3D(Basis(Vector3.FORWARD, lean), pos)
	add_cyl(trunk_key, 0.35, h, base, 6, 0.25)
	var top := base * Vector3(0, h, 0)
	for i in 7:
		var yaw := TAU * i / 7.0 + rng.randf() * 0.3
		var leaf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.35), top)
		add_box(leaf_key, Vector3(0.9, 0.12, 5.0), leaf.translated_local(Vector3(0, 0, -2.4)))


## A text sign (Label3D, not batched).
func add_text(text: String, xf: Transform3D, color: Color, pixel: float = 0.06, font_size: int = 96) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.transform = xf
	label.modulate = color
	label.pixel_size = pixel
	label.font_size = font_size
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.6)
	label.double_sided = true
	_root.add_child(label)
	return label


func add_light(pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	_root.add_child(light)
	return light


func add_node(node: Node) -> void:
	_root.add_child(node)


# --- internals -----------------------------------------------------------------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
		var t := b
		b = c
		c = t
	for v in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_tri(st, a, b, c, inside)
	_tri(st, a, c, d, inside)


func _commit() -> void:
	for key in _batches:
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + key
		mi.mesh = (_batches[key] as SurfaceTool).commit()
		mi.material_override = _materials.get(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mi)
	_batches.clear()
