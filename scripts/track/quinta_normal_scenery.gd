@tool
class_name QuintaNormalScenery
extends TrackScenery
## Parque Quinta Normal Greenhouse (Santiago, Chile; GDD 8.10): the old
## Victorian iron-and-glass greenhouse in a summer park, wire mesh
## everywhere. In driving order: the start inside the long barrel-vaulted
## main wing (two spans with a sunny courtyard between them); out along a
## tree-lined avenue to the Rotunda, where the road runs into the domed
## pavilion and sweeps about 310 degrees round the checkerboard plinth before
## leaving beside where it came in (a "lollipop"); the hedge-lined S-bends
## in the south; the south-west corner; and back up the west side into the
## wing. The infield holds the tiered dome with its exterior staircase and
## gallery (picture 3), with two glass wings. The shortcut is the Fern Wing:
## through a smashable glass panel into a narrow, mesh-caged glasshouse
## across the south-west corner. Mesh fencing on iron posts lines every road
## outside the glasshouses. Bougainvillea, plane trees and Chilean palms
## fill the park; the Andes stand on the eastern horizon. The road is flat
## at y = 0; positions are layout coordinates matching quinta_normal.tscn.

## Main wing over the start straight: [x0, x1] spans along z = WING_Z, with
## the courtyard between them.
const WING_Z := -40.0
const WINGS := [[-190.0, 25.0], [90.0, 295.0]]
const WING_HALF := 11.0
const WING_WALL := 5.0
## The Rotunda (picture 2): the plinth's centre, dome radius / wall / rise.
const ROTUNDA := Vector3(600, 0, 230)
const ROTUNDA_R := 60.0
const ROTUNDA_WALL := 9.0
const ROTUNDA_RISE := 24.0
const PLINTH_R := 14.0
## The tiered dome in the infield (picture 3) and its two glass wings.
const TIERED := Vector3(60, 0, 230)
const TIERED_R := 30.0
const TIERED_WINGS := [[Vector3(60, 0, 198), Vector3(60, 0, 40)], [Vector3(28, 0, 230), Vector3(-150, 0, 230)]]
## Fern Wing (the shortcut): half-width of its cage and wall height.
const FERN_HALF := 7.5
const FERN_WALL := 3.2
## Mesh fencing on the barriers: from the barrier top to this height.
const FENCE_TOP := 2.8
## Park planting bounds and spacing.
const PARK_MIN := Vector2(-720, -460)
const PARK_MAX := Vector2(1000, 900)
const PARK_SPACING := 13.0
## The infield (inside the loop): open lawns, fewer trees.
const INFIELD_MIN := Vector2(-240, -10)
const INFIELD_MAX := Vector2(360, 420)

var gh: GlasshouseBuilder
var _fern: Curve3D


func build() -> void:
	cast_shadows = true
	_materials_setup()
	gh = GlasshouseBuilder.new(self, random_seed)
	_fern = track.shortcuts[0].curve if not track.shortcuts.is_empty() else null
	_wings()
	_fern_wing()
	await step(0.2)
	_rotunda()
	_tiered_dome()
	await step(0.4)
	_fences()
	_hedges()
	await step(0.55)
	_park()
	_bougainvillea()
	_flower_beds()
	await step(0.8)
	_andes()
	_santiago()
	gh.commit()


## Inside a glasshouse (overdrive flight stays low under the glass).
func is_roofed(p: Vector3) -> bool:
	return gh != null and gh.is_roofed(p)


# --- materials -----------------------------------------------------------------

func _materials_setup() -> void:
	material("iron", Color(0.6, 0.64, 0.62), 0.0, 0.55, 0.45)
	material("glass", Color(0.78, 0.9, 0.95, 0.16), 0.0, 0.3, 0.05, true)
	material("glass_old", Color(0.88, 0.84, 0.62, 0.42), 0.0, 0.2, 0.3, true)
	textured("brick", "painted_worn_brick", Color(0.85, 0.6, 0.5), 2.0)
	textured("bark", "bark_willow", Color(0.6, 0.55, 0.48), 3.0)
	material("leaf", Color(0.22, 0.42, 0.15), 0.0, 0.0, 0.85)
	textured("palm_bark", "pine_bark", Color(0.55, 0.5, 0.42), 1.5)
	material("palm_leaf", Color(0.18, 0.38, 0.14), 0.0, 0.0, 0.8)
	material("hedge", Color(0.13, 0.3, 0.11), 0.0, 0.0, 0.95)
	material("bloom", Color(0.86, 0.16, 0.6), 0.04, 0.0, 0.8)
	material("bloom_pale", Color(0.95, 0.46, 0.78), 0.03, 0.0, 0.8)
	material("bloom_leaf", Color(0.2, 0.34, 0.14), 0.0, 0.0, 0.9)
	material("flower_red", Color(0.85, 0.12, 0.1))
	material("flower_yellow", Color(0.98, 0.8, 0.15))
	material("flower_white", Color(0.95, 0.95, 0.9))
	textured("soil", "brown_mud_leaves_01", Color(0.75, 0.6, 0.65), 2.0)
	material("andes", Color(0.46, 0.47, 0.56), 0.0, 0.0, 1.0)
	material("snow", Color(0.96, 0.97, 1.0), 0.15, 0.0, 0.9)
	material("tower", Color(0.24, 0.32, 0.4), 0.0, 0.7, 0.2)
	material("tower_dark", Color(0.3, 0.32, 0.36), 0.0, 0.3, 0.6)
	register_material("checker", _checker_material())
	register_material("graffiti", _graffiti_material())
	no_shadow_keys = ["glass", "glass_old", "andes", "snow", "tower", "tower_dark"]


