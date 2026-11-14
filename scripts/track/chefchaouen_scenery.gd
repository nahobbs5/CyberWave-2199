@tool
class_name ChefchaouenScenery
extends TrackScenery
## Chefchaouen (GDD 8.6i): the blue medina of the Rif mountains, Morocco, on
## a bright late morning. Streets of washed blue plaster climb from the
## lower square to the upper terrace and back down. The main loop is the
## wide Outer Street (up) and the Fountain Steps (down); the branch routes
## are the Blue Stairway (flowerpots and deep-blue doors on a steep climb)
## and the Market Lane (hanging rugs and a horseshoe arch). Stairs are drawn
## over a smooth ramp (the road surface is hidden there). Neon is kept for
## the fork signs, the boost surfaces and the start line.

const STAIR_BRANCH := "BlueStairway"
const MARKET_BRANCH := "MarketLane"
## Fork signs stand this far before each split.
const SIGN_LEAD := 125.0
## Overhead things (gantries, cables, arches) keep this clear of the road.
const OVERHEAD_CLEAR := 6.5
const TERRAIN_AMPLITUDE := 1.6
const KILIMS := 6

## For tests.
var sign_lead: Dictionary = {}
var stair_steps: int = 0
var houses: int = 0
var flowerpots: int = 0
var rugs: int = 0
var fountains: int = 0
var doors: int = 0
var lowest_overhead: float = INF

var _noise: FastNoiseLite
var _stair: TrackShortcut
var _market: TrackShortcut
var _builder: MedinaHouseBuilder
var _rug_tools: Array[SurfaceTool] = []
var _bounds := Rect2()


func build() -> void:
	_stair = _branch(STAIR_BRANCH)
	_market = _branch(MARKET_BRANCH)
	sign_lead.clear()
	stair_steps = 0
	rugs = 0
	fountains = 0
	lowest_overhead = INF
	_setup_materials()
	_bounds = _layout_bounds().grow(260.0)
	_noise = SceneryTerrain.make_noise(random_seed)
	SceneryTerrain.build(self, _bounds, 9.0, TERRAIN_AMPLITUDE, -100.0, "ground_grass", "ground", "", random_seed, _hill)
	await step(0.15)
	_stairs()
	await step(0.25)
	_builder = MedinaHouseBuilder.new(self)
	_line_routes()
	await step(0.55)
	_rooftops()
	await step(0.7)
	_market_lane()
	_fountain()
	_stair_pots()
	_galerie_tower()
	_fork_signs()
	_cables()
	_mountains()
	houses = _builder.houses
	doors = _builder.doors
	flowerpots = _builder.flowerpots
	await step(1.0)


func _branch(branch_name: String) -> TrackShortcut:
	for sc in track.shortcuts:
		if String(sc.name) == branch_name:
			return sc
	return null


func _layout_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for p in track.curve.get_baked_points():
		if first:
			r = Rect2(p.x, p.z, 0, 0)
			first = false
		r = r.expand(Vector2(p.x, p.z))
	return r


## The land: hugs the roads (SceneryTerrain), and beyond the town climbs
## toward the Rif to the north and falls away to the south.
func _hill(x: float, z: float) -> float:
	var north := maxf(0.0, -360.0 - z) * 0.45
	var south := -maxf(0.0, z - 520.0) * 0.25
	# Sunk under and right beside every road, so the coarse terrain grid
	# never pokes up through a road (the routes climb at different heights).
	var edge := edge_distance(Vector3(x, 0.0, z))
	var sink := -1.6 * (1.0 - smoothstep(2.0, 14.0, edge))
	return north + south + sink


func ground_y(x: float, z: float) -> float:
	return SceneryTerrain.height_at(self, _noise, TERRAIN_AMPLITUDE, x, z, _hill)


# --- routes ---------------------------------------------------------------------------

func _main_point(d: float) -> Vector3:
	return track.curve.sample_baked(track.wrap_offset(d))


func _main_forward(d: float) -> Vector3:
	var a := track.curve.sample_baked(track.wrap_offset(d - 1.5))
	var b := track.curve.sample_baked(track.wrap_offset(d + 1.5))
	return Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()


func _sc_forward(sc: TrackShortcut, d: float) -> Vector3:
	var t := sc.tangent_at(d)
	return Vector3(t.x, 0.0, t.z).normalized()


