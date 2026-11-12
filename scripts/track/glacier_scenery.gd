@tool
class_name GlacierScenery
extends TrackScenery
## Vatnajokull Glacier (GDD 8.7): a race through an ice cave under Europe's
## biggest glacier, Iceland. Roomy and bright, not cramped: one continuous
## cave of blue, white and ash-striped ice that opens up and closes in along
## the lap, lit mostly by daylight glowing through the ice. In driving order:
## the Glacier Mouth (the start, with a huge opening to daylight beside the
## grid); the Blue Cathedral (a vast swirling hall with a meltwater stream);
## the Icicle Gallery (lower and lined with icicle curtains and ice columns);
## Moulin Hall (meltwater holes in the roof letting in shafts of sky light,
## snow drifts below); the Ash Canyon (a tall gorge striped with volcanic
## ash); and the Frozen Lake (a glassy lake under hanging ice chandeliers).
## The shortcut is the Crystal Tube: a narrow, glowing round tunnel of
## scalloped ice with white light at its far end. Positions are layout
## coordinates matching vatnajokull_glacier.tscn.

const ICE_SHADER := preload("res://assets/shaders/glacier_ice.gdshader")

## Zone starts (layout points on the main road), in driving order, with the
## cave's shape there. Walls are metres beyond the road edge.
const MOUTH_FROM := Vector3(-330, 0, -8)
const CATHEDRAL_FROM := Vector3(400, 0, 5)
const GALLERY_FROM := Vector3(475, 0, 640)
const MOULIN_FROM := Vector3(66, 0, 640)
const CANYON_FROM := Vector3(-396, 0, 650)
const LAKE_FROM := Vector3(-473, 0, 187)
## Skylights (moulins) per Moulin Hall.
const SKYLIGHTS := 5
const ICICLE_CHUNK := 100.0
const ROOF_CELL := 2.0
## Icicles over a road never hang lower than this.
const ROAD_CLEARANCE := 7.5
## Blend between zone shapes over this many metres.
const BLEND := 60.0

## Zone shapes: left / right wall beyond the road edge, roof height, noise,
## material, icicles per 3 m section, chance of a big fang, ice columns, and
## the longest icicle.
const ZONES := {
	"mouth": {"left": 30.0, "right": 16.0, "crown": 26.0, "rough": 1.0, "key": "ice", "icicles": 7.0, "fangs": 0.05, "pillars": 0.0, "max_len": 5.0},
	"cathedral": {"left": 18.0, "right": 24.0, "crown": 36.0, "rough": 1.5, "key": "ice", "icicles": 8.0, "fangs": 0.25, "pillars": 0.0, "max_len": 6.0},
	"gallery": {"left": 12.0, "right": 12.0, "crown": 15.0, "rough": 0.8, "key": "ice", "icicles": 24.0, "fangs": 0.0, "pillars": 0.12, "max_len": 10.0},
	"moulin": {"left": 16.0, "right": 16.0, "crown": 24.0, "rough": 1.0, "key": "ice", "icicles": 8.0, "fangs": 0.08, "pillars": 0.03, "max_len": 6.0},
	"canyon": {"left": 11.0, "right": 11.0, "crown": 34.0, "rough": 1.2, "key": "ice_ash", "icicles": 5.0, "fangs": 0.1, "pillars": 0.0, "max_len": 5.0},
	"lake": {"left": 34.0, "right": 14.0, "crown": 22.0, "rough": 1.0, "key": "ice", "icicles": 7.0, "fangs": 0.04, "pillars": 0.0, "max_len": 5.0},
}
const ZONE_ORDER := ["mouth", "cathedral", "gallery", "moulin", "canyon", "lake"]

## Zone name -> start offset on the main road (set in build()).
var zone_offsets: Dictionary = {}
var skylights: int = 0
## Every icicle's tip (track-local), kept for tests: headless runs don't store
## MultiMesh transforms.
var icicle_tips: PackedVector3Array = PackedVector3Array()
## Lowest roof point above the road centre at the start line (tests).
var start_roof_height: float = 0.0

