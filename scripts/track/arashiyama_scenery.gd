@tool
class_name ArashiyamaScenery
extends TrackScenery
## Arashiyama Circuit (GDD 8.6): a paved stone road through Kyoto's bamboo
## grove on a soft, sunny day. It should feel like an indoor garden out of
## doors: tall culms bow in from both sides until their leaves close over
## the road like a green ceiling, the sun comes through in shafts and
## dapples, and brushwood fences with bamboo rails line the way. In driving
## order: an open start plaza with stone lanterns and banners; the timber
## ARASHIYAMA gate into the grove; the grove's S-bends; a long wooden bridge
## over the Katsura river (the first open sky, with the mountains behind);
## hillside sweepers past mossy retaining walls and red maples; a
## rain-soaked stretch of wet stone; and a walled temple garden (pond, moss,
## clipped shrubs, raked gravel, a temple hall) before the grove closes in
## again to the finish. The shortcut is a narrow shrine path through black
## torii, blocked by fallen bamboo. Positions are layout coordinates
## matching arashiyama_circuit.tscn.

const TERRAIN_BOUNDS := Rect2(-420, -150, 1180, 960)
const TERRAIN_SEED := 3
const TERRAIN_AMPLITUDE := 1.0
const WATER_LEVEL := -2.6

## Zone starts (points on the main road), in driving order.
const START_FROM := Vector3(-215, 0, 0)
const GROVE_FROM := Vector3(0, 0, 0)
const BRIDGE_FROM := Vector3(556, 0, 95)
const BRIDGE_TO := Vector3(569, 0, 250)
const RAIN_FROM := Vector3(505, 0, 535)
const RAIN_TO := Vector3(120, 0, 637)
const GARDEN_FROM := Vector3(-268, 0, 490)
const GARDEN_TO := Vector3(-205, 0, 259)

## The Katsura river: flows west along RIVER_Z (with a gentle wave) under
## the bridge into a pond inside the loop.
const RIVER_Z := 172.0
const RIVER_HALF := 32.0
const RIVER_DEPTH := 4.5
const POND := Vector3(380, 0, 235)
const POND_RADIUS := 50.0
## The hillside rises east of this x beside the sweepers.
const HILL_X := 592.0
const HILL_Z := Vector2(250, 600)

## The walled temple garden (x, z rect) and what's in it.
const GARDEN := Rect2(-292, 255, 272, 225)
const GARDEN_POND := Vector3(-222, 0, 352)
const GARDEN_POND_RADIUS := 28.0
const GRAVEL := Rect2(-105, 330, 70, 115)
const HALL := Vector3(-70, 0, 300)

## Fraction of the main road under the canopy is measured on this grid (m).
const COVER_CELL := 2.0
const OPEN_CELL := 4.0

var _noise: FastNoiseLite
var _cover: Dictionary = {}
var _open: Dictionary = {}
## Vector2i (10 m cell) -> Array of [Vector3, radius]: spots kept free of bamboo.
var _reserved: Dictionary = {}
var _offsets: Dictionary = {}
var bamboo: BambooBuilder


func build() -> void:
	_setup_materials()
	_cover.clear()
	_open.clear()
	_reserved.clear()
	_noise = SceneryTerrain.make_noise(TERRAIN_SEED)
	_offsets = {
		"start": _off(START_FROM), "grove": _off(GROVE_FROM),
		"bridge_from": _off(BRIDGE_FROM), "bridge_to": _off(BRIDGE_TO),
		"rain_from": _off(RAIN_FROM), "rain_to": _off(RAIN_TO),
		"garden_from": _off(GARDEN_FROM), "garden_to": _off(GARDEN_TO),
	}
	_mark_open()
	cast_shadows = true
	no_shadow_keys = ["wet", "puddle", "lantern_glow", "paper", "hill", "gravel", "gravel_line", "moss_patch", "shoji"]

	# Structures first: they reserve their ground so no bamboo grows through them.
	_start_plaza()
	_grove_gate()
	_bridge()
	_hillside()
	_rain()
	_garden()
	if not track.shortcuts.is_empty():
		_shrine_path(track.shortcuts[0])
	await step(0.05)
	SceneryTerrain.build(self, TERRAIN_BOUNDS, 7.0, TERRAIN_AMPLITUDE, WATER_LEVEL, "litter", "moss", "river", TERRAIN_SEED, _carve)
	_far_ground()
	_hills()
	await step(0.15)

	bamboo = BambooBuilder.new(self, random_seed)
	# The grove is most of the build: it steps the bar on its own, up to 0.8.
	await _grove(0.15, 0.8)
	_canopy()
	_undergrowth()
	_fence_rails()
	bamboo.commit()
	await step(0.9)


func _off(p: Vector3) -> float:
	return track.curve.get_closest_offset(p)


## True if a main-road offset lies in [from, to) (wrapping round the lap).
func _in_span(d: float, from_key: String, to_key: String) -> bool:
	var a: float = _offsets[from_key]
	var b: float = _offsets[to_key]
	return fposmod(d - a, track.length) < fposmod(b - a, track.length)


## The open sections: the start plaza, the bridge and the temple garden.
func is_open_offset(d: float) -> bool:
	return _in_span(d, "start", "grove") or _in_span(d, "bridge_from", "bridge_to") or _in_span(d, "garden_from", "garden_to")


## True if a track-local point is under the leaf canopy.
func is_covered(p: Vector3) -> bool:
	return _cover.has(Vector2i(int(floor(p.x / COVER_CELL)), int(floor(p.z / COVER_CELL))))


func _mark_cover(p: Vector3, radius: float) -> void:
	var r := int(ceil(radius / COVER_CELL))
	var c := Vector2i(int(floor(p.x / COVER_CELL)), int(floor(p.z / COVER_CELL)))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := c + Vector2i(dx, dz)
			var centre := Vector2((cell.x + 0.5) * COVER_CELL, (cell.y + 0.5) * COVER_CELL)
			if centre.distance_to(Vector2(p.x, p.z)) <= radius:
				_cover[cell] = true


## Ground near the open sections, where the bamboo stands upright instead
## of bowing over the road.
func _mark_open() -> void:
	var d := 0.0
	while d < track.length:
		if is_open_offset(d):
			var p := at(d).origin
			var r := int(ceil(18.0 / OPEN_CELL))
			var c := Vector2i(int(floor(p.x / OPEN_CELL)), int(floor(p.z / OPEN_CELL)))
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					_open[c + Vector2i(dx, dz)] = true
		d += 3.0