## Note the lowest point of something overhead (track-local) above the road under it.
func _overhead(bottom: Vector3) -> void:
	if edge_distance(bottom) < 0.0:
		lowest_overhead = minf(lowest_overhead, bottom.y - road_y_at(bottom))


# --- materials --------------------------------------------------------------------------

func _setup_materials() -> void:
	# Washed plaster (Poly Haven painted_plaster_wall, mean ~0.65 grey) tinted.
	textured("wall_blue", "painted_plaster_wall", Color(0.62, 0.92, 1.4), 3.0, 0.9)
	textured("wall_sky", "painted_plaster_wall", Color(0.9, 1.28, 1.6), 3.0, 0.9)
	textured("wall_pale", "painted_plaster_wall", Color(1.08, 1.3, 1.52), 3.0, 0.9)
	textured("wall_white", "painted_plaster_wall", Color(1.38, 1.42, 1.5), 3.0, 0.9)
	textured("wall_deep", "painted_plaster_wall", Color(0.28, 0.58, 1.35), 2.0, 0.85)
	textured("stone", "rough_plaster_brick", Color(1.15, 1.1, 1.05), 1.5, 0.95)
	textured("step_tread", "stone_tiles_02", Color(1.45, 1.45, 1.5), 1.6, 0.9)
	textured("step_riser", "painted_plaster_wall", Color(0.36, 0.72, 1.4), 1.0, 0.8)
	textured("door_blue", "painted_plaster_wall", Color(0.16, 0.66, 1.45), 1.2, 0.6)
	textured("shutter_blue", "painted_plaster_wall", Color(0.25, 0.75, 1.5), 1.0, 0.6)
	textured("door_wood", "wood_shutter", Color(1.0, 0.95, 0.9), 1.2, 0.7)
	textured("tile_green", "terracotta_floor_tiles", Color(0.5, 1.9, 1.2), 1.0, 0.6)
	textured("tile_red", "terracotta_floor_tiles", Color(1.6, 1.4, 1.3), 1.0, 0.6)
	textured("ground", "stone_tiles_02", Color(1.1, 1.05, 1.0), 3.0, 0.95)
	textured("ground_grass", "sparse_grass", Color(1.15, 1.2, 1.0), 6.0, 0.95)
	textured("roof", "painted_plaster_wall", Color(1.3, 1.32, 1.38), 4.0, 0.95)
	textured("bark", "bark_willow", Color(1.1, 1.05, 1.0), 1.5, 0.9)
	material("window_dark", Color(0.06, 0.08, 0.12), 0.0, 0.2, 0.4)
	material("iron", Color(0.08, 0.08, 0.09), 0.0, 0.6, 0.5)
	material("brass", Color(0.62, 0.48, 0.22), 0.0, 0.8, 0.35)
	material("lantern_glass", Color(1.0, 0.82, 0.5), 0.6, 0.0, 0.2)
	material("pot_terracotta", Color(0.72, 0.36, 0.2), 0.0, 0.0, 0.8)
	material("pot_yellow", Color(0.95, 0.75, 0.15), 0.0, 0.0, 0.6)
	material("pot_green", Color(0.15, 0.55, 0.3), 0.0, 0.0, 0.6)
	material("pot_red", Color(0.8, 0.12, 0.1), 0.0, 0.0, 0.6)
	material("pot_blue", Color(0.1, 0.35, 0.85), 0.0, 0.0, 0.6)
	material("plant", Color(0.18, 0.42, 0.14), 0.0, 0.0, 0.85)
	material("flower", Color(0.9, 0.2, 0.45), 0.05, 0.0, 0.8)
	material("leaf", Color(0.2, 0.42, 0.18), 0.0, 0.0, 0.85)
	material("cable", Color(0.1, 0.1, 0.1), 0.0, 0.3, 0.6)
	material("mountain", Color(0.44, 0.5, 0.42), 0.0, 0.0, 1.0)
	material("mountain_far", Color(0.55, 0.62, 0.7), 0.0, 0.0, 1.0)
	material("sign_board", Color(0.04, 0.05, 0.09), 0.0, 0.3, 0.4)
	material("neon_cyan", Color(0.2, 0.9, 1.0), 3.5)
	material("neon_magenta", Color(1.0, 0.2, 0.75), 3.5)
	material("neon_amber", Color(1.0, 0.7, 0.2), 3.5)
	material("neon_green", Color(0.3, 1.0, 0.5), 3.5)
	register_material("water", water_material(Color(0.04, 0.22, 0.3), Color(0.25, 0.6, 0.65), 0.82, 0.0, 0.2, 0.7))
	var zellige := StandardMaterial3D.new()
	zellige.albedo_texture = _zellige_texture()
	zellige.roughness = 0.25
	zellige.metallic = 0.1
	zellige.cull_mode = BaseMaterial3D.CULL_DISABLED
	register_material("zellige", zellige)
	_rug_tools.clear()
	for i in KILIMS:
		var rug := StandardMaterial3D.new()
		rug.albedo_texture = _kilim_texture(i)
		rug.roughness = 0.95
		rug.cull_mode = BaseMaterial3D.CULL_DISABLED
		register_material("rug%d" % i, rug)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_rug_tools.append(st)


