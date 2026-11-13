@tool
class_name GardensScenery
extends TrackScenery
## Gardens by the Bay (GDD 8.6c): a night race along a glass skyway high
## above the Singapore jungle during the Garden Rhapsody light show. The deck
## is glass framed in wood, with amber-lit wooden handrails, and the ground
## is 24 m below. The Supertrees light up in slowly changing colours. In
## driving order: the Supertree Grove start; the Skyway S-bends, heading
## for Marina Bay Sands; the Great Wrap, a hairpin round the tallest
## Supertree; the Canopy Run, low over the treetops with rain-wet glass and
## an open edge; the Bayfront, over the water past the Flower Dome and its
## wooden dragon, with a second open edge; then back through the grove. The
## shortcut is the Cloud Forest walk: through a smashable glass panel into
## the Cloud Forest dome, round the misty waterfall mountain (two open
## edges), and out to rejoin the Bayfront. The skyway is sloped (GDD 8.6c):
## it rolls over four crests between about 10 m (the Bayfront dip) and
## 53 m (the Great Wrap) above the ground, which is flat at FLOOR_Y, with
## grades up to about 9%, and banks in the long
## sweepers; anything that meets the deck works from the road's height there.
## Positions are layout coordinates matching gardens_by_the_bay.tscn.

## The tallest Supertree, inside the Great Wrap hairpin.
const WRAP_TREE := Vector3(517, 0, 150)
## It towers over the skyway's highest crest beside it.
const WRAP_TREE_HEIGHT := 82.0
## Supertrees: [x, z, height, canopy radius]. Trees too close to a road for
## their canopy are left out by _supertrees().
const SUPERTREES := [
	[-140, -26, 42.0, 13.0], [-140, 26, 42.0, 13.0],
	[-60, -60, 34.0, 12.0], [-10, 48, 30.0, 11.0], [60, -40, 46.0, 15.0],
	[140, 40, 38.0, 13.0], [160, 140, 28.0, 10.0], [280, 40, 44.0, 14.0],
	[300, 140, 32.0, 11.0], [400, -50, 36.0, 12.0], [390, 80, 30.0, 10.0],
	[620, 120, 34.0, 12.0], [640, -40, 40.0, 13.0], [-250, -60, 36.0, 12.0],
	[-300, 80, 30.0, 11.0], [-200, 120, 26.0, 10.0], [60, 200, 34.0, 12.0],
	[220, 230, 40.0, 14.0],
]
const CLOUD_FOREST := Vector3(-215, 0, 335)
const CLOUD_FOREST_RADIUS := 95.0
const CLOUD_FOREST_HEIGHT := 72.0
const MOUNTAIN := Vector3(-210, 0, 345)
const FLOWER_DOME := Vector3(-120, 0, 655)
const FLOWER_DOME_RADIUS := 70.0
const FLOWER_DOME_HEIGHT := 56.0
## Marina Bay Sands: the middle tower's base (towers spread along z).
const MBS := Vector3(980, 0, -110)
## Bay water: [x0, z0, x1, z1] rectangles.
const WATER := [[-1100, -500, -470, 1150], [-470, 740, 500, 1150]]
## The jungle is planted inside these bounds.
const JUNGLE_MIN := Vector2(-460, -220)
const JUNGLE_MAX := Vector2(860, 740)
const JUNGLE_SPACING := 11.0
## Deck framing: beams under the glass and strips on it every so many metres.
const BEAM_SPACING := 4.0
const STRIP_SPACING := 8.0
const PYLON_SPACING := 45.0
## Nothing over a road comes lower than this above it.
const ROAD_CLEARANCE := 7.5
## The ground under the skyway (track-local y).
const FLOOR_Y := -24.0

var floor_y: float = FLOOR_Y
## The Cloud Forest walkway's height by the mountain (set in _cloud_forest).
var walk_y: float = 0.0
var supertrees: SupertreeBuilder
var trees: TreeBuilder


