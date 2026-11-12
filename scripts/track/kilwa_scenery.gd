@tool
class_name KilwaScenery
extends TrackScenery
## Kilwa Kisiwani Ruins (GDD 8.6g): the medieval Swahili trading city on its
## island off Tanzania, late on a mildly overcast afternoon. The lap is a
## maze of right-angle corners: out of a coral-rag village of makuti-roofed
## houses and palms, through the walled forecourt into the Great Mosque,
## whose hypostyle halls the road threads three times (columns stand in
## the road; domed and collapsed bays overhead), out along the coast path
## to the Husuni Kubwa palace (walled lanes with niches, a vaulted gallery,
## the octagonal bathing pool, a terrace jump), back west along the shore
## past the Makutani walls and round the crenellated Gereza fort to the
## village. Shortcuts: the Gereza fort yard and the Small Domed Mosque aisle.
## Positions are layout coordinates matching kilwa_kisiwani.tscn (made by
## gen_kilwa.py in the session scratchpad).

## Section boundaries (layout points on the road, driving order).
const VILLAGE_OUT := Vector2(-336, -100)
const FORECOURT := Vector2(-24, 150)
const HALL_EXIT := Vector2(72, -120)
const SHORE := Vector2(384, -200)
const FORT_IN := Vector2(-60, -252)

## The Great Mosque's hall (x, z, width, depth) on a 12 m grid.
const HALL := Rect2(-48, -120, 144, 192)
const GRID := 12.0
const PALACE := Rect2(228, -204, 182, 284)
const FORT := Rect2(-262, -298, 164, 90)
const POOL := Vector2(342, 68)
const POOL_RADIUS := 12.0
## Palace vaulted gallery: from / to layout points.
const GALLERY_FROM := Vector2(252, -112)
const GALLERY_TO := Vector2(300, 14)
const GALLERY_TOP := 8.5
const SHORE_ARCH := Vector2(120, -252)
## Beach and sea north of this line.
const BEACH_Z := -334.0
const TERRAIN_BOUNDS := Rect2(-800, -1500, 1760, 2000)
const TERRAIN_CELL := 10.0

enum Section { VILLAGE, MOSQUE, PALACE, SHORE, FORT }

## For tests.
var hall: HypostyleHallBuilder
var houses: SwahiliHouseBuilder
var section_offsets: Dictionary = {}
var cannons: int = 0
var merlons: int = 0
var towers: int = 0
var niches: int = 0
var baobabs: int = 0
var flame_trees: int = 0
var palms: int = 0
var dhows: int = 0
## Roofed 4 m cells outside the hall (the palace gallery).
var _roof: Dictionary = {}
const ROOF_CELL := 4.0

var _noise: FastNoiseLite


func build() -> void:
	cannons = 0
	merlons = 0
	towers = 0
	niches = 0
	baobabs = 0
	flame_trees = 0
	palms = 0
	dhows = 0
	_roof.clear()
	cast_shadows = true
	no_shadow_keys = ["terrain_grass", "terrain_sand", "sea", "pool_water", "floor", "court_grass", "niche"]
	_setup_materials()
	_find_sections()
	await step(0.05)
	_great_mosque()
	await step(0.35)
	_palace()
	_fort()
	await step(0.55)
	_shore()
	_coast_path()
	_village()
	await step(0.7)
	_noise = SceneryTerrain.make_noise(random_seed)
	SceneryTerrain.build(self, TERRAIN_BOUNDS, TERRAIN_CELL, 0.7, -0.45, "terrain_grass", "terrain_sand", "sea",
			random_seed, _carve)
	await step(0.85)
	_trees()
	_dhows()
	await step(0.95)