## The plinth's black-and-white checkerboard (world-space, no UVs needed).
func _checker_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var white := ((x / 32) + (y / 32)) % 2 == 0
			var c := Color(0.86, 0.84, 0.8) if white else Color(0.14, 0.13, 0.13)
			# A little wear.
			img.set_pixel(x, y, c.darkened(0.05 * float((x * 7 + y * 13) % 5) / 4.0))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 4.8
	m.roughness = 0.6
	return m


## Spray-painted tags on the low walls (picture 2).
func _graffiti_material() -> StandardMaterial3D:
	var img := Image.create(256, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.33, 0.3))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var paints := [Color(0.95, 0.2, 0.7), Color(0.1, 0.8, 0.95), Color(0.98, 0.85, 0.1),
			Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12), Color(0.3, 0.85, 0.3)]
	for stroke in 26:
		var c: Color = paints[r.randi() % paints.size()]
		var p := Vector2(r.randf_range(0, 256), r.randf_range(20, 108))
		var dir := Vector2.from_angle(r.randf() * TAU)
		var width := r.randf_range(2.0, 6.0)
		for step_i in r.randi_range(20, 70):
			dir = dir.rotated(r.randf_range(-0.5, 0.5))
			p += dir * 1.5
			p.y = clampf(p.y, 4, 124)
			for ox in range(-int(width), int(width) + 1):
				for oy in range(-int(width), int(width) + 1):
					if ox * ox + oy * oy <= width * width:
						img.set_pixel(posmod(int(p.x) + ox, 256), clampi(int(p.y) + oy, 0, 127), c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 8.0, 1.0 / 4.0, 1.0 / 8.0)
	m.roughness = 0.9
	return m


# --- glasshouses -----------------------------------------------------------------

func _wings() -> void:
	for span in WINGS:
		var d0 := track.get_offset_at(Vector3(span[0], 0, WING_Z))
		var d1 := track.get_offset_at(Vector3(span[1], 0, WING_Z))
		gh.barrel(track.curve, true, d0, d1, WING_HALF, WING_WALL, 3.0, 0.3, true)


func _fern_wing() -> void:
	if _fern == null:
		return
	gh.barrel(_fern, false, 6.0, _fern.get_baked_length() - 6.0, FERN_HALF, FERN_WALL, 3.0, 0.45, false)


func _rotunda() -> void:
	gh.dome(ROTUNDA, ROTUNDA_R, ROTUNDA_WALL, ROTUNDA_RISE, 48, 0.3, false)
	# The plinth: a raised checkerboard disc on a brick rim with two steps.
	add_cyl("brick", PLINTH_R + 2.2, 0.25, xform(ROTUNDA), 40)
	add_cyl("brick", PLINTH_R + 1.1, 0.5, xform(ROTUNDA), 40)
	add_cyl("brick", PLINTH_R + 0.3, 0.72, xform(ROTUNDA), 40)
	add_cyl("checker", PLINTH_R, 0.76, xform(ROTUNDA), 40)
	# A low graffiti wall ring round the plinth garden (with gaps), and
	# graffiti planters round the outside of the road.
	_low_wall_ring(ROTUNDA, 27.0, 1.1, 0.7, 36, 0.2)
	_low_wall_ring(ROTUNDA, 56.5, 1.3, 0.8, 64, 0.0)
	# Palms and a big flowering shrub in the inner garden.
	var palms := TreeBuilder.new(self, "palm_bark", "palm_leaf", random_seed + 3)
	for i in 7:
		var ang := TAU * float(i) / 7.0 + 0.3
		var p := ROTUNDA + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(18.0, 23.0)
		if clear(p, 3.0):
			palms.place("palm", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 0.9)), p))
	palms.commit()
	_bloom_bush(ROTUNDA + Vector3(-19, 0, 9), 5.0, 7.0)
	_bloom_bush(ROTUNDA + Vector3(16, 0, -14), 3.5, 5.0)