## A Berber kilim: bands of lozenges, zigzags and stripes in reds, oranges,
## blues and cream, with fringes at the ends.
func _kilim_texture(variant: int) -> ImageTexture:
	var palettes := [
		[Color(0.72, 0.1, 0.08), Color(0.95, 0.55, 0.12), Color(0.92, 0.86, 0.7), Color(0.1, 0.12, 0.3)],
		[Color(0.85, 0.42, 0.1), Color(0.75, 0.12, 0.1), Color(0.95, 0.8, 0.3), Color(0.15, 0.3, 0.6)],
		[Color(0.16, 0.3, 0.65), Color(0.92, 0.86, 0.7), Color(0.78, 0.15, 0.12), Color(0.95, 0.6, 0.15)],
		[Color(0.6, 0.08, 0.18), Color(0.92, 0.86, 0.7), Color(0.2, 0.55, 0.45), Color(0.95, 0.7, 0.2)],
		[Color(0.9, 0.85, 0.72), Color(0.7, 0.1, 0.1), Color(0.1, 0.1, 0.12), Color(0.95, 0.5, 0.1)],
		[Color(0.95, 0.65, 0.1), Color(0.65, 0.1, 0.1), Color(0.2, 0.25, 0.55), Color(0.92, 0.86, 0.7)],
	]
	var pal: Array = palettes[variant % palettes.size()]
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var c: Color = pal[0]
			var band := y / 16
			var by := y % 16
			if y < 5 or y >= h - 5:
				# Fringe.
				c = (pal[2] as Color).darkened(0.1) if x % 3 != 0 else (pal[2] as Color).darkened(0.4)
			elif by < 2:
				c = pal[3]
			else:
				match (band + variant) % 3:
					0:
						# Lozenges.
						var dx := absi((x % 16) - 8)
						var dy := absi(by - 9)
						if dx + dy < 5:
							c = pal[1]
						elif dx + dy < 7:
							c = pal[2]
					1:
						# Zigzag.
						var zig := absi((x % 12) - 6)
						if absi(by - 4 - zig) < 2:
							c = pal[2]
						elif absi(by - 4 - zig) < 3:
							c = pal[1]
					_:
						if (x / 4 + by / 3) % 2 == 0:
							c = pal[1]
			# Woven grain.
			c = c.darkened(0.06 * float((x + y) % 2))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Zellige: eight-pointed stars in green, blue and white with dark joints.
func _zellige_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var green := Color(0.1, 0.5, 0.35)
	var blue := Color(0.1, 0.3, 0.75)
	var white := Color(0.92, 0.92, 0.88)
	var ochre := Color(0.85, 0.65, 0.2)
	for y in n:
		for x in n:
			var cx := float(x % 32) - 15.5
			var cy := float(y % 32) - 15.5
			var square := maxf(absf(cx), absf(cy))
			var diamond := (absf(cx) + absf(cy)) * 0.7071
			var star := minf(square, diamond)
			var tile_index := (x / 32 + y / 32) % 2
			var c := white
			if star < 9.0:
				c = green if tile_index == 0 else blue
			if star < 4.0:
				c = ochre
			if absf(star - 9.0) < 0.9 or absf(star - 4.0) < 0.7:
				c = Color(0.08, 0.08, 0.1)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A textured quad with 0..1 UVs (rugs, tiles): w x h in xf's XY plane.
