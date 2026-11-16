@tool
class_name MarbleCanyonScenery
extends TrackScenery
## Marble Canyon set dressing (GDD 8.6j): a switchback climb round two
## rounded sandstone masses, through a natural rock window at the top and
## down into a wave-striped basin (after 'reference files/Marble Canyon
## 1-6.webp').
##
## The land is one heightfield over the layout. Near the road it sits just
## under the road; between two roads it blends their heights with steep
## inverse-distance weights, so each switchback leg gets a level shelf with
## a cut face above it and a fill slope below (the terraces). Past that,
## rounded masses rise behind the hairpins, a ridge crosses the road at the
## window, and canyon walls ring the whole layout. A SandstoneArchBuilder
## fin bridges the window ridge. Rounded rock noses fill each hairpin.
## The land near the roads has a collider, so a car that leaves a terrace
## lands on rock (and the terrace guard puts it back).

## Lap offsets of each hairpin (from the layout generator): [from, to,
## +1 left / -1 right].
const HAIRPINS := {
	"H1": [723.0, 805.0, 1.0],
	"H2": [965.0, 1028.0, -1.0],
	"H3": [1188.0, 1288.0, 1.0],
	"H4": [1408.0, 1515.0, -1.0],
	"H5": [1857.0, 1970.0, 1.0],
	"H6": [2080.0, 2155.0, -1.0],
}
## The rock window: lap offset of the middle of its throat.
const WINDOW_OFFSET := 1686.0
## The wave basin's long sweeper.
const BASIN := Vector2(2375.0, 2606.0)

## Heightfield grid size (m) and margin round the layout.
const CELL := 5.0
const MARGIN := 280.0
## Level shoulder past the road edge (m) before the land turns up or down.
const SHOULDER := 4.0
## Distance over which the land leaves the road level for the blend.
const BLEND := 16.0
## Lap metres apart that two road samples count as different roads.
const SEPARATE := 90.0
## Road sample index (track-local): cell size and sample step (m).
const IDX_CELL := 32.0
const IDX_STEP := 4.0
## Coarse distance field (m) for land far from the road.
const COARSE := 20.0
## Land within this of a road gets a collider.
const COLLIDE_REACH := 45.0
## The window ridge: height above the road and half length along it.
const RIDGE_HEIGHT := 26.0
const RIDGE_LENGTH := 26.0

## Heightfield (row-major, nx * nz) and its origin (track-local x, z).
var heights := PackedFloat32Array()
var origin := Vector2.ZERO
var nx: int = 0
var nz: int = 0
var arch: SandstoneArchBuilder
## Track-local frame of the window (origin = road centre under the fin).
var window_frame := Transform3D.IDENTITY
## Hairpin rock noses: [centre (track-local, y = apex road height), radius].
var noses: Array = []

var _idx: Dictionary = {}
var _coarse := PackedFloat32Array() # (edge distance, road y) per coarse cell
var _cnx: int = 0
var _cnz: int = 0
var _corigin := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _masses: Array = [] # [Vector2 centre, radius, top y]


func build() -> void:
	_noise.seed = 77
	_noise.frequency = 0.008
	_noise.fractal_octaves = 3
	var t0 := Time.get_ticks_msec()
	_materials_setup()
	_index_road()
	_find_features()
	await step(0.1)
	_build_coarse()
	print("[marble] coarse %d ms" % (Time.get_ticks_msec() - t0))
	await step(0.2)
	await _compute_heights()
	print("[marble] heights %d ms (%dx%d)" % [Time.get_ticks_msec() - t0, nx, nz])
	await step(0.6)
	_build_land()
	print("[marble] land %d ms" % (Time.get_ticks_msec() - t0))
	await step(0.8)
	_build_window()
	_build_noses()
	print("[marble] done %d ms" % (Time.get_ticks_msec() - t0))
	await step(1.0)


