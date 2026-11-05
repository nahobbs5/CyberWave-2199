@tool
class_name SixFlagsScenery
extends TrackScenery
## Six Flags New Orleans set dressing (GDD 8.2): an abandoned, overgrown
## amusement park at night, retrofitted with illegal racing neon. Landmark
## positions are layout coordinates (track-local metres) matching
## six_flags_new_orleans.tscn.
##
##   Park Entrance   the decaying "SIX FLAGS / NEW ORLEANS" arch over the start
##   Midway          game booths, stall signs and a carousel along the S-bends
##   Coaster Run     a red roller coaster (lift hill, loop) beside and over the road
##   Water Park      slide tower, spiral tubes and pools along the shortcut
##   Backlot         warehouses ("STAGE 4"), containers and light poles
##   Bayou Outrun    swamp water, cypress trees with moss, a plank boardwalk
##   Skyline         a purple Ferris wheel and a drop tower

const WHEEL := Vector3(120, 0, -220)
const DROP_TOWER := Vector3(-150, 0, 180)
const CAROUSEL := Vector3(290, 0, 75)
const SLIDE_TOWER := Vector3(-330, 0, 500)
## Coaster Run: the straight from (450, 360) to (-80, 370), driven westward.
const COASTER_FROM := Vector3(440, 0, 362)
const COASTER_TO := Vector3(-70, 0, 370)
## Bayou: from the backlot exit up the west straight and round the arc.
const BAYOU_FROM := Vector3(-410, 0, 170)
const BAYOU_TO := Vector3(-150, 0, -130)
const MIDWAY_FROM := Vector3(150, 0, 20)
const MIDWAY_TO := Vector3(420, 0, 230)

const STALLS: Array[String] = ["GAMES", "PRIZES", "HOT DOGS", "RING TOSS", "FUNNEL CAKE", "SHOOTING GALLERY", "TICKETS"]
const NEON: Array[Color] = [Color(1.0, 0.2, 0.8), Color(0.65, 0.3, 1.0), Color(0.2, 0.9, 1.0), Color(1.0, 0.6, 0.2), Color(0.4, 1.0, 0.4)]


func build() -> void:
	material("concrete", Color(0.25, 0.24, 0.26), 0.0, 0.0, 0.95)
	material("rust", Color(0.35, 0.16, 0.1), 0.0, 0.3, 0.8)
	material("coaster", Color(0.9, 0.1, 0.18), 2.2, 0.4, 0.5)
	material("steel", Color(0.32, 0.33, 0.36), 0.0, 0.6, 0.5)
	material("wood", Color(0.36, 0.24, 0.14), 0.0, 0.0, 0.85)
	material("plank", Color(0.3, 0.21, 0.13), 0.0, 0.0, 0.8)
	material("moss", Color(0.12, 0.2, 0.1), 0.15, 0.0, 0.9)
	material("leaf", Color(0.05, 0.16, 0.08), 0.15, 0.0, 0.9)
	material("swamp", Color(0.03, 0.07, 0.06), 0.15, 0.6, 0.1)
	material("pool", Color(0.1, 0.45, 0.6), 0.9, 0.4, 0.1)
	material("slide", Color(0.15, 0.55, 0.65), 0.4, 0.2, 0.4)
	material("slide2", Color(0.6, 0.25, 0.75), 0.4, 0.2, 0.4)
	material("gold", Color(1.0, 0.75, 0.3), 2.0)
	material("sign_red", Color(0.75, 0.12, 0.15), 0.6)
	material("sign_cream", Color(0.85, 0.75, 0.55), 0.3)
	material("warm", Color(1.0, 0.75, 0.4), 2.0)
	material("awning_a", Color(0.85, 0.15, 0.3), 1.0)
	material("awning_b", Color(0.9, 0.85, 0.75), 0.2)
	material("dark", Color(0.06, 0.05, 0.08), 0.0, 0.2, 0.7)
	for i in NEON.size():
		material("neon%d" % i, NEON[i], 4.0)
	_entrance()
	add_ferris_wheel(WHEEL, 45.0, "neon1", "steel", "neon0", "dark")
	add_light(WHEEL + Vector3(0, 53, 0), Color(0.7, 0.3, 1.0), 4.0, 100.0)
	_drop_tower()
	_midway()
	_coaster()
	_water_park()
	_backlot()
	_bayou()
	_overgrowth()


