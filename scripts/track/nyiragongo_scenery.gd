@tool
class_name NyiragongoScenery
extends TrackScenery
## Fires of Nyiragongo (GDD 8.6h): the road runs round the inside of the
## Nyiragongo crater at dusk. Sheer black walls stepped in strata ledges
## (Poly Haven basalt mapped by basalt_fissure.gdshader, with fine molten
## fissures on the flats) tower up to a rim 70 m above the start, which sits
## on a low saddle; a cracked lava lake (lava_lake.gdshader) in a pit below
## a black ledge, with lava fountains at its vents and steam round its edge;
## a channel runs from it across the shelf (the shortcut jumps it); gas
## plumes tower over the lake and drift off downwind; ash falls round the
## cameras; jagged boulders, scree at the foot of the walls, basalt columns,
## spatter cones and glowing pools on the floor; a jagged outcrop inside the
## second hairpin; tin huts and a flag on the rim by the start. Positions
## are track-local metres (x east, z south).
##
## Visual only, except the lava: a RecoveryZone (reason "lava") covers the
## lake and the channel, so a car that falls short of the jump burns up.

const LAKE_CENTRE := Vector2(0.0, -20.0)
const LAKE_RADIUS := 165.0
const LAKE_Y := -68.0
## The channel runs from the lake (FROM) out to its vent (TO).
const CHANNEL_FROM := Vector2(-103.7, -135.2)
const CHANNEL_TO := Vector2(-177.3, -216.9)
const CHANNEL_WIDTH := 9.0
const CHANNEL_Y := -64.5
## Inside the second hairpin (the black rock outcrop) and the first.
const OUTCROP := Vector2(-248.0, 204.0)
const HAIRPIN_1 := Vector2(-302.0, -82.0)
## Vents in the lake: xz and radius (crust breaks up round them; plumes rise).
const VENTS: Array[Vector3] = [Vector3(25.0, -50.0, 28.0), Vector3(-45.0, 5.0, 22.0), Vector3(55.0, 20.0, 18.0)]
const TERRAIN_BOUNDS := Rect2(-620.0, -620.0, 1240.0, 1240.0)
const TERRAIN_CELL := 6.0
## The black ledge round the lake pit (the lava is PIT_DROP below it), and
## the rim: high all round, low where the start straight crosses it.
const FLOOR_Y := -62.5
const RIM_Y := 72.0
const RIM_SADDLE_Y := 14.0
const RIM_RADIUS := 470.0
## Terrain hugs the road surface out to this far past its edge (m), then
## climbs the wall outward (in strata ledges STRATA high, sheer risers
## between) or falls away toward the lake.
const HUG := 9.0
const WALL_SLOPE := 2.2
const STRATA := 8.0
const FALL_SLOPE := 0.9
const ROAD_CELL_SIZE := 20.0

var lava_zone: RecoveryZone
var plumes: Array[VolcanicPlume] = []
var ash: AshFall
var spatter_cones: int = 0
var pools: int = 0
var boulders: int = 0
var scree: int = 0
var columns: int = 0
var fountains: Array[CPUParticles3D] = []
var huts: int = 0
var lake_mesh: MeshInstance3D

## Vector2i cell -> PackedFloat32Array of (x, z, y, half width, cross slope,
## right x, right z) per road sample (main loop and shortcuts, not gaps).
var _roads: Dictionary = {}
var _noise: FastNoiseLite
var _rocks: RockScatter


func build() -> void:
	_setup_materials()
	_index_roads()
	_noise = FastNoiseLite.new()
	_noise.seed = random_seed
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	_terrain()
	await step(0.45)
	_lake()
	_channel()
	_lava_zone()
	await step(0.6)
	_rocks = RockScatter.new(self, get_material("rock"), random_seed)
	_outcrop()
	_cones_and_pools()
	_boulders()
	_scree()
	_columns()
	_rocks.commit()
	_rim_huts()
	await step(0.85)
	_plumes()
	_fountains()
	_lake_lights()
	ash = AshFall.new()
	ash.name = "AshFall"
	ash.amount = 1400
	ash.box = Vector3(80, 34, 80)
	add_node(ash)


