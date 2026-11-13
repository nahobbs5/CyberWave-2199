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

const TEXTURES := "res://assets/textures/polyhaven/%s/%s_%s_1k.jpg"

const ROAD_CELL := 40.0
## Scenery batch chunk size (m).
const CHUNK := 250.0
## Cast shadows from scenery (off by default; interiors with sun shafts turn it on).
@export var cast_shadows: bool = false
## Material keys that never cast shadows even when cast_shadows is on (glass).
var no_shadow_keys: Array[String] = []

var _batches: Dictionary = {}
## Spatial index of road samples: Vector2i cell -> PackedFloat32Array of
## (x, z, half_width, y) per sample, for fast clear() / edge_distance() /
## road_y_at() queries.
var _road_cells: Dictionary = {}
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
	_build_road_index()
	await build()
	_commit()


## Subclasses dress the track here. Long builds call step() between parts.
func build() -> void:
	await step(1.0)


## Set by the loading screen while it builds a track: called with how far
## through build() this set is (0-1) and awaited, so the progress bar can be
## drawn part-way. Unset (the normal case), step() returns at once and the
## whole build runs in one go.
static var stepper: Callable


func step(share: float) -> void:
	if stepper.is_valid():
		await stepper.call(share)


# --- placement helpers ---------------------------------------------------------