func build() -> void:
	floor_y = FLOOR_Y
	_materials_setup()
	_deck(track.curve, track.road_width, true)
	for sc in track.shortcuts:
		_deck(sc.curve, sc.road_width, false)
	_pylons()
	await step(0.15)
	_supertrees()
	_start_sign()
	await step(0.3)
	_cloud_forest()
	_flower_dome()
	await step(0.45)
	_bay()
	_marina_bay_sands()
	_skyline()
	_sky_dressing()
	await step(0.55)
	_jungle()
	await step(0.9)
	_lights()


# --- materials -----------------------------------------------------------------

func _materials_setup() -> void:
	textured("deck_wood", "hinoki_planks", Color(0.85, 0.6, 0.4), 2.0, 0.6)
	material("fascia", Color(1.0, 0.62, 0.28), 2.2)
	textured("pylon", "metal_plate_02", Color(0.48, 0.53, 0.83), 2.5, 0.4, 0.6)
	textured("jungle_bark", "bark_willow", Color(0.45, 0.4, 0.35), 3.0)
	material("jungle_leaf", Color(0.08, 0.2, 0.09), 0.0, 0.0, 0.9)
	material("dome_glass", Color(0.55, 0.75, 0.95, 0.12), 0.15, 0.4, 0.05, true)
	material("dome_rib", Color(0.7, 0.85, 1.0), 0.9)
	textured("mountain", "mossy_rock", Color(0.6, 0.8, 0.55), 6.0)
	# The Cloud Forest's plants glow softly under its night lighting.
	material("mountain_plant", Color(0.16, 0.42, 0.16), 0.35, 0.0, 0.9)
	material("flower", Color(1.0, 0.35, 0.6), 1.6)
	material("waterfall", Color(0.75, 0.92, 1.0, 0.8), 2.6, 0.0, 0.2, true)
	material("mist", Color(0.85, 0.92, 1.0, 0.12), 0.3, 0.0, 1.0, true)
	textured("dragon_wood", "pine_bark", Color(0.95, 0.82, 0.6), 1.5)
	textured("garden_floor", "forest_ground_04", Color(0.29, 0.63, 0.38), 4.0)
	register_material("water", water_material(Color(0.01, 0.03, 0.07), Color(0.05, 0.14, 0.24), 0.9, 0.0, 0.2))
	material("mbs_tower", Color(0.75, 0.78, 0.85), 0.0, 0.3, 0.5)
	material("window_warm", Color(1.0, 0.82, 0.5), 1.6)
	material("window_cool", Color(0.55, 0.78, 1.0), 1.5)
	textured("building", "concrete_panels", Color(0.14, 0.18, 0.3), 4.0, 0.6, 0.3)
	material("skypark", Color(0.85, 0.85, 0.9), 0.4)
	material("beacon", Color(1.0, 0.25, 0.3), 3.0)
	material("star", Color(0.9, 0.92, 1.0), 2.5)
	material("moon", Color(0.95, 0.95, 1.0), 2.2)
	no_shadow_keys = ["dome_glass", "waterfall", "mist", "fascia", "star", "moon"]


# --- the skyway deck -----------------------------------------------------------