func _setup_materials() -> void:
	# Coral rag: rough fieldstone, warm grey-ochre, with lime plaster patches.
	textured("coral", "old_stone_wall", Color(0.86, 0.74, 0.6), 2.4, 0.95)
	textured("coral_dark", "old_stone_wall", Color(0.66, 0.56, 0.46), 2.4, 0.95)
	textured("plaster", "peeling_painted_wall", Color(0.86, 0.86, 0.8), 3.0, 0.9)
	textured("plaster_old", "patterned_plaster_wall", Color(0.82, 0.74, 0.62), 3.5, 0.92)
	textured("pier", "large_sandstone_blocks", Color(0.9, 0.82, 0.7), 2.0, 0.88)
	textured("arch", "old_stone_wall", Color(0.84, 0.74, 0.62), 2.6, 0.95)
	textured("band", "large_sandstone_blocks", Color(0.94, 0.88, 0.78), 1.6, 0.85)
	textured("ceiling", "patterned_plaster_wall", Color(0.62, 0.55, 0.47), 4.0, 0.95)
	textured("dome", "patterned_plaster_wall", Color(0.84, 0.78, 0.68), 3.0, 0.92)
	textured("rubble", "old_stone_wall", Color(0.78, 0.68, 0.56), 1.2, 0.96)
	textured("floor", "brown_mud_leaves_01", Color(0.9, 0.82, 0.7), 5.0, 0.97)
	textured("court_grass", "withered_grass", Color(0.8, 0.85, 0.55), 5.0, 0.97)
	textured("terrain_grass", "sparse_grass", Color(0.62, 0.74, 0.4), 9.0, 0.97)
	textured("terrain_sand", "brown_mud_leaves_01", Color(1.0, 0.9, 0.72), 7.0, 0.97)
	textured("thatch", "reed_roof_04", Color(0.78, 0.66, 0.48), 2.5, 0.95)
	textured("cannon", "rust_coarse_01", Color(0.62, 0.42, 0.3), 1.5, 0.7, 0.4)
	textured("frame", "large_sandstone_blocks", Color(0.92, 0.86, 0.76), 1.5, 0.85)
	material("door", Color(0.26, 0.17, 0.1), 0.0, 0.0, 0.8)
	material("shutter", Color(0.22, 0.2, 0.17), 0.0, 0.0, 0.85)
	material("niche", Color(0.24, 0.2, 0.17), 0.0, 0.0, 1.0)
	material("beam", Color(0.3, 0.22, 0.15), 0.0, 0.0, 0.9)
	material("bark", Color(0.42, 0.36, 0.3), 0.0, 0.0, 0.9)
	material("baobab", Color(0.55, 0.48, 0.42), 0.0, 0.0, 0.95)
	material("canopy", Color(0.22, 0.4, 0.16), 0.0, 0.0, 0.85)
	material("flame", Color(0.86, 0.16, 0.08), 0.0, 0.0, 0.8)
	material("palm_leaf", Color(0.3, 0.46, 0.18), 0.0, 0.0, 0.85)
	material("hull", Color(0.36, 0.25, 0.16), 0.0, 0.0, 0.85)
	material("sail", Color(0.9, 0.86, 0.76), 0.0, 0.0, 0.9)
	material("far_land", Color(0.3, 0.38, 0.26), 0.0, 0.0, 1.0)
	var sea := StandardMaterial3D.new()
	sea.albedo_color = Color(0.32, 0.46, 0.46)
	sea.roughness = 0.18
	sea.metallic = 0.3
	register_material("sea", sea)
	var pool := StandardMaterial3D.new()
	pool.albedo_color = Color(0.24, 0.3, 0.26)
	pool.roughness = 0.1
	pool.metallic = 0.25
	register_material("pool_water", pool)


# --- layout --------------------------------------------------------------------------

func _offset_of(p: Vector2) -> float:
	return track.curve.get_closest_offset(Vector3(p.x, 0, p.y))


func _find_sections() -> void:
	section_offsets = {"village": _offset_of(VILLAGE_OUT), "mosque": _offset_of(FORECOURT),
			"palace": _offset_of(HALL_EXIT), "shore": _offset_of(SHORE), "fort": _offset_of(FORT_IN)}


func section_at(offset: float) -> int:
	var o := track.wrap_offset(offset)
	var s := section_offsets
	if o >= s.village and o < s.mosque:
		return Section.VILLAGE
	if o >= s.mosque and o < s.palace:
		return Section.MOSQUE
	if o >= s.palace and o < s.shore:
		return Section.PALACE
	if o >= s.shore and o < s.fort:
		return Section.SHORE
	return Section.FORT


## Under the mosque ceiling or the palace gallery vault.
func is_roofed(p: Vector3) -> bool:
	if hall != null and hall.is_roofed(p):
		return true
	return _roof.has(Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL))))


## Walks the main road from one offset to another (wrapping) in steps.
func _walk(from_o: float, to_o: float, stepm: float, fn: Callable) -> void:
	var span := fposmod(to_o - from_o, track.length)
	var d := 0.0
	while d < span:
		fn.call(track.wrap_offset(from_o + d))
		d += stepm


## Transform on a wall face with local Z pointing out of it (for niches).
func _out_xf(face: Vector3, out: Vector3) -> Transform3D:
	out.y = 0.0
	return Transform3D(Basis.looking_at(-out.normalized(), Vector3.UP), face)


## Transform at a point facing `toward` (local -Z toward it).
func _facing(pos: Vector3, toward: Vector3) -> Transform3D:
	var dir := toward - pos
	dir.y = 0.0
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), pos)


# --- the Great Mosque ----------------------------------------------------------------