var _icicles: Dictionary = {}
var _icicle_mesh: ArrayMesh
var _roof: Dictionary = {}
var _glow: Array[Vector4] = []
var _mouth_from: float = 0.0
var _mouth_to: float = 0.0
var _zone_list: Array = []
var _cave: CaveShellBuilder


func build() -> void:
	_icicles.clear()
	_roof.clear()
	_glow.clear()
	icicle_tips.clear()
	skylights = 0
	_setup_materials()
	var starts := [MOUTH_FROM, CATHEDRAL_FROM, GALLERY_FROM, MOULIN_FROM, CANYON_FROM, LAKE_FROM]
	_zone_list.clear()
	for i in ZONE_ORDER.size():
		zone_offsets[ZONE_ORDER[i]] = _off(starts[i])
		_zone_list.append([zone_offsets[ZONE_ORDER[i]], ZONE_ORDER[i]])
	# The daylight mouth: beside the grid and the first stretch after the line.
	_mouth_from = track.wrap_offset(track.start_line_offset - 120.0)
	_mouth_to = track.wrap_offset(track.start_line_offset + 130.0)

	var cave := CaveShellBuilder.new(self, null, random_seed)
	_cave = cave
	cave.dims = _dims
	cave.on_roof = mark_roof
	cave.on_section = _dress_section
	cave.min_clear = 10.0
	await step(0.05)
	cave.build(0.0, 0.0)
	var h := track.road_width * 0.5
	start_roof_height = _roof_over_road(cave, track.start_line_offset, h)
	await step(0.45)
	_mouth()
	_cathedral_stream()
	await step(0.55)
	_moulins(cave)
	_frozen_lake()
	await step(0.65)
	_floor_dressing()
	_cave_lights()
	await step(0.75)
	if not track.shortcuts.is_empty():
		_crystal_tube(track.shortcuts[0])
	await step(0.9)
	_apply_glow()
	_commit_icicles()


func _off(p: Vector3) -> float:
	return track.curve.get_closest_offset(p)


# --- cave shape -------------------------------------------------------------------------

## Cave shape at a main-road distance, blended between zones.
func _dims(d: float) -> Dictionary:
	var h := track.road_width * 0.5
	var idx := _zone_at(d)
	var cur: Dictionary = ZONES[_zone_list[idx][1]]
	var prev: Dictionary = ZONES[_zone_list[(idx - 1 + _zone_list.size()) % _zone_list.size()][1]]
	var into := fposmod(d - float(_zone_list[idx][0]), track.length)
	var t := smoothstep(0.0, BLEND, into)
	var out := {}
	for k in ["left", "right", "crown", "rough", "icicles", "fangs", "pillars", "max_len"]:
		out[k] = lerpf(float(prev[k]), float(cur[k]), t)
	out["left_wall"] = h + float(out["left"])
	out["right_wall"] = h + float(out["right"])
	out["key"] = cur["key"]
	out["zone"] = _zone_list[idx][1]
	out["open_left"] = _in_mouth(d)
	out["open_h"] = 18.0
	return out


func _zone_at(d: float) -> int:
	var best := 0
	var best_into := INF
	for i in _zone_list.size():
		var into := fposmod(d - float(_zone_list[i][0]), track.length)
		if into < best_into:
			best_into = into
			best = i
	return best


func _in_mouth(d: float) -> bool:
	return fposmod(d - _mouth_from, track.length) <= fposmod(_mouth_to - _mouth_from, track.length)


func _roof_over_road(cave: CaveShellBuilder, d: float, h: float) -> float:
	var pr := cave.profile(d, _dims(d), h)
	var low := INF
	for p in pr:
		if absf(p.x) <= h and p.y > 0.0:
			low = minf(low, p.y)
	return low


# --- roof map (tests check the whole lap is under the ice) ------------------------------