func _is_open_ground(p: Vector3) -> bool:
	return _open.has(Vector2i(int(floor(p.x / OPEN_CELL)), int(floor(p.z / OPEN_CELL))))


func _reserve(p: Vector3, radius: float) -> void:
	var key := Vector2i(int(floor(p.x / 10.0)), int(floor(p.z / 10.0)))
	if not _reserved.has(key):
		_reserved[key] = []
	(_reserved[key] as Array).append([p, radius])


func _is_reserved(p: Vector3) -> bool:
	var c := Vector2i(int(floor(p.x / 10.0)), int(floor(p.z / 10.0)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for entry: Array in _reserved.get(c + Vector2i(dx, dz), []):
				var q: Vector3 = entry[0]
				if Vector2(p.x - q.x, p.z - q.z).length() < float(entry[1]):
					return true
	return false


func _in_garden(p: Vector3, margin: float = 0.0) -> bool:
	return GARDEN.grow(margin).has_point(Vector2(p.x, p.z))


## Nearest road centre-line sample to a track-local point (main or shortcut).
func _nearest_road(p: Vector3) -> Vector3:
	var best := track.curve.get_closest_point(p)
	for sc in track.shortcuts:
		var q := sc.point_at(sc.local_offset(p))
		if Vector2(p.x - q.x, p.z - q.z).length() < Vector2(p.x - best.x, p.z - best.z).length():
			best = q
	return best


# --- materials -----------------------------------------------------------------------

func _setup_materials() -> void:
	textured("litter", "dry_decay_leaves", Color(0.82, 0.74, 0.62), 5.0, 0.95)
	textured("moss", "sparse_grass", Color(0.5, 0.72, 0.32), 4.0, 0.95)
	textured("mossy_wall", "mossy_stone_wall", Color(0.85, 0.9, 0.8), 3.0, 0.9)
	textured("rock", "mossy_rock", Color(0.75, 0.8, 0.7), 3.0, 0.9)
	textured("granite", "concrete_moss", Color(0.8, 0.8, 0.76), 1.5, 0.9)
	textured("bridge_wood", "hinoki_planks", Color(0.72, 0.52, 0.38), 2.0, 0.75)
	textured("wood", "hinoki_planks", Color(0.62, 0.46, 0.33), 1.5, 0.75)
	textured("bark", "pine_bark", Color(0.5, 0.42, 0.38), 1.5, 0.9)
	textured("hill", "forest_leaves_02", Color(0.42, 0.55, 0.3), 30.0, 0.95)
	material("plaster", Color(0.92, 0.9, 0.84), 0.0, 0.0, 0.9)
	material("roof_tile", Color(0.17, 0.18, 0.2), 0.0, 0.15, 0.55)
	material("dark_wood", Color(0.16, 0.11, 0.08), 0.0, 0.0, 0.8)
	material("kuroki", Color(0.09, 0.075, 0.065), 0.0, 0.0, 0.85)
	material("vermilion", Color(0.85, 0.2, 0.08), 0.0, 0.0, 0.7)
	material("cloth_white", Color(0.93, 0.91, 0.86), 0.0, 0.0, 0.9)
	material("maple_red", Color(0.72, 0.1, 0.05), 0.0, 0.0, 0.8)
	material("maple_orange", Color(0.9, 0.4, 0.07), 0.0, 0.0, 0.8)
	material("maple_green", Color(0.36, 0.55, 0.14), 0.0, 0.0, 0.8)
	material("shrub", Color(0.15, 0.3, 0.1), 0.0, 0.0, 0.9)
	material("pine_needles", Color(0.1, 0.22, 0.09), 0.0, 0.0, 0.9)
	material("dead_culm", Color(0.66, 0.58, 0.34), 0.0, 0.0, 0.55)
	material("rail", Color(0.72, 0.68, 0.4), 0.0, 0.0, 0.45)
	material("rope", Color(0.85, 0.78, 0.55), 0.0, 0.0, 0.9)
	material("gravel", Color(0.8, 0.78, 0.72), 0.0, 0.0, 1.0)
	material("gravel_line", Color(0.9, 0.88, 0.83), 0.0, 0.0, 1.0)
	material("moss_patch", Color(0.3, 0.5, 0.16), 0.0, 0.0, 1.0)
	material("lantern_glow", Color(1.0, 0.72, 0.38), 2.5)
	material("paper", Color(1.0, 0.88, 0.66), 1.4)
	material("shoji", Color(0.96, 0.93, 0.84), 0.25)
	register_material("river", water_material(Color(0.03, 0.06, 0.05), Color(0.1, 0.18, 0.15), 0.92, 0.0, 0.3))
	# Rain-soaked road: a thin film that only shows the drops and the sheen.
	var wet := water_material(Color(0.06, 0.07, 0.07), Color(0.14, 0.16, 0.16), 0.28, 1.0, 0.0, 0.4)
	wet.set_shader_parameter("ripple_strength", 0.2)
	register_material("wet", wet)
	register_material("puddle", water_material(Color(0.03, 0.045, 0.045), Color(0.12, 0.15, 0.15), 0.72, 1.0, 0.25))


# --- terrain -------------------------------------------------------------------------

## River channel, the pond it feeds, the hillside, and the temple garden
## levelled flat (moss) with its own pond.
func _carve(x: float, z: float) -> float:
	var c := minf(_river(x, z), _bowl(x, z, POND, POND_RADIUS, 4.0))
	c += _hill(x, z)
	var g := Vector2(x, z)
	if GARDEN.has_point(g):
		var inset := minf(minf(g.x - GARDEN.position.x, GARDEN.end.x - g.x), minf(g.y - GARDEN.position.y, GARDEN.end.y - g.y))
		var w := clampf(inset / 8.0, 0.0, 1.0)
		var base := SceneryTerrain.height_at(self, _noise, TERRAIN_AMPLITUDE, x, z)
		c += (0.08 - base) * w
		c += _bowl(x, z, GARDEN_POND, GARDEN_POND_RADIUS, 3.6)
	return c


func _river(x: float, z: float) -> float:
	if x < POND.x:
		return 0.0
	var centre := RIVER_Z + sin(x / 50.0) * 10.0
	var across := absf(z - centre) / RIVER_HALF
	if across >= 1.0:
		return 0.0
	# Flat bed, steep banks.
	return -RIVER_DEPTH * (1.0 - across * across * across * across)


func _bowl(x: float, z: float, centre: Vector3, radius: float, depth: float) -> float:
	var r := Vector2(x - centre.x, z - centre.z).length() / radius
	if r >= 1.0:
		return 0.0
	return -depth * (1.0 - r * r * r * r)


func _hill(x: float, z: float) -> float:
	if x <= HILL_X:
		return 0.0
	var fade := clampf((z - HILL_Z.x) / 40.0, 0.0, 1.0) * clampf((HILL_Z.y - z) / 40.0, 0.0, 1.0)
	return clampf((x - HILL_X) * 0.25, 0.0, 10.0) * fade


func ground_y(p: Vector3) -> float:
	return SceneryTerrain.height_at(self, _noise, TERRAIN_AMPLITUDE, p.x, p.z, _carve)


## Leaf-litter ground beyond the terrain, so the view never runs out.
func _far_ground() -> void:
	var r := TERRAIN_BOUNDS
	var far := 900.0
	for rect: Rect2 in [Rect2(r.position.x - far, r.position.y - far, r.size.x + far * 2.0, far),
			Rect2(r.position.x - far, r.end.y, r.size.x + far * 2.0, far),
			Rect2(r.position.x - far, r.position.y, far, r.size.y),
			Rect2(r.end.x, r.position.y, far, r.size.y)]:
		var plane := PlaneMesh.new()
		plane.size = rect.size
		var mi := add_mesh_instance(plane, get_material("litter"), "FarGround")
		mi.position = Vector3(rect.get_center().x, 0.3, rect.get_center().y)


## Arashiyama's wooded mountains around the valley.
func _hills() -> void:
	for h: Array in [[Vector3(1040, 0, 170), 320.0, 190.0], [Vector3(820, 0, 1060), 340.0, 160.0],
			[Vector3(-160, 0, 1160), 380.0, 140.0], [Vector3(250, 0, -520), 400.0, 170.0],
			[Vector3(-820, 0, 280), 330.0, 150.0], [Vector3(1180, 0, -380), 300.0, 210.0]]:
		var c: Vector3 = h[0]
		var r: float = h[1]
		add_sphere("hill", r, xform(c + Vector3(0, -r * 0.2, 0)).scaled_local(Vector3(1.0, float(h[2]) / r, 1.0)), 8, 18)


# --- bamboo --------------------------------------------------------------------------

## Culms in a band up to 42 m either side of every road: dense against the
## fences, thinning into the haze, in clumps with small gaps between them
## (bamboo spreads by rhizome). Near the road they lean in so their crowns
## meet high over it (not by the open sections). Culms the camera only sees
## from afar use the cheap mesh.
## Reports its progress as `from`-`to` of the build.
func _grove(from: float = 0.0, to: float = 1.0) -> void:
	var tiles := {}
	var curves: Array[Curve3D] = [track.curve]
	for sc in track.shortcuts:
		curves.append(sc.curve)
	for curve in curves:
		var d := 0.0
		var length := curve.get_baked_length()
		while d < length:
			var p := curve.sample_baked(d)
			var c := Vector2i(int(floor(p.x / 10.0)), int(floor(p.z / 10.0)))
			for dz in range(-5, 6):
				for dx in range(-5, 6):
					tiles[c + Vector2i(dx, dz)] = true
			d += 8.0
	var clump := FastNoiseLite.new()
	clump.seed = random_seed + 11
	clump.frequency = 0.05
	var step := 2.5
	var deep := Color(0.38, 0.62, 0.26)
	var blue := Color(0.42, 0.58, 0.46)
	var young := Color(0.55, 0.74, 0.3)
	var olive := Color(0.55, 0.55, 0.35)
	var straw := Color(0.72, 0.64, 0.42)
	var done := 0
	for tile: Vector2i in tiles:
		done += 1
		if done % 150 == 0:
			await step(lerpf(from, to, float(done) / tiles.size()))
		for iz in 4:
			for ix in 4:
				var p := Vector3(tile.x * 10.0 + (ix + 0.5) * step + rng.randf_range(-1.0, 1.0), 0,
						tile.y * 10.0 + (iz + 0.5) * step + rng.randf_range(-1.0, 1.0))
				var e := edge_distance(p)
				if e < track.barrier_thickness + 1.3 or e > 42.0:
					continue
				var keep := 0.95 if e < 7.0 else (0.82 if e < 16.0 else (0.66 if e < 28.0 else 0.5))
				# Clumps: full stands and thin patches (less so against the fences).
				var patch := clampf(0.92 + clump.get_noise_2d(p.x, p.z) * 1.4, 0.25, 1.3)
				keep *= lerpf(1.0, patch, 0.45 if e < 7.0 else 1.0)
				if rng.randf() > keep:
					continue
				if _in_garden(p, 2.0) or _river(p.x, p.z) < -0.3 or _bowl(p.x, p.z, POND, POND_RADIUS + 4.0, 1.0) < 0.0 \
						or _is_reserved(p):
					continue
				var road := _nearest_road(p)
				var to_road := Vector3(road.x - p.x, 0, road.z - p.z)
				var kind := "straight"
				var toward := to_road.rotated(Vector3.UP, rng.randf_range(-PI, PI))
				if e < 9.5 and not _is_open_ground(p):
					kind = "arch"
					toward = to_road.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3))
				elif e < 20.0:
					# Leaning a little toward the light over the road.
					toward = to_road.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
				var r := rng.randf()
				var tint: Color
				if r < 0.55:
					tint = deep.lerp(blue, rng.randf() * 0.35)
				elif r < 0.78:
					tint = blue.lerp(deep, rng.randf() * 0.4)
				elif r < 0.88:
					tint = young.lerp(deep, rng.randf() * 0.5)
				else:
					tint = olive.lerp(blue, rng.randf() * 0.4)
				if rng.randf() < 0.03:
					kind = "dead"
					tint = straw.lerp(olive, rng.randf() * 0.6)
				tint = tint.darkened(clampf(e / 42.0, 0.0, 1.0) * 0.4)
				p.y = ground_y(p) - 0.15
				bamboo.place_culm(kind, p, toward, rng.randf_range(0.85, 1.15), tint, rng.randf() < 0.22, e < 12.0)