# --- materials -----------------------------------------------------------------------

func _setup_materials() -> void:
	var basalt := ShaderMaterial.new()
	basalt.shader = preload("res://assets/shaders/basalt_fissure.gdshader")
	basalt.set_shader_parameter("lake_centre", Vector3(LAKE_CENTRE.x, LAKE_Y, LAKE_CENTRE.y))
	basalt.set_shader_parameter("lake_radius", LAKE_RADIUS)
	_set_rock_textures(basalt, "dark_rock_02", "rock_ground")
	register_material("basalt", basalt)
	# Boulders and outcrops: all cliff rock, few fissures.
	var rock := basalt.duplicate() as ShaderMaterial
	_set_rock_textures(rock, "dark_rock", "dark_rock_02")
	rock.set_shader_parameter("cliff_tile", 3.0)
	rock.set_shader_parameter("ground_tile", 3.0)
	rock.set_shader_parameter("ground_tint", Color(0.42, 0.4, 0.42))
	rock.set_shader_parameter("background_molten", 0.0)
	rock.set_shader_parameter("molten_reach", 1.0)
	register_material("rock", rock)
	register_material("lava", _lava_material(0.15))
	register_material("lava_open", _lava_material(0.55))
	material("ember", Color(1.0, 0.42, 0.08), 5.0)
	textured("tin", "rusty_corrugated_iron", Color(0.55, 0.5, 0.48), 2.0, 0.6, 0.4)
	material("hut_frame", Color(0.12, 0.11, 0.1), 0.0, 0.3, 0.6)
	material("flag_blue", Color(0.0, 0.5, 0.95))
	material("flag_red", Color(0.85, 0.08, 0.08))
	material("flag_yellow", Color(1.0, 0.85, 0.1))
	material("pole", Color(0.6, 0.6, 0.62), 0.0, 0.6, 0.4)


## Poly Haven sets (see README): cliff faces and flats. Normal maps only if
## present (the web build leaves them out).
static func _set_rock_textures(m: ShaderMaterial, cliff: String, ground: String) -> void:
	for pair: Array in [["cliff", cliff], ["ground", ground]]:
		var base := TEXTURES % [pair[1], pair[1], "diff"]
		m.set_shader_parameter("%s_albedo" % pair[0], load(base) as Texture2D)
		var nor := TEXTURES % [pair[1], pair[1], "nor"]
		if ResourceLoader.exists(nor):
			m.set_shader_parameter("%s_normal" % pair[0], load(nor) as Texture2D)


