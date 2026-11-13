@tool
class_name CatacombsScenery
extends TrackScenery
## Catacombs Descent (GDD 8.5): a race through the quarried tunnels under
## Paris. The whole lap runs under low stone vaults, lit by wall torches,
## candles and a few shafts of pale light through street grates. In driving
## order: the tall Barriere d'Enfer start chamber; the ossuary galleries
## behind the "Arrete ! C'est ici l'Empire de la Mort" lintel, walls of
## stacked bones set with rows of skulls; a crypt of burial niches and
## sarcophagi; a service passage of pipes and red emergency lamps; a flooded
## cistern of columns standing in black water; a forgotten chapel; more
## ossuary; a bare-rock quarry propped with timber; and a tomb gallery back
## to the start. The shortcut is a low, half-flooded crypt passage blocked by
## fallen rubble. Textures are CC0 Poly Haven sets plus a generated bone-wall
## texture. Positions are layout coordinates matching catacombs_descent.tscn.

## Zone starts (layout points on the main road), in driving order.
const START_FROM := Vector3(-180, 0, 0)
const OSSUARY_FROM := Vector3(110, 0, 0)
const CRYPT_FROM := Vector3(521, 0, 125)
const PASSAGE_FROM := Vector3(472, 0, 372)
const CISTERN_FROM := Vector3(189, 0, 490)
const CHAPEL_FROM := Vector3(140, 0, 651)
const OSSUARY_B_FROM := Vector3(-20, 0, 659)
const QUARRY_FROM := Vector3(-298, 0, 395)
const GALLERY_FROM := Vector3(-176, 0, 150)
## Light shafts through street grates (points on the main road).
const GRATES: Array[Vector3] = [Vector3(-20, 0, 0), Vector3(400, 0, 86), Vector3(187, 0, 600),
		Vector3(-66, 0, 560), Vector3(-200, 0, 95)]
const SKULL_CHUNK := 100.0
const ROOF_CELL := 2.0

var _skulls: Dictionary = {}
var _skull_mesh: ArrayMesh
var _roof: Dictionary = {}
var torches: int = 0
## Every skull's position (track-local), kept for tests: headless runs don't
## store MultiMesh transforms, so they can't be read back from the chunks.
var skull_origins: PackedVector3Array = PackedVector3Array()


func build() -> void:
	_setup_materials()
	_skulls.clear()
	_roof.clear()
	skull_origins.clear()
	torches = 0
	var h := track.road_width * 0.5
	var main := TunnelBuilder.new(self)
	main.on_roof = mark_roof
	main.place_skull = place_skull
	var grates: Array = []
	for g in GRATES:
		grates.append(_off(g))
	var tunnel := {"left_wall": h + 3.0, "right_wall": h + 3.0, "wall_h": 4.0, "crown": 7.5, "torch_every": 18.0, "grates": grates}
	var zones := [
		[START_FROM, {"left_wall": h + 7.0, "right_wall": h + 7.0, "wall_h": 8.0, "crown": 15.0, "wall_key": "blocks",
				"bay": 9.0, "torch_every": 16.0}],
		[OSSUARY_FROM, {"left_style": "skulls", "right_style": "skulls", "candles_every": 11.0}],
		[CRYPT_FROM, {"wall_h": 4.2, "crown": 7.0, "left_style": "tombs", "right_style": "tombs", "candles_every": 15.0}],
		[PASSAGE_FROM, {"wall_h": 4.5, "left_style": "pipes", "right_style": "pipes", "torch_every": 30.0, "lamps_every": 22.0}],
		[CISTERN_FROM, {"left_wall": h + 9.0, "right_wall": h + 9.0, "wall_h": 6.0, "crown": 12.0, "wall_key": "blocks", "bay": 9.0}],
		[CHAPEL_FROM, {"left_wall": h + 13.0, "wall_h": 5.0, "crown": 11.0, "left_style": "stone", "right_style": "skulls",
				"wall_key": "blocks", "candles_every": 9.0}],
		[OSSUARY_B_FROM, {"left_style": "skulls", "right_style": "skulls", "candles_every": 13.0}],
		[QUARRY_FROM, {"crown": 6.8, "wall_key": "rock", "vault_key": "rock", "left_style": "rock", "right_style": "rock",
				"bay": 7.0, "torch_every": 24.0}],
		[GALLERY_FROM, {"left_style": "tombs", "right_style": "skulls", "candles_every": 14.0}],
	]
	var offsets: Array[float] = []
	for z in zones:
		offsets.append(_off(z[0]))
	for i in zones.size():
		var opts: Dictionary = tunnel.duplicate()
		opts.merge(zones[i][1], true)
		main.build(offsets[i], offsets[(i + 1) % zones.size()], opts)
		await step(0.75 * (i + 1) / zones.size())
	_start_chamber(offsets[0], offsets[1])
	_ossuary_gate(offsets[1])
	await step(0.8)
	_cistern(offsets[4], offsets[5], h + 9.0)
	await step(0.87)
	_chapel(offsets[5], offsets[6])
	await step(0.93)
	torches = main.torch_count()
	if not track.shortcuts.is_empty():
		_flooded_crypt(track.shortcuts[0])
	_commit_skulls()