## Leaf sprays hung high over the covered roads, where the leaning crowns
## meet, closing the gaps between them. Each one is mapped for is_covered().
func _canopy() -> void:
	var leaf := Color(0.5, 0.72, 0.3)
	var dark := Color(0.32, 0.5, 0.2)
	var h := track.road_width * 0.5
	var d := 0.0
	while d < track.length:
		if not is_open_offset(d):
			for lat: float in [-h - 4.0, -h + 0.5, -2.2, 2.2, h - 0.5, h + 4.0]:
				var outer := absf(lat) > h
				if rng.randf() > (0.75 if outer else 0.95):
					continue
				var s := rng.randf_range(1.6, 2.3)
				var xf := at(d + rng.randf_range(-1.2, 1.2), lat + rng.randf_range(-1.2, 1.2), rng.randf_range(16.5, 21.0))
				bamboo.place_spray(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), xf.origin),
						leaf.lerp(dark, rng.randf()))
				_mark_cover(xf.origin, 1.9 * s)
		d += 2.8
	for sc in track.shortcuts:
		var sh := sc.road_width * 0.5
		d = 0.0
		while d < sc.length:
			for lat: float in [-sh - 2.5, -1.5, 1.5, sh + 2.5]:
				if rng.randf() > 0.7:
					continue
				var s := rng.randf_range(1.4, 1.9)
				var f := _sc_frame(sc, d)
				var pos := f * Vector3(lat, rng.randf_range(14.0, 18.0), 0)
				bamboo.place_spray(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), pos),
						leaf.lerp(dark, rng.randf()))
				_mark_cover(pos, 1.9 * s)
			d += 3.6


