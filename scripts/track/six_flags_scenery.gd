@tool
class_name SixFlagsScenery
extends TrackScenery
## Six Flags New Orleans set dressing (GDD 8.2): a realistic, eerie,
## abandoned amusement park, after the real park left to rot after Hurricane
## Katrina. Believable decay only: rust, peeling paint, flood lines, standing
## water, overgrowth, debris, failing sodium lamps, search-and-rescue spray
## codes. The only clean light is the illegal racing neon on the barriers.
## Textures are CC0 Poly Haven sets (see README). Positions are layout
## coordinates matching six_flags_new_orleans.tscn.
##
## Representative section (full detail): the derelict entrance, the flooded
## Midway and the Coaster Run with a massive wooden coaster alongside and
## twice over the road. The rest of the lap has a lighter pass for now.

const WHEEL := Vector3(120, 0, -220)
const DROP_TOWER := Vector3(-150, 0, 180)
const CAROUSEL := Vector3(290, 0, 75)
const JESTER := Vector3(225, 0, -60)
const SLIDE_TOWER := Vector3(-330, 0, 500)
const COASTER_FROM := Vector3(440, 0, 362)
const COASTER_TO := Vector3(-70, 0, 370)
const BAYOU_FROM := Vector3(-410, 0, 170)
const BAYOU_TO := Vector3(-150, 0, -130)
const MIDWAY_FROM := Vector3(150, 0, 20)
const MIDWAY_TO := Vector3(420, 0, 230)
const TERRAIN_BOUNDS := Rect2(-820, -470, 1520, 1330)

const STALLS: Array[String] = ["GAMES", "PRIZES", "HOT DOGS", "RING TOSS", "FUNNEL CAKE", "SHOOTING GALLERY", "TICKETS"]
const SIGNS: Array[String] = ["KEEP OUT", "NO TRESPASSING", "CLOSED", "PRIVATE PROPERTY", "DANGER", "PARK CLOSED"]
const SPRAY: Array[Color] = [Color(0.7, 0.18, 0.15), Color(0.8, 0.8, 0.75), Color(0.85, 0.55, 0.15), Color(0.3, 0.5, 0.75)]
const SODIUM := Color(1.0, 0.6, 0.25)


func build() -> void:
	# PBR grime (CC0 Poly Haven, world-mapped).
	textured("rust", "rust_coarse_01", Color(0.85, 0.78, 0.72), 3.0, 0.8, 0.3)
	textured("rust_metal", "rusty_metal_02", Color(0.65, 0.62, 0.58), 3.0, 0.7, 0.4)
	textured("corrugated", "rusty_corrugated_iron", Color(0.7, 0.62, 0.58), 3.0, 0.75, 0.3)
	textured("moss_concrete", "concrete_moss", Color(0.55, 0.6, 0.52), 4.0)
	textured("concrete", "dirty_concrete", Color(0.5, 0.5, 0.5), 4.0)
	textured("peel", "peeling_painted_wall", Color(0.55, 0.42, 0.42), 3.0)
	textured("peel_white", "peeling_painted_wall", Color(0.7, 0.68, 0.66), 3.0)
	textured("wood", "wood_peeling_paint_weathered", Color(0.6, 0.57, 0.53), 2.5)
	textured("coaster_wood", "wood_peeling_paint_weathered", Color(0.78, 0.76, 0.72), 3.0)
	textured("planks", "distressed_painted_planks", Color(0.58, 0.56, 0.53), 2.0)
	textured("mud", "brown_mud_leaves_01", Color(0.45, 0.45, 0.4), 6.0, 0.95)
	textured("bark", "bark_willow", Color(0.42, 0.4, 0.38), 2.0)
	textured("tiles", "dirty_tiles", Color(0.55, 0.55, 0.55), 2.0)
	textured("brick", "painted_worn_brick", Color(0.5, 0.47, 0.45), 3.0)
	textured("terrain_grass", "sparse_grass", Color(0.55, 0.58, 0.5), 7.0, 0.95)
	textured("terrain_mud", "brown_mud_leaves_01", Color(0.38, 0.38, 0.34), 6.0, 0.6)
	# Flat colours.
	material("dead_leaf", Color(0.11, 0.12, 0.07), 0.0, 0.0, 0.95)
	material("moss", Color(0.14, 0.18, 0.11), 0.0, 0.0, 0.95)
	material("weeds", Color(0.17, 0.19, 0.1), 0.0, 0.0, 0.95)
	material("dark", Color(0.03, 0.03, 0.035), 0.0, 0.2, 0.8)
	material("canvas", Color(0.33, 0.14, 0.13), 0.0, 0.0, 0.9)
	material("canvas2", Color(0.45, 0.43, 0.38), 0.0, 0.0, 0.9)
	material("stain", Color(0.13, 0.11, 0.08), 0.0, 0.0, 0.95)
	material("bulb_dead", Color(0.22, 0.2, 0.17), 0.0, 0.3, 0.4)
	material("toy", Color(0.35, 0.28, 0.3), 0.0, 0.0, 0.9)
	material("jester_face", Color(0.62, 0.6, 0.55), 0.0, 0.0, 0.85)
	material("jester_red", Color(0.45, 0.08, 0.07), 0.0, 0.0, 0.85)
	# Water: standing flood water off the road, and thin puddles on it.
	var flood := StandardMaterial3D.new()
	flood.albedo_color = Color(0.05, 0.07, 0.07)
	flood.metallic = 0.4
	flood.roughness = 0.08
	register_material("terrain_water", flood)
	register_material("flood", flood)
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.04, 0.045, 0.05)
	puddle.metallic = 0.85
	puddle.roughness = 0.04
	register_material("puddle", puddle)
	register_material("chain_link", ChainLinkFence.material())

	SceneryTerrain.build(self, TERRAIN_BOUNDS, 7.0, 2.2, -0.12)
	_entrance()
	_midway()
	_coaster()
	_ferris_wheel()
	_road_puddles()
	_fences()
	# Lighter pass for the rest of the lap.
	_drop_tower()
	_water_park()
	_backlot()
	_bayou()
	_dead_woods()
	_debris()
	_signs_and_codes()
	_lamps()