func _off(p: Vector3) -> float:
	return track.curve.get_closest_offset(p)


# --- roof map (tests check the whole lap is under a ceiling) ---------------------------

func mark_roof(f: Transform3D, from_lateral: float, to_lateral: float) -> void:
	var along := 0.0
	while along <= TunnelBuilder.STEP:
		var lat := from_lateral
		while lat <= to_lateral:
			var p := f * Vector3(lat, 0, -along)
			_roof[Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL)))] = true
			lat += 1.0
		along += 1.0


## True if a track-local point is under a vault or ceiling slab.
func is_roofed(p: Vector3) -> bool:
	return _roof.has(Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL))))


# --- materials -----------------------------------------------------------------------

func _setup_materials() -> void:
	textured("wall", "old_stone_wall", Color(0.78, 0.7, 0.6), 3.0, 0.9)
	textured("vault", "old_stone_wall", Color(0.62, 0.55, 0.47), 3.5, 0.9)
	textured("blocks", "large_sandstone_blocks", Color(0.86, 0.78, 0.66), 4.0, 0.85)
	textured("rib", "large_sandstone_blocks", Color(0.75, 0.68, 0.58), 2.0, 0.85)
	textured("rock", "mossy_rock", Color(0.62, 0.53, 0.44), 3.0, 0.95)
	textured("slab", "monastery_stone_floor", Color(0.72, 0.66, 0.58), 2.0, 0.85)
	textured("pipe", "rusty_metal_02", Color(0.7, 0.6, 0.55), 1.5, 0.6, 0.4)
	material("niche", Color(0.03, 0.025, 0.02), 0.0, 0.0, 1.0)
	material("iron", Color(0.06, 0.055, 0.05), 0.0, 0.7, 0.5)
	material("wood", Color(0.22, 0.14, 0.08), 0.0, 0.0, 0.85)
	material("wax", Color(0.92, 0.86, 0.72), 0.15, 0.0, 0.6)
	material("flame", Color(1.0, 0.58, 0.22), 4.0)
	material("red_lamp", Color(1.0, 0.1, 0.06), 3.0)
	material("grate_glow", Color(0.7, 0.8, 1.0), 2.5)
	material("statue", Color(0.82, 0.8, 0.75), 0.0, 0.0, 0.6)
	material("cloth", Color(0.32, 0.04, 0.04), 0.0, 0.0, 0.9)
	# Black, still crypt water: faint ripples, silt, torch-coloured glints.
	var water := water_material(Color(0.01, 0.012, 0.015), Color(0.05, 0.055, 0.06), 0.95, 0.0, 0.6, 0.8)
	water.set_shader_parameter("glint_color", Color(1.0, 0.7, 0.4))
	water.set_shader_parameter("ripple_speed", 0.4)
	register_material("water", water)
	register_material("ossuary", _ossuary_material())


## Generated bone-wall texture: three courses of femur ends, then a course of
## skulls, repeated, with a matching normal map for relief.
func _ossuary_material() -> StandardMaterial3D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.04, 0.03))
	bump.fill(Color.BLACK)
	var y := 0
	while y < size:
		for course in 3:
			var x := rng.randi_range(0, 6)
			while x < size + 8:
				_bone_blob(img, bump, x + 7, y + course * 14 + 7, rng.randf_range(5.0, 6.8), rng.randf_range(4.2, 5.6))
				x += rng.randi_range(12, 15)
		var sx := rng.randi_range(0, 8)
		while sx < size + 10:
			_skull_glyph(img, bump, sx, y + 42)
			sx += rng.randi_range(19, 23)
		y += 64
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	bump.bump_map_to_normal_map(6.0)
	bump.generate_mipmaps()
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(bump)
	m.roughness = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _bone_color() -> Color:
	return Color(0.74, 0.64, 0.48).lerp(Color(0.5, 0.4, 0.28), rng.randf())