## The grove floor: sasa (dwarf bamboo) clumps along the outside of the
## fences, ferns in patches between the culms, and old culms that have
## come down and lie in the litter.
func _undergrowth() -> void:
	var patches := FastNoiseLite.new()
	patches.seed = random_seed + 23
	patches.frequency = 0.06
	var h := track.road_width * 0.5
	var outside := h + track.barrier_thickness
	var sasa := Color(0.34, 0.52, 0.22)
	var fern := Color(0.62, 0.8, 0.48)
	var frames: Array = []
	var d := 0.0
	while d < track.length:
		frames.append(at(d))
		d += 2.0
	for sc in track.shortcuts:
		d = 0.0
		while d < sc.length:
			frames.append(_sc_frame(sc, d))
			d += 2.0
	for f: Transform3D in frames:
		for side: float in [-1.0, 1.0]:
			# Sasa right outside the fence.
			if rng.randf() < 0.45:
				var p := f * Vector3(side * (outside + rng.randf_range(0.8, 3.0)), 0, rng.randf_range(-1.0, 1.0))
				if _ground_ok(p, 0.6):
					var s := rng.randf_range(0.8, 1.3)
					p.y = ground_y(p) - 0.05
					bamboo.place_item("sasa", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p),
							sasa.lerp(Color(0.46, 0.6, 0.26), rng.randf()).darkened(rng.randf() * 0.2))
			# Ferns in patches deeper in.
			var q := f * Vector3(side * (outside + rng.randf_range(3.0, 30.0)), 0, rng.randf_range(-1.0, 1.0))
			if patches.get_noise_2d(q.x, q.z) > 0.05 and rng.randf() < 0.7 and _ground_ok(q, 1.0):
				var s := rng.randf_range(0.7, 1.2)
				q.y = ground_y(q) - 0.05
				var e := edge_distance(q)
				bamboo.place_item("fern", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), q),
						fern.lerp(Color(0.48, 0.66, 0.3), rng.randf()).darkened(clampf(e / 30.0, 0.0, 1.0) * 0.35))
	# Fallen culms in the litter.
	d = 0.0
	while d < track.length:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := at(d, side * (outside + rng.randf_range(4.0, 22.0))).origin
		var len := rng.randf_range(6.0, 13.0)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
		var a := p - dir * len * 0.5
		var b := p + dir * len * 0.5
		if _ground_ok(p, 1.0) and _ground_ok(a, 0.5) and _ground_ok(b, 0.5):
			a.y = ground_y(a) + 0.08
			b.y = ground_y(b) + 0.08 + rng.randf_range(0.0, 0.5)
			_rail(a, b, rng.randf_range(0.06, 0.09), "dead_culm")
		d += rng.randf_range(18.0, 34.0)


## True where undergrowth may go: off every road and fence, not in the
## temple garden, river or pond, nor on reserved ground.
func _ground_ok(p: Vector3, radius: float) -> bool:
	return clear(p, radius) and not _in_garden(p, 1.0) and _river(p.x, p.z) > -0.3 \
			and _bowl(p.x, p.z, POND, POND_RADIUS + 2.0, 1.0) >= 0.0 and not _is_reserved(p)


func _sc_frame(sc: TrackShortcut, d: float) -> Transform3D:
	var dd := clampf(d, 0.0, sc.length)
	return Transform3D(Basis.looking_at(sc.tangent_at(dd), Vector3.UP), sc.point_at(dd))


# --- fences --------------------------------------------------------------------------

## The barriers are brushwood (shibagaki) fences: each gets two thick
## bamboo rails on its road face and a bristly crest of brushwood standing
## above the wall (about 2 m tall in all; the collider is unchanged). The
## bridge has wooden railings instead.
func _fence_rails() -> void:
	var h := track.road_width * 0.5
	var d := 0.0
	while d < track.length:
		if not _in_span(d, "bridge_from", "bridge_to"):
			for side: float in [-1.0, 1.0]:
				var fa := at(d, side * (h - 0.06), 0.0)
				var fb := at(d + 3.0, side * (h - 0.06), 0.0)
				if _on_shortcut(fa.origin, 1.5) or _on_shortcut(fb.origin, 1.5):
					continue
				_fence_bay(fa.origin, fb.origin, fa.basis.x * side, track.barrier_thickness)
		d += 3.0
	for sc in track.shortcuts:
		var sh := sc.road_width * 0.5
		d = 0.0
		while d < sc.length - 3.0:
			for side: float in [-1.0, 1.0]:
				var fa := _sc_frame(sc, d)
				var a := fa * Vector3(side * (sh - 0.06), 0, 0)
				var b := _sc_frame(sc, d + 3.0) * Vector3(side * (sh - 0.06), 0, 0)
				if _on_main(a, 1.5) or _on_main(b, 1.5):
					continue
				_fence_bay(a, b, fa.basis.x * side, track.barrier_thickness)
			d += 3.0


## One 3 m bay of fence from a to b (on the wall's road face); out points
## away from the road.
func _fence_bay(a: Vector3, b: Vector3, out: Vector3, thickness: float) -> void:
	var straw := Color(0.8, 0.72, 0.46).darkened(rng.randf() * 0.12)
	for y: float in [0.5, 1.25]:
		bamboo.add_pole(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.055, straw)
	var along := b - a
	var o := Vector3(out.x, 0, out.z).normalized()
	var x := Vector3.UP.cross(o)
	var mid := (a + b) * 0.5 + o * (thickness * 0.72) + Vector3(0, track.barrier_height - 0.14, 0)
	var basis := Basis(x * (along.length() / 3.0 * 1.06), Vector3.UP * rng.randf_range(0.9, 1.15), o)
	bamboo.place_item("brush", Transform3D(basis, mid), Color(1.0, 0.95, 0.88).darkened(rng.randf() * 0.15))