# --- helpers ----------------------------------------------------------------------

func _dead_tree(pos: Vector3, h: float) -> void:
	var base := xform(pos, rng.randf() * TAU).rotated_local(Vector3.FORWARD, rng.randf_range(-0.1, 0.1))
	add_cyl("bark", 0.5, h, base, 6, 0.15)
	for b in rng.randi_range(3, 6):
		var y := h * rng.randf_range(0.45, 0.9)
		var len := rng.randf_range(2.5, 6.0)
		var branch := base.translated_local(Vector3(0, y, 0)).rotated_local(Vector3.UP, rng.randf() * TAU).rotated_local(Vector3.RIGHT, -rng.randf_range(0.4, 1.0))
		add_box("bark", Vector3(0.18, 0.18, len), branch.translated_local(Vector3(0, 0, -len * 0.5)))


func _weeds(pos: Vector3, spread: float) -> void:
	for i in rng.randi_range(4, 9):
		var p := pos + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var h := rng.randf_range(0.5, 1.6)
		add_box("weeds", Vector3(0.12, h, 0.5), xform(p + Vector3(0, h * 0.5, 0), rng.randf() * TAU).rotated_local(Vector3.FORWARD, rng.randf_range(-0.4, 0.4)))


func _wreck(pos: Vector3) -> void:
	var xf := xform(pos, rng.randf() * TAU).rotated_local(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
	add_box("rust", Vector3(1.9, 0.8, 4.4), xf.translated_local(Vector3(0, 0.45, 0)))
	add_box("rust_metal", Vector3(1.6, 0.6, 2.0), xf.translated_local(Vector3(0, 1.1, 0.3)))


## Dark flood-line band around the bottom of a box-shaped structure.
func _flood_line(xf: Transform3D, size: Vector3, depth: float = 1.5) -> void:
	add_box("stain", Vector3(size.x + 0.06, depth, size.z + 0.06), xf.translated_local(Vector3(0, depth * 0.5, 0)))


func _label(text: String, xf: Transform3D, color: Color, size: float) -> Label3D:
	var l := add_text(text, xf, color, size, 110)
	l.outline_size = 0
	return l


## Post-Katrina search-and-rescue mark: an X with date, team, findings.
func _x_code(xf: Transform3D, scale: float = 1.0) -> void:
	var col := SPRAY[rng.randi_range(0, SPRAY.size() - 1)]
	_label("X", xf, col, 0.09 * scale)
	_label("9-%d" % rng.randi_range(4, 19), xf.translated_local(Vector3(0, 0.9 * scale, 0)), col, 0.025 * scale)
	_label(["TF2", "CA-6", "NOFD", "LA-4"][rng.randi_range(0, 3)], xf.translated_local(Vector3(-0.9 * scale, 0, 0)), col, 0.022 * scale)
	_label("0", xf.translated_local(Vector3(0, -0.9 * scale, 0)), col, 0.025 * scale)
	_label(["NE", "1 DOG", "-", "NO ENTRY"][rng.randi_range(0, 3)], xf.translated_local(Vector3(1.0 * scale, 0, 0)), col, 0.02 * scale)


# --- Entrance (representative section) ---------------------------------------------------

func _entrance() -> void:
	var xf := at(track.start_line_offset + 30.0)
	var half := track.road_width * 0.5 + 4.0
	for side in [-1.0, 1.0]:
		var pillar := xf.translated_local(Vector3(side * half, 8.0, 0))
		add_box("moss_concrete", Vector3(4.0, 16.0, 4.0), pillar)
		_flood_line(xf.translated_local(Vector3(side * half, 0, 0)), Vector3(4.0, 0, 4.0), 1.6)
		add_box("concrete", Vector3(5.0, 1.2, 5.0), xf.translated_local(Vector3(side * half, 16.4, 0)))
		for v in 6:
			add_box("moss", Vector3(0.22, rng.randf_range(3, 9), 0.22),
					xf.translated_local(Vector3(side * half + rng.randf_range(-1.9, 1.9), 12.5, rng.randf_range(-2.1, 2.1))))
		# Chained gates pushed open, sagging on their hinges.
		var gate := xf.translated_local(Vector3(side * (half - 2.0), 2.6, 2.4)).rotated_local(Vector3.UP, side * 1.25).rotated_local(Vector3.BACK, side * 0.06)
		add_box("rust_metal", Vector3(6.0, 4.4, 0.12), gate.translated_local(Vector3(-side * 3.0, 0, 0)))
		add_box("rust_metal", Vector3(0.06, 0.06, 1.6), gate.translated_local(Vector3(-side * 0.4, 0.4, 0.2)).rotated_local(Vector3.RIGHT, 0.8))
		# Ticket booth with smashed windows, and toppled turnstiles.
		var booth := xf.translated_local(Vector3(side * (half + 8.0), 0, -6.0))
		add_box("peel_white", Vector3(4.0, 3.0, 3.0), booth.translated_local(Vector3(0, 1.5, 0)))
		add_box("dark", Vector3(3.0, 1.1, 3.1), booth.translated_local(Vector3(0, 1.9, 0)))
		add_box("rust", Vector3(4.4, 0.3, 3.4), booth.translated_local(Vector3(0, 3.15, 0)))
		_flood_line(booth, Vector3(4.0, 0, 3.0), 1.4)
		for t in 3:
			var stile := booth.translated_local(Vector3(-side * (4.0 + t * 1.6), 0.0, 3.0))
			if t == 1:
				stile = stile.translated_local(Vector3(0, 0.45, 0)).rotated_local(Vector3.FORWARD, PI * 0.5)
			add_cyl("rust_metal", 0.45, 1.0, stile, 8)
			add_box("rust_metal", Vector3(0.06, 0.06, 1.2), stile.translated_local(Vector3(0, 0.9, 0.5)))
	# The sign board: peeling, stained, with letters simply missing.
	add_box("peel", Vector3(half * 2.0 + 4.0, 7.0, 1.0), xf.translated_local(Vector3(0, 19.5, 0)))
	add_box("rust", Vector3(half * 2.0 + 4.4, 0.4, 1.1), xf.translated_local(Vector3(0, 23.1, 0)))
	add_box("rust", Vector3(half * 2.0 + 4.4, 0.4, 1.1), xf.translated_local(Vector3(0, 15.9, 0)))
	var top := xf.translated_local(Vector3(1.0, 23.5, 0))
	add_cone("rust", 1.6, 6.0, top)
	for side in [-1.0, 1.0]:
		add_box("rust", Vector3(1.2, 3.5, 0.8), top.translated_local(Vector3(side * 1.6, 2.0, 0)).rotated_local(Vector3.FORWARD, side * 0.6))
	var letters := "SIX FLAGS"
	for i in letters.length():
		if letters[i] == " " or i == 5 or i == 8:
			continue # missing L and S
		var lx := (i - (letters.length() - 1) * 0.5) * 2.6
		_label(letters[i], xf.translated_local(Vector3(lx, 20.6, 0.55)), Color(0.62, 0.58, 0.52), 0.07)
	_label("NEW ORLEANS", xf.translated_local(Vector3(0, 17.6, 0.55)), Color(0.55, 0.45, 0.35), 0.04)
	for i in 22:
		var bx := lerpf(-half - 1.5, half + 1.5, i / 21.0)
		if i % 5 != 3:
			add_sphere("bulb_dead", 0.22, xf.translated_local(Vector3(bx, 22.7, 0.6)), 3, 5)
	# Cracked plaza paving with weeds pushing through, beside the road.
	for i in 30:
		var p := at(track.start_line_offset + rng.randf_range(-40.0, 90.0), (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(half + 2.0, half + 26.0)).origin
		if clear(p, 1.0):
			_weeds(p, 1.5)


# --- Flooded Midway (representative section) ----------------------------------------------

func _midway() -> void:
	var a := track.curve.get_closest_offset(MIDWAY_FROM)
	var b := track.curve.get_closest_offset(MIDWAY_TO)
	var half := track.road_width * 0.5
	# Standing flood water either side of the Midway road.
	var d := a
	while d < b:
		for side in [-1.0, 1.0]:
			var wxf := at(d, side * (half + 22.0))
			if clear_rect(wxf, 38.0, 22.0):
				add_box("flood", Vector3(38.0, 0.06, 22.0), wxf.translated_local(Vector3(0, 0.05, 0)))
		d += 20.0
	d = a
	var n := 0
	while d < b:
		for side in [-1.0, 1.0]:
			var xf := at(d, side * (half + 9.0))
			if not clear_rect(xf, 10.0, 8.0):
				continue
			xf = xf.rotated_local(Vector3.UP, rng.randf_range(-0.08, 0.08))
			add_box("wood", Vector3(7.0, 3.2, 6.0), xf.translated_local(Vector3(0, 1.6, 0)))
			_flood_line(xf, Vector3(7.0, 0, 6.0), 1.3)
			for p in 3:
				add_box("planks", Vector3(0.12, 0.35, 6.4), xf.translated_local(Vector3(-side * 3.56, 1.3 + p * 0.55, 0)).rotated_local(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)))
			for stripe in 4:
				if rng.randf() < 0.35:
					continue
				add_box("canvas" if stripe % 2 == 0 else "canvas2", Vector3(1.6, 0.12, 7.0),
						xf.translated_local(Vector3(-side * 3.0 + (stripe - 1.5) * 1.6 * -side, 3.5 - stripe * 0.12, 0)).rotated_local(Vector3.FORWARD, side * (0.25 + rng.randf() * 0.25)))
			var sign_xf := xf.translated_local(Vector3(-side * 3.6, 4.6, 0))
			sign_xf.basis = sign_xf.basis * Basis(Vector3.UP, -side * PI * 0.5) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12))
			_label(STALLS[n % STALLS.size()], sign_xf, Color(0.48, 0.43, 0.38), 0.03)
			if n % 3 == 0:
				for t in 5:
					add_sphere("toy", rng.randf_range(0.3, 0.6), xf.translated_local(Vector3(-side * 4.4 + rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(-2, 2))), 3, 5)
			if n % 4 == 1:
				_x_code(xf.translated_local(Vector3(-side * 3.56, 2.0, 1.5)) * Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3.ZERO), 0.8)
			n += 1
		d += 26.0
	_carousel()
	_jester()