# --- Park Entrance ----------------------------------------------------------------

func _entrance() -> void:
	var xf := at(track.start_line_offset + 30.0)
	var half := track.road_width * 0.5 + 4.0
	for side in [-1.0, 1.0]:
		add_box("concrete", Vector3(4.0, 16.0, 4.0), xf.translated_local(Vector3(side * half, 8.0, 0)))
		add_box("neon0", Vector3(0.4, 14.0, 0.4), xf.translated_local(Vector3(side * (half - 2.2), 7.0, 2.1)))
		# Vines hanging off the pillars.
		for v in 4:
			add_box("moss", Vector3(0.25, rng.randf_range(3, 7), 0.25),
					xf.translated_local(Vector3(side * half + rng.randf_range(-1.8, 1.8), 13.0, 2.2)))
	add_box("sign_red", Vector3(half * 2.0 + 4.0, 7.0, 1.0), xf.translated_local(Vector3(0, 19.5, 0)))
	add_box("gold", Vector3(half * 2.0 + 4.4, 0.4, 1.1), xf.translated_local(Vector3(0, 23.1, 0)))
	add_box("gold", Vector3(half * 2.0 + 4.4, 0.4, 1.1), xf.translated_local(Vector3(0, 15.9, 0)))
	# Fleur-de-lis on top: a centre petal and two curled side petals.
	var top := xf.translated_local(Vector3(0, 23.5, 0))
	add_cone("gold", 1.6, 6.0, top)
	for side in [-1.0, 1.0]:
		add_box("gold", Vector3(1.2, 3.5, 0.8), top.translated_local(Vector3(side * 1.6, 2.0, 0)).rotated_local(Vector3.FORWARD, side * 0.6))
	add_box("gold", Vector3(4.0, 0.6, 0.9), top.translated_local(Vector3(0, 1.2, 0)))
	# Lettering faces the cars driving in (+Z in at()'s frame).
	add_text("SIX FLAGS", xf.translated_local(Vector3(0, 20.8, 0.55)), Color(1.0, 0.85, 0.7), 0.06, 140)
	add_text("NEW ORLEANS", xf.translated_local(Vector3(0, 17.6, 0.55)), Color(1.0, 0.75, 0.5), 0.04, 120)
	add_light(xf * Vector3(0, 14, 6), Color(1.0, 0.5, 0.8), 4.0, 30.0)
	# Graffiti-coloured panels along the entrance walls.
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := at(track.start_line_offset - 40.0 + i * 22.0, side * (track.road_width * 0.5 + 6.0))
		if clear(p.origin, 1.0):
			add_box("concrete", Vector3(0.6, 4.0, 14.0), p.translated_local(Vector3(0, 2.0, 0)))
			add_box("neon%d" % (i % NEON.size()), Vector3(0.2, 1.6, 9.0), p.translated_local(Vector3(-side * 0.35, 2.3, 0)))


func _drop_tower() -> void:
	var b := xform(DROP_TOWER)
	add_cyl("steel", 3.0, 75.0, b, 8, 2.2)
	add_cyl("neon2", 6.0, 1.2, b.translated_local(Vector3(0, 30, 0)), 12)
	add_cyl("neon0", 5.0, 1.0, b.translated_local(Vector3(0, 74, 0)), 12)
	add_cone("rust", 3.5, 6.0, b.translated_local(Vector3(0, 75, 0)), 8)
	add_light(DROP_TOWER + Vector3(0, 70, 0), Color(1.0, 0.2, 0.8), 3.0, 60.0)


# --- Midway -------------------------------------------------------------------------