func _great_mosque() -> void:
	hall = HypostyleHallBuilder.new(self, HALL, GRID)
	hall.spring = 3.4
	hall.rise = 6.0
	hall.top = 10.2
	# The collapsed dome with a tree growing up through it (between lanes 2
	# and 3), light shafts over each lane, small domes over the side aisle.
	hall.force_broken = {Vector2i(7, 5): true}
	hall.force_collapsed = {Vector2i(1, 9): true, Vector2i(10, 3): true, Vector2i(5, 13): true}
	for gx in range(6, 10):
		for gz in range(8, 11):
			hall.force_domes[Vector2i(gx, gz)] = true
	hall.build()
	# Floor (the terrain is flattened just below it).
	add_box("floor", Vector3(HALL.size.x, 0.2, HALL.size.y),
			xform(Vector3(HALL.get_center().x, -0.16, HALL.get_center().y)))
	var tree_spot := hall.point(Vector2i(7, 5)) + Vector3(GRID * 0.5, 0, GRID * 0.5)
	var trees := TreeBuilder.new(self, "bark", "canopy", random_seed + 11)
	trees.place("rainforest", Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 0.75), tree_spot))
	trees.commit()
	_hall_walls()
	_forecourt()


## The hall's outer walls: coral rag with buttresses, pointed niches on the
## outside, a crenellated parapet, and a tall pishtaq portal where the road
## goes in and out.
func _hall_walls() -> void:
	var h := hall.top + 1.2
	var t := 1.6
	var corners := [Vector3(HALL.position.x, 0, HALL.position.y), Vector3(HALL.end.x, 0, HALL.position.y),
			Vector3(HALL.end.x, 0, HALL.end.y), Vector3(HALL.position.x, 0, HALL.end.y)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var out := ((a + b) * 0.5 - Vector3(HALL.get_center().x, 0, HALL.get_center().y)).normalized()
		_wall_run(a, b, h, t, "coral", out, 6.0)
	for p in corners:
		add_box("coral_dark", Vector3(3.0, h + 1.5, 3.0), xform(p + Vector3(0, (h + 1.5) * 0.5, 0)))
	# Portals where the road crosses the walls.
	_pishtaq(Vector3(-24, 0, HALL.end.y), 0.0)
	_pishtaq(Vector3(72, 0, HALL.position.y), 0.0)


## A straight wall from a to b in 3 m pieces, left out where a road passes;
## each unbroken run gets a crenellated top. `out` is the outer face's
## normal for niches every niche_every metres (0 = none).
func _wall_run(a: Vector3, b: Vector3, h: float, t: float, key: String, out: Vector3, niche_every: float,
		crenels: bool = true) -> void:
	var dir := b - a
	var length := dir.length()
	var n := maxi(1, int(round(length / 3.0)))
	var seg := length / n
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var run_start := -1
	var next_niche := niche_every * 0.5
	for i in n + 1:
		var ok := false
		var mid := a + dir * ((i + 0.5) / n)
		if i < n:
			ok = edge_distance(mid) > t * 0.5 + 1.2
		if ok:
			add_box(key, Vector3(t, h, seg + 0.05), Transform3D(basis, mid + Vector3(0, h * 0.5, 0)))
			if run_start < 0:
				run_start = i
			if niche_every > 0.0 and (i + 0.5) * seg >= next_niche and i > run_start and edge_distance(mid + out * 3.0) > 1.0:
				next_niche += niche_every
				var face := mid + out * (t * 0.5)
				PointedArch.niche(self, "niche", "frame", _out_xf(face, out), 1.6, 3.2)
				niches += 1
		elif run_start >= 0:
			if crenels:
				merlons += PointedArch.crenellate(self, "coral", a + dir * (float(run_start) / n) + Vector3(0, h, 0),
						a + dir * (float(i) / n) + Vector3(0, h, 0), t)
			run_start = -1


## A tall portal frame (pishtaq) over the road: two square towers and a
## pointed arch spanning the road, with a crenellated top.
func _pishtaq(centre: Vector3, extra: float) -> void:
	var o := track.curve.get_closest_offset(centre)
	var f := at(o)
	var half := track.road_width * 0.5 + track.barrier_thickness + 1.2
	var top := 19.0 + extra
	for s in [-1.0, 1.0]:
		var p := f.translated_local(Vector3(s * (half + 1.3), 0, 0))
		add_box("coral", Vector3(2.6, top, 3.0), p.translated_local(Vector3(0, top * 0.5, 0)))
		add_box("frame", Vector3(2.9, 0.5, 3.3), p.translated_local(Vector3(0, 4.2, 0)))
	PointedArch.arch_wall(self, "coral", f, half * 2.0, 4.2, 12.6, top, 3.0, "band", 0.7)
	merlons += PointedArch.crenellate(self, "coral", f * Vector3(-half - 2.6, top, 0), f * Vector3(half + 2.6, top, 0), 3.0)
	towers += 1


## The walled forecourt in front of the mosque gate: low plastered walls
## along the road and an ablution tank.
func _forecourt() -> void:
	var from := _offset_of(FORECOURT)
	var to := _offset_of(Vector2(-24, HALL.end.y))
	_lane_walls(from, to, 2.4, "plaster_old", 0.0, false)
	var tank := Vector3(-48, 0, 112)
	if clear(tank, 6.0):
		add_box("plaster", Vector3(10, 0.9, 6), xform(tank + Vector3(0, 0.45, 0)))
		add_box("pool_water", Vector3(9, 0.1, 5), xform(tank + Vector3(0, 0.8, 0)))


## Walls lining both sides of the main road between two offsets, just
## behind the barriers (the maze's walls), in 3 m pieces, left out near
## other roads. niche_every > 0 adds pointed niches on the road side.
func _lane_walls(from_o: float, to_o: float, h: float, key: String, niche_every: float, crenels: bool,
		ruin: float = 0.0) -> void:
	var lat := track.road_width * 0.5 + track.barrier_thickness + 0.9
	var counter := [0]
	_walk(from_o, to_o, 3.0, func(o: float) -> void:
		counter[0] += 1
		for s in [-1.0, 1.0]:
			var f := at(o, s * lat)
			if edge_distance(f.origin) < 1.6 or (Vector2(f.origin.x, f.origin.z) - POOL).length() < POOL_RADIUS + 3.0:
				continue
			var wh := h
			if ruin > 0.0:
				if rng.randf() < ruin * 0.4:
					continue
				wh = h * rng.randf_range(1.0 - ruin, 1.0)
			add_box(key, Vector3(0.9, wh, 3.15), f.translated_local(Vector3(0, wh * 0.5, 0)))
			if crenels and counter[0] % 2 == 0 and ruin == 0.0:
				add_box(key, Vector3(0.9, 0.6, 1.0), f.translated_local(Vector3(0, wh + 0.3, 0)))
				merlons += 1
			if niche_every > 0.0 and counter[0] % int(niche_every / 3.0) == 0:
				var face := f.translated_local(Vector3(-s * 0.45, 0, 0)).origin
				PointedArch.niche(self, "niche", "frame", _out_xf(face, at(o).origin - face), 1.5, minf(3.0, wh - 0.8))
				niches += 1)


# --- Husuni Kubwa palace -------------------------------------------------------------

func _palace() -> void:
	var gal_from := _offset_of(GALLERY_FROM)
	var gal_to := _offset_of(GALLERY_TO)
	var from := _offset_of(Vector2(PALACE.position.x, -156))
	var to := _offset_of(Vector2(384, PALACE.position.y))
	# Walled lanes with niches, except along the gallery.
	_lane_walls(from, gal_from, 5.5, "coral", 9.0, true)
	_lane_walls(gal_to, to, 5.5, "coral", 9.0, true)
	_gallery(gal_from, gal_to)
	# Palace precinct wall (broken where the road passes).
	var c := [Vector3(PALACE.position.x, 0, PALACE.position.y), Vector3(PALACE.end.x, 0, PALACE.position.y),
			Vector3(PALACE.end.x, 0, PALACE.end.y), Vector3(PALACE.position.x, 0, PALACE.end.y)]
	var centre := Vector3(PALACE.get_center().x, 0, PALACE.get_center().y)
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		_wall_run(a, b, 7.0, 1.4, "coral", ((a + b) * 0.5 - centre).normalized(), 8.0)
	_pishtaq(Vector3(PALACE.position.x, 0, -156), -3.0)
	_bathing_pool()
	# Courts: a sandy floor and ruined rooms in the blocks between lanes.
	add_box("floor", Vector3(PALACE.size.x, 0.2, PALACE.size.y), xform(Vector3(centre.x, -0.16, centre.z)))
	for i in 70:
		var p := Vector3(rng.randf_range(PALACE.position.x + 8, PALACE.end.x - 8), 0,
				rng.randf_range(PALACE.position.y + 8, PALACE.end.y - 8))
		_ruined_room(p, rng.randf_range(6, 11), rng.randf_range(5, 8), rng.randf_range(2.0, 4.5), "coral")


## The vaulted gallery: arcades on piers just behind both barriers and a
## stone ceiling across the road.
func _gallery(from_o: float, to_o: float) -> void:
	var lat := track.road_width * 0.5 + track.barrier_thickness + 0.9
	var prev := {}
	var span := fposmod(to_o - from_o, track.length)
	var d := 0.0
	while d <= span:
		var o := track.wrap_offset(from_o + d)
		for s in [-1.0, 1.0]:
			var p := at(o, s * lat)
			if edge_distance(p.origin) < 1.2:
				prev.erase(s)
				continue
			add_box("pier", Vector3(1.4, GALLERY_TOP, 1.4), p.translated_local(Vector3(0, GALLERY_TOP * 0.5, 0)))
			if prev.has(s):
				var a: Vector3 = prev[s]
				var b := p.origin
				var gap := a.distance_to(b) - 1.4
				if gap > 2.0:
					var xf := Transform3D(Basis.looking_at((b - a).normalized().cross(Vector3.UP), Vector3.UP), (a + b) * 0.5)
					PointedArch.arch_wall(self, "arch", xf, gap, 3.6, gap * 0.62, GALLERY_TOP, 1.2, "band", 0.35)
			prev[s] = p.origin
		d += 8.0
	# Ceiling slab in 4 m pieces, marked as roof for Overdrive flights.
	_walk(from_o, to_o, 4.0, func(o: float) -> void:
		var f := at(o)
		add_box("ceiling", Vector3(lat * 2.0 + 1.4, 0.9, 4.4), f.translated_local(Vector3(0, GALLERY_TOP + 0.45, 0)))
		for k in range(-int(lat), int(lat) + 1, 2):
			var p := f * Vector3(k, 0, 0)
			_roof[Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL)))] = true)