func _carousel() -> void:
	var c := xform(CAROUSEL)
	add_box("flood", Vector3(46, 0.06, 46), c.translated_local(Vector3(0, 0.05, 0)))
	add_cyl("wood", 14.0, 1.0, c, 20)
	_flood_line(c, Vector3(28, 0, 28), 0.6)
	add_cyl("rust", 1.2, 9.0, c, 8)
	for i in 12:
		var ang := TAU * i / 12.0
		if i % 4 == 2:
			continue
		add_cyl("rust_metal", 0.2, 6.5, c.translated_local(Vector3(cos(ang) * 11.0, 1.0, sin(ang) * 11.0)), 4)
		var horse := c.translated_local(Vector3(cos(ang) * 11.0, 2.6, sin(ang) * 11.0)).rotated_local(Vector3.UP, -ang)
		if i % 3 == 0:
			horse = c.translated_local(Vector3(cos(ang) * 15.0, 0.4, sin(ang) * 15.0)).rotated_local(Vector3.UP, -ang).rotated_local(Vector3.FORWARD, 1.4)
		add_box("peel_white", Vector3(0.8, 1.2, 2.2), horse)
		add_box("peel_white", Vector3(0.6, 1.0, 0.6), horse.translated_local(Vector3(0, 0.8, -1.0)))
	var roof := c.translated_local(Vector3(0, 7.2, 0)).rotated_local(Vector3.FORWARD, 0.18)
	add_cyl("canvas", 15.0, 0.8, roof, 20)
	add_cone("canvas2", 15.0, 5.5, roof.translated_local(Vector3(0, 0.8, 0)), 20)
	for i in 20:
		add_box("moss", Vector3(0.2, rng.randf_range(1, 4), 0.2), roof.translated_local(Vector3(cos(i) * 14.5, -1.0, sin(i) * 14.5)))