## Wooden framing for a road's glass deck: beams across under the glass,
## wooden edge girders with an amber light strip, and wooden strips across
## the top of the glass.
func _deck(curve: Curve3D, width: float, closed: bool) -> void:
	var length := curve.get_baked_length()
	var half := width * 0.5 + track.barrier_thickness
	var d := 0.0
	while d < length - (0.0 if closed else BEAM_SPACING):
		var p := curve.sample_baked(d)
		var q := curve.sample_baked(fposmod(d + BEAM_SPACING, length) if closed else minf(d + BEAM_SPACING, length))
		var dir := q - p
		if Vector2(dir.x, dir.z).length() < 0.01:
			d += BEAM_SPACING
			continue
		# Pitched with the road, and on the main loop banked with it too.
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		if closed and track.sloped:
			basis = track.road_frame(d + BEAM_SPACING * 0.5)
		var up := basis.y
		var mid := (p + q) * 0.5
		var seg := dir.length() + 0.4
		# A beam across under the glass.
		add_box("deck_wood", Vector3(half * 2.0, 0.35, 0.35), Transform3D(basis, p - up * 0.4))
		for side in [-1.0, 1.0]:
			var right: Vector3 = basis.x * side
			# Edge girder and its light strip, outside the barrier.
			add_box("deck_wood", Vector3(0.45, 0.9, seg), Transform3D(basis, mid + right * (half + 0.2) - up * 0.45))
			add_box("fascia", Vector3(0.08, 0.12, seg), Transform3D(basis, mid + right * (half + 0.45) - up * 0.25))
		if int(round(d / BEAM_SPACING)) % int(STRIP_SPACING / BEAM_SPACING) == 0:
			add_box("deck_wood", Vector3(width - 1.0, 0.03, 0.3), Transform3D(basis, p + up * 0.035))
		d += BEAM_SPACING


## Slim steel columns from the ground up to the deck.
func _pylons() -> void:
	var curves: Array[Curve3D] = [track.curve]
	for sc in track.shortcuts:
		curves.append(sc.curve)
	for curve in curves:
		var length := curve.get_baked_length()
		var d := PYLON_SPACING * 0.5
		while d < length:
			var p := curve.sample_baked(d)
			# From the ground up to the deck's underside here.
			add_cyl("pylon", 0.7, p.y - 0.6 - floor_y, xform(Vector3(p.x, floor_y, p.z)), 8, 0.5)
			d += PYLON_SPACING


# --- Supertrees ------------------------------------------------------------------

## Whether a Supertree here keeps its trunk and canopy off the roads (the
## canopy may hang over a road only if it is high enough).
func supertree_fits(pos: Vector3, height: float, radius: float) -> bool:
	var span := SupertreeBuilder.canopy_span(floor_y, height)
	var trunk_r := clampf(height * 0.075, 2.0, 4.0) * 1.3
	if not clear(pos, trunk_r):
		return false
	# A canopy that reaches road level (from just under the deck to the
	# clearance height above it, at the nearest road's height) must stay
	# clear of every road.
	var road_y := road_y_near(pos)
	if span.y > road_y - 1.0 and span.x < road_y + ROAD_CLEARANCE:
		return clear(pos, radius + 1.0)
	return true


## Height (track-local y) of the nearest road (main loop or shortcut).
func road_y_near(pos: Vector3) -> float:
	return track.to_local(Vector3(0, track.road_floor_y(track.to_global(Vector3(pos.x, 0, pos.z))), 0)).y


func _supertrees() -> void:
	supertrees = SupertreeBuilder.new(self)
	var list := SUPERTREES.duplicate()
	list.append([WRAP_TREE.x, WRAP_TREE.z, WRAP_TREE_HEIGHT, 20.0])
	for t in list:
		var pos := Vector3(t[0], floor_y, t[1])
		if supertree_fits(Vector3(t[0], 0, t[1]), t[2], t[3]):
			supertrees.add(pos, t[2], t[3])


func _start_sign() -> void:
	# High over the grid, above the start gantry.
	var xf := at(track.start_line_offset + 6.0, 0.0, 15.0)
	add_text("GARDENS BY THE BAY", xf, Color(1.0, 0.75, 0.4), 0.035, 120)


# --- domes ---------------------------------------------------------------------