## The octagonal bathing pool beside the road (its spill floods the road:
## the PoolWater feature).
func _bathing_pool() -> void:
	var c := Vector3(POOL.x, 0, POOL.y)
	for i in 8:
		var a0 := TAU * i / 8.0 + PI / 8.0
		var a1 := TAU * (i + 1) / 8.0 + PI / 8.0
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * POOL_RADIUS
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * POOL_RADIUS
		var mid := (p0 + p1) * 0.5
		add_box("band", Vector3(1.0, 0.8, p0.distance_to(p1) + 0.6),
				Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), mid + Vector3(0, 0.25, 0)))
		# Steps down into it.
		add_box("pier", Vector3(1.6, 0.3, p0.distance_to(p1) * 0.8),
				Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), mid.lerp(c, 0.12) + Vector3(0, -0.2, 0)))
	add_cyl("pool_water", POOL_RADIUS - 0.6, 0.05, xform(c + Vector3(0, -0.12, 0)), 8)


## A small roofless room: four low walls with a doorway, if it's clear of
## the roads.
func _ruined_room(p: Vector3, w: float, d: float, h: float, key: String) -> bool:
	var xf := xform(p, rng.randi() % 4 * PI * 0.5)
	if not clear_rect(xf, w + 2.0, d + 2.0) or (Vector2(p.x, p.z) - POOL).length() < POOL_RADIUS + w:
		return false
	var t := 0.7
	var walls := [[Vector3(0, 0, -d * 0.5), w, 0.0], [Vector3(0, 0, d * 0.5), w, 0.0],
			[Vector3(-w * 0.5, 0, 0), d, PI * 0.5], [Vector3(w * 0.5, 0, 0), d, PI * 0.5]]
	for i in 4:
		var wl: float = walls[i][1]
		var wxf := xf * Transform3D(Basis(Vector3.UP, walls[i][2]), walls[i][0])
		if i == 0:
			var side := (wl - 1.6) * 0.5
			for s in [-1.0, 1.0]:
				var hh := h * rng.randf_range(0.6, 1.0)
				add_box(key, Vector3(side, hh, t), wxf.translated_local(Vector3(s * (side + 1.6) * 0.5, hh * 0.5, 0)))
		else:
			var hh := h * rng.randf_range(0.5, 1.0)
			add_box(key, Vector3(wl + t, hh, t), wxf.translated_local(Vector3(0, hh * 0.5, 0)))
	return true