func mark_roof(f: Transform3D, from_lateral: float, to_lateral: float) -> void:
	var along := 0.0
	while along <= CaveShellBuilder.STEP:
		var lat := from_lateral
		while lat <= to_lateral:
			var p := f * Vector3(lat, 0, -along)
			_roof[Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL)))] = true
			lat += 1.0
		along += 1.0


## True if a track-local point is under the ice.
func is_roofed(p: Vector3) -> bool:
	return _roof.has(Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL))))


# --- materials ---------------------------------------------------------------------------

func _setup_materials() -> void:
	register_material("ice", _ice_material(0.45, 0.06, 0.35))
	var ash := _ice_material(0.9, 0.05, 0.3)
	ash.set_shader_parameter("deep_color", Color(0.02, 0.1, 0.26))
	register_material("ice_ash", ash)
	var tube := _ice_material(0.15, 0.13, 0.9)
	tube.set_shader_parameter("mid_color", Color(0.2, 0.7, 1.0))
	register_material("ice_tube", tube)
	material("snow", Color(0.88, 0.93, 1.0), 0.25, 0.0, 0.9)
	material("basalt", Color(0.06, 0.065, 0.075), 0.0, 0.0, 0.7)
	material("daylight", Color(0.85, 0.93, 1.0), 2.6)
	material("sky_hole", Color(0.85, 0.94, 1.0), 6.0)
	var melt := StandardMaterial3D.new()
	melt.albedo_color = Color(0.02, 0.07, 0.1)
	melt.metallic = 0.6
	melt.roughness = 0.03
	register_material("melt", melt)
	var lake := StandardMaterial3D.new()
	lake.albedo_color = Color(0.35, 0.6, 0.78)
	lake.metallic = 0.35
	lake.roughness = 0.02
	lake.emission_enabled = true
	lake.emission = Color(0.1, 0.35, 0.55)
	lake.emission_energy_multiplier = 0.6
	register_material("lake", lake)


func _ice_material(ash_amount: float, scale: float, base_glow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ICE_SHADER
	m.set_shader_parameter("ash_amount", ash_amount)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("base_glow", base_glow)
	return m


## Where daylight glows through the ice (mouth, skylights, tube ends).
func _add_glow(p: Vector3, reach: float) -> void:
	if _glow.size() < 12:
		_glow.append(Vector4(p.x, p.y, p.z, reach))


func _apply_glow() -> void:
	var arr := PackedVector4Array()
	for g in _glow:
		arr.append(g)
	while arr.size() < 12:
		arr.append(Vector4(0, -1000, 0, 1))
	for key in ["ice", "ice_ash", "ice_tube"]:
		var m := get_material(key) as ShaderMaterial
		m.set_shader_parameter("glow_points", arr)
		m.set_shader_parameter("glow_count", _glow.size())


# --- icicles, fangs and ice columns -----------------------------------------------------

## Called for every cave section: hangs icicles from the real ceiling and
## stands ice columns where the roof comes low enough.
func _dress_section(f: Transform3D, pr: PackedVector2Array, d: float, dm: Dictionary) -> void:
	var count := float(dm.get("icicles", 6.0))
	var n := int(count) + (1 if rng.randf() < fmod(count, 1.0) else 0)
	var crown := float(dm.get("crown", 15.0))
	var max_len := float(dm.get("max_len", 5.0))
	for i in n:
		var seg := rng.randi_range(1, pr.size() - 3)
		var a := pr[seg]
		var b := pr[seg + 1]
		if minf(a.y, b.y) < 4.0:
			continue
		var p := a.lerp(b, rng.randf())
		var along := -rng.randf_range(0.0, CaveShellBuilder.STEP)
		var top := f * Vector3(p.x, p.y - 0.1, along)
		var length := lerpf(0.4, max_len, pow(rng.randf(), 2.2))
		var radius := 0.05 + 0.05 * length * rng.randf_range(0.6, 1.2)
		if rng.randf() < float(dm.get("fangs", 0.0)) and p.y > crown * 0.6:
			length = rng.randf_range(4.0, 11.0)
			radius = rng.randf_range(0.5, 1.2)
		_hang(top, length, radius)
	if rng.randf() < float(dm.get("pillars", 0.0)):
		_column(f, pr, dm)


## Hangs one icicle with its top at `top` (kept clear above any road).
func _hang(top: Vector3, length: float, radius: float) -> void:
	var ground := Vector3(top.x, 0, top.z)
	var lowest := ROAD_CLEARANCE if edge_distance(ground) < 2.0 else 0.6
	length = minf(length, top.y - lowest)
	if length < 0.3:
		return
	radius = minf(radius, length * 0.3)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius, length, radius))
	var xf := Transform3D(basis, top)
	var key := Vector2i(int(floor(top.x / ICICLE_CHUNK)), int(floor(top.z / ICICLE_CHUNK)))
	if not _icicles.has(key):
		_icicles[key] = []
	(_icicles[key] as Array).append(xf)
	icicle_tips.append(top - Vector3(0, length, 0))