## The park's faded jester billboard: paint only, torn, unlit.
func _jester() -> void:
	var road := track.curve.get_closest_offset(JESTER)
	var to_road := track.curve.sample_baked(road) - JESTER
	to_road.y = 0.0
	var xf := Transform3D(Basis.looking_at(-to_road.normalized(), Vector3.UP), JESTER)
	for side in [-1.0, 1.0]:
		add_box("rust_metal", Vector3(0.6, 12, 0.6), xf.translated_local(Vector3(side * 8.0, 6.0, 0.6)))
	var board := xf.translated_local(Vector3(0, 17.0, 0)).rotated_local(Vector3.BACK, 0.05)
	add_box("peel_white", Vector3(18, 10, 0.4), board)
	add_box("dark", Vector3(5, 4, 0.5), board.translated_local(Vector3(7, 3.5, 0.02))) # torn corner
	var face := board.translated_local(Vector3(-1.5, 0, 0.25))
	add_cyl("jester_face", 3.6, 0.1, face.rotated_local(Vector3.RIGHT, PI * 0.5), 18)
	for s in [-1.0, 1.0]:
		add_cyl("dark", 0.55, 0.12, face.translated_local(Vector3(s * 1.3, 0.9, 0.02)).rotated_local(Vector3.RIGHT, PI * 0.5), 10)
		add_cone("jester_red", 1.4, 3.5, face.translated_local(Vector3(s * 2.4, 2.6, 0)).rotated_local(Vector3.BACK, -s * 0.5), 6)
	add_cyl("jester_red", 0.5, 0.14, face.translated_local(Vector3(0, -0.1, 0.03)).rotated_local(Vector3.RIGHT, PI * 0.5), 10)
	for i in 7:
		var t := (i - 3) / 3.0
		add_box("jester_red", Vector3(0.6, 0.25, 0.12), face.translated_local(Vector3(t * 1.8, -1.6 + t * t * 0.6, 0.04)))
	_label("SIX FLAGS NEW ORLEANS", board.translated_local(Vector3(3.5, -3.6, 0.25)), Color(0.4, 0.35, 0.3), 0.035)