## A glass dome (half-ellipsoid) standing on the ground: glass panels and
## glowing ribs, with openings wherever a road passes through.
func _dome(centre: Vector3, radius: float, height: float, lat: int, lon: int) -> void:
	var c := Vector3(centre.x, floor_y, centre.z)
	var pt := func(i: int, k: int) -> Vector3:
		var phi := PI * 0.5 * float(i) / lat
		var th := TAU * float(k) / lon
		return c + Vector3(cos(phi) * cos(th) * radius, sin(phi) * height, cos(phi) * sin(th) * radius)
	for i in lat:
		for k in lon:
			var a: Vector3 = pt.call(i, k)
			var b: Vector3 = pt.call(i, k + 1)
			var cc: Vector3 = pt.call(i + 1, k + 1)
			var dd: Vector3 = pt.call(i + 1, k)
			if _in_doorway(a) or _in_doorway(b) or _in_doorway(cc) or _in_doorway(dd):
				continue
			_quad(_st("dome_glass", a), a, b, cc, dd, c)
			_rib(a, b)
			_rib(a, dd)


## True for points of a dome that a road (and the cars on it) passes through.
func _in_doorway(p: Vector3) -> bool:
	return p.y < road_y_near(p) + ROAD_CLEARANCE + 3.0 and p.y > floor_y + 4.0 and edge_distance(p) < 14.0


func _rib(a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	add_box("dome_rib", Vector3(0.35, 0.35, d.length()), Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5))


## The Cloud Forest: a tall dome round a misty mountain covered in plants,
## with a waterfall pouring down the side the shortcut passes.
func _cloud_forest() -> void:
	_dome(CLOUD_FOREST, CLOUD_FOREST_RADIUS, CLOUD_FOREST_HEIGHT, 9, 30)
	var base := Vector3(MOUNTAIN.x, floor_y, MOUNTAIN.z)
	# The walkway's height where it wraps the mountain.
	walk_y = road_y_near(MOUNTAIN + Vector3(0, 0, -40.0))
	var top_y := walk_y + 30.0
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.08
	var rings := 14
	var segs := 28
	var st := _st("mountain", base)
	var ring_pt := func(i: int, k: int) -> Vector3:
		var t := float(i) / rings
		var y := lerpf(floor_y, top_y, t)
		var r := lerpf(36.0, 12.0, pow(t, 0.8)) * mountain_scale_at(y)
		var th := TAU * float(k) / segs
		var wobble := 1.0 + noise.get_noise_2d(th * 6.0, y * 0.4) * 0.22
		return base + Vector3(cos(th) * r * wobble, y - floor_y, sin(th) * r * wobble)
	for i in rings:
		for k in segs:
			_quad(st, ring_pt.call(i, k), ring_pt.call(i, k + 1), ring_pt.call(i + 1, k + 1), ring_pt.call(i + 1, k), base + Vector3(0, (top_y - floor_y) * 0.5, 0))
	# Cap.
	for k in segs:
		_tri(st, ring_pt.call(rings, k), ring_pt.call(rings, k + 1), base + Vector3(0, top_y - floor_y + 3.0, 0), base)
	# Plants clinging all over it, and a few bright flowers.
	for n in 160:
		var i := rng.randi_range(1, rings - 1)
		var k := rng.randi_range(0, segs - 1)
		var p: Vector3 = ring_pt.call(i, k)
		var out := Vector3(p.x - base.x, 0, p.z - base.z).normalized()
		add_sphere("mountain_plant", rng.randf_range(1.6, 3.2), xform(p + out * 0.8), 3, 6)
		if n % 5 == 0:
			add_sphere("flower", 0.6, xform(p + out * 2.2), 2, 5)
	# The waterfall faces north (towards the walkway), from near the top to a pool.
	var fall_top := base + Vector3(0, top_y - floor_y - 4.0, -13.5)
	for w in 3:
		var x := (w - 1) * 2.4
		var y_top := fall_top.y - w * 3.0
		var panel := Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(base.x + x, floor_y, base.z - 33.0 + w * 0.6))
		add_panel("waterfall", 3.4, y_top - floor_y, panel)
	add_cyl("water", 14.0, 0.6, xform(Vector3(base.x, floor_y, base.z - 38.0)), 18)
	for m in 10:
		add_sphere("mist", rng.randf_range(5.0, 9.0), xform(Vector3(base.x + rng.randf_range(-14, 14), floor_y + rng.randf_range(2, 10), base.z - 38.0 + rng.randf_range(-8, 8))), 4, 8)
	add_text("CLOUD FOREST", Transform3D(Basis(Vector3.UP, PI * 0.6), Vector3(CLOUD_FOREST.x + 70.0, walk_y + 30.0, CLOUD_FOREST.z - 60.0)),
			Color(0.6, 0.95, 1.0), 0.06, 140)