func icicle_count() -> int:
	return icicle_tips.size()


## An hourglass ice column from floor to roof, beside the road.
func _column(f: Transform3D, pr: PackedVector2Array, dm: Dictionary) -> void:
	var h := track.road_width * 0.5
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var wall := float(dm.get("left_wall" if side < 0.0 else "right_wall", h + 10.0))
	if wall - h < 8.0:
		return
	var lat := side * rng.randf_range(h + 4.5, wall - 3.0)
	var top := _ceiling_at(pr, lat)
	if top < 5.0 or top > 20.0:
		return
	var base := f.translated_local(Vector3(lat, 0, -1.5))
	if not clear(base.origin, 1.8):
		return
	var waist := top * rng.randf_range(0.45, 0.6)
	add_cyl("ice", rng.randf_range(1.1, 1.6), waist, base, 9, 0.45)
	add_cyl("ice", 0.45, top - waist + 0.5, base.translated_local(Vector3(0, waist, 0)), 9, rng.randf_range(1.2, 1.9))


## Roof height above a lateral position in a cross-section (0 if none).
func _ceiling_at(pr: PackedVector2Array, lat: float) -> float:
	var best := 0.0
	for i in pr.size() - 1:
		var a := pr[i]
		var b := pr[i + 1]
		if (a.x - lat) * (b.x - lat) <= 0.0 and absf(b.x - a.x) > 0.001:
			var y := lerpf(a.y, b.y, (lat - a.x) / (b.x - a.x))
			best = maxf(best, y)
	return best


func _commit_icicles() -> void:
	if _icicle_mesh == null:
		_icicle_mesh = _build_icicle_mesh()
	for key: Vector2i in _icicles:
		var list: Array = _icicles[key]
		var centre := Vector3((key.x + 0.5) * ICICLE_CHUNK, 0, (key.y + 0.5) * ICICLE_CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _icicle_mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, (list[i] as Transform3D).translated(-centre))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Icicles_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 170.0 + ICICLE_CHUNK * 0.71
		add_node(mmi)
	_icicles.clear()


## One icicle: radius 1 at the top (y = 0) tapering to a tip at y = -1, with
## a slightly lumpy, twisted outline.
func _build_icicle_mesh() -> ArrayMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.9, 1.0)
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.72, 1.0)
	mat.emission_energy_multiplier = 0.7
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var rings := [[0.0, 1.0], [-0.25, 0.8], [-0.55, 0.5], [-0.8, 0.22]]
	var ring_pts: Array = []
	for r in rings:
		var pts: Array[Vector3] = []
		for s in sides:
			var a := TAU * s / sides + float(r[0]) * 1.2
			var wob := 1.0 + 0.12 * sin(a * 3.0 + float(r[0]) * 7.0)
			pts.append(Vector3(cos(a) * float(r[1]) * wob, float(r[0]), sin(a) * float(r[1]) * wob))
		ring_pts.append(pts)
	var tip := Vector3(0, -1, 0)
	for ri in ring_pts.size() - 1:
		var up: Array[Vector3] = ring_pts[ri]
		var dn: Array[Vector3] = ring_pts[ri + 1]
		for s in sides:
			var s2 := (s + 1) % sides
			_icicle_quad(st, up[s], up[s2], dn[s2], dn[s])
	var last: Array[Vector3] = ring_pts[-1]
	for s in sides:
		_icicle_tri(st, last[s], last[(s + 1) % sides], tip)
	st.set_material(mat)
	return st.commit()