func _on_shortcut(p: Vector3, margin: float) -> bool:
	for sc in track.shortcuts:
		if sc.lateral_distance(p) < sc.road_width * 0.5 + margin:
			return true
	return false


func _on_main(p: Vector3, margin: float) -> bool:
	var q := track.curve.get_closest_point(p)
	return Vector2(p.x - q.x, p.z - q.z).length() < track.road_width * 0.5 + margin


## A horizontal pole from a to b.
func _rail(a: Vector3, b: Vector3, radius: float, key: String = "rail") -> void:
	var dir := b - a
	if dir.length() < 0.01:
		return
	var xf := Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), a).rotated_local(Vector3.RIGHT, -PI * 0.5)
	add_cyl(key, radius, dir.length() + 0.04, xf, 6)


# --- start plaza and the grove gate ------------------------------------------------------

func _start_plaza() -> void:
	var h := track.road_width * 0.5
	var from: float = _offsets["start"]
	var span := fposmod(float(_offsets["grove"]) - from, track.length)
	var d := 8.0
	var k := 0
	while d < span - 10.0:
		for side: float in [-1.0, 1.0]:
			var p := at(from + d, side * (h + 2.8))
			if clear(p.origin, 0.6):
				_toro(p, k % 3 == 0)
		d += 24.0
		k += 1
	# Nobori banners on poles, white and vermilion, around the grid.
	var o := track.start_line_offset
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := at(o - 60.0 + i * 14.0, side * (h + 1.7))
		if clear(p.origin, 0.3):
			add_cyl("dark_wood", 0.06, 6.0, p, 6)
			add_box("vermilion" if i % 4 < 2 else "cloth_white", Vector3(0.04, 3.6, 0.9), p.translated_local(Vector3(0, 3.9, 0.48)))
			add_box("dark_wood", Vector3(0.05, 0.05, 1.0), p.translated_local(Vector3(0, 5.75, 0.5)))
			_reserve(p.origin, 1.5)


## Stone lantern (ishidoro): base, post, platform, firebox, roof, finial.
func _toro(xf: Transform3D, lit: bool = false) -> void:
	add_cyl("granite", 0.45, 0.25, xf, 8)
	add_cyl("granite", 0.16, 1.0, xf.translated_local(Vector3(0, 0.25, 0)), 8)
	add_box("granite", Vector3(0.75, 0.18, 0.75), xf.translated_local(Vector3(0, 1.3, 0)))
	add_box("granite", Vector3(0.5, 0.48, 0.5), xf.translated_local(Vector3(0, 1.63, 0)))
	add_box("lantern_glow", Vector3(0.3, 0.26, 0.52), xf.translated_local(Vector3(0, 1.63, 0)))
	add_box("lantern_glow", Vector3(0.52, 0.26, 0.3), xf.translated_local(Vector3(0, 1.63, 0)))
	add_pyramid("granite", 0.55, 0.42, xf.translated_local(Vector3(0, 1.87, 0)))
	add_sphere("granite", 0.1, xf.translated_local(Vector3(0, 2.33, 0)), 3, 6)
	if lit:
		add_light(xf * Vector3(0, 1.65, 0), Color(1.0, 0.72, 0.4), 0.8, 6.0)
	_reserve(xf.origin, 1.4)


## The timber gate where the road enters the grove, with a roofed lintel
## and the ARASHIYAMA plaque.
func _grove_gate() -> void:
	var c := at(_offsets["grove"])
	var half := track.road_width * 0.5 + track.barrier_thickness + 1.4
	for side: float in [-1.0, 1.0]:
		var post := c.translated_local(Vector3(side * half, 0, 0))
		add_cyl("wood", 0.42, 8.6, post, 10)
		add_box("granite", Vector3(1.3, 0.6, 1.3), post.translated_local(Vector3(0, 0.3, 0)))
		_reserve(post.origin, 3.0)
	add_box("wood", Vector3(half * 2.0 + 1.4, 0.7, 0.8), c.translated_local(Vector3(0, 7.6, 0)))
	add_box("wood", Vector3(half * 2.0 - 0.6, 0.45, 0.5), c.translated_local(Vector3(0, 6.2, 0)))
	# Small gabled roof of dark tiles over the lintel.
	for side: float in [-1.0, 1.0]:
		add_box("roof_tile", Vector3(half * 2.0 + 3.2, 0.18, 1.7), c.translated_local(Vector3(0, 8.45, side * 0.62)).rotated_local(Vector3.RIGHT, side * 0.42))
	add_box("roof_tile", Vector3(half * 2.0 + 3.4, 0.25, 0.3), c.translated_local(Vector3(0, 8.95, 0)))
	add_box("dark_wood", Vector3(5.6, 1.3, 0.12), c.translated_local(Vector3(0, 6.9, 0.36)))
	var label := add_text("ARASHIYAMA", c.translated_local(Vector3(0, 6.9, 0.44)), Color(0.95, 0.88, 0.7), 0.03, 110)
	label.outline_size = 0
	# Paper lanterns hanging from the lintel.
	for side: float in [-1.0, 1.0]:
		var l := c.translated_local(Vector3(side * (half - 1.6), 5.2, 0))
		add_box("dark_wood", Vector3(0.04, 1.0, 0.04), l.translated_local(Vector3(0, 0.9, 0)))
		add_sphere("paper", 0.38, l.scaled_local(Vector3(1, 1.35, 1)), 5, 8)
		add_light(l.origin, Color(1.0, 0.8, 0.5), 0.9, 9.0)


# --- the bridge over the Katsura ----------------------------------------------------------