## The mountain narrows in a little near the walkway level (the walkway
## wraps it closely).
func mountain_scale_at(y: float) -> float:
	return 1.0 - 0.12 * exp(-pow((y - walk_y) / 10.0, 2.0))


## The Flower Dome: a lower, wider dome with a garden and the wooden dragon
## perched on a dead tree in the middle, warm-lit.
func _flower_dome() -> void:
	_dome(FLOWER_DOME, FLOWER_DOME_RADIUS, FLOWER_DOME_HEIGHT, 8, 28)
	var c := Vector3(FLOWER_DOME.x, floor_y, FLOWER_DOME.z)
	add_cyl("garden_floor", FLOWER_DOME_RADIUS * 0.98, 0.3, xform(c), 28)
	for n in 70:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * FLOWER_DOME_RADIUS * 0.85
		var p := c + Vector3(cos(a) * r, 0.3, sin(a) * r)
		if r > 14.0:
			add_sphere("mountain_plant", rng.randf_range(1.5, 3.0), xform(p), 3, 6)
			if n % 2 == 0:
				add_sphere("flower", 0.9, xform(p + Vector3(0, 1.8, 0)), 2, 5)
	_dragon(c)
	add_text("FLOWER DOME", Transform3D(Basis(Vector3.UP, PI), c + Vector3(0, FLOWER_DOME_HEIGHT * 0.62, -FLOWER_DOME_RADIUS * 0.72)),
			Color(1.0, 0.7, 0.85), 0.08, 120)


## The driftwood dragon on its dead tree (after the Flower Dome sculpture).
func _dragon(ground: Vector3) -> void:
	var trunk := xform(ground)
	add_cyl("dragon_wood", 2.6, 16.0, trunk, 10, 1.6)
	# Two crooked limbs reaching out from the top.
	var top := ground + Vector3(0, 16.0, 0)
	for limb in [[Vector3(-9, 5, 2), 0.9], [Vector3(7, 3, -3), 0.8]]:
		var tip: Vector3 = top + limb[0]
		_wood_beam(top, tip, limb[1])
		_wood_beam(tip, tip + Vector3(signf(limb[0].x) * 3.0, 4.0, 0.5), limb[1] * 0.6)
	# Body crouched on the trunk, neck rearing up to the head, long tail.
	var body := top + Vector3(1.5, 3.5, 0)
	add_sphere("dragon_wood", 1.0, Transform3D(Basis.from_scale(Vector3(5.5, 2.6, 2.6)), body), 5, 10)
	var neck := [body + Vector3(4.5, 1.0, 0), body + Vector3(7.0, 4.0, 0.5), body + Vector3(8.0, 7.0, 0.3)]
	var prev := body + Vector3(3.0, 0.5, 0)
	for p in neck:
		_wood_beam(prev, p, 1.2)
		prev = p
	add_box("dragon_wood", Vector3(4.2, 1.6, 1.8), Transform3D(Basis(Vector3.FORWARD, -0.25), prev + Vector3(1.8, 0.2, 0)))
	for horn in [-0.6, 0.6]:
		_wood_beam(prev + Vector3(-0.4, 0.6, horn), prev + Vector3(-2.2, 2.2, horn * 1.6), 0.25)
	var tail := [body + Vector3(-5.0, -1.0, 0), body + Vector3(-9.0, -3.5, 1.5), body + Vector3(-12.0, -7.0, 0.5), body + Vector3(-13.0, -10.0, -1.0)]
	prev = body + Vector3(-3.0, 0, 0)
	for p in tail:
		_wood_beam(prev, p, 0.9)
		prev = p
	# Wings raised in a V: a few ribbed panels each.
	for side in [-1.0, 1.0]:
		var root := body + Vector3(0.5, 1.8, side * 1.4)
		for f in 4:
			var span := Vector3(-2.0 + f * 1.6, 8.0 - f * 1.2, side * (7.0 + f * 0.8))
			_wood_beam(root, root + span, 0.35)
			var panel_xf := Transform3D(Basis.looking_at(span.normalized(), Vector3.UP), root + span * 0.5)
			add_box("dragon_wood", Vector3(2.2, 0.15, span.length()), panel_xf)