# --- Gereza fort ---------------------------------------------------------------------

func _fort() -> void:
	var h := 8.5
	var t := 2.2
	var c := [Vector3(FORT.position.x, 0, FORT.position.y), Vector3(FORT.end.x, 0, FORT.position.y),
			Vector3(FORT.end.x, 0, FORT.end.y), Vector3(FORT.position.x, 0, FORT.end.y)]
	var centre := Vector3(FORT.get_center().x, 0, FORT.get_center().y)
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		_wall_run(a, b, h, t, "coral", ((a + b) * 0.5 - centre).normalized(), 0.0)
	# Yard.
	add_box("court_grass", Vector3(FORT.size.x, 0.2, FORT.size.y), xform(Vector3(centre.x, -0.16, centre.z)))
	# Round tower (north-west) with merlons round its top, square towers.
	var round_c: Vector3 = c[0] + Vector3(6, 0, 6)
	add_cyl("coral", 7.5, 14.0, xform(round_c), 16, 7.0)
	for i in 14:
		var a := TAU * i / 14.0
		add_box("coral", Vector3(1.4, 1.3, 1.2), _facing(round_c + Vector3(cos(a) * 6.5, 14.6, sin(a) * 6.5), round_c + Vector3(0, 14.6, 0)))
		merlons += 1
	towers += 1
	for p in [c[1] + Vector3(-5, 0, 5), c[2] + Vector3(-5, 0, -5), c[3] + Vector3(5, 0, -5)]:
		var th := rng.randf_range(10.0, 12.5)
		add_box("coral", Vector3(10, th, 10), xform(p + Vector3(0, th * 0.5, 0)))
		for e in 4:
			var a: Vector3 = Vector3(-5, th, -5).rotated(Vector3.UP, e * PI * 0.5) + p
			var b: Vector3 = Vector3(5, th, -5).rotated(Vector3.UP, e * PI * 0.5) + p
			merlons += PointedArch.crenellate(self, "coral", a, b, 1.0, 1.0, 1.8)
		# Little square windows high up (photo: Gereza's upper rooms).
		for e in 4:
			var face: Vector3 = p + Vector3(0, th - 3.0, 5.05).rotated(Vector3.UP, e * PI * 0.5)
			add_box("niche", Vector3(1.4, 1.4, 0.1), _facing(face, p + Vector3(0, th - 3.0, 0)))
		towers += 1
	# Gate: a pointed arch where the yard road leaves the east wall.
	var sc := track.get_node_or_null("GerezaFortYard") as TrackShortcut
	if sc == null or not sc.is_valid():
		return
	var gate_d := 0.0
	var best := INF
	var dd := 0.0
	while dd < sc.length:
		var gx := absf(sc.point_at(dd).x - FORT.end.x)
		if gx < best:
			best = gx
			gate_d = dd
		dd += 1.0
	var gp := sc.point_at(gate_d)
	var gt := sc.tangent_at(gate_d)
	var gxf := Transform3D(Basis.looking_at(gt, Vector3.UP), gp)
	var half := sc.road_width * 0.5 + track.barrier_thickness + 0.4
	for s in [-1.0, 1.0]:
		add_box("coral", Vector3(1.6, h + 1.0, t + 0.6), gxf.translated_local(Vector3(s * (half + 0.8), (h + 1.0) * 0.5, 0)))
	PointedArch.arch_wall(self, "coral", gxf, half * 2.0, 3.8, half * 1.25, h + 1.0, t + 0.6, "band", 0.5)
	# Cannons in the yard, a fallen beam, steps up to the ramparts.
	for k in 4:
		var d := sc.length * (0.25 + 0.15 * k)
		var side := -1.0 if k % 2 == 0 else 1.0
		var tang := sc.tangent_at(d)
		var right := tang.cross(Vector3.UP).normalized()
		var p := sc.point_at(d) + right * side * (sc.road_width * 0.5 + track.barrier_thickness + 2.2)
		if not clear(p, 0.5) and edge_distance(p) < 1.0:
			continue
		var yaw := rng.randf_range(-0.6, 0.6)
		var cxf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 - 0.08), p + Vector3(0, 0.45, 0))
		add_cyl("cannon", 0.42, 3.2, cxf.translated_local(Vector3(0, -1.6, 0)), 10, 0.32)
		add_cyl("cannon", 0.5, 0.35, cxf.translated_local(Vector3(0, -1.75, 0)), 10)
		cannons += 1
	var bp := sc.point_at(sc.length * 0.5) + Vector3(0, 0.3, 0)
	var br := sc.tangent_at(sc.length * 0.5).cross(Vector3.UP).normalized()
	add_box("beam", Vector3(0.5, 0.5, 6.0), _facing(bp + br * 10.5, bp + br * 10.5 + sc.tangent_at(sc.length * 0.5).rotated(Vector3.UP, 0.4)))
	for k in 6:
		var sp: Vector3 = c[0] + Vector3(30 + k * 1.2, 0, t + 1.0)
		add_box("coral", Vector3(1.2, (k + 1) * 1.2, 2.2), xform(sp + Vector3(0, (k + 1) * 0.6, 0)))