func _icicle_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3.0
	if n.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


func _icicle_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_icicle_tri(st, a, b, c)
	_icicle_tri(st, a, c, d)


# --- set pieces ------------------------------------------------------------------------

## The Glacier Mouth: a wide opening on the left of the grid onto a snow
## slope rising to bright daylight.
func _mouth() -> void:
	var h := track.road_width * 0.5
	var span := fposmod(_mouth_to - _mouth_from, track.length)
	var d := 0.0
	while d < span:
		var o := track.wrap_offset(_mouth_from + d)
		var o2 := track.wrap_offset(o + 6.0)
		var wl := float(_dims(o)["left_wall"])
		var wl2 := float(_dims(o2)["left_wall"])
		var f := at(o)
		var f2 := at(o2)
		# Snow: flat from the barrier to the cave edge, then up the slope outside.
		var ring := [[h + 2.5, 0.03], [wl, 0.03], [wl + 25.0, 5.0], [wl + 55.0, 16.0], [wl + 80.0, 30.0]]
		for i in ring.size() - 1:
			var a0: Array = ring[i]
			var a1: Array = ring[i + 1]
			var w0 := float(a0[0]) + (wl2 - wl) * (1.0 if i > 0 else 0.0)
			var w1 := float(a1[0]) + (wl2 - wl)
			var p0 := f * Vector3(-float(a0[0]), float(a0[1]), 0)
			var p1 := f * Vector3(-float(a1[0]), float(a1[1]), 0)
			var p2 := f2 * Vector3(-w1, float(a1[1]), 0)
			var p3 := f2 * Vector3(-w0, float(a0[1]), 0)
			_quad(_st("snow", p0), p0, p1, p2, p3, p0 + Vector3.DOWN)
		var sky := f.translated_local(Vector3(-(wl + 82.0), 26.0, -3.0))
		add_panel("daylight", 9.0, 60.0, Transform3D(sky.basis * Basis(Vector3.UP, PI * 0.5), sky.origin))
		if fmod(d, 18.0) < 6.0:
			var lat := wl + rng.randf_range(5.0, 50.0)
			var y := clampf((lat - wl) * 0.33, 0.0, 16.0)
			add_sphere("snow", rng.randf_range(2.5, 5.0), f.translated_local(Vector3(-lat, y - 0.8, 0)).scaled_local(Vector3(1.6, 0.4, 1.3)), 4, 8)
			var rock := f.translated_local(Vector3(-(wl + rng.randf_range(8.0, 60.0)), 0, rng.randf_range(-3.0, 3.0)))
			rock.origin.y = clampf((absf((f.affine_inverse() * rock.origin).x) - wl) * 0.36, 0.0, 28.0)
			add_sphere("basalt", rng.randf_range(0.8, 2.2), rock.scaled_local(Vector3(1.2, 0.7, 1.0)), 3, 6)
		d += 6.0
	var mid_o := track.wrap_offset(_mouth_from + span * 0.5)
	var mid := at(mid_o)
	_add_glow(mid * Vector3(-float(_dims(mid_o)["left_wall"]) - 6.0, 12.0, 0), 60.0)
	for k in 3:
		var o := track.wrap_offset(_mouth_from + span * (0.2 + 0.3 * k))
		add_light(at(o) * Vector3(-(float(_dims(o)["left_wall"]) + 20.0), 14.0, 0), Color(0.92, 0.96, 1.0), 3.0, 80.0)