## Transform (track-local) at a distance along the main road, lateral metres right.
func at(offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	return track.global_transform.affine_inverse() * track.get_safe_transform(offset, lateral, height)


## True if a disc at a track-local point is clear of every road and barrier.
func clear(local_pos: Vector3, radius: float) -> bool:
	return edge_distance(local_pos) > track.barrier_thickness + 1.0 + radius


## Metres from a track-local point to the nearest road edge (main loop or
## shortcut); negative on a road. Capped at about ROAD_CELL when far away.
func edge_distance(local_pos: Vector3) -> float:
	var cx := int(floor(local_pos.x / ROAD_CELL))
	var cz := int(floor(local_pos.z / ROAD_CELL))
	var best := ROAD_CELL * 1.5
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell: PackedFloat32Array = _road_cells.get(Vector2i(cx + dx, cz + dz), PackedFloat32Array())
			var i := 0
			while i < cell.size():
				var ex := local_pos.x - cell[i]
				var ez := local_pos.z - cell[i + 1]
				var d := sqrt(ex * ex + ez * ez) - cell[i + 2]
				if d < best:
					best = d
				i += 4
	return best


## Height (track-local y) of the road nearest a point by horizontal
## distance (main loop or shortcut), searching about 100 m round it; 0 if
## no road is that close. Sloped tracks dress their ground with it.
func road_y_at(local_pos: Vector3) -> float:
	var cx := int(floor(local_pos.x / ROAD_CELL))
	var cz := int(floor(local_pos.z / ROAD_CELL))
	var best := INF
	var y := 0.0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell: PackedFloat32Array = _road_cells.get(Vector2i(cx + dx, cz + dz), PackedFloat32Array())
			var i := 0
			while i < cell.size():
				var ex := local_pos.x - cell[i]
				var ez := local_pos.z - cell[i + 1]
				var d := ex * ex + ez * ez
				if d < best:
					best = d
					y = cell[i + 3]
				i += 4
	return y


func _build_road_index() -> void:
	_road_cells.clear()
	_index_curve(track.curve, track.road_width * 0.5)
	for sc in track.shortcuts:
		_index_curve(sc.curve, sc.road_width * 0.5)


func _index_curve(curve: Curve3D, half: float) -> void:
	var length := curve.get_baked_length()
	var d := 0.0
	while d <= length:
		var p := curve.sample_baked(d)
		var key := Vector2i(int(floor(p.x / ROAD_CELL)), int(floor(p.z / ROAD_CELL)))
		var cell: PackedFloat32Array = _road_cells.get(key, PackedFloat32Array())
		cell.append(p.x)
		cell.append(p.z)
		cell.append(half)
		cell.append(p.y)
		_road_cells[key] = cell
		d += 2.5


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


## Rippling still water (assets/shaders/standing_water.gdshader) for puddles,
## pools and ponds. Patterns are in world space, so any mesh works.
static func water_material(deep: Color, shallow: Color, opacity: float = 0.75, rain_rings: float = 0.0,
		murk: float = 0.35, glint: float = 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/standing_water.gdshader")
	m.set_shader_parameter("deep_color", deep)
	m.set_shader_parameter("shallow_color", shallow)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("rain_rings", rain_rings)
	m.set_shader_parameter("murk", murk)
	m.set_shader_parameter("glint", glint)
	return m


## Registers a material using a Poly Haven texture set (CC0, see README),
## mapped triplanar in world space so generated geometry needs no UVs.
## tint multiplies the texture; metres_per_tile sets its scale.
func textured(key: String, texture_name: String, tint: Color = Color.WHITE, metres_per_tile: float = 4.0,
		roughness: float = 0.85, metallic: float = 0.0) -> void:
	if _materials.has(key):
		return
	_materials[key] = texture_material(texture_name, tint, metres_per_tile, roughness, metallic)


## Adds a steady glow to a registered StandardMaterial3D (e.g. a textured
## material that should still read in the dark, as its plain one did).
func add_glow(key: String, color: Color, energy: float) -> void:
	var m := _materials.get(key) as StandardMaterial3D
	if m == null or energy <= 0.0:
		return
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy


## Set by the loading screen while it builds a track: texture files then load
## on worker threads while the geometry is built, and finish_textures() fills
## them into their materials. Off, textures load right away.
static var async_textures: bool = false
## Texture path -> [[material, property], ...] waiting for a threaded load.
static var _pending_textures: Dictionary = {}


## Puts a texture on a StandardMaterial3D property or a ShaderMaterial
## uniform (now, or when its threaded load finishes).
static func _set_texture(m: Material, property: StringName, path: String) -> void:
	if not async_textures or ResourceLoader.has_cached(path):
		_apply_texture(m, property, load(path) as Texture2D)
		return
	if not _pending_textures.has(path):
		if ResourceLoader.load_threaded_request(path, "", true) != OK:
			_apply_texture(m, property, load(path) as Texture2D)
			return
		_pending_textures[path] = []
	(_pending_textures[path] as Array).append([m, property])


static func _apply_texture(m: Material, property: StringName, texture: Texture2D) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(property, texture)
	else:
		m.set(property, texture)


## Sets a shader's "<prefix>_albedo" and "<prefix>_normal" uniforms from a
## Poly Haven set (the normal map only if present: the web build leaves
## them out).
static func shader_textures(m: ShaderMaterial, prefix: String, texture_name: String, albedo: bool = true) -> void:
	if albedo:
		_set_texture(m, StringName("%s_albedo" % prefix), TEXTURES % [texture_name, texture_name, "diff"])
	var nor := TEXTURES % [texture_name, texture_name, "nor"]
	if ResourceLoader.exists(nor):
		_set_texture(m, StringName("%s_normal" % prefix), nor)


## Turns on a procedural shader's Poly Haven detail (shaders including
## detail_common.gdshaderinc): grain strength, the texture's average linear
## brightness (so the grain keeps the colour's overall level), normal-map
## strength and metres per tile.
static func shader_detail(m: ShaderMaterial, texture_name: String, tile: float, strength: float,
		mean: float, normal_strength: float) -> void:
	# Normal-only detail skips loading the albedo map.
	shader_textures(m, "detail", texture_name, strength > 0.0)
	m.set_shader_parameter("detail_tile", tile)
	m.set_shader_parameter("detail_strength", strength)
	m.set_shader_parameter("detail_mean", mean)
	m.set_shader_parameter("detail_normal_strength", normal_strength)


## Share of the queued texture loads that are done (1 when none are queued).
static func texture_progress() -> float:
	if _pending_textures.is_empty():
		return 1.0
	var total := 0.0
	var progress := []
	for path in _pending_textures:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not progress.is_empty():
			total += float(progress[0])
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			total += 1.0
	return total / _pending_textures.size()


## Waits for every queued texture and puts it on its materials.
static func finish_textures() -> void:
	for path in _pending_textures:
		var texture := ResourceLoader.load_threaded_get(path) as Texture2D
		for entry in _pending_textures[path]:
			_apply_texture(entry[0] as Material, entry[1], texture)
	_pending_textures.clear()


static func texture_material(texture_name: String, tint: Color = Color.WHITE, metres_per_tile: float = 4.0,
		roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	_set_texture(m, &"albedo_texture", TEXTURES % [texture_name, texture_name, "diff"])
	# The web build leaves the normal and roughness maps out (download size).
	var normal_path := TEXTURES % [texture_name, texture_name, "nor"]
	if ResourceLoader.exists(normal_path):
		m.normal_enabled = true
		_set_texture(m, &"normal_texture", normal_path)
	var rough_path := TEXTURES % [texture_name, texture_name, "rough"]
	if ResourceLoader.exists(rough_path):
		_set_texture(m, &"roughness_texture", rough_path)
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / maxf(metres_per_tile, 0.01)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func get_material(key: String) -> Material:
	return _materials.get(key)


## Registers a ready-made material under a key (e.g. alpha-tested fencing).
func register_material(key: String, mat: Material) -> void:
	_materials[key] = mat


## A mesh built outside the batches (e.g. terrain), added under the scenery.
func add_mesh_instance(mesh: Mesh, mat: Material, node_name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


## A flickering lamp (see FlickerLight). If glow_key names a registered
## material, that material's glow flickers with it (dying neon, bulbs).
func add_flicker_light(pos: Vector3, color: Color, energy: float, light_range: float,
		failing: float = 0.35, glow_key: String = "") -> FlickerLight:
	var light := FlickerLight.new()
	light.position = pos
	light.light_color = color
	light.base_energy = energy
	light.omni_range = light_range
	light.failing = failing
	if glow_key != "" and _materials.has(glow_key):
		light.material = _materials[glow_key]
	_root.add_child(light)
	return light


## Batches are split per material AND per CHUNK-metre square, so the renderer
## can cull what's off screen and lights only touch nearby geometry.
func _st(key: String, at: Vector3 = Vector3.ZERO) -> SurfaceTool:
	var batch_key := "%s@%d,%d" % [key, int(floor(at.x / CHUNK)), int(floor(at.z / CHUNK))]
	if not _batches.has(batch_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[batch_key] = st
	return _batches[batch_key]


# --- geometry ------------------------------------------------------------------

func add_box(key: String, size: Vector3, xf: Transform3D) -> void:
	var st := _st(key, xf.origin)
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], xf.origin)


## Vertical cylinder standing on xf.origin.
func add_cyl(key: String, radius: float, height: float, xf: Transform3D, segments: int = 10,
		top_radius: float = -1.0) -> void:
	var st := _st(key, xf.origin)
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
	var st := _st(key, xf.origin)
	var top := xf * Vector3(0, height, 0)
	var c := xf * Vector3(0, height * 0.3, 0)
	var b := [xf * Vector3(-half_base, 0, -half_base), xf * Vector3(half_base, 0, -half_base),
			xf * Vector3(half_base, 0, half_base), xf * Vector3(-half_base, 0, half_base)]
	for i in 4:
		_tri(st, b[i], b[(i + 1) % 4], top, c)


func add_sphere(key: String, radius: float, xf: Transform3D, rings: int = 6, segments: int = 10) -> void:
	var st := _st(key, xf.origin)
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
	var st := _st(key, xf.origin)
	var a := xf * Vector3(-w * 0.5, 0, 0)
	var b := xf * Vector3(w * 0.5, 0, 0)
	var c := xf * Vector3(w * 0.5, h, 0)
	var d := xf * Vector3(-w * 0.5, h, 0)
	_quad(st, a, b, c, d, xf * Vector3(0, h * 0.5, -1.0))


## One quad (track-local corners in order); `inside` is a point behind it,
## so the normal faces away from it.
func add_quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_quad(_st(key, (a + c) * 0.5), a, b, c, d, inside)


## Convex polygon (local XY, counter-clockwise or not) extruded `depth`
## along local Z, centred on xf: trapezoid jambs, gable ends, piers.
func add_prism(key: String, poly: PackedVector2Array, depth: float, xf: Transform3D) -> void:
	var st := _st(key, xf.origin)
	var n := poly.size()
	var front := []
	var back := []
	var c2 := Vector2.ZERO
	for p in poly:
		front.append(xf * Vector3(p.x, p.y, -depth * 0.5))
		back.append(xf * Vector3(p.x, p.y, depth * 0.5))
		c2 += p
	c2 /= n
	var inside := xf * Vector3(c2.x, c2.y, 0.0)
	for i in range(1, n - 1):
		_tri(st, front[0], front[i], front[i + 1], inside)
		_tri(st, back[0], back[i], back[i + 1], inside)
	for i in n:
		var j := (i + 1) % n
		_quad(st, front[i], front[j], back[j], back[i], inside)


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
	for batch_key in _batches:
		var key: String = batch_key.get_slice("@", 0)
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + batch_key.replace(",", "_")
		mi.mesh = (_batches[batch_key] as SurfaceTool).commit()
		mi.material_override = _materials.get(key)
		var shadows := cast_shadows and not no_shadow_keys.has(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mi)
	_batches.clear()