## A shaded ellipse of bone (a femur end), wrapping horizontally.
func _bone_blob(img: Image, bump: Image, cx: int, cy: int, rx: float, ry: float, color: Color = Color(0, 0, 0, 0)) -> void:
	var c := _bone_color() if color.a == 0.0 else color
	var size := img.get_width()
	for py in range(cy - int(ry) - 1, cy + int(ry) + 2):
		if py < 0 or py >= size:
			continue
		for px in range(cx - int(rx) - 1, cx + int(rx) + 2):
			var u := (px - cx) / rx
			var v := (py - cy) / ry
			var d := u * u + v * v
			if d > 1.0:
				continue
			var dome := sqrt(1.0 - d)
			var x := posmod(px, size)
			img.set_pixel(x, py, c.darkened(0.45 * (1.0 - dome) + 0.15 * clampf(v, 0.0, 1.0)))
			bump.set_pixel(x, py, Color.WHITE * (0.35 + 0.65 * dome))


func _hole(img: Image, bump: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	var size := img.get_width()
	for py in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for px in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var u := (px - cx) / rx
			var v := (py - cy) / ry
			if u * u + v * v <= 1.0 and py >= 0 and py < size:
				img.set_pixel(posmod(px, size), py, Color(0.03, 0.02, 0.015))
				bump.set_pixel(posmod(px, size), py, Color(0.1, 0.1, 0.1))


## A skull face-on, about 20 x 21 px, top-left at (x, y).
func _skull_glyph(img: Image, bump: Image, x: int, y: int) -> void:
	var c := _bone_color()
	_bone_blob(img, bump, x + 10, y + 8, 9.0, 8.0, c)
	_bone_blob(img, bump, x + 10, y + 14, 6.5, 6.0, c)
	_hole(img, bump, x + 6.6, y + 10.0, 2.6, 2.3)
	_hole(img, bump, x + 13.4, y + 10.0, 2.6, 2.3)
	_hole(img, bump, x + 10.0, y + 14.0, 1.0, 1.6)
	for t in 4:
		_hole(img, bump, x + 7.3 + t * 1.8, y + 18.0, 0.5, 0.9)


# --- skulls (instanced) ------------------------------------------------------------------

func place_skull(xf: Transform3D) -> void:
	var key := Vector2i(int(floor(xf.origin.x / SKULL_CHUNK)), int(floor(xf.origin.z / SKULL_CHUNK)))
	if not _skulls.has(key):
		_skulls[key] = []
	(_skulls[key] as Array).append(xf)


func skull_count() -> int:
	var total := 0
	for key in _skulls:
		total += (_skulls[key] as Array).size()
	return total


func _commit_skulls() -> void:
	if _skull_mesh == null:
		_skull_mesh = _build_skull_mesh()
	for key: Vector2i in _skulls:
		var list: Array = _skulls[key]
		var centre := Vector3((key.x + 0.5) * SKULL_CHUNK, 0, (key.y + 0.5) * SKULL_CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _skull_mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, (list[i] as Transform3D).translated(-centre))
			skull_origins.append((list[i] as Transform3D).origin)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Skulls_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 120.0 + SKULL_CHUNK * 0.71
		add_node(mmi)
	_skulls.clear()


## One skull, resting on its base and facing -Z: cranium, cheeks and jaw in
## bone, with dark eye sockets, nose and a line of teeth.
func _build_skull_mesh() -> ArrayMesh:
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.78, 0.69, 0.54)
	bone.roughness = 0.7
	bone.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.035, 0.028, 0.02)
	dark.roughness = 1.0
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0, 0.115, 0.01), Vector3(0.085, 0.085, 0.1), 5, 8)
	_ellipsoid(st, Vector3(0, 0.06, -0.045), Vector3(0.062, 0.05, 0.06), 4, 7)
	_ellipsoid(st, Vector3(0, 0.022, -0.06), Vector3(0.045, 0.022, 0.04), 3, 6)
	st.set_material(bone)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		_ellipsoid(st, Vector3(sx * 0.031, 0.085, -0.088), Vector3(0.024, 0.021, 0.012), 3, 6)
	_ellipsoid(st, Vector3(0, 0.055, -0.1), Vector3(0.009, 0.015, 0.006), 2, 4)
	_ellipsoid(st, Vector3(0, 0.033, -0.098), Vector3(0.035, 0.004, 0.005), 2, 4)
	st.set_material(dark)
	st.commit(mesh)
	return mesh