func _midway() -> void:
	var a := track.curve.get_closest_offset(MIDWAY_FROM)
	var b := track.curve.get_closest_offset(MIDWAY_TO)
	var half := track.road_width * 0.5
	var d := a
	var n := 0
	while d < b:
		for side in [-1.0, 1.0]:
			var xf := at(d, side * (half + 9.0))
			if not clear_rect(xf, 10.0, 8.0):
				continue
			# Booth with a striped awning and a glowing sign facing the road.
			add_box("wood", Vector3(7.0, 3.2, 6.0), xf.translated_local(Vector3(0, 1.6, 0)))
			for stripe in 4:
				add_box("awning_a" if stripe % 2 == 0 else "awning_b", Vector3(1.6, 0.25, 7.0),
						xf.translated_local(Vector3(-side * 3.0 + (stripe - 1.5) * 1.6 * -side, 3.5, 0)).rotated_local(Vector3.FORWARD, side * 0.25))
			var sign_xf := xf.translated_local(Vector3(-side * 3.6, 4.6, 0))
			sign_xf.basis = sign_xf.basis * Basis(Vector3.UP, -side * PI * 0.5)
			add_text(STALLS[n % STALLS.size()], sign_xf, NEON[n % NEON.size()], 0.03, 90)
			add_box("neon%d" % (n % NEON.size()), Vector3(0.15, 0.15, 6.0), xf.translated_local(Vector3(-side * 3.55, 3.25, 0)))
			n += 1
		d += 26.0
	# Carousel.
	var c := xform(CAROUSEL)
	add_cyl("dark", 14.0, 1.0, c, 20)
	add_cyl("gold", 1.2, 9.0, c, 8)
	for i in 12:
		var ang := TAU * i / 12.0
		add_cyl("steel", 0.2, 6.5, c.translated_local(Vector3(cos(ang) * 11.0, 1.0, sin(ang) * 11.0)), 4)
		add_box("awning_b", Vector3(1.0, 1.4, 2.0), c.translated_local(Vector3(cos(ang) * 11.0, 2.6, sin(ang) * 11.0)).rotated_local(Vector3.UP, -ang))
	add_cyl("awning_a", 15.0, 1.0, c.translated_local(Vector3(0, 7.5, 0)), 20)
	add_cone("awning_b", 15.0, 6.0, c.translated_local(Vector3(0, 8.5, 0)), 20)
	add_cyl("neon0", 15.2, 0.4, c.translated_local(Vector3(0, 8.2, 0)), 24)
	add_light(CAROUSEL + Vector3(0, 6, 0), Color(1.0, 0.7, 0.5), 3.0, 30.0)


# --- Coaster Run -----------------------------------------------------------------------

func _coaster() -> void:
	var a := track.curve.get_closest_offset(COASTER_FROM)
	var b := track.curve.get_closest_offset(COASTER_TO)
	var span := b - a
	# The coaster runs along the south side, crosses high over the road once,
	# climbs a lift hill and turns a loop.
	var points: Array[Vector3] = []
	var steps := 70
	for i in steps + 1:
		var t := float(i) / steps
		var d := a + span * t
		var lateral := -34.0 # left of westbound = south side
		if t > 0.55 and t < 0.7:
			lateral = lerpf(-34.0, 30.0, sin((t - 0.55) / 0.15 * PI * 0.5))
		elif t >= 0.7:
			lateral = 30.0
		var height := 12.0 + 10.0 * sin(t * TAU * 2.0)
		if t < 0.2:
			height = lerpf(6.0, 40.0, t / 0.2) # lift hill
		elif t < 0.28:
			height = lerpf(40.0, 14.0, (t - 0.2) / 0.08) # first drop
		if t > 0.55 and t < 0.7:
			height = maxf(height, 18.0) # high over the road
		var p := at(d, lateral).origin + Vector3(0, height, 0)
		points.append(p)
	for i in points.size() - 1:
		var p0 := points[i]
		var p1 := points[i + 1]
		var dir := (p1 - p0)
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		var seg := Transform3D(basis, (p0 + p1) * 0.5)
		for rail in [-0.8, 0.8]:
			add_box("coaster", Vector3(0.45, 0.45, dir.length() + 0.2), seg.translated_local(Vector3(rail, 0, 0)))
		add_box("steel", Vector3(2.0, 0.15, 0.3), seg)
		# Supports down to the ground where they won't stand in the road.
		if i % 2 == 0:
			var foot := Vector3(p0.x, 0.0, p0.z)
			if clear(foot, 1.0):
				add_box("rust", Vector3(0.6, p0.y, 0.6), xform(foot + Vector3(0, p0.y * 0.5, 0)))
	# A vertical loop beside the run.
	var loop_center := at(a + span * 0.4, -46.0).origin + Vector3(0, 18, 0)
	var loop_basis := at(a + span * 0.4).basis
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		var p0 := loop_center + loop_basis * Vector3(0, cos(a0) * 13.0, sin(a0) * 13.0)
		var p1 := loop_center + loop_basis * Vector3(0, cos(a1) * 13.0, sin(a1) * 13.0)
		var seg := Transform3D(Basis.looking_at((p1 - p0).normalized(), loop_basis.x), (p0 + p1) * 0.5)
		add_box("coaster", Vector3(1.8, 0.3, (p1 - p0).length() + 0.2), seg)
	add_box("rust", Vector3(0.8, 18.0, 0.8), xform(loop_center - Vector3(0, 9.0, 0)))
	for i in 4:
		add_light(points[i * 17], Color(1.0, 0.25, 0.3), 2.5, 40.0)