static func _uv_quad(st: SurfaceTool, xf: Transform3D, w: float, h: float) -> void:
	var a := xf * Vector3(-w * 0.5, 0, 0)
	var b := xf * Vector3(w * 0.5, 0, 0)
	var c := xf * Vector3(w * 0.5, h, 0)
	var d := xf * Vector3(-w * 0.5, h, 0)
	var n := xf.basis.z.normalized()
	for v in [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [c, Vector2(1, 0)], [a, Vector2(0, 1)], [c, Vector2(1, 0)], [d, Vector2(0, 0)]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


# --- stairs ------------------------------------------------------------------------------

func _stairs() -> void:
	var stairs := StairBuilder.new(self)
	for r in track.hidden_surface:
		stairs.flight(_main_point, _main_forward, r.x, r.y, track.road_width + 0.4)
	if _stair != null:
		var sc := _stair
		for r in sc.hidden_surface:
			stairs.flight(sc.point_at, func(d: float) -> Vector3: return _sc_forward(sc, d), r.x, r.y, sc.road_width + 0.4)
	stair_steps = stairs.steps


# --- houses ------------------------------------------------------------------------------

## Houses along both sides of every route.
func _line_routes() -> void:
	var front_main := track.road_width * 0.5 + track.barrier_thickness + 0.25
	var view_from := -1.0
	var view_to := -1.0
	if _stair != null and _market != null:
		# The terrace's north side stays open: the view over the Rif.
		view_from = track.wrap_offset(_stair.end_offset - 60.0)
		view_to = _market.start_offset
	_line(_main_point, _main_forward, track.length, front_main, true, view_from, view_to)
	for sc in track.shortcuts:
		var s := sc
		_builder.pot_heavy = String(sc.name) == STAIR_BRANCH
		_line(sc.point_at, func(d: float) -> Vector3: return _sc_forward(s, d), sc.length,
				sc.road_width * 0.5 + track.barrier_thickness + 0.25, false, -1.0, -1.0)
	_builder.pot_heavy = false


func _line(point: Callable, forward: Callable, length: float, front: float, loop: bool, view_from: float,
		view_to: float) -> void:
	for side: float in [-1.0, 1.0]:
		var d := 0.0 if loop else 12.0
		var end := length if loop else length - 12.0
		while d < end:
			var width := rng.randf_range(4.5, 9.0)
			var c := d + width * 0.5
			var at: Vector3 = point.call(c)
			var fwd: Vector3 = forward.call(c)
			var in_view := side > 0.0 and view_from >= 0.0 and fposmod(c - view_from, track.length) < fposmod(view_to - view_from, track.length)
			if not in_view:
				_builder.house(at, fwd, side, front, at.y, width, rng.randf_range(6.0, 10.0), rng.randf_range(6.0, 11.5))
			d += width + rng.randf_range(0.0, 0.4)


## Rooftops filling the blocks between the streets and the town round them.
func _rooftops() -> void:
	var cell := 11.0
	var x := _bounds.position.x + 120.0
	while x < _bounds.end.x - 120.0:
		var z := _bounds.position.y + 120.0
		while z < _bounds.end.y - 120.0:
			var p := Vector3(x + rng.randf_range(-2.0, 2.0), 0, z + rng.randf_range(-2.0, 2.0))
			z += cell
			if edge_distance(p) < track.barrier_thickness + 12.0:
				continue
			var g := ground_y(p.x, p.z)
			var w := rng.randf_range(7.0, 10.5)
			var dpt := rng.randf_range(7.0, 10.5)
			var h := rng.randf_range(4.0, 9.5)
			var key: String = MedinaHouseBuilder.WALL_KEYS[rng.randi() % MedinaHouseBuilder.WALL_KEYS.size()]
			var yaw := rng.randf_range(-0.12, 0.12)
			add_box(key, Vector3(w, h + 4.0, dpt), xform(Vector3(p.x, g - 4.0 + (h + 4.0) * 0.5, p.z), yaw))
			add_box("roof", Vector3(w + 0.2, 0.3, dpt + 0.2), xform(Vector3(p.x, g + h + 0.1, p.z), yaw))
			if rng.randf() < 0.08:
				# A tiled roof, or a little rooftop room.
				add_box("tile_green" if rng.randf() < 0.5 else "tile_red", Vector3(w * 0.6, 0.2, dpt * 0.6),
						xform(Vector3(p.x, g + h + 0.3, p.z), yaw))
		x += cell


# --- Market Lane: rugs and the horseshoe arch ---------------------------------------------

func _market_lane() -> void:
	if _market == null:
		return
	var sc := _market
	var front := sc.road_width * 0.5 + track.barrier_thickness + 0.1
	for side: float in [-1.0, 1.0]:
		var d := sc.length * 0.08
		while d < sc.length * 0.92:
			var w := rng.randf_range(1.1, 1.8)
			var h := rng.randf_range(2.0, 3.3)
			var at := sc.point_at(d)
			var fwd := _sc_forward(sc, d)
			var right := fwd.cross(Vector3.UP).normalized()
			var p := at + right * side * front
			# Only where there's a wall behind (not a gap onto another road).
			if edge_distance(p + right * side * 1.0) > track.barrier_thickness:
				var basis := Basis(right.cross(Vector3.UP) * side * -1.0, Vector3.UP, -right * side)
				var top := at.y + rng.randf_range(3.6, 5.0)
				var xf := Transform3D(basis, Vector3(p.x, top - h, p.z)).rotated_local(Vector3.UP, rng.randf_range(-0.05, 0.05))
				_uv_quad(_rug_tools[rng.randi() % KILIMS], xf, w, h)
				add_box("iron", Vector3(w + 0.3, 0.05, 0.05), xf.translated_local(Vector3(0, h + 0.05, 0.05)))
				rugs += 1
			d += w + rng.randf_range(0.2, 1.4)
	for i in KILIMS:
		add_mesh_instance(_rug_tools[i].commit(), get_material("rug%d" % i), "Kilims%d" % i)
	_horseshoe_arch(sc, sc.length * 0.5)


## A whitewashed horseshoe arch across a route, the opening at least
## OVERHEAD_CLEAR over the road, set in a wall that joins the houses.
func _horseshoe_arch(sc: TrackShortcut, d: float) -> void:
	var at := sc.point_at(d)
	var fwd := _sc_forward(sc, d)
	var right := fwd.cross(Vector3.UP).normalized()
	var basis := Basis(right, Vector3.UP, -fwd)
	var half := sc.road_width * 0.5 + track.barrier_thickness + 0.3
	var xf := Transform3D(basis, at)
	var spring := OVERHEAD_CLEAR + 0.6
	# Piers and the wall above.
	for s in [-1.0, 1.0]:
		add_box("wall_white", Vector3(1.6, spring + 4.0, 1.4), xf.translated_local(Vector3(s * (half + 0.8), (spring + 4.0) * 0.5 - 1.0, 0)))
	var r := half
	var crown := spring + r * 0.95
	add_box("wall_white", Vector3(half * 2.0 + 3.2, 1.8, 1.4), xf.translated_local(Vector3(0, crown + 0.9, 0)))
	# The horseshoe ring: from beyond the springing round over the top.
	var prev := Vector2.ZERO
	var steps := 14
	for i in steps + 1:
		var a := lerpf(-0.25, PI + 0.25, float(i) / steps)
		var p := Vector2(cos(a) * r, spring + sin(a) * r * 0.95)
		if i > 0:
			var mid := (p + prev) * 0.5
			var seg := p - prev
			var piece := xf.translated_local(Vector3(mid.x, mid.y, 0)).rotated_local(Vector3.FORWARD, -atan2(seg.y, seg.x))
			add_box("wall_deep", Vector3(seg.length() + 0.1, 0.5, 1.5), piece)
			var bottom := xf * Vector3(mid.x, mid.y - 0.25, 0)
			_overhead(bottom)
		prev = p


# --- the tiled fountain on the Fountain Steps ----------------------------------------------

func _fountain() -> void:
	# Beside the third landing of the descent (between the last two flights).
	var hs := track.hidden_surface
	if hs.size() < 3:
		return
	var d := (hs[2].y + hs[3].x) * 0.5 if hs.size() >= 4 else hs[2].y + 30.0
	var at := _main_point(d)
	var fwd := _main_forward(d)
	var right := fwd.cross(Vector3.UP).normalized()
	var side := 1.0
	var face := at + right * side * (track.road_width * 0.5 + track.barrier_thickness + 0.4)
	var basis := Basis(fwd * side, Vector3.UP, right * side) # facing the road
	var xf := Transform3D(basis, Vector3(face.x, at.y, face.z))
	# Wall block with the tiled panel, a carved hood and a basin.
	add_box("wall_white", Vector3(6.0, 7.0, 1.4), xf.translated_local(Vector3(0, 3.0, 0.7)))
	var tiles := SurfaceTool.new()
	tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
	_uv_quad(tiles, xf.translated_local(Vector3(0, 0.6, -0.03)).rotated_local(Vector3.UP, PI), 3.6, 3.4)
	add_mesh_instance(tiles.commit(), get_material("zellige"), "FountainTiles")
	var hood := PackedVector2Array()
	for i in 11:
		var a := PI * i / 10.0
		hood.append(Vector2(cos(a) * 2.1, sin(a) * 1.3))
	add_prism("wall_deep", hood, 0.5, xf.translated_local(Vector3(0, 4.0, -0.2)))
	add_box("wall_deep", Vector3(4.4, 0.25, 0.7), xf.translated_local(Vector3(0, 4.0, -0.3)))
	add_box("wall_deep", Vector3(3.9, 0.8, 1.1), xf.translated_local(Vector3(0, 0.4, -0.6)))
	var water := PlaneMesh.new()
	water.size = Vector2(3.5, 0.8)
	var wm := add_mesh_instance(water, get_material("water"), "FountainWater")
	wm.transform = xf.translated_local(Vector3(0, 0.82, -0.6))
	# A brass spout.
	add_cyl("brass", 0.06, 0.4, xf.translated_local(Vector3(0, 2.0, -0.1)).rotated_local(Vector3.RIGHT, -PI * 0.5), 6)
	fountains += 1


# --- the Blue Stairway's flowerpots --------------------------------------------------------

func _stair_pots() -> void:
	if _stair == null:
		return
	var sc := _stair
	var lip := sc.road_width * 0.5 + track.barrier_thickness * 0.5
	var d := 20.0
	var side := 1.0
	while d < sc.length - 20.0:
		var at := sc.point_at(d)
		var right := _sc_forward(sc, d).cross(Vector3.UP).normalized()
		var p := at + right * side * lip
		# On top of the low wall, unless a junction opened it.
		if edge_distance(p) > -track.barrier_thickness:
			_builder.pot(xform(Vector3(p.x, at.y + track.barrier_height, p.z)))
		side = -side
		d += rng.randf_range(2.5, 4.5)


# --- the terrace tower ---------------------------------------------------------------------

func _galerie_tower() -> void:
	if _stair == null:
		return
	var d := track.wrap_offset(_stair.end_offset + 50.0)
	var at := _main_point(d)
	var fwd := _main_forward(d)
	var right := fwd.cross(Vector3.UP).normalized()
	var base := at + right * (track.road_width * 0.5 + track.barrier_thickness + 4.5)
	var basis := Basis(fwd, Vector3.UP, right) # front faces the road
	var xf := Transform3D(basis, base)
	add_box("wall_white", Vector3(7.0, 22.0, 7.0), xf.translated_local(Vector3(0, 6.0, 0)))
	add_box("wall_white", Vector3(4.5, 4.0, 4.5), xf.translated_local(Vector3(0, 19.0, 0)))
	add_box("wall_deep", Vector3(7.3, 0.3, 7.3), xf.translated_local(Vector3(0, 17.1, 0)))
	for k in 3:
		var y := 4.0 + k * 4.0
		add_box("door_wood", Vector3(1.6, 2.0, 0.12), xf.translated_local(Vector3(0, y, -3.56)))
		for s in [-1.0, 1.0]:
			add_box("door_wood", Vector3(0.8, 2.0, 0.08), xf.translated_local(Vector3(s * 1.3, y, -3.6)))
	add_box("brass", Vector3(0.08, 0.08, 1.2), xf.translated_local(Vector3(2.0, 9.0, -4.0)))
	add_box("lantern_glass", Vector3(0.5, 0.7, 0.5), xf.translated_local(Vector3(2.0, 8.4, -4.5)))
	var name_label := add_text("GALERIE", xf.translated_local(Vector3(-2.4, 7.5, -3.6)).rotated_local(Vector3.UP, PI).rotated_local(Vector3.FORWARD, PI * 0.5),
			Color(0.15, 0.3, 0.75), 0.03, 72)
	name_label.outline_size = 0


# --- fork signs ------------------------------------------------------------------------------

## A neon gantry before each fork: the branch's board over its lane, the main
## route's board over the other, each with an arrow and a route picture.
func _fork_signs() -> void:
	for sc in track.shortcuts:
		var is_stair := String(sc.name) == STAIR_BRANCH
		var d := track.wrap_offset(sc.start_offset - SIGN_LEAD)
		var at := _main_point(d)
		var fwd := _main_forward(d)
		var right := fwd.cross(Vector3.UP).normalized()
		var basis := Basis(right, Vector3.UP, -fwd)
		var xf := Transform3D(basis, at)
		var half := track.road_width * 0.5 + track.barrier_thickness + 0.6
		var beam_y := OVERHEAD_CLEAR + 1.0
		for s in [-1.0, 1.0]:
			add_box("iron", Vector3(0.5, beam_y + 3.0, 0.5), xf.translated_local(Vector3(s * half, (beam_y + 3.0) * 0.5 - 1.0, 0)))
		add_box("iron", Vector3(half * 2.0 + 0.6, 0.45, 0.5), xf.translated_local(Vector3(0, beam_y, 0)))
		_overhead(xf * Vector3(0, beam_y - 0.23, 0))
		var branch_side := signf(sc.start_lateral) if sc.start_lateral != 0.0 else -1.0
		var branch_name := "BLUE STAIRWAY" if is_stair else "MARKET LANE"
		var main_name := "OUTER STREET" if is_stair else "FOUNTAIN STEPS"
		_sign_board(xf.translated_local(Vector3(branch_side * 4.0, beam_y + 0.3, 0)), branch_name,
				"neon_cyan", Color(0.3, 0.95, 1.0), 0.0, "stairs" if is_stair else "rug")
		_sign_board(xf.translated_local(Vector3(-branch_side * 4.0, beam_y + 0.3, 0)), main_name,
				"neon_magenta", Color(1.0, 0.35, 0.85), -branch_side, "road" if is_stair else "fountain")
		sign_lead[String(sc.name)] = SIGN_LEAD


## One board standing on the beam: neon border, name, arrow (0 = straight on,
## +1 = right, -1 = left) and a little route picture.
func _sign_board(xf: Transform3D, text: String, neon: String, color: Color, arrow: float, icon: String) -> void:
	var w := 7.4
	var h := 2.0
	add_box("sign_board", Vector3(w, h, 0.2), xf.translated_local(Vector3(0, h * 0.5, 0)))
	for e in [[0.0, h, w, 0.12], [0.0, 0.0, w, 0.12]]:
		add_box(neon, Vector3(e[2], e[3], 0.24), xf.translated_local(Vector3(e[0], e[1], 0)))
	for s in [-1.0, 1.0]:
		add_box(neon, Vector3(0.12, h, 0.24), xf.translated_local(Vector3(s * w * 0.5, h * 0.5, 0)))
	var label := add_text(text, xf.translated_local(Vector3(0.1, h * 0.5, 0.14)), color, 0.0072, 96)
	label.outline_size = 0
	# Arrow (chevrons) at the left of the board.
	var ax := -w * 0.5 + 0.8
	var ay := h * 0.38
	if arrow == 0.0:
		for s in [-1.0, 1.0]:
			add_box(neon, Vector3(0.6, 0.14, 0.26), xf.translated_local(Vector3(ax + s * 0.2, ay + 0.15, 0)).rotated_local(Vector3.FORWARD, s * 0.75))
		add_box(neon, Vector3(0.14, 0.7, 0.26), xf.translated_local(Vector3(ax, ay - 0.15, 0)))
	else:
		for s in [-1.0, 1.0]:
			add_box(neon, Vector3(0.6, 0.14, 0.26), xf.translated_local(Vector3(ax + arrow * 0.15, ay + s * 0.2, 0)).rotated_local(Vector3.FORWARD, -s * arrow * 0.75))
		add_box(neon, Vector3(0.7, 0.14, 0.26), xf.translated_local(Vector3(ax - arrow * 0.2, ay, 0)))
	# Route picture at the right of the board.
	var ix := w * 0.5 - 0.9
	var iy := h * 0.2
	match icon:
		"stairs":
			for k in 4:
				add_box(neon, Vector3(0.22, 0.1 + k * 0.17, 0.26), xf.translated_local(Vector3(ix - 0.33 + k * 0.22, iy + (0.1 + k * 0.17) * 0.5, 0)))
		"road":
			for k in 5:
				var a := -0.9 + k * 0.45
				add_box(neon, Vector3(0.3, 0.12, 0.26), xf.translated_local(Vector3(ix + sin(a) * 0.3, iy + 0.1 + k * 0.28, 0)).rotated_local(Vector3.FORWARD, a))
		"rug":
			add_box(neon, Vector3(0.7, 0.08, 0.26), xf.translated_local(Vector3(ix, iy + 1.2, 0)))
			for k in 3:
				add_box(neon, Vector3(0.5, 0.08, 0.26), xf.translated_local(Vector3(ix, iy + 0.3 + k * 0.3, 0)))
		"fountain":
			add_box(neon, Vector3(0.8, 0.14, 0.26), xf.translated_local(Vector3(ix, iy + 0.1, 0)))
			add_box(neon, Vector3(0.12, 0.7, 0.26), xf.translated_local(Vector3(ix, iy + 0.5, 0)))
			for s in [-1.0, 1.0]:
				add_box(neon, Vector3(0.4, 0.1, 0.26), xf.translated_local(Vector3(ix + s * 0.2, iy + 0.95, 0)).rotated_local(Vector3.FORWARD, -s * 0.6))


# --- cables and hanging lanterns ---------------------------------------------------------

func _cables() -> void:
	var routes: Array = [[_main_point, _main_forward, track.length, track.road_width]]
	for sc in track.shortcuts:
		var s := sc
		routes.append([sc.point_at, func(d: float) -> Vector3: return _sc_forward(s, d), sc.length, sc.road_width])
	for r in routes:
		var point: Callable = r[0]
		var forward: Callable = r[1]
		var length: float = r[2]
		var width: float = r[3]
		var d := rng.randf_range(20.0, 50.0)
		while d < length - 20.0:
			var at: Vector3 = point.call(d)
			var fwd: Vector3 = forward.call(d)
			var right := fwd.cross(Vector3.UP).normalized()
			var y := at.y + rng.randf_range(7.6, 9.0)
			var reach := width * 0.5 + track.barrier_thickness + 0.6
			add_box("cable", Vector3(0.04, 0.04, reach * 2.0), Transform3D(Basis.looking_at(right, Vector3.UP), Vector3(at.x, y, at.z)))
			if rng.randf() < 0.5:
				var lamp := Vector3(at.x, y - 0.9, at.z) + right * rng.randf_range(-2.0, 2.0)
				add_box("cable", Vector3(0.03, 0.6, 0.03), xform(lamp + Vector3(0, 0.55, 0)))
				add_box("lantern_glass", Vector3(0.3, 0.45, 0.3), xform(lamp))
				add_box("brass", Vector3(0.36, 0.06, 0.36), xform(lamp + Vector3(0, 0.25, 0)))
				_overhead(lamp - Vector3(0, 0.25, 0))
			else:
				_overhead(Vector3(at.x, y - 0.05, at.z))
			d += rng.randf_range(35.0, 80.0)


# --- the Rif -----------------------------------------------------------------------------------

## Mountain ridges round the town, highest to the north behind it.
func _mountains() -> void:
	var centre := Vector3(_bounds.get_center().x, 0, _bounds.get_center().y)
	for ring: Array in [[1900.0, "mountain", 1.0], [2900.0, "mountain_far", 1.6]]:
		var radius: float = ring[0]
		var key: String = ring[1]
		var size_k: float = ring[2]
		var n := 72
		var noise := FastNoiseLite.new()
		noise.seed = random_seed + int(radius)
		noise.frequency = 1.2
		var prev_top := Vector3.ZERO
		var prev_base := Vector3.ZERO
		for i in n + 1:
			var a := TAU * i / n
			var dir := Vector3(cos(a), 0, sin(a))
			# North is -z: taller there.
			var north := clampf(-dir.z, 0.0, 1.0)
			var h := (160.0 + 380.0 * north + 120.0 * noise.get_noise_1d(float(i) / n * 8.0)) * size_k
			var base := centre + dir * radius + Vector3(0, -40.0, 0)
			var top := centre + dir * (radius + 220.0) + Vector3(0, h, 0)
			if i > 0:
				add_quad(key, prev_base, base, top, prev_top, centre)
			prev_top = top
			prev_base = base