func _low_wall_ring(c: Vector3, r: float, h: float, thick: float, n: int, gap_chance: float) -> void:
	for i in n:
		if rng.randf() < gap_chance:
			continue
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var mid := (p0 + p1) * 0.5
		if not clear(mid, thick):
			continue
		var len := p0.distance_to(p1) + 0.1
		add_box("graffiti", Vector3(thick, h, len), Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), mid + Vector3.UP * h * 0.5))


func _tiered_dome() -> void:
	gh.dome(TIERED, TIERED_R, 8.0, 16.0, 36, 0.25, true)
	for w in TIERED_WINGS:
		gh.barrel_line(w[0], w[1], 8.0, 4.0, 3.5, 0.25)
	_bloom_bush(TIERED + Vector3(TIERED_R + 3.0, 0, -12), 4.0, 6.0)
	_bloom_bush(TIERED + Vector3(-8, 0, -TIERED_R - 3.0), 3.0, 5.0)


# --- wire-mesh fencing -----------------------------------------------------------

## Mesh fencing on every barrier outside the glasshouses (those have mesh
## walls of their own).
func _fences() -> void:
	var skip := func(p: Vector3) -> bool: return _in_glasshouse_band(p) or edge_distance(p) < 0.2
	_fence_curve(track.curve, track.road_width, true, skip)
	for sc in track.shortcuts:
		_fence_curve(sc.curve, sc.road_width, false, skip)


func _fence_curve(curve: Curve3D, width: float, closed: bool, skip: Callable) -> void:
	var length := curve.get_baked_length()
	var edge := width * 0.5 + track.barrier_thickness * 0.5
	for side in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var d := 0.0
		while d <= length:
			var p := curve.sample_baked(d)
			var q := curve.sample_baked(fposmod(d + 1.0, length) if closed else minf(d + 1.0, length))
			if q.distance_to(p) < 0.01:
				q = p + (p - curve.sample_baked(maxf(d - 1.0, 0.0)))
			var right := Vector3(q.x - p.x, 0, q.z - p.z).normalized().cross(Vector3.UP)
			pts.append(Vector3(p.x, 0, p.z) + right * edge * side)
			d += 3.0
		if closed and pts.size() > 0:
			pts.append(pts[0])
		gh.fence(pts, track.barrier_height, FENCE_TOP, 3.0, skip)


## Inside a main-wing span or the Fern Wing (whose own walls are mesh).
func _in_glasshouse_band(p: Vector3) -> bool:
	if absf(p.z - WING_Z) < WING_HALF + 1.0:
		for span in WINGS:
			if p.x > span[0] - 2.0 and p.x < span[1] + 2.0:
				return true
	if _fern != null:
		var c := _fern.get_closest_point(p)
		var t := _fern.get_closest_offset(p)
		if c.distance_to(p) < FERN_HALF + 1.0 and t > 4.0 and t < _fern.get_baked_length() - 4.0:
			return true
	return false


# --- park -------------------------------------------------------------------------

## Clipped box hedges outside the fences along the avenue and the south.
func _hedges() -> void:
	var length := track.curve.get_baked_length()
	var ranges := [[470.0, 820.0], [1300.0, 2100.0], [2650.0, 3050.0]]
	var lat := track.road_width * 0.5 + track.barrier_thickness + 2.6
	for r in ranges:
		var d: float = r[0]
		while d < minf(r[1], length):
			for side in [-1.0, 1.0]:
				var xf := at(d, lat * side, 0.0)
				var p := xf.origin
				if clear(p, 1.0) and not _in_glasshouse_band(p) and _outside_buildings(p, 3.0):
					add_box("hedge", Vector3(1.6, 1.3, 3.1), Transform3D(xf.basis, p + Vector3.UP * 0.65))
			d += 3.0


func _park() -> void:
	var trees := TreeBuilder.new(self, "bark", "leaf", random_seed)
	var palms := TreeBuilder.new(self, "palm_bark", "palm_leaf", random_seed + 1)
	var x := PARK_MIN.x
	while x < PARK_MAX.x:
		var z := PARK_MIN.y
		while z < PARK_MAX.y:
			var p := Vector3(x + rng.randf_range(-5, 5), 0, z + rng.randf_range(-5, 5))
			z += PARK_SPACING
			var infield := p.x > INFIELD_MIN.x and p.x < INFIELD_MAX.x and p.z > INFIELD_MIN.y and p.z < INFIELD_MAX.y
			if rng.randf() > (0.12 if infield else 0.42):
				continue
			if not clear(p, 9.0) or not _outside_buildings(p, 12.0):
				continue
			var yaw := rng.randf() * TAU
			if rng.randf() < 0.16:
				palms.place("palm", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.75, 1.05)), p))
			else:
				trees.place("rainforest", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.55, 0.85)), p))
		x += PARK_SPACING
	trees.commit()
	palms.commit()