# --- shore, coast path, village ------------------------------------------------------

## The shore straight: a low sea wall and beach to the north, the Makutani
## palace walls (crenellated, with niches) to the south, and a great
## gateway arch over the road at the boost ring.
func _shore() -> void:
	var from := _offset_of(SHORE)
	var to := _offset_of(FORT_IN)
	var lat := track.road_width * 0.5 + track.barrier_thickness + 0.9
	var counter := [0]
	_walk(from, to, 3.0, func(o: float) -> void:
		counter[0] += 1
		var sea_side := at(o, -lat)
		var land := at(o, lat)
		# The sea side is the one further north.
		if sea_side.origin.z > land.origin.z:
			var tmp := sea_side
			sea_side = land
			land = tmp
		if edge_distance(sea_side.origin) > 1.6:
			add_box("coral_dark", Vector3(0.9, 1.1, 3.15), sea_side.translated_local(Vector3(0, 0.55, 0)))
		if edge_distance(land.origin) > 1.6 and land.origin.x > FORT.end.x + 30.0:
			var hh := 6.5 if (counter[0] / 8) % 3 != 2 else 3.0
			add_box("coral", Vector3(0.9, hh, 3.15), land.translated_local(Vector3(0, hh * 0.5, 0)))
			if counter[0] % 2 == 0 and hh > 5.0:
				add_box("coral", Vector3(0.9, 0.6, 1.0), land.translated_local(Vector3(0, hh + 0.3, 0)))
				merlons += 1
			if counter[0] % 5 == 0 and hh > 5.0:
				var in_dir := at(o).origin - land.origin
				var face := land.origin + Vector3(in_dir.x, 0, in_dir.z).normalized() * 0.45
				PointedArch.niche(self, "niche", "frame", _out_xf(face, in_dir), 1.5, 3.4)
				niches += 1)
	_pishtaq(Vector3(SHORE_ARCH.x, 0, SHORE_ARCH.y), -1.0)
	# Rooms of the Makutani compound behind its wall.
	for i in 40:
		var p := Vector3(rng.randf_range(-60, 360), 0, rng.randf_range(-232, -176))
		_ruined_room(p, rng.randf_range(6, 10), rng.randf_range(5, 7), rng.randf_range(2.0, 5.0), "coral")