# --- Water Park ----------------------------------------------------------------------

func _water_park() -> void:
	var t := xform(SLIDE_TOWER)
	add_box("steel", Vector3(9, 26, 9), t.translated_local(Vector3(0, 13, 0)))
	add_box("neon2", Vector3(9.4, 0.4, 9.4), t.translated_local(Vector3(0, 26.2, 0)))
	# Two spiral slides winding down around the tower.
	for s in 2:
		var key := "slide" if s == 0 else "slide2"
		var phase := float(s) * PI
		var prev := Vector3.ZERO
		for i in 40:
			var ang := phase + i * 0.35
			var r := 10.0 + s * 4.0
			var p := SLIDE_TOWER + Vector3(cos(ang) * r, 25.0 - i * 0.6, sin(ang) * r)
			if i > 0:
				add_box(key, Vector3(1.8, 1.0, (p - prev).length() + 0.4),
						Transform3D(Basis.looking_at((p - prev).normalized(), Vector3.UP), (p + prev) * 0.5))
			prev = p
	# Pools and lounge decks around the shortcut (flooded, glowing).
	for p in [Vector3(-300, 0, 560), Vector3(-430, 0, 470), Vector3(-260, 0, 440), Vector3(-480, 0, 590)]:
		var xf := xform(p, rng.randf_range(-0.4, 0.4))
		var w := rng.randf_range(26, 40)
		var dd := rng.randf_range(18, 30)
		if clear_rect(xf, w, dd):
			add_box("concrete", Vector3(w + 4, 0.3, dd + 4), xf.translated_local(Vector3(0, 0.15, 0)))
			add_box("pool", Vector3(w, 0.32, dd), xf.translated_local(Vector3(0, 0.2, 0)))
	add_light(SLIDE_TOWER + Vector3(0, 10, 0), Color(0.3, 0.8, 1.0), 3.0, 50.0)
	for p in [Vector3(-300, 3, 560), Vector3(-430, 3, 470)]:
		add_light(p, Color(0.2, 0.7, 0.9), 2.0, 30.0)


# --- Backlot -------------------------------------------------------------------------

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
		add_box("concrete", Vector3(w, h, dd), xf.translated_local(Vector3(0, h * 0.5, 0)))
		add_box("rust", Vector3(w + 1, 1.0, dd + 1), xf.translated_local(Vector3(0, h, 0)))
		if lot[1] != "":
			# Painted name on the side facing the road (east).
			add_text(lot[1], Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(w * 0.5 + 0.3, h * 0.6, 0)), Color(0.9, 0.85, 0.75), 0.1, 120)
	# Stacked containers and light poles.
	for i in 14:
		var p := Vector3(rng.randf_range(-720, -440), 0, rng.randf_range(60, 520))
		var xf := xform(p, rng.randf_range(0, PI))
		if clear_rect(xf, 13.0, 4.0):
			var stack := rng.randi_range(1, 3)
			for k in stack:
				add_box("neon%d" % rng.randi_range(0, NEON.size() - 1) if k == stack - 1 and rng.randf() < 0.2 else ("rust" if (i + k) % 2 == 0 else "steel"),
						Vector3(12.0, 2.6, 2.5), xf.translated_local(Vector3(0, 1.3 + k * 2.6, 0)))
	var half := track.road_width * 0.5
	for d in range(0, int(track.length), 70):
		var center := track.curve.sample_baked(float(d))
		if center.x < -440 and center.z > 60 and center.z < 520:
			var pole := at(float(d), half + 4.0)
			add_box("steel", Vector3(0.3, 10, 0.3), pole.translated_local(Vector3(0, 5, 0)))
			add_box("warm", Vector3(1.6, 0.3, 0.6), pole.translated_local(Vector3(-0.8, 10, 0)))
			add_light(pole * Vector3(-1, 9, 0), Color(1.0, 0.65, 0.3), 2.0, 22.0)


