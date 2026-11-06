@tool
class_name HoiaScenery
extends TrackScenery
## Hoia Baciu Run (GDD 8.4): a dirt road through Romania's haunted forest on
## a foggy, moonlit night. Dense pines and Hoia's crooked, S-bent trees close
## in on the road; a forest graveyard with a chapel ruin; a stone viaduct
## over a ravine; a ruined red-stone castle whose gatehouse is the shortcut;
## and the Round Clearing, the treeless meadow at the heart of the legend.
## Believable, not supernatural: lanterns, candles and a few faint marsh
## lights in the fog. Positions are layout coordinates matching
## hoia_baciu.tscn.

const TERRAIN_BOUNDS := Rect2(-560, -260, 1340, 1060)
## The crooked grove around the S-bends.
const GROVE := Rect2(110, -90, 460, 230)
const GRAVEYARD := Rect2(590, 90, 80, 180)
const CHAPEL := Vector3(640, 0, 300)
## Ravine under the viaduct: centre line z, from x.
const RAVINE_Z := 450.0
const RAVINE_FROM_X := 430.0
const RAVINE_HALF := 38.0
const RAVINE_DEPTH := 22.0
const VIADUCT_FROM := Vector3(556, 0, 385)
const VIADUCT_TO := Vector3(548, 0, 515)
## Castle curtain wall (x, z rect) with gates where the shortcut crosses.
const CASTLE := Rect2(-115, 420, 130, 108)
const KEEP := Vector3(-40, 0, 360)
const CLEARING := Vector3(-225, 0, 235)
const CLEARING_RADIUS := 72.0
const BOG := Vector3(300, 0, 585)
const MOON_DIR := Vector3(-2500, 900, -300)


func build() -> void:
	textured("terrain_grass", "forest_leaves_02", Color(0.42, 0.4, 0.34), 6.0, 0.95)
	textured("terrain_mud", "brown_mud_leaves_01", Color(0.3, 0.29, 0.26), 6.0, 0.8)
	textured("bark", "pine_bark", Color(0.55, 0.5, 0.46), 2.0, 0.9)
	textured("stone", "red_sandstone_wall", Color(0.78, 0.55, 0.47), 3.0, 0.9)
	textured("rock", "mossy_rock", Color(0.6, 0.62, 0.56), 3.0, 0.9)
	textured("wood", "wood_peeling_paint_weathered", Color(0.36, 0.3, 0.25), 2.0, 0.9)
	textured("headstone", "concrete_moss", Color(0.55, 0.57, 0.55), 2.0, 0.9)
	material("needles", Color(0.06, 0.09, 0.07), 0.0, 0.0, 0.95)
	material("fern", Color(0.08, 0.12, 0.07), 0.0, 0.0, 0.95)
	material("iron", Color(0.05, 0.05, 0.06), 0.0, 0.6, 0.6)
	material("banner", Color(0.32, 0.05, 0.05), 0.0, 0.0, 0.9)
	material("lantern", Color(1.0, 0.62, 0.28), 2.5)
	material("candle", Color(1.0, 0.75, 0.4), 3.0)
	material("window_glow", Color(1.0, 0.55, 0.22), 1.2)
	material("wisp", Color(0.55, 0.9, 0.85), 2.0)
	var stream := StandardMaterial3D.new()
	stream.albedo_color = Color(0.03, 0.04, 0.05)
	stream.metallic = 0.6
	stream.roughness = 0.06
	register_material("stream", stream)

	SceneryTerrain.build(self, TERRAIN_BOUNDS, 8.0, 3.0, -100.0, "terrain_grass", "terrain_mud", "", 3, _carve)
	_forest()
	_start_arch()
	_graveyard()
	_viaduct()
	_castle()
	_keep()
	_clearing()
	_bog()
	_undergrowth()
	_lanterns()
	_moon()