## A meltwater stream along the right of the Blue Cathedral.
func _cathedral_stream() -> void:
	var h := track.road_width * 0.5
	var from := float(zone_offsets["cathedral"]) + 40.0
	var to := float(zone_offsets["gallery"]) - 30.0
	var d := from
	while d < to:
		var f0 := at(d)
		var f1 := at(d + 3.0)
		var lat0 := h + 5.0 + sin(d * 0.03) * 1.5
		var lat1 := h + 5.0 + sin((d + 3.0) * 0.03) * 1.5
		var a := f0 * Vector3(lat0, 0.04, 0)
		var b := f0 * Vector3(lat0 + 3.5, 0.04, 0)
		var c := f1 * Vector3(lat1 + 3.5, 0.04, 0)
		var e := f1 * Vector3(lat1, 0.04, 0)
		if edge_distance(a) > 1.5:
			_quad(_st("melt", a), a, b, c, e, a + Vector3.DOWN)
		d += 3.0


## Moulin Hall: holes in the roof letting sky light onto the road, snow
## below (no visible beam or fog cone: they read as UFO lights).
func _moulins(cave: CaveShellBuilder) -> void:
	var h := track.road_width * 0.5
	var from := float(zone_offsets["moulin"])
	var span := fposmod(float(zone_offsets["canyon"]) - from, track.length)
	for i in SKYLIGHTS:
		var o := track.wrap_offset(from + span * (i + 0.6) / (SKYLIGHTS + 0.4))
		var lat := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(0.0, h * 0.6)
		var pr := cave.profile(o, _dims(o), h)
		var top := _ceiling_at(pr, lat)
		var f := at(o)
		add_cyl("sky_hole", 3.2, 0.5, f.translated_local(Vector3(lat, top - 0.6, 0)), 14)
		var spot := SpotLight3D.new()
		spot.name = "Skylight%d" % (i + 1)
		spot.position = f * Vector3(lat, top - 1.0, 0)
		spot.basis = Basis(Vector3.RIGHT, -PI * 0.5)
		spot.light_color = Color(0.85, 0.94, 1.0)
		spot.light_energy = 8.0
		spot.spot_range = top + 6.0
		spot.spot_angle = 22.0
		spot.light_volumetric_fog_energy = 0.0
		add_node(spot)
		skylights += 1
		_add_glow(f * Vector3(lat, top, 0), 22.0)
		for side: float in [-1.0, 1.0]:
			var drift := f.translated_local(Vector3(side * (h + rng.randf_range(4.0, 7.0)), -0.6, rng.randf_range(-4.0, 4.0)))
			if clear(drift.origin, 3.0):
				add_sphere("snow", rng.randf_range(3.0, 4.5), drift.scaled_local(Vector3(1.5, 0.4, 1.8)), 4, 8)


## The Frozen Lake: glassy ice to the left of the road, under chandeliers.
func _frozen_lake() -> void:
	var h := track.road_width * 0.5
	var from := float(zone_offsets["lake"]) + 40.0
	var to := from + fposmod(float(zone_offsets["mouth"]) - from, track.length) - 50.0
	var d := from
	while d < to:
		var o := track.wrap_offset(d)
		var wl := float(_dims(o)["left_wall"])
		var f0 := at(o)
		var f1 := at(track.wrap_offset(d + 3.0))
		var inner := -(h + 4.0)
		var outer := -(wl - 7.0)
		var a := f0 * Vector3(inner, 0.03, 0)
		var b := f0 * Vector3(outer, 0.03, 0)
		var c := f1 * Vector3(outer, 0.03, 0)
		var e := f1 * Vector3(inner, 0.03, 0)
		if edge_distance(b) > 2.0:
			_quad(_st("lake", a), a, b, c, e, a + Vector3.DOWN)
		# Ice chandeliers: clusters of icicles over the lake.
		if fmod(d - from, 45.0) < 3.0:
			var lat := -rng.randf_range(h + 8.0, wl - 10.0)
			var top := _ceiling_at(_cave.profile(o, _dims(o), h), lat) - 0.4
			var centre := f0 * Vector3(lat, top, 0)
			for k in 26:
				var ang := rng.randf() * TAU
				var r := rng.randf_range(0.0, 3.5)
				_hang(centre + Vector3(cos(ang) * r, rng.randf_range(-0.5, 0.5), sin(ang) * r),
						rng.randf_range(1.5, 7.0) * (1.0 - r / 5.0), rng.randf_range(0.12, 0.35))
		d += 3.0