# --- Bayou Outrun --------------------------------------------------------------------------

func _bayou() -> void:
	# Swamp water around the west straight and the arc.
	for p in [Vector3(-560, 0, -120), Vector3(-520, 0, 50), Vector3(-300, 0, -30), Vector3(-330, 0, -260), Vector3(-560, 0, -300)]:
		var xf := xform(p)
		var size := Vector2(rng.randf_range(120, 180), rng.randf_range(120, 180))
		add_box("swamp", Vector3(size.x, 0.1, size.y), xf.translated_local(Vector3(0, 0.03, 0)))
	# Boardwalk planks across the road along the bayou section.
	var a := track.curve.get_closest_offset(BAYOU_FROM)
	var b := track.curve.get_closest_offset(BAYOU_TO)
	var d := a
	while d < b:
		var xf := at(d)
		add_box("plank", Vector3(track.road_width - 0.8, 0.03, 1.0), xf.translated_local(Vector3(0, 0.035, 0)))
		d += 1.4
	# Boardwalk posts and lanterns along the edges.
	d = a
	var n := 0
	while d < b:
		for side in [-1.0, 1.0]:
			var post := at(d, side * (track.road_width * 0.5 + 2.2))
			add_box("wood", Vector3(0.4, 2.5, 0.4), post.translated_local(Vector3(0, 1.25, 0)))
			if n % 3 == 0:
				add_box("warm", Vector3(0.5, 0.6, 0.5), post.translated_local(Vector3(0, 2.8, 0)))
		if n % 6 == 0:
			add_light(at(d, track.road_width * 0.5 + 2.2) * Vector3(0, 3, 0), Color(1.0, 0.7, 0.35), 2.0, 20.0)
		d += 18.0
		n += 1
	# Cypress trees with hanging moss.
	for i in 70:
		var p := Vector3(rng.randf_range(-720, -100), 0, rng.randf_range(-380, 160))
		if clear(p, 4.0):
			_cypress(p, rng.randf_range(12, 22))


func _cypress(pos: Vector3, h: float) -> void:
	var base := xform(pos)
	add_cone("wood", 2.0, 3.0, base, 6)
	add_cyl("wood", 0.9, h, base, 6, 0.35)
	for k in 3:
		var y := h * (0.65 + k * 0.13)
		var r := rng.randf_range(3.0, 5.5)
		add_box("leaf", Vector3(r * 2.0, 1.4, r * 1.6), base.translated_local(Vector3(rng.randf_range(-1, 1), y, rng.randf_range(-1, 1))).rotated_local(Vector3.UP, rng.randf() * PI))
		for m in 3:
			var len := rng.randf_range(2.0, 5.0)
			add_box("moss", Vector3(0.2, len, 0.2), base.translated_local(Vector3(rng.randf_range(-r, r), y - len * 0.5, rng.randf_range(-r, r))))


# --- Overgrowth ---------------------------------------------------------------------------

func _overgrowth() -> void:
	material("palm_trunk", Color(0.22, 0.16, 0.1), 0.0, 0.0, 0.9)
	material("palm_leaf", Color(0.06, 0.25, 0.12), 0.25)
	for i in 160:
		var p := Vector3(rng.randf_range(-750, 650), 0, rng.randf_range(-400, 780))
		if p.distance_to(CAROUSEL) < 25.0 or p.distance_to(SLIDE_TOWER) < 30.0 or p.distance_to(WHEEL) < 50.0:
			continue
		if not clear(p, 4.0):
			continue
		if rng.randf() < 0.35:
			add_palm(p, rng.randf_range(8, 14), "palm_trunk", "palm_leaf")
		else:
			var r := rng.randf_range(2.0, 6.0)
			add_sphere("leaf", r, xform(p + Vector3(0, r * 0.6, 0)), 4, 7)
