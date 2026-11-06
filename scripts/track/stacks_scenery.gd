@tool
class_name StacksScenery
extends TrackScenery
## The Stacks (GDD 8.1): racing through the Library of Congress at
## sunset. Monumental marble halls with painted coffered ceilings, gilded
## trim and chandeliers; tall west windows letting long shafts of low gold
## light across the floor; galleries of bookshelves; the narrow archive
## stacks (the shortcut); the domed Main Reading Room; and one open-air
## courtyard under the sunset sky. Textures are CC0 Poly Haven sets plus a
## generated book-spine texture. Positions are layout coordinates matching
## the_stacks.tscn.

## Hall stretches (from, to) in layout coordinates, driven in this order.
const GREAT_FROM := Vector3(-130, 0, 0)
const GREAT_TO := Vector3(250, 0, 140)
const GALLERY_TO := Vector3(250, 0, 385)
const ARCHIVE_TO := Vector3(22, 0, 400)
const COURT_FROM := Vector3(-15, 0, 525)
const COURT_TO := Vector3(312, 0, 525)
const CORRIDOR_FROM := Vector3(350, 0, 490)
const TOP_FROM := Vector3(330, 0, -100)
## Main Reading Room: the road's semicircle sweeps round this centre.
const ROTUNDA := Vector3(-20, 0, 462)
const ROTUNDA_RADIUS := 84.0

const PAINT: Array[Color] = [Color(0.42, 0.55, 0.72), Color(0.8, 0.62, 0.38), Color(0.75, 0.48, 0.45), Color(0.4, 0.62, 0.58)]


func build() -> void:
	textured("marble", "marble_01", Color(0.95, 0.92, 0.88), 3.0, 0.25)
	# Smooth warm plaster (the patterned texture read as brick at speed).
	material("plaster", Color(0.86, 0.76, 0.6), 0.0, 0.0, 0.75)
	material("ceiling", Color(0.9, 0.82, 0.66), 0.0, 0.0, 0.8)
	textured("velvet", "velour_velvet", Color(0.75, 0.12, 0.14), 2.0, 0.9)
	textured("stone", "monastery_stone_floor", Color(0.85, 0.8, 0.72), 3.0, 0.8)
	textured("parquet", "herringbone_parquet", Color(0.8, 0.68, 0.55), 2.0, 0.35)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.64, 0.3)
	gold.metallic = 1.0
	gold.roughness = 0.3
	register_material("gold", gold)
	material("wood", Color(0.24, 0.13, 0.07), 0.0, 0.1, 0.45)
	material("glass", Color(1.0, 0.72, 0.45), 1.8)
	material("candle", Color(1.0, 0.82, 0.55), 3.0)
	material("lamp_green", Color(0.2, 0.75, 0.4), 2.5)
	material("hedge", Color(0.13, 0.25, 0.1), 0.0, 0.0, 0.9)
	material("water", Color(0.25, 0.4, 0.5), 0.3, 0.6, 0.05)
	material("oculus", Color(1.0, 0.75, 0.4), 4.0)
	material("statue", Color(0.88, 0.86, 0.82), 0.0, 0.0, 0.5)
	for i in PAINT.size():
		material("paint%d" % i, PAINT[i], 0.35, 0.0, 0.9)
	register_material("books", _books_material())
	no_shadow_keys = ["glass", "candle", "lamp_green", "oculus", "water"]

	var great_from := _off(GREAT_FROM)
	var great_to := _off(GREAT_TO)
	var gallery_to := _off(GALLERY_TO)
	var archive_to := _off(ARCHIVE_TO)
	var court_from := _off(COURT_FROM)
	var court_to := _off(COURT_TO)
	var corridor_from := _off(CORRIDOR_FROM)
	var top_from := _off(TOP_FROM)
	# Great Hall: the grandest room, windows both sides.
	HallBuilder.build(self, great_from, great_to, {"width": 18.0, "height": 24.0, "bay": 14.0,
			"windows_left": true, "windows_right": true, "chandelier_every": 30.0})
	_great_hall(great_from, great_to)
	# Gallery: shelves on the east side, tall windows to the west.
	HallBuilder.build(self, great_to, gallery_to, {"width": 15.0, "height": 18.0, "bay": 12.0,
			"windows_right": true, "shelves_left": true, "chandelier_every": 36.0})
	# Archive: lower and narrower, shelves both sides.
	HallBuilder.build(self, gallery_to, archive_to, {"width": 13.0, "height": 12.0, "bay": 9.0,
			"shelves_left": true, "shelves_right": true, "chandelier_every": 40.0})
	_archive_stacks()
	_reading_room()
	_courtyard(court_from, court_to)
	# Card-catalogue corridor north, then the long hall west to the start.
	HallBuilder.build(self, corridor_from, top_from, {"width": 15.0, "height": 16.0, "bay": 12.0,
			"windows_left": true, "shelves_right": true, "chandelier_every": 36.0})
	_card_catalogue(corridor_from, top_from)
	HallBuilder.build(self, top_from, great_from, {"width": 15.0, "height": 18.0, "bay": 12.0,
			"windows_left": true, "shelves_right": true, "chandelier_every": 36.0})