## A long, low wooden bridge (after Togetsukyo): plank railings boxing in
## the barriers, a deck fascia, and timber pile bents down to the river.
func _bridge() -> void:
	var h := track.road_width * 0.5
	var from: float = _offsets["bridge_from"]
	var span := fposmod(float(_offsets["bridge_to"]) - from, track.length)
	var d := 0.0
	var n := 0
	while d < span:
		var c := at(from + d)
		var ground := _river(c.origin.x, c.origin.z)
		# Railings over the barriers (which are the real rails).
		for side: float in [-1.0, 1.0]:
			add_box("bridge_wood", Vector3(1.25, 1.66, 3.05), c.translated_local(Vector3(side * (h + 0.5), 0.83, 0)))
			add_box("dark_wood", Vector3(1.45, 0.14, 3.05), c.translated_local(Vector3(side * (h + 0.5), 1.72, 0)))
			if n % 2 == 0:
				add_box("dark_wood", Vector3(0.32, 0.4, 0.32), c.translated_local(Vector3(side * (h + 0.5), 1.98, 0)))
			add_box("dark_wood", Vector3(0.4, 0.8, 3.05), c.translated_local(Vector3(side * (h + 1.4), -0.2, 0)))
		if ground < -0.3:
			add_box("dark_wood", Vector3(h * 2.0 + 2.6, 0.5, 3.05), c.translated_local(Vector3(0, -0.5, 0)))
			if n % 3 == 0:
				# A pile bent: four piles and a cross beam.
				for lat: float in [-h - 0.6, -h * 0.35, h * 0.35, h + 0.6]:
					var top := -0.7
					add_cyl("dark_wood", 0.32, top - ground + 0.4, c.translated_local(Vector3(lat, ground - 0.4, 0)), 8)
				add_box("dark_wood", Vector3(h * 2.0 + 2.4, 0.45, 0.5), c.translated_local(Vector3(0, -1.6, 0)))
				add_box("dark_wood", Vector3(h * 2.0 + 2.4, 0.3, 0.4), c.translated_local(Vector3(0, ground * 0.55, 0)))
		d += 3.0
		n += 1
	# Rocks along the river banks.
	var x := POND.x + 20.0
	while x < TERRAIN_BOUNDS.end.x:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				var z := RIVER_Z + sin(x / 50.0) * 10.0 + side * RIVER_HALF * rng.randf_range(0.7, 0.95)
				var p := Vector3(x + rng.randf_range(-3, 3), 0, z)
				if clear(p, 2.0):
					var r := rng.randf_range(0.8, 2.2)
					p.y = _river(p.x, p.z) + r * 0.2
					add_sphere("rock", r, xform(p, rng.randf() * TAU).scaled_local(Vector3(1.3, 0.6, 1.0)), 4, 7)
		x += 8.0


# --- hillside --------------------------------------------------------------------------

## Mossy retaining walls and boulders on the hill side of the sweepers, with
## maples among the bamboo.
func _hillside() -> void:
	var h := track.road_width * 0.5
	var from: float = _offsets["bridge_to"] + 15.0
	var span := fposmod(float(_offsets["rain_from"]) - from, track.length)
	var centre := Vector3(130, 0, 330) # inside the loop
	var d := 0.0
	while d < span:
		var c := at(from + d)
		var side := 1.0 if (c * Vector3(1, 0, 0)).distance_to(centre) > (c * Vector3(-1, 0, 0)).distance_to(centre) else -1.0
		var p := c.translated_local(Vector3(side * (h + 2.7), 0, 0))
		if clear(p.origin, 0.6):
			var wall_h := 2.2 + 0.5 * sin(d * 0.05)
			add_box("mossy_wall", Vector3(1.3, wall_h, 3.2), p.translated_local(Vector3(0, wall_h * 0.5, 0)))
			_reserve(p.origin, 1.5)
			if rng.randf() < 0.5:
				var r := rng.randf_range(0.5, 1.0)
				add_sphere("rock", r, p.translated_local(Vector3(-side * 0.8, r * 0.3, rng.randf_range(-1, 1))).scaled_local(Vector3(1.2, 0.8, 1)), 4, 7)
		if int(d) % 21 < 3 and rng.randf() < 0.8:
			var m := c.translated_local(Vector3(-side * (h + rng.randf_range(5.0, 9.0)), 0, 0))
			if clear(m.origin, 2.5):
				_maple(m.origin)
		d += 3.0
	# A stacked boulder wall along the first grove, as in the photos.
	_boulder_wall(_off(Vector3(220, 0, 100)), 90.0, -1.0)
	_boulder_wall(_off(Vector3(-40, 0, 625)), 80.0, 1.0)


func _boulder_wall(from: float, length: float, side: float) -> void:
	var h := track.road_width * 0.5
	var d := 0.0
	while d < length:
		for row in 2:
			var p := at(from + d + row * 0.9, side * (h + 2.4 + row * 0.4), 0.0)
			if clear(p.origin, 0.6):
				var r := rng.randf_range(0.55, 0.85)
				add_sphere("rock", r, p.translated_local(Vector3(0, 0.45 + row * 0.9, 0)).rotated_local(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(1.2, 0.75, 1.0)), 4, 7)
				_reserve(p.origin, 1.2)
		d += 1.6


## A Japanese maple: short leaning trunk, a few branches and a layered crown,
## red, orange or still green.
func _maple(pos: Vector3) -> void:
	var roll := rng.randf()
	var key := "maple_red" if roll < 0.5 else ("maple_orange" if roll < 0.8 else "maple_green")
	var lean := rng.randf_range(-0.15, 0.15)
	var base := Transform3D(Basis(Vector3.FORWARD, lean).rotated(Vector3.UP, rng.randf() * TAU), pos)
	var hgt := rng.randf_range(3.5, 5.5)
	add_cyl("bark", 0.2, hgt, base, 7, 0.1)
	var top := base * Vector3(0, hgt, 0)
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(1.4, 2.2)
		var c := top + Vector3(cos(a) * r * 0.8, rng.randf_range(-0.8, 0.4), sin(a) * r * 0.8)
		add_sphere(key, r, xform(c).scaled_local(Vector3(1.0, 0.45, 1.0)), 4, 8)
	add_sphere(key, 1.8, xform(top + Vector3(0, 0.6, 0)).scaled_local(Vector3(1.0, 0.5, 1.0)), 4, 8)
	_reserve(pos, 3.0)


# --- rain-soaked stretch ----------------------------------------------------------------