## Black volcanic boulders and snow patches on the cave floor.
func _floor_dressing() -> void:
	var h := track.road_width * 0.5
	var d := 0.0
	while d < track.length:
		var dm := _dims(d)
		var f := at(d)
		for side: float in [-1.0, 1.0]:
			var wall := float(dm["left_wall" if side < 0.0 else "right_wall"])
			if side < 0.0 and bool(dm["open_left"]):
				continue
			var lat := side * rng.randf_range(h + 3.5, wall - 1.5)
			var pos := f * Vector3(lat, 0, -rng.randf_range(0.0, 9.0))
			var r := rng.randf_range(0.4, 1.6)
			if not clear(pos, r):
				continue
			if rng.randf() < 0.3:
				add_sphere("snow", r * 2.0, Transform3D(Basis.from_scale(Vector3(1.4, 0.25, 1.1)), pos), 3, 7)
			else:
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.2)))
				add_sphere("basalt", r, Transform3D(basis, pos + Vector3(0, r * 0.2, 0)), 3, 6)
		d += 9.0


## Soft blue fill lights high in the cave (the ice's glow does the rest).
func _cave_lights() -> void:
	var d := 50.0
	while d < track.length:
		var dm := _dims(d)
		var y := minf(float(dm["crown"]) * 0.5, 14.0)
		add_light(at(d) * Vector3(0, y, 0), Color(0.6, 0.82, 1.0), 1.6, 55.0)
		d += 115.0


## The Crystal Tube: a narrow, glowing tunnel with white light at its end.
func _crystal_tube(sc: TrackShortcut) -> void:
	var main_h := track.road_width * 0.5
	var t0 := 0.0
	var t1 := sc.length
	var d := 0.0
	while d < sc.length * 0.5:
		if _main_distance(sc.point_at(d)) > main_h + 6.0:
			break
		t0 = d
		d += 3.0
	d = sc.length
	while d > sc.length * 0.5:
		if _main_distance(sc.point_at(d)) > main_h + 6.0:
			break
		t1 = d
		d -= 3.0
	var h := sc.road_width * 0.5
	var tube := CaveShellBuilder.new(self, sc, 4242)
	tube.min_clear = 7.6
	tube.dims = func(td: float) -> Dictionary:
		var flare := 1.0 + 0.7 * (1.0 - smoothstep(0.0, 18.0, minf(td - t0, t1 - td)))
		return {"left_wall": (h + 3.0) * flare, "right_wall": (h + 3.0) * flare, "crown": 8.6 * flare,
				"rough": 0.45, "key": "ice_tube", "icicles": 5.0, "fangs": 0.0, "pillars": 0.0, "max_len": 1.6}
	tube.on_roof = mark_roof
	tube.on_section = _dress_section
	tube.build(t0, t1)
	var exit := sc.point_at(t1)
	add_light(exit + Vector3(0, 4.0, 0), Color(0.92, 0.97, 1.0), 3.0, 28.0)
	_add_glow(exit + Vector3(0, 3.0, 0), 26.0)
	_add_glow(sc.point_at(t0) + Vector3(0, 3.0, 0), 14.0)
	var mid := 0.25
	while mid < 1.0:
		add_light(sc.point_at(lerpf(t0, t1, mid)) + Vector3(0, 5.5, 0), Color(0.35, 0.75, 1.0), 1.4, 22.0)
		mid += 0.25


func _main_distance(p: Vector3) -> float:
	var q := track.curve.get_closest_point(p)
	return Vector2(p.x - q.x, p.z - q.z).length()