func _off(p: Vector3) -> float:
	return track.curve.get_closest_offset(p)


## Generated book-spine texture: shelf rows of books in leather colours with
## gilt bands, and dark shelf boards (no external asset needed).
func _books_material() -> StandardMaterial3D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.06, 0.035, 0.02))
	var colors := [Color(0.45, 0.08, 0.07), Color(0.12, 0.22, 0.12), Color(0.1, 0.12, 0.3), Color(0.35, 0.2, 0.08),
			Color(0.5, 0.35, 0.15), Color(0.2, 0.1, 0.12), Color(0.55, 0.45, 0.3)]
	var row_h := 64
	for row in size / row_h:
		var y0 := row * row_h
		var x := 0
		while x < size:
			var w := rng.randi_range(4, 11)
			var h := rng.randi_range(44, 58)
			var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
			c = c.lightened(rng.randf_range(-0.1, 0.15))
			for px in range(x, mini(x + w - 1, size)):
				for py in range(y0 + row_h - 6 - h, y0 + row_h - 6):
					img.set_pixel(px, py, c)
				for band: int in [12, h - 10]:
					var by: int = y0 + row_h - 6 - h + band
					img.set_pixel(px, by, Color(0.8, 0.62, 0.3))
			x += w
		for px in size:
			for py in range(y0 + row_h - 6, y0 + row_h):
				img.set_pixel(px, py, Color(0.2, 0.11, 0.05))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# --- Great Hall -------------------------------------------------------------------

func _great_hall(from_offset: float, to_offset: float) -> void:
	var span := fposmod(to_offset - from_offset, track.length)
	var half := track.road_width * 0.5
	# Twin grand staircases rising along both walls near the start.
	for side: float in [-1.0, 1.0]:
		for step in 16:
			var xf := at(from_offset + 20.0 + step * 1.2, side * (half + 6.0))
			if clear(xf.origin, 2.0):
				add_box("marble", Vector3(6.0, 0.4 + step * 0.45, 1.2), xf.translated_local(Vector3(0, (0.4 + step * 0.45) * 0.5, 0)))
		var landing := at(from_offset + 40.0, side * (half + 6.0))
		if clear(landing.origin, 2.0):
			add_box("marble", Vector3(6.0, 0.5, 6.0), landing.translated_local(Vector3(0, 7.4, 0)))
			add_box("gold", Vector3(0.12, 1.0, 6.0), landing.translated_local(Vector3(-side * 3.0, 8.1, 0)))
	# Statues on pedestals and red velvet banners with a gilt emblem.
	var d := 12.0
	var n := 0
	while d < span:
		for side: float in [-1.0, 1.0]:
			var p := at(from_offset + d, side * (half + 4.0))
			if not clear(p.origin, 1.5):
				continue
			if n % 2 == 0:
				add_box("marble", Vector3(1.6, 1.6, 1.6), p.translated_local(Vector3(0, 0.8, 0)))
				_statue(p.translated_local(Vector3(0, 1.6, 0)))
			var banner := at(from_offset + d, side * (half + 9.0))
			if clear(banner.origin, 1.0):
				add_box("velvet", Vector3(0.1, 8.0, 3.2), banner.translated_local(Vector3(0, 15.0, 0)))
				add_cyl("gold", 0.9, 0.05, banner.translated_local(Vector3(-side * 0.08, 15.5, 0)).rotated_local(Vector3.FORWARD, PI * 0.5), 12)
				add_box("gold", Vector3(0.15, 0.2, 3.4), banner.translated_local(Vector3(0, 19.0, 0)))
		d += 24.0
		n += 1