func _lava_material(openness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/lava_lake.gdshader")
	var vents: Array[Vector4] = []
	for v in VENTS:
		vents.append(Vector4(v.x, v.y, v.z, 0.0))
	vents.append(Vector4(CHANNEL_TO.x, CHANNEL_TO.y, 10.0, 0.0))
	m.set_shader_parameter("vents", vents)
	m.set_shader_parameter("vent_count", vents.size())
	m.set_shader_parameter("openness", openness)
	return m


# --- roads with heights -----------------------------------------------------------------

func _index_roads() -> void:
	_roads.clear()
	var d := 0.0
	var half := track.road_width * 0.5
	while d < track.length:
		var frame := track.road_frame(d)
		var c := track.curve.sample_baked(d)
		_add_road(c, half, frame.x)
		d += 3.0
	for sc in track.shortcuts:
		var sh := sc.road_width * 0.5
		d = 0.0
		while d <= sc.length:
			if not sc.in_gap(d):
				var right := sc.tangent_at(d).cross(Vector3.UP).normalized()
				_add_road(sc.point_at(d), sh, right)
			d += 3.0


func _add_road(c: Vector3, half: float, right: Vector3) -> void:
	var flat := Vector2(right.x, right.z)
	var slope := right.y / maxf(flat.length(), 0.001)
	flat = flat.normalized()
	var key := Vector2i(int(floor(c.x / ROAD_CELL_SIZE)), int(floor(c.z / ROAD_CELL_SIZE)))
	# Packed arrays are values: append to the cell's copy and store it back.
	var cell: PackedFloat32Array = _roads.get(key, PackedFloat32Array())
	cell.append_array(PackedFloat32Array([c.x, c.z, c.y, half, slope, flat.x, flat.y]))
	_roads[key] = cell


## Nearest road sample to (x, z): Vector4(metres past the road edge (negative
## on it), road surface height there, radial distance of the sample from
## the lake centre, found 1/0). Searches 3 cells round the point.
func _nearest_road(x: float, z: float) -> Vector4:
	var cx := int(floor(x / ROAD_CELL_SIZE))
	var cz := int(floor(z / ROAD_CELL_SIZE))
	var best := INF
	var best_y := 0.0
	var best_r := 0.0
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var cell: PackedFloat32Array = _roads.get(Vector2i(cx + dx, cz + dz), PackedFloat32Array())
			var i := 0
			while i < cell.size():
				var ex := x - cell[i]
				var ez := z - cell[i + 1]
				var e := sqrt(ex * ex + ez * ez) - cell[i + 3]
				if e < best:
					best = e
					var lat := clampf(ex * cell[i + 5] + ez * cell[i + 6], -cell[i + 3], cell[i + 3])
					best_y = cell[i + 2] + cell[i + 4] * lat
					best_r = Vector2(cell[i], cell[i + 1]).distance_to(LAKE_CENTRE)
				i += 7
	return Vector4(best, best_y, best_r, 0.0 if best == INF else 1.0)


# --- terrain -------------------------------------------------------------------------

## Ground height at (x, z) (track-local).
func ground_y(x: float, z: float) -> float:
	var r := Vector2(x, z).distance_to(LAKE_CENTRE)
	var road := _nearest_road(x, z)
	var h: float
	if road.w > 0.0:
		var past := maxf(0.0, road.x - HUG)
		if r > road.z:
			# Cut into the wall on the outer side: strata ledges and sheer risers.
			h = road.y - 0.6 + _strata(WALL_SLOPE * past, x, z)
		else:
			# Falling away toward the lake.
			h = road.y - 0.6 - FALL_SLOPE * past + _noise.get_noise_2d(x, z) * 3.0 * smoothstep(HUG, HUG + 25.0, road.x)
	else:
		h = _profile(r) + _noise.get_noise_2d(x, z) * 4.0
	# The ledge round the lake pit (just under the shelf roads); the rim on top.
	h = maxf(h, _floor_at(r) + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.4)
	h = minf(h, _rim_cap(x, z, r) + _noise.get_noise_2d(x * 0.7, z * 0.7) * 6.0)
	# The lava channel's trench, with steep banks.
	var dc := _channel_distance(Vector2(x, z))
	var bank := smoothstep(CHANNEL_WIDTH * 0.5, CHANNEL_WIDTH * 0.5 + 6.0, dc)
	h = minf(h, lerpf(CHANNEL_Y - 1.5, h, bank))
	return h


## A climb of `rise` metres up a wall as strata: flat ledges and sheer
## risers, with the ledge heights wandering a little from place to place.
func _strata(rise: float, x: float, z: float) -> float:
	var phase := (_noise.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5) * 0.6
	var t := rise / STRATA + phase
	var step_h: float = floorf(t) + smoothstep(0.55, 0.95, fposmod(t, 1.0))
	# Ragged edges, fading in from the foot of the wall (never above the road).
	return maxf(0.0, (step_h - phase) * STRATA) + _noise.get_noise_2d(x * 1.5, z * 1.5) * 0.8 * smoothstep(0.0, 4.0, rise)


## Far from any road: the crater bowl.
func _profile(r: float) -> float:
	if r < LAKE_RADIUS + 15.0:
		return _floor_at(r)
	return lerpf(FLOOR_Y, RIM_Y, smoothstep(230.0, 440.0, r))


## The lake pit: under the lava inside, a sheer pit wall, then the black
## ledge (FLOOR_Y) out to the walls.
func _floor_at(r: float) -> float:
	if r < LAKE_RADIUS - 4.0:
		return LAKE_Y - 6.0
	return lerpf(LAKE_Y - 1.5, FLOOR_Y, smoothstep(LAKE_RADIUS - 1.0, LAKE_RADIUS + 3.0, r))


## The rim's top: high all round, a low saddle where the start straight
## crosses the south rim; the volcano's outer flank falls away beyond.
func _rim_cap(x: float, z: float, r: float) -> float:
	var south := Vector2(x - LAKE_CENTRE.x, z - LAKE_CENTRE.y).normalized().dot(Vector2(0.0, 1.0))
	var top := lerpf(RIM_Y, RIM_SADDLE_Y, smoothstep(0.45, 0.8, south))
	return top - maxf(0.0, r - RIM_RADIUS) * 0.6


func _channel_distance(p: Vector2) -> float:
	var ab := CHANNEL_TO - CHANNEL_FROM
	var t := clampf((p - CHANNEL_FROM).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(CHANNEL_FROM + ab * t)


func _terrain() -> void:
	var b := TERRAIN_BOUNDS
	var cell := TERRAIN_CELL
	var nx := int(b.size.x / cell) + 1
	var nz := int(b.size.y / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = ground_y(b.position.x + ix * cell, b.position.y + iz * cell)
	# Smooth normals from the height grid.
	var normals := PackedVector3Array()
	normals.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var hl := heights[iz * nx + maxi(ix - 1, 0)]
			var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
			var hd := heights[maxi(iz - 1, 0) * nx + ix]
			var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
			normals[iz * nx + ix] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
	# One mesh per chunk, so off-screen terrain is culled.
	var tools := {}
	for iz in nz - 1:
		for ix in nx - 1:
			var x0 := b.position.x + ix * cell
			var z0 := b.position.y + iz * cell
			var key := Vector2i(int(floor(x0 / CHUNK)), int(floor(z0 / CHUNK)))
			if not tools.has(key):
				var nst := SurfaceTool.new()
				nst.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = nst
			var st: SurfaceTool = tools[key]
			var idx := [iz * nx + ix, iz * nx + ix + 1, (iz + 1) * nx + ix + 1, (iz + 1) * nx + ix]
			var pos := [Vector3(x0, heights[idx[0]], z0), Vector3(x0 + cell, heights[idx[1]], z0),
					Vector3(x0 + cell, heights[idx[2]], z0 + cell), Vector3(x0, heights[idx[3]], z0 + cell)]
			for k: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(normals[idx[k]])
				st.add_vertex(pos[k])
	for key: Vector2i in tools:
		var mi := add_mesh_instance((tools[key] as SurfaceTool).commit(), get_material("basalt"), "Crater_%d_%d" % [key.x, key.y])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- lava -------------------------------------------------------------------------------

func _lake() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS + 4.0
	disc.bottom_radius = LAKE_RADIUS + 4.0
	disc.height = 0.2
	disc.radial_segments = 96
	disc.rings = 1
	lake_mesh = add_mesh_instance(disc, get_material("lava"), "LavaLake")
	lake_mesh.position = Vector3(LAKE_CENTRE.x, LAKE_Y - 0.1, LAKE_CENTRE.y)
	lake_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The lava channel: an open, brighter strip in its trench from the lake to
## its vent, with a spatter cone at the vent.
func _channel() -> void:
	var ab := CHANNEL_TO - CHANNEL_FROM
	var mid := (CHANNEL_FROM + CHANNEL_TO) * 0.5
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHANNEL_WIDTH + 3.0, ab.length() + 10.0)
	var mi := add_mesh_instance(plane, get_material("lava_open"), "LavaChannel")
	mi.transform = Transform3D(Basis(Vector3.UP, atan2(ab.x, ab.y)), Vector3(mid.x, CHANNEL_Y, mid.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spatter_cone(Vector3(CHANNEL_TO.x, ground_y(CHANNEL_TO.x, CHANNEL_TO.y), CHANNEL_TO.y) + Vector3(-4.0, 0.0, -4.0), 7.0, 6.0)


## Lava recovers any car that reaches it: the lake (rows of boxes over the
## disc, inside its shore) and the channel (one long box down its trench).
## The tops sit well below every road, so only a car that falls in is caught.
func _lava_zone() -> void:
	lava_zone = RecoveryZone.new()
	lava_zone.name = "LavaZone"
	lava_zone.reason = "lava"
	var r := LAKE_RADIUS - 4.0
	var z := -r
	while z < r:
		# Each 10 m strip as wide as the disc at its narrower end.
		var edge := maxf(absf(z), absf(z + 10.0))
		var half := sqrt(maxf(0.0, r * r - edge * edge))
		lava_zone.add_box(Vector3(LAKE_CENTRE.x, LAKE_Y, LAKE_CENTRE.y + z + 5.0), Vector3(half * 2.0, 6.0, 10.0))
		z += 10.0
	var ab := CHANNEL_TO - CHANNEL_FROM
	var mid := (CHANNEL_FROM + CHANNEL_TO) * 0.5
	var shape := lava_zone.add_box(Vector3.ZERO, Vector3(CHANNEL_WIDTH + 2.0, 5.0, ab.length() + 6.0))
	shape.transform = Transform3D(Basis(Vector3.UP, atan2(ab.x, ab.y)), Vector3(mid.x, CHANNEL_Y - 0.5, mid.y))
	add_node(lava_zone)


# --- rock dressing -----------------------------------------------------------------------

## The jagged black rock outcrop the second hairpin turns round, and a
## smaller one in the first.
func _outcrop() -> void:
	for spot: Array in [[OUTCROP, 1.0], [HAIRPIN_1, 0.6]]:
		var c: Vector2 = spot[0]
		var s: float = spot[1]
		var base := ground_y(c.x, c.y)
		for i in 18:
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, 9.0) * s
			var p := Vector3(c.x + cos(a) * d, base, c.y + sin(a) * d)
			if not clear(p, 3.0 * s):
				continue
			var tall := rng.randf_range(7.0, 18.0) * s * (1.25 - d / (10.0 * s))
			_rocks.place(p + Vector3(0, tall * 0.35, 0), Vector3(rng.randf_range(3.0, 5.5) * s, tall, rng.randf_range(3.0, 5.5) * s))


## Spatter cones with glowing throats, and glowing pools, on the crater floor
## and the shelf (off the roads).
func _cones_and_pools() -> void:
	var tries := 0
	while spatter_cones < 12 and tries < 400:
		tries += 1
		var p := _random_floor_point(LAKE_RADIUS + 15.0, 300.0)
		if p == Vector3.INF or not clear(p, 14.0):
			continue
		_spatter_cone(p, rng.randf_range(4.0, 9.0), rng.randf_range(3.0, 7.0))
	tries = 0
	while pools < 24 and tries < 600:
		tries += 1
		var p := _random_floor_point(LAKE_RADIUS + 10.0, 420.0)
		if p == Vector3.INF or not clear(p, 10.0):
			continue
		var radius := rng.randf_range(2.5, 7.0)
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.1
		disc.radial_segments = 16
		var mi := add_mesh_instance(disc, get_material("lava_open"), "Pool")
		mi.position = p + Vector3(0, 0.15, 0)
		mi.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
		mi.rotation.y = rng.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pools += 1


func _spatter_cone(at: Vector3, radius: float, height: float) -> void:
	add_cone("rock", radius, height, Transform3D(Basis(), at))
	add_cyl("ember", radius * 0.28, 0.3, Transform3D(Basis(), at + Vector3(0, height * 0.72, 0)), 8)
	spatter_cones += 1


## A random point on the ground between two radii from the lake centre.
func _random_floor_point(r_min: float, r_max: float) -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(r_min, r_max)
	var x := LAKE_CENTRE.x + cos(a) * r
	var z := LAKE_CENTRE.y + sin(a) * r
	if _channel_distance(Vector2(x, z)) < CHANNEL_WIDTH + 6.0:
		return Vector3.INF
	return Vector3(x, ground_y(x, z), z)


## Jagged boulders and blocks of basalt scattered over the crater floor.
func _boulders() -> void:
	var tries := 0
	while boulders < 420 and tries < 3000:
		tries += 1
		var p := _random_floor_point(LAKE_RADIUS + 8.0, 560.0)
		if p == Vector3.INF or not clear(p, 2.5):
			continue
		var size := rng.randf_range(0.7, 3.4)
		_rocks.place(p + Vector3(0, size * 0.2, 0), Vector3(size * rng.randf_range(0.8, 1.6), size * rng.randf_range(0.5, 1.1), size))
		boulders += 1


## Scree: fans of broken rock at the foot of the walls beside the road.
func _scree() -> void:
	var d := 0.0
	while d < track.length:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var fan := track.surface_point(d, side * (track.road_width * 0.5 + track.barrier_thickness + rng.randf_range(HUG - 4.0, HUG + 2.0)))
		var r_fan := Vector2(fan.x, fan.z).distance_to(LAKE_CENTRE)
		var road := _nearest_road(fan.x, fan.z)
		if road.w > 0.0 and r_fan > road.z and clear(fan, 2.0):
			for k in rng.randi_range(5, 12):
				var p := fan + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-6.0, 6.0))
				if not clear(p, 1.2):
					continue
				p.y = ground_y(p.x, p.z)
				var size := rng.randf_range(0.4, 1.6)
				_rocks.place(p + Vector3(0, size * 0.15, 0), Vector3(size, size * rng.randf_range(0.4, 0.8), size * rng.randf_range(0.8, 1.4)))
				scree += 1
		d += rng.randf_range(18.0, 35.0)


## Clusters of hexagonal basalt columns on the crater floor.
func _columns() -> void:
	var hexagon := PackedVector2Array()
	for k in 6:
		hexagon.append(Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0)))
	var tries := 0
	var clusters := 0
	while clusters < 9 and tries < 300:
		tries += 1
		var c := _random_floor_point(LAKE_RADIUS + 20.0, 330.0)
		if c == Vector3.INF or not clear(c, 12.0):
			continue
		clusters += 1
		for i in rng.randi_range(8, 16):
			var p := c + Vector3(rng.randf_range(-5.0, 5.0), 0, rng.randf_range(-5.0, 5.0))
			if not clear(p, 1.5):
				continue
			var radius := rng.randf_range(0.5, 0.9)
			var height := rng.randf_range(1.5, 7.0)
			var poly := PackedVector2Array()
			for v in hexagon:
				poly.append(v * radius)
			# add_prism extrudes along the transform's z: stand it up.
			var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, rng.randf() * TAU),
					Vector3(p.x, ground_y(p.x, p.z) - 0.5, p.z))
			add_prism("rock", poly, height + 0.5, xf)
			columns += 1