## Ravine under the viaduct (terrain carve; also used by the stream).
func _carve(x: float, z: float) -> float:
	if x < RAVINE_FROM_X - 20.0:
		return 0.0
	var centre := RAVINE_Z + sin(x / 45.0) * 10.0
	var across := absf(z - centre) / RAVINE_HALF
	if across >= 1.0:
		return 0.0
	var fade := clampf((x - RAVINE_FROM_X + 20.0) / 40.0, 0.0, 1.0)
	var shape := 1.0 - across * across
	return -RAVINE_DEPTH * shape * fade


func _in_clearing(p: Vector3, margin: float = 0.0) -> bool:
	return Vector2(p.x - CLEARING.x, p.z - CLEARING.z).length() < CLEARING_RADIUS + margin


func _in_castle(p: Vector3, margin: float = 0.0) -> bool:
	return CASTLE.grow(margin).has_point(Vector2(p.x, p.z))


func _in_ravine(p: Vector3) -> bool:
	return _carve(p.x, p.z) < -1.0


# --- Forest -----------------------------------------------------------------------

func _forest() -> void:
	var trees := TreeBuilder.new(self, "bark", "needles", random_seed)
	var step := 7.0
	var x := TERRAIN_BOUNDS.position.x
	while x < TERRAIN_BOUNDS.end.x:
		var z := TERRAIN_BOUNDS.position.y
		while z < TERRAIN_BOUNDS.end.y:
			var p := Vector3(x + rng.randf_range(-3.0, 3.0), 0, z + rng.randf_range(-3.0, 3.0))
			z += step
			if _in_clearing(p, 8.0) or _in_castle(p, 10.0) or _in_ravine(p) or p.distance_to(KEEP) < 30.0 \
					or GRAVEYARD.grow(6.0).has_point(Vector2(p.x, p.z)) or p.distance_to(CHAPEL) < 16.0:
				continue
			var edge := edge_distance(p)
			if edge < track.barrier_thickness + 2.5:
				continue
			# Dense wall of trunks by the road, thinning into the fog.
			var keep_chance := 0.75 if edge < 18.0 else (0.45 if edge < 38.0 else 0.22)
			if rng.randf() > keep_chance:
				continue
			var yaw := rng.randf() * TAU
			var kind := "pine"
			var roll := rng.randf()
			if GROVE.has_point(Vector2(p.x, p.z)):
				# The crooked grove: bent trees, bases all bowing the same way.
				kind = "crooked" if roll < 0.7 else "pine"
				yaw = PI * 0.5 + rng.randf_range(-0.35, 0.35)
			elif _in_clearing(p, 30.0):
				kind = "crooked" if roll < 0.5 else "bare"
				# Bowing away from the clearing's centre.
				yaw = atan2(p.x - CLEARING.x, p.z - CLEARING.z) + rng.randf_range(-0.3, 0.3)
			elif roll < 0.12:
				kind = "bare"
			elif roll < 0.18:
				kind = "snag"
			elif roll < 0.24:
				kind = "crooked"
			var s := rng.randf_range(0.85, 1.15)
			trees.place(kind, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), p + Vector3(0, -0.1, 0)))
		x += step
	trees.commit()