func _statue(xf: Transform3D) -> void:
	add_cyl("statue", 0.45, 1.5, xf, 8, 0.35)
	add_cyl("statue", 0.35, 0.9, xf.translated_local(Vector3(0, 1.5, 0)), 8, 0.3)
	add_sphere("statue", 0.26, xf.translated_local(Vector3(0, 2.65, 0)), 4, 6)
	add_box("statue", Vector3(0.18, 0.9, 0.18), xf.translated_local(Vector3(0.45, 1.9, 0)).rotated_local(Vector3.FORWARD, -0.5))


# --- Archive stacks (the shortcut) ------------------------------------------------------

func _archive_stacks() -> void:
	var sc: TrackShortcut = track.shortcuts[0] if not track.shortcuts.is_empty() else null
	if sc == null:
		return
	# Towering shelves both sides of the narrow lane, a low ceiling, and lamps.
	var d := 6.0
	var n := 0
	while d < sc.length - 6.0:
		var center := sc.point_at(d)
		var tangent := sc.tangent_at(d)
		var right := tangent.cross(Vector3.UP).normalized()
		var basis := Basis.looking_at(tangent, Vector3.UP)
		for side: float in [-1.0, 1.0]:
			var pos := center + right * side * (sc.road_width * 0.5 + 2.2)
			if clear(pos, 0.5) or edge_distance(pos) > 1.0:
				HallBuilder.bookcase(self, Transform3D(basis * Basis(Vector3.UP, -side * PI * 0.5), pos), 3.0, 7.5)
		add_box("ceiling", Vector3(sc.road_width + 6.0, 0.5, 3.05), Transform3D(basis, center + Vector3(0, 9.5, 0)))
		if n % 2 == 0:
			add_box("gold", Vector3(sc.road_width + 6.0, 0.3, 0.4), Transform3D(basis, center + Vector3(0, 9.15, 0)))
		if n % 5 == 0:
			add_box("candle", Vector3(0.6, 0.3, 0.6), Transform3D(basis, center + Vector3(0, 9.1, 0)))
			add_light(center + Vector3(0, 8.5, 0), Color(1.0, 0.8, 0.55), 2.2, 18.0)
		d += 3.0
		n += 1


# --- Main Reading Room -------------------------------------------------------------------