## The coast path from the mosque to the palace: ruined low walls, and
## baobabs and flame trees in the grass.
func _coast_path() -> void:
	var from := _offset_of(HALL_EXIT)
	var to := _offset_of(Vector2(PALACE.position.x, -156))
	_lane_walls(from, to, 2.2, "coral_dark", 0.0, false, 0.7)
	for p in [Vector2(120, -184), Vector2(196, -126), Vector2(150, -120)]:
		var v := Vector3(p.x, 0, p.y)
		if clear(v, 4.0):
			_baobab(v)
	for p in [Vector2(104, -128), Vector2(220, -186), Vector2(-60, -150), Vector2(-120, 130)]:
		var v := Vector3(p.x, 0, p.y)
		if clear(v, 3.0):
			_flame_tree(v)


func _village() -> void:
	houses = SwahiliHouseBuilder.new(self, ["plaster", "plaster_old", "coral"])
	var from := _offset_of(VILLAGE_OUT)
	var to := _offset_of(FORECOURT)
	# A row of houses either side of the streets.
	var lat0 := track.road_width * 0.5 + track.barrier_thickness + 2.5
	_walk(from, to, 13.0, func(o: float) -> void:
		for s in [-1.0, 1.0]:
			var w := rng.randf_range(7.0, 11.0)
			var d := rng.randf_range(5.5, 7.5)
			var f := at(o, s * (lat0 + d * 0.5 + rng.randf_range(0.0, 2.5)))
			var road_pt := at(o).origin
			var xf := _facing(f.origin, road_pt)
			if rng.randf() < 0.15 or not clear_rect(xf, w + 1.0, d + 1.0):
				continue
			houses.house(xf, w, d, {"ruined": rng.randf() < 0.18, "flat": rng.randf() < 0.15}))
	# And the rest of the village round about.
	for i in 520:
		var p := Vector3(rng.randf_range(-520, -40), 0, rng.randf_range(-80, 340))
		if FORT.grow(30).has_point(Vector2(p.x, p.z)) or HALL.grow(20).has_point(Vector2(p.x, p.z)):
			continue
		var w := rng.randf_range(7.0, 11.0)
		var d := rng.randf_range(5.5, 7.5)
		var xf := xform(p, (rng.randi() % 4) * PI * 0.5)
		if edge_distance(p) < 8.0 or not clear_rect(xf, w + 3.0, d + 3.0):
			continue
		houses.house(xf, w, d, {"ruined": rng.randf() < 0.2, "flat": rng.randf() < 0.15})