## Tin shelters and a DRC flag on the rim beside the start straight.
func _rim_huts() -> void:
	for i in 5:
		var x := -150.0 + i * 55.0 + rng.randf_range(-10.0, 10.0)
		var z := 420.0 + rng.randf_range(0.0, 15.0)
		var p := Vector3(x, ground_y(x, z), z)
		if not clear(p, 6.0):
			continue
		var xf := xform(p, rng.randf_range(-0.2, 0.2))
		add_box("tin", Vector3(5.0, 2.6, 4.0), xf.translated_local(Vector3(0, 1.3, 0)))
		add_prism("tin", PackedVector2Array([Vector2(-2.7, 0), Vector2(2.7, 0), Vector2(0, 1.2)]), 4.4,
				xf.translated_local(Vector3(0, 2.6, 0)))
		add_box("hut_frame", Vector3(1.0, 2.0, 0.1), xf.translated_local(Vector3(0, 1.0, -2.02)))
		huts += 1
	# The flag: sky blue, a red diagonal edged in yellow, a yellow star.
	var fx := -40.0
	var fz := 412.0
	var base := Vector3(fx, ground_y(fx, fz), fz)
	if clear(base, 1.0):
		add_cyl("pole", 0.08, 9.0, Transform3D(Basis(), base), 8)
		var flag := Transform3D(Basis(), base + Vector3(1.5, 8.0, 0))
		add_box("flag_blue", Vector3(3.0, 2.0, 0.04), flag)
		add_box("flag_yellow", Vector3(3.6, 0.55, 0.05), flag.rotated_local(Vector3.FORWARD, 0.6))
		add_box("flag_red", Vector3(3.6, 0.38, 0.06), flag.rotated_local(Vector3.FORWARD, 0.6))
		add_box("flag_yellow", Vector3(0.4, 0.4, 0.06), flag.translated_local(Vector3(-1.0, 0.55, 0)))