func _materials_setup() -> void:
	textured("sandstone", "rock_face", Color(1.0, 0.72, 0.55), 14.0, 0.9)
	textured("sandstone_dark", "rock_face", Color(0.95, 0.66, 0.5), 10.0, 0.9)
	textured("nose", "rock_face", Color(1.0, 0.78, 0.62), 6.0, 0.9)


# --- road queries ----------------------------------------------------------------

func _index_road() -> void:
	_idx.clear()
	var length := track.length
	var count := int(length / IDX_STEP)
	for i in count:
		var o := length * float(i) / float(count)
		var p := track.curve.sample_baked(o)
		var key := Vector2i(int(floor(p.x / IDX_CELL)), int(floor(p.z / IDX_CELL)))
		if not _idx.has(key):
			_idx[key] = PackedFloat32Array()
		var arr: PackedFloat32Array = _idx[key]
		arr.append_array(PackedFloat32Array([p.x, p.z, p.y, o]))
		_idx[key] = arr


## Nearest road sample and the nearest one from a different part of the lap
## within `cells` index cells: [e1, y1, o1, e2, y2] (edge distances; e2 is
## INF when there's no second road).
func _nearest_two(x: float, z: float, cells: int) -> PackedFloat32Array:
	var half := track.road_width * 0.5
	var cx := int(floor(x / IDX_CELL))
	var cz := int(floor(z / IDX_CELL))
	var e1 := INF
	var y1 := 0.0
	var o1 := 0.0
	var found: Array[PackedFloat32Array] = []
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var arr: PackedFloat32Array = _idx.get(Vector2i(cx + dx, cz + dz), PackedFloat32Array())
			if arr.is_empty():
				continue
			found.append(arr)
			var i := 0
			while i < arr.size():
				var ex := x - arr[i]
				var ez := z - arr[i + 1]
				var d := ex * ex + ez * ez
				if d < e1:
					e1 = d
					y1 = arr[i + 2]
					o1 = arr[i + 3]
				i += 4
	if e1 == INF:
		return PackedFloat32Array([INF, 0.0, 0.0, INF, 0.0])
	var e2 := INF
	var y2 := 0.0
	var length := track.length
	for arr in found:
		var i := 0
		while i < arr.size():
			var dl := absf(arr[i + 3] - o1)
			if minf(dl, length - dl) > SEPARATE:
				var ex := x - arr[i]
				var ez := z - arr[i + 1]
				var d := ex * ex + ez * ez
				if d < e2:
					e2 = d
					y2 = arr[i + 2]
			i += 4
	return PackedFloat32Array([sqrt(e1) - half, y1, o1, sqrt(e2) - half if e2 < INF else INF, y2])