# --- trees, terrain, sea -------------------------------------------------------------

func _trees() -> void:
	var trees := TreeBuilder.new(self, "bark", "palm_leaf", random_seed + 5)
	for i in 2600:
		var x := rng.randf_range(-700, 760)
		var z := rng.randf_range(-330, 460)
		var p := Vector3(x, 0, z)
		if HALL.grow(4).has_point(Vector2(x, z)) or FORT.grow(4).has_point(Vector2(x, z)) \
				or PALACE.grow(2).has_point(Vector2(x, z)):
			continue
		if not clear(p, 2.5):
			continue
		var near_village := x < -20 and z > -100
		var on_shore := z < -300
		if not (near_village or on_shore) and rng.randf() < 0.6:
			continue
		var kind := "palm" if (on_shore or rng.randf() < 0.7) else "rainforest"
		var s := rng.randf_range(0.75, 1.15) if kind == "palm" else rng.randf_range(0.4, 0.7)
		trees.place(kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s),
				Vector3(x, ground_y(x, z) - 0.2, z)))
		if kind == "palm":
			palms += 1
	trees.commit()
	for p in [Vector2(-420, 40), Vector2(-150, 290), Vector2(460, -40)]:
		var v := Vector3(p.x, 0, p.y)
		if clear(v, 4.0):
			_baobab(v)


## A baobab: a fat, slightly tapering trunk with stubby branches and a thin crown.
func _baobab(p: Vector3) -> void:
	add_cyl("baobab", 2.4, 8.5, xform(p), 12, 1.8)
	for i in 7:
		var yaw := TAU * i / 7.0 + rng.randf() * 0.4
		var tilt := rng.randf_range(0.45, 0.9)
		var len := rng.randf_range(3.0, 5.0)
		var base := p + Vector3(0, 8.2, 0)
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt), sin(tilt) * sin(yaw))
		add_cyl("baobab", 0.5, len, Transform3D(Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir)), base), 6, 0.25)
		add_sphere("canopy", 1.4, xform(base + dir * len).scaled_local(Vector3(1.3, 0.6, 1.3)), 4, 6)
	baobabs += 1


## A flamboyant (flame tree): short trunk, wide flat crown of red flowers.
func _flame_tree(p: Vector3) -> void:
	add_cyl("bark", 0.45, 4.2, xform(p), 8, 0.35)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var c := p + Vector3(cos(a) * rng.randf_range(2.0, 4.5), rng.randf_range(4.6, 5.6), sin(a) * rng.randf_range(2.0, 4.5))
		add_sphere("flame" if i % 3 != 2 else "canopy", rng.randf_range(2.2, 3.0), xform(c).scaled_local(Vector3(1.4, 0.45, 1.4)), 4, 8)
	flame_trees += 1


## Terrain lift: flattened just under the floors of the hall, palace and
## fort; a beach dropping into the sea to the north; the mainland coast
## across the channel.
func _carve(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if HALL.has_point(p) or PALACE.has_point(p) or FORT.has_point(p):
		return -0.25 - SceneryTerrain.height_at(self, _noise, 0.7, x, z)
	var down := 0.0
	if z < BEACH_Z:
		down = -smoothstep(BEACH_Z, BEACH_Z - 60.0, z) * 4.0
	if z < -1150.0:
		var hills := (_noise.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5) * 30.0
		down += smoothstep(-1150.0, -1300.0, z) * (8.0 + hills)
	return down


func ground_y(x: float, z: float) -> float:
	return SceneryTerrain.height_at(self, _noise, 0.7, x, z, _carve)


## Dhows on the channel: a curved-ish hull, a raked mast and a lateen sail.
func _dhows() -> void:
	for p in [Vector3(-160, 0, -470), Vector3(140, 0, -620), Vector3(420, 0, -520), Vector3(-460, 0, -760)]:
		var xf := xform(p + Vector3(0, -0.4, 0), rng.randf() * TAU)
		add_prism("hull", PackedVector2Array([Vector2(-7, 1.6), Vector2(7.5, 2.2), Vector2(5, 0), Vector2(-5, 0)]), 3.2,
				xf.rotated_local(Vector3.UP, PI * 0.5))
		var mast := xf.translated_local(Vector3(0, 1.6, 1.0))
		add_cyl("beam", 0.18, 10.0, mast.rotated_local(Vector3.RIGHT, -0.15), 6, 0.12)
		add_prism("sail", PackedVector2Array([Vector2(-6, 4), Vector2(5, 11.5), Vector2(3, 2.5)]), 0.08,
				xf.translated_local(Vector3(0, 1.0, 1.4)).rotated_local(Vector3.UP, PI * 0.5))
		dhows += 1