# --- Coaster Run: the massive wooden coaster (representative section) -------------------------

func coaster_path() -> Array[PackedVector3Array]:
	var a := track.curve.get_closest_offset(COASTER_FROM)
	var b := track.curve.get_closest_offset(COASTER_TO)
	var out := PackedVector3Array()
	var start := a - 90.0
	var end := b - 30.0
	var d := start
	while d <= end:
		var u := d - a
		var lateral := 24.0
		# Two crossings over the road.
		if u > 150.0 and u < 200.0:
			lateral = lerpf(24.0, -24.0, smoothstep(150.0, 200.0, u))
		elif u >= 200.0 and u <= 330.0:
			lateral = -24.0
		elif u > 330.0 and u < 380.0:
			lateral = lerpf(-24.0, 24.0, smoothstep(330.0, 380.0, u))
		var h: float
		if d < a + 20.0:
			h = lerpf(4.0, 36.0, clampf((d - start) / 110.0, 0.0, 1.0))
		elif d < a + 70.0:
			h = lerpf(36.0, 12.0, (d - a - 20.0) / 50.0)
		else:
			h = 15.0 + 9.0 * (1.0 + sin((d - a - 70.0) / 45.0))
		if u > 140.0 and u < 390.0 and absf(lateral) < 23.0:
			h = maxf(h, 19.0)
		out.append(at(d, lateral).origin + Vector3(0, h, 0))
		d += 6.0
	# Turnaround at the west end, then the return run further out.
	var last := out[out.size() - 1]
	var back := PackedVector3Array()
	var center_xf := at(end, 39.0)
	var fwd := -center_xf.basis.z
	var right := center_xf.basis.x
	for k in 13:
		var ang := PI * k / 12.0
		var p := center_xf.origin + right * (-cos(ang) * 15.0) + fwd * (sin(ang) * 15.0)
		back.append(p + Vector3(0, lerpf(last.y, 14.0, k / 12.0), 0))
	d = end - 6.0
	while d >= a:
		back.append(at(d, 54.0).origin + Vector3(0, 10.0 + 5.0 * sin((d - a) / 30.0), 0))
		d -= 6.0
	return [out, back]