func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, rings: int, segments: int) -> void:
	var v := func(p: float, a: float) -> Vector3: return Vector3(sin(p) * cos(a), cos(p), sin(p) * sin(a))
	for ri in rings:
		var p0 := PI * ri / rings
		var p1 := PI * (ri + 1) / rings
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var q: Array[Vector3] = [v.call(p0, a0), v.call(p1, a0), v.call(p1, a1), v.call(p0, a1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var u: Vector3 = q[idx]
				st.set_normal((u / r).normalized() if r.x > 0.0 else u)
				st.add_vertex(c + u * r)


# --- start chamber -------------------------------------------------------------------------

func _start_chamber(from_offset: float, to_offset: float) -> void:
	var h := track.road_width * 0.5
	var span := fposmod(to_offset - from_offset, track.length)
	# A colonnade of cut-stone piers up to the vault, both sides.
	var d := 6.0
	while d < span - 4.0:
		for side: float in [-1.0, 1.0]:
			var p := at(from_offset + d, side * (h + 4.0))
			if clear(p.origin, 0.9):
				var top := TunnelBuilder.vault_height(h + 7.0, h + 7.0, 8.0, 15.0, h + 4.0)
				add_box("blocks", Vector3(1.6, top, 1.6), p.translated_local(Vector3(0, top * 0.5, 0)))
				add_box("rib", Vector3(2.1, 0.5, 2.1), p.translated_local(Vector3(0, 0.25, 0)))
				add_box("rib", Vector3(2.1, 0.5, 2.1), p.translated_local(Vector3(0, 7.8, 0)))
		d += 12.0
	# Iron braziers either side of the start gantry.
	for along: float in [-22.0, 22.0]:
		for side: float in [-1.0, 1.0]:
			var p := at(track.start_line_offset + along, side * (h + 2.4))
			if clear(p.origin, 0.5):
				_brazier(p)


func _brazier(xf: Transform3D) -> void:
	for i in 3:
		var leg := xf.rotated_local(Vector3.UP, TAU * i / 3.0).translated_local(Vector3(0.35, 0, 0))
		add_box("iron", Vector3(0.08, 1.3, 0.08), leg.translated_local(Vector3(0, 0.65, 0)))
	add_cyl("iron", 0.35, 0.3, xf.translated_local(Vector3(0, 1.2, 0)), 8, 0.6)
	add_cone("flame", 0.45, 0.9, xf.translated_local(Vector3(0, 1.45, 0)), 7)
	var light := add_flicker_light(xf.origin + Vector3(0, 2.3, 0), Color(1.0, 0.52, 0.2), 3.2, 20.0, 0.0)
	light.flame = true


# --- the ossuary gate ----------------------------------------------------------------------

## The famous lintel over the way into the ossuary, seen from the start chamber.
func _ossuary_gate(offset: float) -> void:
	var f := at(offset - 0.4)
	add_box("slab", Vector3(13.0, 2.6, 0.4), f.translated_local(Vector3(0, 9.3, 0.1)))
	add_box("rib", Vector3(13.6, 0.3, 0.6), f.translated_local(Vector3(0, 10.75, 0.1)))
	add_box("rib", Vector3(13.6, 0.3, 0.6), f.translated_local(Vector3(0, 7.85, 0.1)))
	var label := add_text("ARRÊTE ! C'EST ICI\nL'EMPIRE DE LA MORT", f.translated_local(Vector3(0, 9.3, 0.35)),
			Color(0.12, 0.09, 0.07), 0.011, 96)
	label.outline_size = 0
	label.line_spacing = -8.0
	for side: float in [-1.0, 1.0]:
		var p := at(offset - 2.0, side * 7.6)
		var light := add_flicker_light(p.origin + Vector3(0, 6.2, 0) + f.basis.z * 1.5, Color(1.0, 0.6, 0.28), 2.0, 12.0, 0.0)
		light.flame = true


# --- flooded cistern -----------------------------------------------------------------------

func _cistern(from_offset: float, to_offset: float, wall: float) -> void:
	var h := track.road_width * 0.5
	var span := fposmod(to_offset - from_offset, track.length)
	var d := 0.0
	var n := 0
	while d < span:
		var o := from_offset + d
		for side: float in [-1.0, 1.0]:
			# Black water from the barrier to the wall.
			var water := at(o, side * (h + 1.0 + (wall - h - 1.2) * 0.5))
			if clear(water.origin, 0.0) or edge_distance(water.origin) > 1.0:
				add_box("water", Vector3(wall - h - 1.2, 0.05, 3.05), water.translated_local(Vector3(0, 0.04, 0)))
			if n % 3 == 0:
				for lat: float in [h + 3.2, h + 6.6]:
					var p := at(o, side * lat)
					if clear(p.origin, 0.8):
						var top := TunnelBuilder.vault_height(wall, wall, 6.0, 12.0, lat)
						add_cyl("blocks", 0.65, top, p, 10)
						add_box("rib", Vector3(1.6, 0.4, 1.6), p.translated_local(Vector3(0, top - 0.2, 0)))
						add_box("rib", Vector3(1.6, 0.3, 1.6), p.translated_local(Vector3(0, 0.3, 0)))
		d += 3.0
		n += 1


# --- forgotten chapel ----------------------------------------------------------------------

func _chapel(from_offset: float, to_offset: float) -> void:
	var h := track.road_width * 0.5
	var wl := h + 13.0
	var span := fposmod(to_offset - from_offset, track.length)
	# Paved nave floor beside the road, and an arcade of columns along it.
	var d := 0.0
	var n := 0
	while d < span:
		var o := from_offset + d
		var floor_xf := at(o, -(h + 1.0 + (wl - h - 1.0) * 0.5))
		if edge_distance(floor_xf.origin) > 1.0:
			add_box("slab", Vector3(wl - h - 1.0, 0.06, 3.05), floor_xf.translated_local(Vector3(0, 0.03, 0)))
		if n % 4 == 1:
			var p := at(o, -(h + 2.9))
			if clear(p.origin, 0.6):
				var top := TunnelBuilder.vault_height(wl, h + 3.0, 5.0, 11.0, -(h + 2.9))
				add_cyl("blocks", 0.5, top, p, 10)
				add_box("rib", Vector3(1.3, 0.35, 1.3), p.translated_local(Vector3(0, top - 0.2, 0)))
		d += 3.0
		n += 1
	# The apse: steps, an altar, a white statue, a cross on the wall, candles.
	var mid := from_offset + span * 0.5
	var apse := at(mid, -(wl - 4.0))
	add_box("slab", Vector3(6.0, 0.3, 9.0), apse.translated_local(Vector3(0, 0.15, 0)))
	add_box("slab", Vector3(4.5, 0.3, 7.0), apse.translated_local(Vector3(-0.5, 0.45, 0)))
	add_box("blocks", Vector3(1.3, 1.1, 3.2), apse.translated_local(Vector3(0.4, 1.15, 0)))
	add_box("cloth", Vector3(1.35, 0.05, 3.25), apse.translated_local(Vector3(0.4, 1.72, 0)))
	add_box("cloth", Vector3(0.05, 0.6, 3.25), apse.translated_local(Vector3(1.08, 1.42, 0)))
	var plinth := apse.translated_local(Vector3(-1.9, 0.6, 0))
	add_box("blocks", Vector3(1.2, 1.4, 1.2), plinth.translated_local(Vector3(0, 0.7, 0)))
	_statue(plinth.translated_local(Vector3(0, 1.4, 0)).rotated_local(Vector3.UP, PI * 0.5))
	add_box("rib", Vector3(0.35, 4.2, 0.6), apse.translated_local(Vector3(-3.7, 4.6, 0)))
	add_box("rib", Vector3(0.35, 0.6, 2.6), apse.translated_local(Vector3(-3.7, 5.6, 0)))
	var builder := TunnelBuilder.new(self)
	builder.place_skull = place_skull
	for i in 10:
		var c := apse.translated_local(Vector3(rng.randf_range(-1.5, 2.6), 0.6, rng.randf_range(-4.0, 4.0)))
		if absf(c.origin.distance_to(apse.origin)) > 1.2:
			builder.candles(c, rng.randi_range(5, 9), i % 4 == 0)
	for side: float in [-1.0, 1.0]:
		builder.skull_pile(apse.translated_local(Vector3(1.6, 0.3, side * 3.6)), 12)
		_candelabra(apse.translated_local(Vector3(0.6, 0.6, side * 2.4)))
	builder.shaft(at(mid), -(wl - 5.0), TunnelBuilder.vault_height(wl, h + 3.0, 5.0, 11.0, -(wl - 5.0)))


func _candelabra(xf: Transform3D) -> void:
	add_box("iron", Vector3(0.08, 1.8, 0.08), xf.translated_local(Vector3(0, 0.9, 0)))
	add_box("iron", Vector3(0.08, 0.06, 1.0), xf.translated_local(Vector3(0, 1.8, 0)))
	for k in 3:
		var c := xf.translated_local(Vector3(0, 1.83, -0.45 + k * 0.45))
		add_cyl("wax", 0.04, 0.25, c, 6)
		add_sphere("flame", 0.035, c.translated_local(Vector3(0, 0.3, 0)), 2, 4)
	var light := add_flicker_light(xf.origin + Vector3(0, 2.3, 0), Color(1.0, 0.68, 0.36), 1.4, 9.0, 0.0)
	light.flame = true


func _statue(xf: Transform3D) -> void:
	add_cyl("statue", 0.45, 1.5, xf, 8, 0.35)
	add_cyl("statue", 0.35, 0.9, xf.translated_local(Vector3(0, 1.5, 0)), 8, 0.3)
	add_sphere("statue", 0.26, xf.translated_local(Vector3(0, 2.65, 0)), 4, 6)
	add_box("statue", Vector3(0.18, 0.9, 0.18), xf.translated_local(Vector3(0.45, 1.9, 0)).rotated_local(Vector3.FORWARD, -0.5))
	add_box("statue", Vector3(0.18, 0.9, 0.18), xf.translated_local(Vector3(-0.45, 1.9, 0)).rotated_local(Vector3.FORWARD, 0.5))


# --- the flooded crypt (shortcut) ----------------------------------------------------------

func _flooded_crypt(sc: TrackShortcut) -> void:
	var h := sc.road_width * 0.5
	var wall := h + 2.5
	var tube := TunnelBuilder.new(self, sc)
	tube.on_roof = mark_roof
	tube.place_skull = place_skull
	tube.build(0.0, sc.length, {"left_wall": wall, "right_wall": wall, "wall_h": 3.2, "crown": 5.6,
			"left_style": "tombs", "right_style": "skulls", "torch_every": 34.0, "candles_every": 16.0, "caps": false})
	torches += tube.torch_count()
	# Black water lapping both sides of the flooded stretch.
	var water_from := 90.0
	var water_to := minf(sc.length - 60.0, 300.0)
	var d := water_from
	while d < water_to:
		var f := tube.frame(d)
		for side: float in [-1.0, 1.0]:
			var p := f.translated_local(Vector3(side * (h + 1.0 + (wall - h - 1.0) * 0.5), 0.05, 0))
			if edge_distance(p.origin) > 0.4:
				add_box("water", Vector3(wall - h - 1.0, 0.05, 3.05), p)
		d += 3.0
	# The half-collapsed stretch around the rubble barricade: fallen blocks
	# heaped against both walls and a broken rib hanging from the vault.
	var rubble := 330.0
	for i in 18:
		var side := -1.0 if i % 2 == 0 else 1.0
		var f := tube.frame(rubble + rng.randf_range(-10.0, 10.0))
		var p := f.translated_local(Vector3(side * rng.randf_range(h + 1.2, wall - 0.4), rng.randf_range(0.1, 0.5), 0))
		if edge_distance(p.origin) > 0.6:
			var s := rng.randf_range(0.4, 1.1)
			add_box("rock", Vector3(s, s * 0.7, s * 1.2), p.rotated_local(Vector3.UP, rng.randf() * TAU).rotated_local(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)))
	var hang := tube.frame(rubble - 6.0)
	# It hangs over the rubble beside the road, clear of the cars and the camera.
	add_box("rib", Vector3(0.7, 0.5, 3.4), hang.translated_local(Vector3(h + 1.6, 4.6, 0)).rotated_local(Vector3.FORWARD, 0.7).rotated_local(Vector3.UP, PI * 0.5))
	# Ceiling slabs over the two junctions, so the vaults close up where the tunnels meet.
	_junction_slab(sc.point_at(28.0), track.curve.sample_baked(track.wrap_offset(sc.start_offset + 28.0)))
	_junction_slab(sc.point_at(sc.length - 28.0), track.curve.sample_baked(track.wrap_offset(sc.end_offset - 28.0)))


func _junction_slab(a: Vector3, b: Vector3) -> void:
	var c := (a + b) * 0.5
	var size := 44.0
	add_box("vault", Vector3(size, 0.6, size), xform(c + Vector3(0, 7.9, 0)))
	var x := -size * 0.5
	while x <= size * 0.5:
		var z := -size * 0.5
		while z <= size * 0.5:
			var p := c + Vector3(x, 0, z)
			_roof[Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL)))] = true
			z += 1.0
		x += 1.0