func _wood_beam(a: Vector3, b: Vector3, thickness: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	add_box("dragon_wood", Vector3(thickness, thickness, d.length()), Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5))


# --- the bay and the city ----------------------------------------------------------

func _bay() -> void:
	for r in WATER:
		var size := Vector3(r[2] - r[0], 0.2, r[3] - r[1])
		add_box("water", size, xform(Vector3((r[0] + r[2]) * 0.5, floor_y + 0.15, (r[1] + r[3]) * 0.5)))


## Marina Bay Sands: three tapered hotel towers in a row with the SkyPark
## "ship" across their tops, windows lit.
func _marina_bay_sands() -> void:
	var tower_h := 190.0
	for i in 3:
		var base := MBS + Vector3(0, floor_y, (i - 1) * 85.0)
		var xf := xform(base)
		# Each tower is two leaning slabs meeting at the top.
		for side in [-1.0, 1.0]:
			var lean := Basis(Vector3.FORWARD, side * 0.08)
			add_box("mbs_tower", Vector3(16, tower_h, 44), Transform3D(lean, base + Vector3(side * 10.0, tower_h * 0.5, 0)))
			for f in 30:
				var y := 8.0 + f * 6.0
				var x: float = side * (10.0 - (y - tower_h * 0.5) * 0.08 * side * side) + side * 8.2
				add_box("window_warm" if (f + i) % 4 != 0 else "window_cool", Vector3(0.3, 1.1, 40), xform(base + Vector3(x, y, 0)))
		add_box("beacon", Vector3(2, 2, 2), xf.translated(Vector3(0, tower_h + 9.0, 0)))
	# SkyPark: a long deck across the three tops, overhanging at one end.
	var park := xform(MBS + Vector3(0, floor_y + tower_h + 4.0, 20.0))
	add_box("skypark", Vector3(38, 6, 330), park)
	add_box("window_cool", Vector3(38.5, 0.6, 300), park.translated(Vector3(0, -1.5, -10)))
	add_text("MARINA BAY SANDS", Transform3D(Basis(Vector3.UP, -PI * 0.5), MBS + Vector3(-22.0, floor_y + tower_h + 12.0, 0)),
			Color(1.0, 0.85, 0.6), 0.25, 140)


## Downtown Singapore beyond the grove (north), lit windows and a few beacons.
func _skyline() -> void:
	for n in 46:
		var x := rng.randf_range(-800.0, 900.0)
		var z := rng.randf_range(-850.0, -380.0)
		var w := rng.randf_range(24.0, 50.0)
		var dpt := rng.randf_range(24.0, 50.0)
		var h := rng.randf_range(60.0, 230.0)
		var xf := xform(Vector3(x, floor_y, z), rng.randf_range(-0.3, 0.3))
		add_box("building", Vector3(w, h, dpt), xf.translated_local(Vector3(0, h * 0.5, 0)))
		var window := "window_warm" if rng.randf() < 0.55 else "window_cool"
		var f := 10.0
		while f < h - 4.0:
			if rng.randf() < 0.8:
				add_box(window, Vector3(w * 0.86, 1.0, dpt + 0.4), xf.translated_local(Vector3(0, f, 0)))
			f += rng.randf_range(5.0, 9.0)
		if h > 160.0:
			add_box("beacon", Vector3(1.5, 1.5, 1.5), xf.translated_local(Vector3(0, h + 2.0, 0)))