func _coaster() -> void:
	var paths := coaster_path()
	WoodenCoaster.build(self, paths[0], "coaster_wood", "rust_metal", "rust", 4.0)
	# The return run has a collapsed stretch.
	WoodenCoaster.build(self, paths[1], "coaster_wood", "rust_metal", "rust", 4.0, [Vector2(40, 44)])
	var fall := paths[1][42]
	var ground := Vector3(fall.x, 0, fall.z)
	if clear(ground, 6.0):
		for k in 4:
			add_box("coaster_wood", Vector3(0.3, rng.randf_range(6, 12), 0.3),
					xform(ground + Vector3(rng.randf_range(-4, 4), 2.0, rng.randf_range(-4, 4)), rng.randf() * TAU).rotated_local(Vector3.FORWARD, rng.randf_range(1.0, 1.4)))
		add_box("rust_metal", Vector3(1.8, 0.3, 14.0), xform(ground + Vector3(0, 2.5, 0), 0.5).rotated_local(Vector3.RIGHT, 0.3))
		add_box("peel", Vector3(1.8, 1.2, 3.0), xform(ground + Vector3(5, 0.6, 3), 1.1).rotated_local(Vector3.FORWARD, 2.7))
	# Station shed at the start of the lift hill.
	var station := at(track.curve.get_closest_offset(COASTER_FROM) - 100.0, 40.0)
	if clear_rect(station, 16.0, 26.0):
		add_box("corrugated", Vector3(14, 6, 24), station.translated_local(Vector3(0, 3, 0)))
		add_box("rust", Vector3(16, 0.5, 26), station.translated_local(Vector3(0, 6.2, 0)))
		_flood_line(station, Vector3(14, 0, 24), 1.5)