## Logs, stumps, boulders and ferns near the road.
func _undergrowth() -> void:
	for i in 1400:
		var p := Vector3(rng.randf_range(TERRAIN_BOUNDS.position.x, TERRAIN_BOUNDS.end.x), 0,
				rng.randf_range(TERRAIN_BOUNDS.position.y, TERRAIN_BOUNDS.end.y))
		if _in_clearing(p) or _in_castle(p, 4.0) or _in_ravine(p) or not clear(p, 1.5):
			continue
		if edge_distance(p) > 36.0 and rng.randf() < 0.7:
			continue
		var roll := rng.randf()
		if roll < 0.5:
			# Fern clump.
			for k in rng.randi_range(3, 6):
				var h := rng.randf_range(0.4, 0.9)
				add_box("fern", Vector3(0.08, h, 0.9), xform(p + Vector3(rng.randf_range(-0.8, 0.8), h * 0.4, rng.randf_range(-0.8, 0.8)),
						rng.randf() * TAU).rotated_local(Vector3.FORWARD, rng.randf_range(-0.7, 0.7)))
		elif roll < 0.72:
			var r := rng.randf_range(0.6, 2.2)
			add_sphere("rock", r, xform(p + Vector3(0, r * 0.25, 0), rng.randf() * TAU).scaled_local(Vector3(1.2, 0.65, 1.0)), 4, 7)
		elif roll < 0.88:
			var len := rng.randf_range(4.0, 10.0)
			add_cyl("bark", rng.randf_range(0.25, 0.45), len, xform(p + Vector3(0, 0.3, 0), rng.randf() * TAU).rotated_local(Vector3.RIGHT, PI * 0.5).translated_local(Vector3(0, -len * 0.5, 0)), 7)
		else:
			add_cyl("bark", rng.randf_range(0.35, 0.55), rng.randf_range(0.4, 1.0), xform(p), 7, 0.3)


# --- Start / finish ------------------------------------------------------------------

func _start_arch() -> void:
	var o := track.start_line_offset - 6.0
	var half := track.road_width * 0.5 + track.barrier_thickness + 1.2
	var c := at(o)
	for side: float in [-1.0, 1.0]:
		var post := c.translated_local(Vector3(side * half, 0, 0))
		add_box("wood", Vector3(0.9, 8.0, 0.9), post.translated_local(Vector3(0, 4.0, 0)))
		add_box("wood", Vector3(1.4, 0.6, 1.4), post.translated_local(Vector3(0, 0.3, 0)))
		# Carved notches and a lantern on each post.
		for k in 4:
			add_box("wood", Vector3(1.05, 0.15, 1.05), post.translated_local(Vector3(0, 1.5 + k * 1.4, 0)))
		add_box("lantern", Vector3(0.4, 0.55, 0.4), post.translated_local(Vector3(-side * 0.7, 5.2, 0)))
		add_flicker_light((post.translated_local(Vector3(-side * 0.9, 5.2, 0))).origin, Color(1.0, 0.62, 0.3), 1.6, 18.0, 0.15)
		# Banners on poles before the arch.
		for b in 3:
			var pole := at(o - 20.0 - b * 22.0, side * (half + 1.5))
			if clear(pole.origin, 0.4):
				add_box("wood", Vector3(0.18, 7.0, 0.18), pole.translated_local(Vector3(0, 3.5, 0)))
				add_box("banner", Vector3(0.06, 3.2, 1.2), pole.translated_local(Vector3(0, 4.8, 0.65)))
				add_box("wood", Vector3(0.1, 0.1, 1.5), pole.translated_local(Vector3(0, 6.45, 0.65)))
	# Lintel with a small shingled roof.
	add_box("wood", Vector3(half * 2.0 + 2.0, 0.8, 1.0), c.translated_local(Vector3(0, 8.2, 0)))
	add_box("wood", Vector3(half * 2.0 + 1.0, 0.4, 0.7), c.translated_local(Vector3(0, 7.2, 0)))
	for side: float in [-1.0, 1.0]:
		add_box("wood", Vector3(half * 2.0 + 3.0, 0.2, 1.8), c.translated_local(Vector3(0, 9.0, side * 0.55)).rotated_local(Vector3.RIGHT, side * 0.45))
	_label("HOIA BACIU", c.translated_local(Vector3(0, 8.2, 0.52)), Color(0.85, 0.7, 0.45), 0.045)


func _label(text: String, xf: Transform3D, color: Color, size: float) -> Label3D:
	var l := add_text(text, xf, color, size, 110)
	l.outline_size = 0
	return l


# --- Graveyard -----------------------------------------------------------------------