## Away from the glasshouses (trees and hedges keep this far out).
func _outside_buildings(p: Vector3, margin: float) -> bool:
	if Vector2(p.x - ROTUNDA.x, p.z - ROTUNDA.z).length() < ROTUNDA_R + margin:
		return false
	if Vector2(p.x - TIERED.x, p.z - TIERED.z).length() < TIERED_R + margin:
		return false
	for w in TIERED_WINGS:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < 8.0 + margin:
			return false
	if absf(p.z - WING_Z) < WING_HALF + margin and p.x > -200.0 and p.x < 305.0:
		return false
	return true


## Bougainvillea: magenta clusters climbing the wings' outer walls and
## round the domes.
func _bougainvillea() -> void:
	for span in WINGS:
		var x: float = span[0]
		while x < span[1]:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.22:
					var base := Vector3(x, 0, WING_Z + side * (WING_HALF + 0.9))
					_bloom_bush(base, rng.randf_range(1.6, 3.0), rng.randf_range(3.0, 8.5))
			x += 6.0
	for i in 18:
		var ang := rng.randf() * TAU
		var p := ROTUNDA + Vector3(cos(ang), 0, sin(ang)) * (ROTUNDA_R + 2.0)
		if clear(p, 3.0):
			_bloom_bush(p, rng.randf_range(2.0, 3.5), rng.randf_range(4.0, 9.0))


## A climbing / bushy bougainvillea: leafy mass with magenta blooms.
func _bloom_bush(base: Vector3, spread: float, height: float) -> void:
	if not clear(base, spread * 0.6):
		return
	var blobs := int(spread * 1.6)
	for i in blobs:
		var p := base + Vector3(rng.randf_range(-spread, spread), rng.randf_range(0.6, height), rng.randf_range(-spread, spread) * 0.6)
		var r := rng.randf_range(0.6, 1.4)
		add_sphere("bloom_leaf", r, xform(p), 4, 6)
		add_sphere("bloom" if rng.randf() < 0.65 else "bloom_pale", r * 0.8, xform(p + Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4))), 4, 6)


## Formal flower beds round the tiered dome and in the wing courtyard.
func _flower_beds() -> void:
	var colours := ["flower_red", "flower_yellow", "flower_white", "bloom"]
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var p := TIERED + Vector3(cos(ang), 0, sin(ang)) * (TIERED_R + 9.0)
		if clear(p, 3.0) and _outside_buildings(p, 1.0):
			add_box("soil", Vector3(5.0, 0.35, 2.4), Transform3D(Basis(Vector3.UP, -ang), p + Vector3.UP * 0.17))
			add_box(colours[i % colours.size()], Vector3(4.6, 0.3, 2.0), Transform3D(Basis(Vector3.UP, -ang), p + Vector3.UP * 0.5))
	# The courtyard between the two wing spans.
	for sx in [35.0, 55.0, 75.0]:
		for side in [-1.0, 1.0]:
			var p := Vector3(sx, 0, WING_Z + side * 16.0)
			if clear(p, 2.0):
				add_box("soil", Vector3(12.0, 0.35, 3.0), xform(p + Vector3.UP * 0.17))
				add_box(colours[int(sx) % colours.size()], Vector3(11.4, 0.32, 2.6), xform(p + Vector3.UP * 0.5))


# --- horizon ---------------------------------------------------------------------

## The Andes, east of Santiago: big rock peaks with snow caps.
func _andes() -> void:
	for i in 46:
		var p := Vector3(rng.randf_range(2600.0, 3600.0), -30.0, rng.randf_range(-3600.0, 3600.0))
		var h := rng.randf_range(650.0, 1500.0)
		var r := h * rng.randf_range(0.8, 1.15)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		add_cone("andes", r, h, Transform3D(yaw, p), 7)
		add_cone("snow", r * 0.34, h * 0.34, Transform3D(yaw, p + Vector3.UP * h * 0.66), 7)


## Santiago's skyline to the north-east: the Gran Torre and a few towers.
func _santiago() -> void:
	var gt := Vector3(1500, 0, -1900)
	add_box("tower", Vector3(46, 260, 46), xform(gt + Vector3.UP * 130.0))
	add_box("tower", Vector3(34, 40, 34), xform(gt + Vector3.UP * 280.0))
	for i in 24:
		var p := gt + Vector3(rng.randf_range(-900, 700), 0, rng.randf_range(-500, 500))
		var h := rng.randf_range(35.0, 140.0)
		var w := rng.randf_range(18.0, 40.0)
		add_box("tower" if rng.randf() < 0.5 else "tower_dark", Vector3(w, h, w * rng.randf_range(0.6, 1.2)), xform(p + Vector3.UP * h * 0.5))