func _ferris_wheel() -> void:
	var center := WHEEL + Vector3(0, 53, 0)
	var radius := 45.0
	var tilt := Basis(Vector3.FORWARD, 0.06)
	var segments := 36
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := center + tilt * Vector3(0, cos(a0) * radius, sin(a0) * radius)
		var p1 := center + tilt * Vector3(0, cos(a1) * radius, sin(a1) * radius)
		if i == 20:
			continue
		add_box("rust_metal", Vector3(1.0, 1.0, (p1 - p0).length()),
				Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.RIGHT), (p0 + p1) * 0.5))
		if i % 3 == 0:
			add_box("rust", Vector3(0.35, 0.35, radius),
					Transform3D(Basis.looking_at((p0 - center).normalized(), Vector3.RIGHT), (center + p0) * 0.5))
			if i % 9 != 0:
				add_box("peel", Vector3(3.0, 2.6, 3.4), xform(p0 + Vector3(2.5, -2.4, 0), rng.randf_range(-0.2, 0.2)).rotated_local(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	add_cyl("dark", 4.0, 6.0, xform(center + Vector3(-3, 0, 0)).rotated_local(Vector3.FORWARD, PI * 0.5), 10)
	for side in [-1.0, 1.0]:
		var foot := WHEEL + Vector3(0, 0, side * 26.0)
		var dir := center - foot
		add_box("rust", Vector3(2.5, 2.5, dir.length()), Transform3D(Basis.looking_at(dir.normalized(), Vector3.RIGHT), (foot + center) * 0.5))
	add_box("peel", Vector3(3.0, 2.6, 3.4), xform(WHEEL + Vector3(6, 1.0, 12), 0.6).rotated_local(Vector3.FORWARD, 1.3))


# --- road puddles, fences -------------------------------------------------------------------

## Thin reflective puddles near the road edges (looks only; the gameplay
## WATER patches are separate, tinted and lit).
func _road_puddles() -> void:
	var half := track.road_width * 0.5
	var d := 20.0
	while d < track.length:
		var near_water := false
		for f in track.get_children():
			if f is TrackFeature and (f as TrackFeature).kind == TrackFeature.Kind.WATER:
				if (f as TrackFeature).global_position.distance_to(track.to_global(track.curve.sample_baked(d))) < 40.0:
					near_water = true
		if not near_water and rng.randf() < 0.55:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var w := rng.randf_range(1.2, 3.0)
			var l := rng.randf_range(2.0, 6.0)
			var xf := at(d, side * (half - 0.6 - w * 0.5)).rotated_local(Vector3.UP, rng.randf_range(-0.3, 0.3))
			add_box("puddle", Vector3(w, 0.01, l), xf.translated_local(Vector3(0, 0.026, 0)))
		d += rng.randf_range(18.0, 40.0)


func _fences() -> void:
	# Perimeter chain-link a few metres outside the barriers, both sides.
	var half := track.road_width * 0.5
	for side in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var d := 0.0
		while d < track.length:
			pts.append(at(d, side * (half + 6.5)).origin)
			d += 9.0
		ChainLinkFence.build(self, pts, "rust_metal")


# --- the rest of the lap (lighter pass) ----------------------------------------------------

func _drop_tower() -> void:
	var b := xform(DROP_TOWER).rotated_local(Vector3.RIGHT, 0.04)
	add_cyl("rust_metal", 3.0, 75.0, b, 8, 2.2)
	add_cyl("rust", 6.0, 2.0, b.translated_local(Vector3(0, 22, 0)), 12)
	add_cone("rust", 3.5, 6.0, b.translated_local(Vector3(0, 75, 0)), 8)


func _water_park() -> void:
	var t := xform(SLIDE_TOWER)
	add_box("rust_metal", Vector3(9, 26, 9), t.translated_local(Vector3(0, 13, 0)))
	add_box("planks", Vector3(10, 0.4, 10), t.translated_local(Vector3(0, 26.2, 0)))
	for s in 2:
		var key := "peel" if s == 0 else "peel_white"
		var prev := Vector3.ZERO
		for i in 40:
			var ang := float(s) * PI + i * 0.35
			var r := 10.0 + s * 4.0
			var p := SLIDE_TOWER + Vector3(cos(ang) * r, 25.0 - i * 0.6, sin(ang) * r)
			if i > 0 and not (s == 1 and i >= 18 and i <= 22):
				add_box(key, Vector3(1.8, 1.0, (p - prev).length() + 0.4), Transform3D(Basis.looking_at((p - prev).normalized(), Vector3.UP), (p + prev) * 0.5))
			prev = p
	for p in [Vector3(-300, 0, 560), Vector3(-430, 0, 470), Vector3(-260, 0, 440), Vector3(-480, 0, 590)]:
		var xf := xform(p, rng.randf_range(-0.4, 0.4))
		var w := rng.randf_range(26, 40)
		var dd := rng.randf_range(18, 30)
		if clear_rect(xf, w, dd):
			add_box("tiles", Vector3(w + 4, 0.3, dd + 4), xf.translated_local(Vector3(0, 0.15, 0)))
			add_box("flood", Vector3(w, 0.32, dd), xf.translated_local(Vector3(0, 0.2, 0)))


func _backlot() -> void:
	var lots := [[Vector3(-680, 0, 300), "STAGE 4"], [Vector3(-690, 0, 130), ""], [Vector3(-490, 0, 90), "MAINTENANCE"],
			[Vector3(-470, 0, 300), ""], [Vector3(-680, 0, 470), "STAGE 2"]]
	for lot in lots:
		var p: Vector3 = lot[0]
		var xf := xform(p)
		var w := rng.randf_range(50, 70)
		var dd := rng.randf_range(40, 60)
		if not clear_rect(xf, w, dd):
			w *= 0.6
			dd *= 0.6
			if not clear_rect(xf, w, dd):
				continue
		var h := rng.randf_range(14, 22)
		add_box("corrugated", Vector3(w, h, dd), xf.translated_local(Vector3(0, h * 0.5, 0)))
		add_box("rust", Vector3(w + 1, 1.0, dd + 1), xf.translated_local(Vector3(0, h, 0)))
		_flood_line(xf, Vector3(w, 0, dd), 1.8)
		if lot[1] != "":
			_label(lot[1], Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(w * 0.5 + 0.3, h * 0.6, 0)), Color(0.55, 0.52, 0.46), 0.1)
			_x_code(Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(w * 0.5 + 0.3, 3.0, -8.0)), 1.4)