## Wet sheen over the road and puddles near the edges (visual; the standing
## water feature is the one that slows you).
func _rain() -> void:
	var h := track.road_width * 0.5
	var from: float = _offsets["rain_from"]
	var span := fposmod(float(_offsets["rain_to"]) - from, track.length)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 0.0
	while d < span:
		var fade0 := clampf(minf(d, span - d) / 20.0, 0.0, 1.0)
		var a0 := at(from + d, -h, 0.028).origin
		var b0 := at(from + d, h, 0.028).origin
		var a1 := at(from + d + 3.0, -h, 0.028).origin
		var b1 := at(from + d + 3.0, h, 0.028).origin
		if fade0 > 0.0:
			for v in [a0, b0, b1, a0, b1, a1]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		d += 3.0
	add_mesh_instance(st.commit(), get_material("wet"), "WetRoad")
	for i in 26:
		var o := from + rng.randf_range(10.0, span - 10.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := at(o, side * rng.randf_range(h - 3.0, h - 0.6), 0.034)
		add_cyl("puddle", rng.randf_range(0.7, 1.8), 0.004, p.scaled_local(Vector3(1.0, 1.0, rng.randf_range(1.2, 2.2))), 12)


# --- temple garden -----------------------------------------------------------------------

## Walled (tsuiji walls with tiled caps), levelled and mossy, with a pond,
## clipped shrubs, maples, stone lanterns, raked gravel and a temple hall.
func _garden() -> void:
	var r := GARDEN
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var dir := (b - a).normalized()
		var basis := Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP)
		var d := 1.5
		while d < a.distance_to(b):
			var p2 := a + dir * d
			var p := Vector3(p2.x, 0, p2.y)
			d += 3.0
			if not clear(p, 2.0):
				continue # the gates where the road passes through
			var xf := Transform3D(basis, p)
			add_box("granite", Vector3(1.2, 0.5, 3.05), xf.translated_local(Vector3(0, 0.25, 0)))
			add_box("plaster", Vector3(0.9, 2.5, 3.05), xf.translated_local(Vector3(0, 1.75, 0)))
			add_box("dark_wood", Vector3(1.0, 0.12, 3.05), xf.translated_local(Vector3(0, 2.9, 0)))
			for side: float in [-1.0, 1.0]:
				add_box("roof_tile", Vector3(1.0, 0.14, 3.1), xf.translated_local(Vector3(side * 0.42, 3.15, 0)).rotated_local(Vector3.FORWARD, side * 0.5))
			add_box("roof_tile", Vector3(0.25, 0.2, 3.1), xf.translated_local(Vector3(0, 3.42, 0)))
	# Pond: rocks round the rim, an island with a pine, two snow-viewing lanterns.
	var pc := GARDEN_POND
	for i in 34:
		var a := TAU * i / 34.0 + rng.randf_range(-0.05, 0.05)
		var p := pc + Vector3(cos(a), 0, sin(a)) * GARDEN_POND_RADIUS * rng.randf_range(0.82, 0.95)
		var rr := rng.randf_range(0.5, 1.3)
		p.y = ground_y(p) + rr * 0.2
		add_sphere("rock", rr, xform(p, rng.randf() * TAU).scaled_local(Vector3(1.3, 0.7, 1.0)), 4, 7)
	var island := pc + Vector3(4, 0, -3)
	add_sphere("moss_patch", 5.0, xform(island + Vector3(0, -2.4, 0)).scaled_local(Vector3(1.0, 0.55, 0.8)), 5, 10)
	_pine(island + Vector3(0, 0.3, 0))
	for k in 2:
		var a := 0.8 + k * 2.6
		var p := pc + Vector3(cos(a), 0, sin(a)) * (GARDEN_POND_RADIUS + 3.0)
		_yukimi(xform(p, a))
	# Maples, clipped azalea mounds and moss.
	for i in 140:
		var p := Vector3(rng.randf_range(r.position.x + 4, r.end.x - 4), 0, rng.randf_range(r.position.y + 4, r.end.y - 4))
		if not clear(p, 3.0) or Vector2(p.x - pc.x, p.z - pc.z).length() < GARDEN_POND_RADIUS + 2.0 \
				or GRAVEL.grow(3.0).has_point(Vector2(p.x, p.z)) or p.distance_to(HALL) < 22.0:
			continue
		var roll := rng.randf()
		if roll < 0.22:
			_maple(p)
		elif roll < 0.62:
			var s := rng.randf_range(0.8, 1.8)
			add_sphere("shrub", s, xform(p + Vector3(0, s * 0.15, 0)).scaled_local(Vector3(1.3, 0.6, 1.1)), 4, 8)
		elif roll < 0.7:
			_toro(xform(p, rng.randf() * TAU))
		else:
			add_cyl("moss_patch", rng.randf_range(1.5, 3.5), 0.05, xform(p + Vector3(0, 0.08, 0)), 10)
	_karesansui()
	_hall()


## Raked gravel with rock groups ringed in moss, in front of the hall.
func _karesansui() -> void:
	var g := GRAVEL
	add_box("gravel", Vector3(g.size.x, 0.12, g.size.y), xform(Vector3(g.get_center().x, 0.08, g.get_center().y)))
	var z := g.position.y + 0.4
	while z < g.end.y:
		add_box("gravel_line", Vector3(g.size.x - 0.4, 0.05, 0.1), xform(Vector3(g.get_center().x, 0.16, z)))
		z += 0.55
	for c: Vector3 in [Vector3(-90, 0, 350), Vector3(-60, 0, 380), Vector3(-80, 0, 415), Vector3(-48, 0, 432), Vector3(-95, 0, 437)]:
		add_cyl("moss_patch", rng.randf_range(2.6, 3.4), 0.12, xform(c + Vector3(0, 0.1, 0)), 14)
		for k in rng.randi_range(1, 3):
			var s := rng.randf_range(0.7, 1.6)
			add_sphere("rock", s, xform(c + Vector3(rng.randf_range(-1.2, 1.2), s * 0.35, rng.randf_range(-1.2, 1.2)), rng.randf() * TAU).scaled_local(Vector3(1.2, 0.85, 0.9)), 4, 7)


## The abbot's hall facing the gravel: stone plinth, veranda, posts, shoji
## and a big hipped roof of dark tiles.
func _hall() -> void:
	var c := xform(HALL)
	add_box("granite", Vector3(32.0, 0.9, 18.0), c.translated_local(Vector3(0, 0.45, 0)))
	add_box("wood", Vector3(31.0, 0.25, 17.0), c.translated_local(Vector3(0, 1.0, 0)))
	add_box("shoji", Vector3(26.0, 3.2, 12.0), c.translated_local(Vector3(0, 2.7, 0)))
	var x := -15.0
	while x <= 15.0:
		for z: float in [-8.0, 8.0]:
			add_box("dark_wood", Vector3(0.35, 4.0, 0.35), c.translated_local(Vector3(x, 3.0, z)))
		x += 3.0
	add_box("dark_wood", Vector3(31.0, 0.5, 17.0), c.translated_local(Vector3(0, 5.1, 0)))
	add_pyramid("roof_tile", 1.0, 6.5, c.translated_local(Vector3(0, 5.3, 0)).scaled_local(Vector3(18.5, 1.0, 11.5)))
	add_box("roof_tile", Vector3(14.0, 0.6, 0.8), c.translated_local(Vector3(0, 11.6, 0)))
	_reserve(HALL, 20.0)