func _graveyard() -> void:
	var r := GRAVEYARD
	# Iron railing round the plot, a few panels fallen.
	var corners := [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var d := 0.0
		var length := a.distance_to(b)
		while d < length:
			var p := a.lerp(b, d / length)
			if clear(p, 0.3) and rng.randf() > 0.12:
				add_box("iron", Vector3(0.06, 1.6, 0.06), xform(p + Vector3(0, 0.8, 0)))
				add_box("iron", Vector3(0.05, 0.05, 2.0), Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), p + Vector3(0, 1.45, 0) + (b - a).normalized()))
			d += 2.0
	# Rows of leaning crosses and headstones.
	var x := r.position.x + 5.0
	while x < r.end.x - 4.0:
		var z := r.position.y + 5.0
		while z < r.end.y - 4.0:
			var p := Vector3(x + rng.randf_range(-0.6, 0.6), 0, z + rng.randf_range(-0.6, 0.6))
			if rng.randf() < 0.85 and clear(p, 1.0):
				var lean := xform(p, PI * 0.5 + rng.randf_range(-0.2, 0.2)).rotated_local(Vector3.FORWARD, rng.randf_range(-0.25, 0.25)).rotated_local(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
				if rng.randf() < 0.6:
					var h := rng.randf_range(1.4, 2.3)
					add_box("wood", Vector3(0.18, h, 0.18), lean.translated_local(Vector3(0, h * 0.5, 0)))
					add_box("wood", Vector3(0.18, 0.16, 0.9), lean.translated_local(Vector3(0, h * 0.72, 0)))
				else:
					add_box("headstone", Vector3(0.25, rng.randf_range(0.8, 1.3), 0.8), lean.translated_local(Vector3(0, 0.5, 0)))
				if rng.randf() < 0.12:
					add_box("candle", Vector3(0.08, 0.2, 0.08), xform(p + Vector3(0.6, 0.1, 0)))
			z += 4.0
		x += 4.0
	for k in 3:
		add_flicker_light(Vector3(r.position.x + 20 + k * 22, 0.6, r.get_center().y + rng.randf_range(-40, 40)), Color(1.0, 0.7, 0.4), 0.9, 10.0, 0.2)
	_chapel()


func _chapel() -> void:
	var c := xform(CHAPEL, PI * 0.5)
	add_box("stone", Vector3(9.0, 6.0, 0.8), c.translated_local(Vector3(0, 3.0, -7.0)))
	add_box("stone", Vector3(0.8, 4.5, 14.0), c.translated_local(Vector3(-4.5, 2.25, 0)))
	add_box("stone", Vector3(0.8, 2.6, 8.0), c.translated_local(Vector3(4.5, 1.3, -3.0)))
	# Gable, a bell cote and a broken arch window with candlelight inside.
	add_pyramid("stone", 4.5, 3.5, c.translated_local(Vector3(0, 6.0, -7.0)).scaled_local(Vector3(1, 1, 0.12)))
	add_box("stone", Vector3(1.6, 2.2, 1.6), c.translated_local(Vector3(0, 10.2, -7.0)))
	add_box("window_glow", Vector3(1.2, 2.0, 0.1), c.translated_local(Vector3(0, 3.6, -6.55)))
	add_box("wood", Vector3(0.2, 2.2, 0.2), c.translated_local(Vector3(0, 12.4, -7.0)))
	add_box("wood", Vector3(1.2, 0.2, 0.2), c.translated_local(Vector3(0, 12.9, -7.0)))
	for k in 5:
		add_box("candle", Vector3(0.1, 0.3, 0.1), c.translated_local(Vector3(-1.5 + k * 0.7, 0.9, -5.8)))
	add_box("stone", Vector3(4.0, 0.8, 1.0), c.translated_local(Vector3(0, 0.4, -5.8)))
	add_flicker_light(c * Vector3(0, 1.6, -5.0), Color(1.0, 0.65, 0.35), 1.6, 14.0, 0.25)


# --- Viaduct -------------------------------------------------------------------------

func _viaduct() -> void:
	var a := track.curve.get_closest_offset(VIADUCT_FROM)
	var b := track.curve.get_closest_offset(VIADUCT_TO)
	var half := track.road_width * 0.5 + track.barrier_thickness
	var span := 18.0
	var d := a
	while d < b:
		var c := at(d)
		var into := fmod(d - a, span)
		# Arch soffit height below the deck: a semicircle between piers.
		var u := (into - span * 0.5) / (span * 0.5 - 1.5)
		var ground := _carve(c.origin.x, c.origin.z)
		var pier := into < 3.0
		if pier:
			var h := -ground + 1.0
			if h > 2.0:
				add_box("stone", Vector3(half * 2.0 + 1.0, h, 3.0), c.translated_local(Vector3(0, -h * 0.5 - 0.6, 0)))
				add_box("stone", Vector3(half * 2.0 + 2.0, 0.6, 3.6), c.translated_local(Vector3(0, -h + 1.4, 0)))
		else:
			var arch_y := -1.2 - (span * 0.5 - 1.5) * sqrt(maxf(0.0, 1.0 - u * u)) * 0.9
			var top := -0.6
			# Spandrel walls on both faces and the soffit between them.
			for side: float in [-1.0, 1.0]:
				add_box("stone", Vector3(0.9, top - arch_y + 0.1, 3.05), c.translated_local(Vector3(side * (half + 0.05), (top + arch_y) * 0.5, 0)))
			add_box("stone", Vector3(half * 2.0, 0.7, 3.05), c.translated_local(Vector3(0, arch_y - 0.35, 0)))
		# Deck edge and parapet stones (the barriers are the real rails).
		add_box("stone", Vector3(half * 2.0 + 1.6, 0.6, 3.05), c.translated_local(Vector3(0, -0.3, 0)))
		for side: float in [-1.0, 1.0]:
			add_box("stone", Vector3(0.5, 1.2, 3.05), c.translated_local(Vector3(side * (half + 0.6), 0.6, 0)))
		d += 3.0
	# The stream at the bottom of the ravine.
	var x := RAVINE_FROM_X
	while x < TERRAIN_BOUNDS.end.x:
		var z := RAVINE_Z + sin(x / 45.0) * 10.0
		var z2 := RAVINE_Z + sin((x + 10.0) / 45.0) * 10.0
		var fade := clampf((x - RAVINE_FROM_X + 20.0) / 40.0, 0.0, 1.0)
		var y := -RAVINE_DEPTH * fade + 1.0
		add_box("stream", Vector3(10.4, 0.1, 6.0), Transform3D(Basis.looking_at(Vector3(10.0, 0, z2 - z).normalized(), Vector3.UP).rotated(Vector3.UP, PI * 0.5), Vector3(x + 5.0, y, (z + z2) * 0.5)))
		if rng.randf() < 0.35:
			var r := rng.randf_range(0.8, 2.0)
			add_sphere("rock", r, xform(Vector3(x, y, z + rng.randf_range(-6, 6))).scaled_local(Vector3(1.2, 0.6, 1)), 4, 6)
		x += 10.0


# --- Castle ruin -----------------------------------------------------------------------

func _castle() -> void:
	var r := CASTLE
	var wall_h := 11.0
	# Curtain wall segments every 3 m, broken in places, with crenellations;
	# gates on the shortcut line (east and west) are left open.
	var edges := [[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)],
			[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)],
			[Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)],
			[Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y)]]
	var sc: TrackShortcut = track.shortcuts[0] if not track.shortcuts.is_empty() else null
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var basis := Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP)
		var d := 1.5
		var k := 0
		while d < length:
			var p2 := a + dir * d
			var p := Vector3(p2.x, 0, p2.y)
			d += 3.0
			k += 1
			if not clear(p, 1.5):
				continue # the gates and the road outside
			var h := wall_h
			var broken := sin(p.x * 0.07 + p.z * 0.05) > 0.55
			if broken:
				h = rng.randf_range(2.0, 5.0)
			add_box("stone", Vector3(2.2, h, 3.05), Transform3D(basis, p + Vector3(0, h * 0.5, 0)))
			if not broken and k % 2 == 0:
				add_box("stone", Vector3(2.4, 1.2, 1.5), Transform3D(basis, p + Vector3(0, h + 0.6, 0)))
	# Round corner towers, one collapsed.
	var towers := [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]
	for i in towers.size():
		var t: Vector3 = towers[i]
		if not clear(t, 6.0):
			continue
		var h := 18.0 if i != 2 else 7.0
		add_cyl("stone", 5.0, h, xform(t), 14)
		if i != 2:
			add_cyl("stone", 5.6, 1.4, xform(t + Vector3(0, h, 0)), 14)
			add_box("window_glow", Vector3(0.6, 1.4, 0.1), xform(t + Vector3(0, h * 0.6, 5.02)))
	# Gatehouses spanning the shortcut at the east and west walls.
	if sc != null:
		for gate_x in [r.end.x, r.position.x]:
			var g := Vector3(gate_x, 0, 465.0)
			var d_sc := sc.local_offset(g)
			var gxf := Transform3D(Basis.looking_at(sc.tangent_at(d_sc), Vector3.UP), sc.point_at(d_sc))
			var half := sc.road_width * 0.5 + 2.5
			for side: float in [-1.0, 1.0]:
				add_box("stone", Vector3(4.0, 15.0, 7.0), gxf.translated_local(Vector3(side * (half + 2.0), 7.5, 0)))
				add_box("stone", Vector3(4.6, 1.2, 7.6), gxf.translated_local(Vector3(side * (half + 2.0), 15.6, 0)))
			add_box("stone", Vector3(half * 2.0 + 8.0, 4.0, 7.0), gxf.translated_local(Vector3(0, 12.0, 0)))
			# The raised portcullis, rusted in its slot.
			add_box("iron", Vector3(half * 2.0, 2.2, 0.25), gxf.translated_local(Vector3(0, 9.0, -2.0)))
			add_box("lantern", Vector3(0.4, 0.6, 0.4), gxf.translated_local(Vector3(half - 0.5, 6.0, 3.6)))
			add_flicker_light(gxf * Vector3(half - 1.0, 6.0, 4.5), Color(1.0, 0.62, 0.3), 2.0, 22.0, 0.15)
	# Courtyard: rubble heaps and a dry well.
	for i in 14:
		var p := Vector3(rng.randf_range(r.position.x + 6, r.end.x - 6), 0, rng.randf_range(r.position.y + 6, r.end.y - 6))
		if clear(p, 2.0):
			add_box("stone", Vector3(rng.randf_range(1, 3), rng.randf_range(0.5, 1.5), rng.randf_range(1, 3)), xform(p, rng.randf() * TAU).rotated_local(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	var well := Vector3(r.get_center().x, 0, r.end.y - 20.0)
	if clear(well, 3.0):
		add_cyl("stone", 2.0, 1.0, xform(well), 12)
		add_cyl("iron", 1.6, 1.02, xform(well), 12)


## Ruined keep on a rocky rise, the landmark seen across the lap.
func _keep() -> void:
	var k := KEEP
	add_cone("rock", 26.0, 9.0, xform(k), 12)
	add_box("stone", Vector3(16.0, 30.0, 14.0), xform(k + Vector3(0, 9.0 + 15.0, 0), 0.3))
	add_box("stone", Vector3(9.0, 10.0, 9.0), xform(k + Vector3(4.0, 39.0 + 5.0, -2.0), 0.3))
	# Broken top: one high corner standing.
	add_box("stone", Vector3(3.0, 8.0, 3.0), xform(k + Vector3(-5.5, 39.0 + 4.0, 4.5), 0.3))
	for i in 6:
		var y := 14.0 + i * 4.5
		add_box("window_glow" if i % 3 == 1 else "iron", Vector3(0.1, 1.6, 0.7), xform(k + Vector3(8.05, y, rng.randf_range(-4, 4)), 0.3))
	add_light(k + Vector3(14.0, 24.0, 0), Color(1.0, 0.55, 0.25), 1.2, 30.0)


# --- Round Clearing ----------------------------------------------------------------------

func _clearing() -> void:
	# A treeless meadow ringed by bowing trees (placed in _forest). Just low
	# grass tufts and a ring of old stones.
	for i in 220:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * CLEARING_RADIUS
		var p := CLEARING + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if clear(p, 0.5):
			var h := rng.randf_range(0.2, 0.5)
			add_box("fern", Vector3(0.06, h, 0.5), xform(p + Vector3(0, h * 0.4, 0), rng.randf() * TAU))
	for i in 12:
		var ang := TAU * i / 12.0
		var p := CLEARING + Vector3(cos(ang), 0, sin(ang)) * (CLEARING_RADIUS - 4.0)
		if clear(p, 1.5) and i % 4 != 3:
			add_box("rock", Vector3(1.2, rng.randf_range(1.2, 2.2), 0.7), xform(p + Vector3(0, 0.6, 0), ang).rotated_local(Vector3.FORWARD, rng.randf_range(-0.2, 0.2)))


# --- Bog --------------------------------------------------------------------------------

func _bog() -> void:
	# Black water and dead snags beside the hairpin, with faint marsh lights.
	for i in 8:
		var p := BOG + Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-14, 30))
		if clear(p, 4.0):
			add_cyl("stream", rng.randf_range(3.0, 7.0), 0.06, xform(p + Vector3(0, -0.02, 0)), 12)
	for i in 4:
		var p := BOG + Vector3(rng.randf_range(-35, 35), 1.0, rng.randf_range(10, 30))
		if clear(p, 1.0):
			add_sphere("wisp", 0.15, xform(p), 3, 5)
			add_flicker_light(p, Color(0.5, 0.9, 0.85), 0.5, 7.0, 0.3)