func _reading_room() -> void:
	var c := ROTUNDA
	var r := ROTUNDA_RADIUS
	var drum_h := 26.0
	# Ring of marble columns, a drum wall with arched windows above.
	for i in 28:
		var ang := TAU * i / 28.0
		var p := c + Vector3(cos(ang), 0, sin(ang)) * (r - 6.0)
		if clear(p, 1.5):
			add_cyl("marble", 1.0, drum_h - 6.0, xform(p), 10)
			add_box("gold", Vector3(2.4, 0.6, 2.4), xform(p + Vector3(0, drum_h - 6.5, 0)))
		var w0 := c + Vector3(cos(ang), 0, sin(ang)) * r
		var w1 := c + Vector3(cos(TAU * (i + 1) / 28.0), 0, sin(TAU * (i + 1) / 28.0)) * r
		var seg := Transform3D(Basis.looking_at((w1 - w0).normalized(), Vector3.UP), (w0 + w1) * 0.5)
		if clear(w0, 1.0) and clear(w1, 1.0):
			add_box("marble", Vector3(1.0, 6.0, (w1 - w0).length() + 0.2), seg.translated_local(Vector3(0, 3.0, 0)))
			add_box("plaster", Vector3(1.0, 8.0, (w1 - w0).length() + 0.2), seg.translated_local(Vector3(0, 10.0, 0)))
			add_box("plaster", Vector3(1.0, 6.0, (w1 - w0).length() + 0.2), seg.translated_local(Vector3(0, 23.0, 0)))
			add_box("glass", Vector3(0.1, 6.0, (w1 - w0).length() - 2.0), seg.translated_local(Vector3(0, 17.0, 0)).translated_local(Vector3(0.6, 0, 0)))
		else:
			# Entrances: a gilded arch over the road.
			add_box("plaster", Vector3(1.0, 8.0, (w1 - w0).length() + 0.2), seg.translated_local(Vector3(0, drum_h - 4.0, 0)))
		# Balcony ring with statues.
		var bal := c + Vector3(cos(ang), 0, sin(ang)) * (r - 3.0)
		add_box("marble", Vector3(4.0, 0.5, (w1 - w0).length() + 0.2), Transform3D(seg.basis, bal + Vector3(0, 12.0, 0)))
		add_box("gold", Vector3(0.12, 1.0, (w1 - w0).length() + 0.2), Transform3D(seg.basis, bal + Vector3(0, 12.8, 0) - (bal - c).normalized() * 1.9))
		if i % 4 == 0:
			_statue(xform(bal + Vector3(0, 12.25, 0)))
	# Ribbed dome with painted panels and a glowing oculus.
	var rings := 8
	for k in rings:
		var a0 := PI * 0.5 * k / rings
		var a1 := PI * 0.5 * (k + 1) / rings
		for i in 28:
			var t0 := TAU * i / 28.0
			var t1 := TAU * (i + 1) / 28.0
			var q := func(a: float, t: float) -> Vector3: return c + Vector3(cos(t) * cos(a) * r, drum_h + sin(a) * r * 0.75, sin(t) * cos(a) * r)
			var key := "ceiling" if (i + k) % 2 == 0 else "paint%d" % (k % 4)
			if k == rings - 1:
				key = "oculus"
			var st := _st(key, c)
			_quad(st, q.call(a0, t0), q.call(a0, t1), q.call(a1, t1), q.call(a1, t0), c + Vector3(0, drum_h, 0))
			if i % 4 == 0:
				var p0: Vector3 = q.call(a0, t0)
				var p1: Vector3 = q.call(a1, t0)
				add_box("gold", Vector3(0.6, 0.6, p0.distance_to(p1) + 0.2), Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5))
	add_light(c + Vector3(0, drum_h + r * 0.7, 0), Color(1.0, 0.75, 0.45), 6.0, 90.0)
	# Concentric reading desks with green lamps, and the central desk.
	for ring_r: float in [26.0, 38.0]:
		var count := int(ring_r * 0.5)
		for i in count:
			var ang := TAU * i / count
			var p := c + Vector3(cos(ang), 0, sin(ang)) * ring_r
			if not clear(p, 2.0):
				continue
			var desk := Transform3D(Basis(Vector3.UP, -ang), p)
			add_box("wood", Vector3(1.0, 0.9, 5.0), desk.translated_local(Vector3(0, 0.45, 0)))
			add_box("lamp_green", Vector3(0.3, 0.2, 0.5), desk.translated_local(Vector3(0, 1.15, 0)))
	add_cyl("wood", 7.0, 1.2, xform(c), 16)
	add_cyl("marble", 3.0, 3.5, xform(c + Vector3(0, 1.2, 0)), 12, 2.0)
	for i in 4:
		add_light(c + Vector3(cos(i * PI * 0.5) * 32.0, 3.0, sin(i * PI * 0.5) * 32.0), Color(0.6, 1.0, 0.7), 1.2, 16.0)