func _sky_dressing() -> void:
	for n in 260:
		var az := rng.randf() * TAU
		var el := rng.randf_range(0.18, 1.35)
		var r := 2600.0
		var p := Vector3(cos(el) * cos(az) * r, sin(el) * r * 0.8, cos(el) * sin(az) * r)
		var s := rng.randf_range(2.5, 6.0)
		add_box("star", Vector3(s, s, s), xform(p))
	var moon := track.get_node_or_null("Moon") as Node3D
	var dir := Vector3(-0.4, 0.55, 0.7).normalized()
	if moon != null:
		dir = moon.transform.basis.z.normalized()
	add_sphere("moon", 60.0, xform(dir * 2400.0), 8, 14)


# --- the jungle below ----------------------------------------------------------------

## Rainforest and palms filling the ground under the skyway. Tree tops stay
## under the deck near the roads; a few taller trees break through the
## canopy away from them.
func _jungle() -> void:
	trees = TreeBuilder.new(self, "jungle_bark", "jungle_leaf", random_seed)
	var x := JUNGLE_MIN.x
	while x < JUNGLE_MAX.x:
		var z := JUNGLE_MIN.y
		while z < JUNGLE_MAX.y:
			var p := Vector3(x + rng.randf_range(-4.5, 4.5), 0, z + rng.randf_range(-4.5, 4.5))
			z += JUNGLE_SPACING
			if _in_water(p) or _in_dome(p) or not clear(p, 1.5):
				continue
			var ground := Vector3(p.x, floor_y, p.z)
			# Palms (up to about 16 m with fronds) only where they stay under the deck.
			if rng.randf() < 0.18 and (edge_distance(p) > 8.0 or road_y_near(p) - floor_y > 18.0):
				trees.place("palm", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), ground))
				continue
			var s := rng.randf_range(0.85, 1.1)
			# Emergents: taller trees whose crowns rise past the deck, away from roads.
			if rng.randf() < 0.12 and clear(p, 12.0):
				s = rng.randf_range(1.3, 1.45)
			elif edge_distance(p) < 14.0:
				# Crowns (about 21 m at scale 1) stay under a low deck nearby.
				s = minf(s, (road_y_near(p) - floor_y - 2.0) / 21.0)
			trees.place("rainforest", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), ground))
		x += JUNGLE_SPACING
	trees.commit()


func _in_water(p: Vector3) -> bool:
	for r in WATER:
		if p.x > r[0] - 6.0 and p.x < r[2] + 6.0 and p.z > r[1] - 6.0 and p.z < r[3] + 6.0:
			return true
	return false


func _in_dome(p: Vector3) -> bool:
	return Vector2(p.x - CLOUD_FOREST.x, p.z - CLOUD_FOREST.z).length() < CLOUD_FOREST_RADIUS + 6.0 \
			or Vector2(p.x - FLOWER_DOME.x, p.z - FLOWER_DOME.z).length() < FLOWER_DOME_RADIUS + 6.0


# --- lights ----------------------------------------------------------------------------

## A handful of lights (the web build's renderer has a small light budget):
## the rest of the night glow is emissive.
func _lights() -> void:
	add_light(at(track.start_line_offset, 0.0, 14.0).origin, Color(0.85, 0.6, 1.0), 2.0, 60.0)
	add_light(WRAP_TREE + Vector3(0, road_y_near(WRAP_TREE) + 8.0, 0), Color(0.6, 0.3, 1.0), 2.5, 75.0)
	add_light(Vector3(MOUNTAIN.x, walk_y + 12.0, MOUNTAIN.z - 45.0), Color(0.5, 0.9, 1.0), 2.2, 70.0)
	add_light(Vector3(FLOWER_DOME.x, floor_y + 22.0, FLOWER_DOME.z), Color(1.0, 0.7, 0.4), 3.0, 55.0)