# --- Lanterns and moon -------------------------------------------------------------------

func _lanterns() -> void:
	var d := 40.0
	var i := 0
	while d < track.length:
		var side := 1.0 if i % 2 == 0 else -1.0
		var post := at(d, side * (track.road_width * 0.5 + track.barrier_thickness + 2.0))
		if clear(post.origin, 0.5) and not _in_ravine(post.origin):
			add_box("wood", Vector3(0.22, 3.4, 0.22), post.translated_local(Vector3(0, 1.7, 0)))
			add_box("wood", Vector3(0.9, 0.12, 0.12), post.translated_local(Vector3(-side * 0.4, 3.3, 0)))
			add_box("lantern", Vector3(0.3, 0.42, 0.3), post.translated_local(Vector3(-side * 0.75, 2.95, 0)))
			if i % 2 == 0:
				add_flicker_light(post * Vector3(-side * 0.75, 2.8, 0), Color(1.0, 0.62, 0.3), 1.3, 16.0, 0.12)
		d += rng.randf_range(85.0, 120.0)
		i += 1


func _moon() -> void:
	# A pale disc low in the west behind the keep, unaffected by fog.
	var dir := MOON_DIR.normalized()
	var pos := dir * 1800.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.9, 1.0)
	m.set("disable_fog", true)
	var disc := SphereMesh.new()
	disc.radius = 45.0
	disc.height = 90.0
	var mi := add_mesh_instance(disc, m, "Moon")
	mi.position = pos
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(0.6, 0.7, 0.9, 0.12)
	halo.set("disable_fog", true)
	var glow := SphereMesh.new()
	glow.radius = 110.0
	glow.height = 220.0
	var hi := add_mesh_instance(glow, halo, "MoonHalo")
	hi.position = pos