func _bayou() -> void:
	var a := track.curve.get_closest_offset(BAYOU_FROM)
	var b := track.curve.get_closest_offset(BAYOU_TO)
	var d := a
	while d < b:
		add_box("planks", Vector3(track.road_width - 0.8, 0.03, 1.0), at(d).translated_local(Vector3(0, 0.035, 0)))
		d += 1.4
	d = a
	while d < b:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.2:
				continue
			var post := at(d, side * (track.road_width * 0.5 + 2.2)).rotated_local(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
			add_box("wood", Vector3(0.4, 2.5, 0.4), post.translated_local(Vector3(0, 1.25, 0)))
		d += 18.0
	for i in 70:
		var p := Vector3(rng.randf_range(-720, -100), 0, rng.randf_range(-380, 160))
		if clear(p, 4.0):
			_cypress(p, rng.randf_range(12, 22))


func _cypress(pos: Vector3, h: float) -> void:
	var base := xform(pos)
	add_cone("bark", 2.0, 3.0, base, 6)
	add_cyl("bark", 0.9, h, base, 6, 0.35)
	for k in 3:
		var y := h * (0.65 + k * 0.13)
		var r := rng.randf_range(3.0, 5.5)
		if rng.randf() < 0.6:
			add_box("dead_leaf", Vector3(r * 2.0, 1.2, r * 1.6), base.translated_local(Vector3(rng.randf_range(-1, 1), y, rng.randf_range(-1, 1))).rotated_local(Vector3.UP, rng.randf() * PI))
		for m in 4:
			var len := rng.randf_range(2.0, 6.0)
			add_box("moss", Vector3(0.2, len, 0.2), base.translated_local(Vector3(rng.randf_range(-r, r), y - len * 0.5, rng.randf_range(-r, r))))


func _dead_woods() -> void:
	for i in 140:
		var p := Vector3(rng.randf_range(-760, 640), 0, rng.randf_range(-420, 800))
		if p.distance_to(CAROUSEL) < 25.0 or p.distance_to(SLIDE_TOWER) < 30.0 or p.distance_to(WHEEL) < 50.0 or p.distance_to(JESTER) < 20.0:
			continue
		if clear(p, 3.0):
			_dead_tree(p, rng.randf_range(7, 16))


func _debris() -> void:
	for i in 380:
		var p := Vector3(rng.randf_range(-760, 640), 0, rng.randf_range(-420, 800))
		if not clear(p, 2.0):
			continue
		var roll := rng.randf()
		if roll < 0.55:
			_weeds(p, 2.5)
		elif roll < 0.75:
			var r := rng.randf_range(1.5, 4.0)
			add_sphere("dead_leaf", r, xform(p + Vector3(0, r * 0.35, 0)).scaled_local(Vector3(1, 0.55, 1)), 4, 7)
		elif roll < 0.88:
			var s := rng.randf_range(0.6, 2.2)
			add_box("concrete", Vector3(s, s * 0.5, s * 0.8), xform(p + Vector3(0, s * 0.2, 0), rng.randf() * TAU).rotated_local(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)))
		elif roll < 0.95:
			add_cyl("rust_metal", 0.45, 1.0, xform(p, 0).rotated_local(Vector3.RIGHT, PI * 0.5 if rng.randf() < 0.4 else 0.0), 8)
		else:
			_wreck(p)


func _signs_and_codes() -> void:
	var d := 90.0
	var i := 0
	while d < track.length - 40.0:
		var side := -1.0 if i % 2 == 0 else 1.0
		var xf := at(d, side * (track.road_width * 0.5 + 9.0))
		if clear(xf.origin, 1.5):
			add_box("brick", Vector3(0.6, 3.0, 10.0), xf.translated_local(Vector3(0, 1.5, 0)))
			_flood_line(xf.translated_local(Vector3(0, 0, 0)), Vector3(0.6, 0, 10.0), 1.4)
			var face := xf.translated_local(Vector3(-side * 0.35, 1.9, 0))
			face.basis = face.basis * Basis(Vector3.UP, -side * PI * 0.5)
			if i % 2 == 0:
				_x_code(face.translated_local(Vector3(2.5, 0, 0)), 0.9)
			else:
				_label(SIGNS[i % SIGNS.size()], face, Color(0.75, 0.2, 0.15), 0.035)
		d += rng.randf_range(150.0, 230.0)
		i += 1


func _lamps() -> void:
	# Old park lamps: most dead, a few still struggling.
	var d := 0.0
	var i := 0
	while d < track.length:
		var side := 1.0 if i % 2 == 0 else -1.0
		var pole := at(d, side * (track.road_width * 0.5 + 3.0))
		if clear(pole.origin, 0.8):
			add_box("rust_metal", Vector3(0.3, 9.0, 0.3), pole.translated_local(Vector3(0, 4.5, 0)))
			add_box("rust_metal", Vector3(1.8, 0.25, 0.25), pole.translated_local(Vector3(-side * 0.9, 9.0, 0)))
			if i % 3 == 0:
				add_flicker_light(pole * Vector3(-side * 1.6, 8.6, 0), SODIUM, 1.8, 22.0, 0.25)
		d += 80.0
		i += 1