## Coarse (edge distance, road height) field over the whole area, for land
## far from the road.
func _build_coarse() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.curve.get_baked_points():
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	origin = lo - Vector2.ONE * MARGIN
	nx = int((hi.x - lo.x + MARGIN * 2.0) / CELL) + 1
	nz = int((hi.y - lo.y + MARGIN * 2.0) / CELL) + 1
	_corigin = origin
	_cnx = int((hi.x - lo.x + MARGIN * 2.0) / COARSE) + 2
	_cnz = int((hi.y - lo.y + MARGIN * 2.0) / COARSE) + 2
	var pts := PackedVector3Array()
	var count := int(track.length / 12.0)
	for i in count:
		pts.append(track.curve.sample_baked(track.length * float(i) / float(count)))
	_coarse.resize(_cnx * _cnz * 2)
	var half := track.road_width * 0.5
	for iz in _cnz:
		for ix in _cnx:
			var x := _corigin.x + ix * COARSE
			var z := _corigin.y + iz * COARSE
			var best := INF
			var y := 0.0
			for p in pts:
				var d := (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
				if d < best:
					best = d
					y = p.y
			_coarse[(iz * _cnx + ix) * 2] = sqrt(best) - half
			_coarse[(iz * _cnx + ix) * 2 + 1] = y


func _coarse_at(x: float, z: float) -> Vector2:
	var fx := clampf((x - _corigin.x) / COARSE, 0.0, _cnx - 1.001)
	var fz := clampf((z - _corigin.y) / COARSE, 0.0, _cnz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var out := Vector2.ZERO
	for k in 2:
		var a := _coarse[(iz * _cnx + ix) * 2 + k]
		var b := _coarse[(iz * _cnx + ix + 1) * 2 + k]
		var c := _coarse[((iz + 1) * _cnx + ix) * 2 + k]
		var d := _coarse[((iz + 1) * _cnx + ix + 1) * 2 + k]
		out[k] = lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)
	return out


# --- features --------------------------------------------------------------------

## Hairpin noses, the masses behind them and the window frame.
func _find_features() -> void:
	noses.clear()
	_masses.clear()
	for key in HAIRPINS:
		var h: Array = HAIRPINS[key]
		var a := track.curve.sample_baked(h[0])
		var b := track.curve.sample_baked(h[1])
		var m := track.curve.sample_baked((h[0] + h[1]) * 0.5)
		var centre := (a + b) * 0.5
		var radius := Vector2(a.x - b.x, a.z - b.z).length() * 0.5
		var apex_y := m.y
		var nose_r := radius - track.road_width * 0.5 - track.barrier_thickness - 2.0
		noses.append([Vector3(centre.x, apex_y, centre.z), nose_r])
		# A rounded mass rises behind the hairpin (beyond its apex).
		var out := Vector2(m.x - centre.x, m.z - centre.z).normalized()
		var c2 := Vector2(m.x, m.z) + out * (track.road_width * 0.5 + 48.0)
		_masses.append([c2, 46.0, apex_y + 26.0])
	var p := track.curve.sample_baked(WINDOW_OFFSET)
	var t := track.get_tangent_at(WINDOW_OFFSET)
	var fwd := Vector3(t.x, 0.0, t.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	window_frame = Transform3D(Basis(right, Vector3.UP, fwd), p)


## Land height (track-local) at x, z.
func land_height(x: float, z: float) -> float:
	var c := _coarse_at(x, z)
	var e1: float
	var y1: float
	var o1 := -1.0
	var e2 := INF
	var y2 := 0.0
	if c.x < 60.0:
		var q := _nearest_two(x, z, 1 if c.x < 26.0 else 2)
		e1 = q[0]
		y1 = q[1]
		o1 = q[2]
		e2 = q[3]
		y2 = q[4]
		if e1 == INF:
			e1 = c.x
			y1 = c.y
	else:
		e1 = c.x
		y1 = c.y
	# On a banked stretch the low edge sits below the centre line.
	var bank_drop := sin(absf(track.bank_at(o1))) * (track.road_width * 0.5 + SHOULDER) if o1 >= 0.0 else 0.0
	if e1 < 0.0:
		return y1 - 0.9 - bank_drop
	var road := y1
	if e2 < INF:
		var w1 := 1.0 / pow(e1 + 3.0, 3.0)
		var w2 := 1.0 / pow(e2 + 3.0, 3.0)
		road = (y1 * w1 + y2 * w2) / (w1 + w2)
	var near := smoothstep(SHOULDER, SHOULDER + BLEND, e1)
	var far := smoothstep(SHOULDER + 6.0, 70.0, e1)
	var extra := 0.0
	# Canyon walls ring the layout.
	extra += (34.0 + _noise.get_noise_2d(x * 0.5, z * 0.5) * 16.0) * smoothstep(55.0, 230.0, e1)
	# Rolling, dune-like sandstone everywhere off the road.
	extra += _noise.get_noise_2d(x, z) * 7.0 * far
	# Rounded masses behind the hairpins.
	for m in _masses:
		var d := Vector2(x, z).distance_to(m[0])
		var r: float = m[1]
		if d < r * 2.2:
			var bump: float = (m[2] - road) * exp(-pow(d / r, 2.0))
			extra = maxf(extra, bump * smoothstep(SHOULDER, SHOULDER + 14.0, e1))
	# The ridge the window cuts through: steep walls either side of the road.
	var local := window_frame.affine_inverse() * Vector3(x, 0.0, z)
	if absf(local.z) < RIDGE_LENGTH * 3.0 and absf(local.x) < 160.0:
		var ridge := RIDGE_HEIGHT * exp(-pow(local.z / RIDGE_LENGTH, 2.0)) * (1.0 - smoothstep(60.0, 160.0, absf(local.x)))
		var wall := smoothstep(arch_half_width() - track.road_width * 0.5, arch_half_width() - track.road_width * 0.5 + 9.0, e1)
		extra = maxf(extra, ridge * wall)
	var level := y1 - 0.3 - bank_drop
	return lerpf(level, road, near) + extra


func arch_half_width() -> float:
	return 15.0


func _compute_heights() -> void:
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = land_height(origin.x + ix * CELL, origin.y + iz * CELL)
		if iz % 40 == 39:
			await step(0.2 + 0.4 * float(iz) / float(nz))


## Land height from the built heightfield (bilinear), for standing things on it.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / CELL, 0.0, nx - 1.001)
	var fz := clampf((z - origin.y) / CELL, 0.0, nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := heights[iz * nx + ix]
	var b := heights[iz * nx + ix + 1]
	var c := heights[(iz + 1) * nx + ix]
	var d := heights[(iz + 1) * nx + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


# --- geometry --------------------------------------------------------------------

func _build_land() -> void:
	var tools := {}
	var faces := {}
	var normals := PackedVector3Array()
	normals.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var hl := heights[iz * nx + maxi(ix - 1, 0)]
			var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
			var hd := heights[maxi(iz - 1, 0) * nx + ix]
			var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
			normals[iz * nx + ix] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
	for iz in nz - 1:
		for ix in nx - 1:
			var idx: Array[int] = [iz * nx + ix, iz * nx + ix + 1, (iz + 1) * nx + ix + 1, (iz + 1) * nx + ix]
			var x0 := origin.x + ix * CELL
			var z0 := origin.y + iz * CELL
			var p: Array[Vector3] = [
				Vector3(x0, heights[idx[0]], z0), Vector3(x0 + CELL, heights[idx[1]], z0),
				Vector3(x0 + CELL, heights[idx[2]], z0 + CELL), Vector3(x0, heights[idx[3]], z0 + CELL)]
			var key := "%d,%d" % [int(floor(p[0].x / CHUNK)), int(floor(p[0].z / CHUNK))]
			if not tools.has(key):
				var nst := SurfaceTool.new()
				nst.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = nst
				faces[key] = PackedVector3Array()
			var st: SurfaceTool = tools[key]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normals[idx[k]])
				st.add_vertex(p[k])
			var c := _coarse_at(p[0].x, p[0].z)
			if c.x < COLLIDE_REACH:
				var f: PackedVector3Array = faces[key]
				f.append_array(PackedVector3Array([p[0], p[2], p[1], p[0], p[3], p[2]]))
				faces[key] = f
	var body := StaticBody3D.new()
	body.name = "LandCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	for key in tools:
		var mi := add_mesh_instance((tools[key] as SurfaceTool).commit(), get_material("sandstone"),
				"Land_" + (key as String).replace(",", "_"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var f: PackedVector3Array = faces[key]
		if f.is_empty():
			continue
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(f)
		concave.backface_collision = true
		shape.shape = concave
		body.add_child(shape)
	add_node(body)


func _build_window() -> void:
	arch = SandstoneArchBuilder.new()
	arch.hole_half_width = arch_half_width()
	arch.build(self, "sandstone_dark", window_frame)


## Rounded rock noses inside each hairpin (squashed spheres).
func _build_noses() -> void:
	for n in noses:
		var c: Vector3 = n[0]
		var r: float = n[1]
		if r < 3.0:
			continue
		var top := height_at(c.x, c.z) + r * 0.9
		var xf := Transform3D(Basis.from_scale(Vector3(r, maxf(top - c.y + 2.0, r * 0.8), r)), Vector3(c.x, c.y - 2.0, c.z))
		add_sphere("nose", 1.0, xf, 8, 18)