# --- Courtyard ---------------------------------------------------------------------------

func _courtyard(from_offset: float, to_offset: float) -> void:
	var span := fposmod(to_offset - from_offset, track.length)
	var half := track.road_width * 0.5
	var d := 0.0
	var n := 0
	while d < span:
		var o := from_offset + d
		var center := at(o)
		# Stone paving from façade to façade.
		add_box("stone", Vector3(52.0, 0.02, 4.05), center.translated_local(Vector3(0, 0.008, 0)))
		for side: float in [-1.0, 1.0]:
			var face := at(o, side * 26.0)
			if clear(face.origin, 1.0):
				add_box("marble", Vector3(2.0, 3.0, 4.05), face.translated_local(Vector3(0, 1.5, 0)))
				add_box("plaster", Vector3(2.0, 17.0, 4.05), face.translated_local(Vector3(side * 0.2, 11.5, 0)))
				add_box("gold", Vector3(2.6, 0.6, 4.05), face.translated_local(Vector3(0, 20.2, 0)))
				# Windows glowing with interior light, three storeys.
				if n % 3 == 1:
					for storey in 3:
						add_box("glass", Vector3(0.2, 2.6, 2.0), face.translated_local(Vector3(-side * 1.05, 5.0 + storey * 5.0, 0)))
			var hedge := at(o, side * 13.0)
			if clear(hedge.origin, 0.8):
				add_box("hedge", Vector3(1.4, 1.2, 4.05), hedge.translated_local(Vector3(0, 0.6, 0)))
			if n % 7 == 3:
				var lamp := at(o, side * 11.0)
				if clear(lamp.origin, 0.4):
					add_box("wood", Vector3(0.2, 4.0, 0.2), lamp.translated_local(Vector3(0, 2.0, 0)))
					add_box("candle", Vector3(0.6, 0.8, 0.6), lamp.translated_local(Vector3(0, 4.3, 0)))
					add_light(lamp * Vector3(0, 4.3, 0), Color(1.0, 0.75, 0.45), 2.0, 18.0)
		d += 4.0
		n += 1
	# A fountain on the south lawn and low stairs flanking the jump.
	var f := at(from_offset + span * 0.35, -18.0)
	add_cyl("marble", 5.5, 0.8, f, 20)
	add_cyl("water", 5.0, 0.85, f, 20)
	add_cyl("marble", 0.6, 3.0, f, 8)
	add_cyl("marble", 1.8, 0.4, f.translated_local(Vector3(0, 3.0, 0)), 12)
	for side: float in [-1.0, 1.0]:
		for s in 4:
			var step := at(from_offset + span * 0.66 - 6.0 + s * 1.5, side * (half + 6.0))
			if clear(step.origin, 2.0):
				add_box("marble", Vector3(8.0, 0.25 * (s + 1), 1.5), step.translated_local(Vector3(0, 0.125 * (s + 1), 0)))


# --- Card catalogue ----------------------------------------------------------------------

func _card_catalogue(from_offset: float, to_offset: float) -> void:
	var span := fposmod(to_offset - from_offset, track.length)
	var half := track.road_width * 0.5
	var d := 8.0
	while d < span:
		var p := at(from_offset + d, -(half + 4.0))
		if clear(p.origin, 1.5):
			add_box("wood", Vector3(1.2, 1.6, 3.6), p.translated_local(Vector3(0, 0.8, 0)))
			for row in 3:
				for col in 4:
					add_box("gold", Vector3(0.05, 0.06, 0.25), p.translated_local(Vector3(0.62, 0.35 + row * 0.45, -1.3 + col * 0.85)))
		d += 9.0