## Cloud-pruned pine on the island.
func _pine(pos: Vector3) -> void:
	var base := Transform3D(Basis(Vector3.FORWARD, 0.35), pos)
	add_cyl("bark", 0.3, 4.5, base, 7, 0.15)
	var top := base * Vector3(0, 4.5, 0)
	for k in 4:
		var a := TAU * k / 4.0
		var c := top + Vector3(cos(a) * 1.8, -k * 0.6, sin(a) * 1.8)
		add_sphere("pine_needles", 1.2, xform(c).scaled_local(Vector3(1.4, 0.4, 1.1)), 4, 8)
	add_sphere("pine_needles", 1.4, xform(top + Vector3(0, 0.6, 0)).scaled_local(Vector3(1.4, 0.45, 1.2)), 4, 8)


## Snow-viewing lantern: short legs, wide umbrella roof.
func _yukimi(xf: Transform3D) -> void:
	for i in 3:
		var leg := xf.rotated_local(Vector3.UP, TAU * i / 3.0).translated_local(Vector3(0.35, 0, 0))
		add_box("granite", Vector3(0.14, 0.7, 0.14), leg.translated_local(Vector3(0, 0.35, 0)))
	add_box("granite", Vector3(0.6, 0.45, 0.6), xf.translated_local(Vector3(0, 0.95, 0)))
	add_box("lantern_glow", Vector3(0.62, 0.22, 0.3), xf.translated_local(Vector3(0, 0.95, 0)))
	add_cone("granite", 1.0, 0.5, xf.translated_local(Vector3(0, 1.17, 0)), 8)
	add_sphere("granite", 0.12, xf.translated_local(Vector3(0, 1.72, 0)), 3, 6)


# --- shrine path (shortcut) ----------------------------------------------------------------

## A narrow lane through the bamboo under black torii, with paper lanterns,
## a small shrine hall, and fallen culms where the bamboo has come down
## across the entrance.
func _shrine_path(sc: TrackShortcut) -> void:
	var sh := sc.road_width * 0.5
	var d := 12.0
	var k := 0
	while d < sc.length - 15.0:
		_torii(_sc_frame(sc, d), sh + 1.6, 7.0 if k == 0 else 6.0, k % 2 == 0)
		d += 42.0
		k += 1
	# The shrine hall on whichever side has room.
	var mid := _sc_frame(sc, sc.length * 0.5)
	for side: float in [-1.0, 1.0]:
		var p := mid.translated_local(Vector3(side * (sh + 9.0), 0, 0))
		if clear(p.origin, 6.0):
			_shrine(p.rotated_local(Vector3.UP, -side * PI * 0.5))
			break
	# Fallen bamboo heaped around the barricade at the entrance.
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var f := _sc_frame(sc, rng.randf_range(18.0, 44.0))
		var p := f.translated_local(Vector3(side * rng.randf_range(sh + 1.6, sh + 4.0), 0.25, 0))
		if edge_distance(p.origin) > 1.0:
			var len := rng.randf_range(7.0, 14.0)
			var lie := p.rotated_local(Vector3.UP, rng.randf_range(-0.6, 0.6)).rotated_local(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.25, 0.1))
			add_cyl("dead_culm", 0.1, len, lie.translated_local(Vector3(0, -len * 0.5, 0)), 6)
			_reserve(p.origin, 2.0)


## Black-timber torii over the shrine path, with a paper lantern.
func _torii(f: Transform3D, half: float, height: float, lantern: bool) -> void:
	for side: float in [-1.0, 1.0]:
		var post := f.translated_local(Vector3(side * half, 0, 0))
		add_cyl("kuroki", 0.3, height, post, 10)
		add_cyl("granite", 0.42, 0.35, post, 10)
		_reserve(post.origin, 1.5)
	add_box("kuroki", Vector3(half * 2.0 + 1.0, 0.32, 0.32), f.translated_local(Vector3(0, height - 1.3, 0)))
	add_box("kuroki", Vector3(half * 2.0 + 2.6, 0.4, 0.55), f.translated_local(Vector3(0, height + 0.05, 0)))
	for side: float in [-1.0, 1.0]:
		add_box("kuroki", Vector3(1.0, 0.4, 0.55), f.translated_local(Vector3(side * (half + 1.6), height + 0.2, 0)).rotated_local(Vector3.FORWARD, side * 0.25))
	# Straw rope (shimenawa) between the posts.
	add_box("rope", Vector3(half * 2.0, 0.16, 0.16), f.translated_local(Vector3(0, height - 1.75, 0)))
	if lantern:
		var l := f.translated_local(Vector3(0, height - 2.6, 0))
		add_sphere("paper", 0.36, l.scaled_local(Vector3(1, 1.4, 1)), 5, 8)
		add_light(l.origin, Color(1.0, 0.78, 0.48), 1.0, 10.0)


func _shrine(xf: Transform3D) -> void:
	add_box("granite", Vector3(9.0, 0.6, 7.0), xf.translated_local(Vector3(0, 0.3, 0)))
	add_box("wood", Vector3(7.0, 3.0, 5.0), xf.translated_local(Vector3(0, 2.1, 0)))
	add_box("kuroki", Vector3(7.4, 0.3, 5.4), xf.translated_local(Vector3(0, 3.75, 0)))
	for side: float in [-1.0, 1.0]:
		add_box("roof_tile", Vector3(9.4, 0.22, 4.6), xf.translated_local(Vector3(0, 4.9, side * 1.95)).rotated_local(Vector3.RIGHT, side * 0.55))
	add_box("roof_tile", Vector3(9.6, 0.3, 0.4), xf.translated_local(Vector3(0, 6.15, 0)))
	add_box("rope", Vector3(5.0, 0.22, 0.22), xf.translated_local(Vector3(0, 3.3, -2.65)))
	for side: float in [-1.0, 1.0]:
		add_box("cloth_white", Vector3(0.25, 0.6, 0.02), xf.translated_local(Vector3(side * 1.2, 2.9, -2.7)))
		add_sphere("paper", 0.3, xf.translated_local(Vector3(side * 3.0, 3.0, -2.9)).scaled_local(Vector3(1, 1.4, 1)), 5, 8)
	add_light(xf * Vector3(0, 2.6, -3.5), Color(1.0, 0.78, 0.48), 1.2, 10.0)
	_reserve(xf.origin, 7.0)