# --- air ----------------------------------------------------------------------------------

## Gas plumes off the vents: they tower over the lake and lean away
## downwind, well clear of the roads.
func _plumes() -> void:
	plumes.clear()
	var winds := [Vector3(3.0, 0.0, -1.2), Vector3(2.6, 0.0, -0.8), Vector3(3.4, 0.0, -1.5)]
	var heights := [240.0, 190.0, 160.0]
	for i in VENTS.size():
		var v := VENTS[i]
		var plume := VolcanicPlume.new()
		plume.name = "Plume%d" % i
		plume.height = heights[i]
		plume.wind = winds[i]
		plume.puff_size = 22.0 + v.z * 0.4
		plume.position = Vector3(v.x, LAKE_Y + 2.0, v.y)
		add_node(plume)
		plumes.append(plume)


## Lava fountains at the vents: glowing blobs thrown up in arcs that fall
## back, in bursts. And low steam round the lake's edge.
func _fountains() -> void:
	fountains.clear()
	var blob := SphereMesh.new()
	blob.radius = 0.6
	blob.height = 1.2
	blob.radial_segments = 6
	blob.rings = 3
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.55, 0.12)
	hot.vertex_color_use_as_albedo = true
	blob.material = hot
	for v in VENTS:
		var p := CPUParticles3D.new()
		p.name = "LavaFountain"
		p.mesh = blob
		p.amount = 90
		p.lifetime = 2.6
		p.explosiveness = 0.55
		p.randomness = 0.6
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = v.z * 0.35
		p.direction = Vector3.UP
		p.spread = 28.0
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 22.0
		p.gravity = Vector3(0, -9.8, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 2.2
		var ramp := Gradient.new()
		ramp.set_color(0, Color(3.0, 2.2, 0.8))
		ramp.set_color(1, Color(0.6, 0.12, 0.02))
		p.color_ramp = ramp
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.position = Vector3(v.x, LAKE_Y + 0.2, v.y)
		p.emitting = true
		add_node(p)
		fountains.append(p)
	# Steam skirt: short, pale plumes along the lake's edge.
	for k in 8:
		var a := TAU * k / 8.0 + rng.randf_range(-0.2, 0.2)
		var steam := VolcanicPlume.new()
		steam.name = "Steam%d" % k
		steam.height = rng.randf_range(35.0, 60.0)
		steam.rise_speed = 3.0
		steam.puff_size = 12.0
		steam.wind = Vector3(1.2, 0.0, -0.6)
		steam.position = Vector3(LAKE_CENTRE.x + cos(a) * (LAKE_RADIUS - 12.0), LAKE_Y + 1.0, LAKE_CENTRE.y + sin(a) * (LAKE_RADIUS - 12.0))
		add_node(steam)


## Orange light thrown up from the lake onto the plumes and walls (Forward+;
## the shaders carry the glow on their own in Compatibility).
func _lake_lights() -> void:
	for p: Vector2 in [Vector2(0, -20), Vector2(-90, -100), Vector2(90, 60)]:
		var light := add_light(Vector3(p.x, LAKE_Y + 25.0, p.y), Color(1.0, 0.45, 0.15), 3.0, 230.0)
		light.shadow_enabled = false
