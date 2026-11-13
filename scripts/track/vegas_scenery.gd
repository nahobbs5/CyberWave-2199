@tool
class_name VegasScenery
extends TrackScenery
## Vegas Overdrive set dressing (GDD 8.3): a neon casino district at night.
## Landmarks sit at fixed layout coordinates (track-local metres, matching
## vegas_overdrive.tscn); generic dressing follows the road and skips
## anything that would overlap it.
##
##   The Strip         casino towers, palms, billboards, the Welcome sign
##   Fountain lake     a lake with an animated fountain show (east side)
##   Paris             an Eiffel-style tower and a glowing balloon (south-east)
##   Casino interior   a roofed section with chandeliers and slot rows (infield)
##   High Roller       a giant observation wheel (infield)
##   Service tunnel    an enclosed concrete tunnel with strip lights
##   Excalibur         a castle with coloured spires (south)
##   Luxor             a glass pyramid and sky beam; the shortcut runs through it

## Area names and their layout positions (also used by tests and the minimap).
const LAKE := Vector3(530, 0, 290)
const EIFFEL := Vector3(60, 0, 695)
const BALLOON := Vector3(200, 0, 680)
const WHEEL := Vector3(-110, 0, 450)
const CASTLE := Vector3(-320, 0, 825)
const PYRAMID := Vector3(-500, 0, 420)
const PYRAMID_HALF := 50.0
const PYRAMID_HEIGHT := 80.0
const SPHINX := Vector3(-395, 0, 480)
## Roofed casino floor: up the infield and along its top straight.
const CASINO_FROM := Vector3(-20, 0, 505)
const CASINO_TO := Vector3(-175, 0, 304)
## Service tunnel along the infield straight going south.
const TUNNEL_FROM := Vector3(-200, 0, 365)
const TUNNEL_TO := Vector3(-200, 0, 615)

const CASINO_NAMES: Array[String] = ["NEON PALACE", "GOLDEN 2199", "OVERDRIVE", "STARFALL", "JACKPOT CITY",
		"VELVET", "HIGH ROLLER", "LUCKY 7", "CHROME CROWN", "MIDNIGHT"]
const NEON: Array[Color] = [Color(1.0, 0.15, 0.75), Color(0.0, 0.9, 1.0), Color(1.0, 0.7, 0.15),
		Color(0.6, 0.3, 1.0), Color(1.0, 0.3, 0.3), Color(0.3, 1.0, 0.6)]


func build() -> void:
	textured("tower", "concrete_panels", Color(0.12, 0.12, 0.23), 4.0, 0.5, 0.3)
	textured("tower_light", "concrete_panels", Color(0.2, 0.21, 0.37), 4.0, 0.6, 0.2)
	textured("concrete", "brushed_concrete", Color(0.53, 0.54, 0.7), 3.0, 0.9)
	material("gold", Color(1.0, 0.75, 0.3), 2.2)
	textured("white_stone", "marble_01", Color(1.0, 1.0, 1.15), 3.0, 0.7)
	material("window_warm", Color(1.0, 0.8, 0.45), 1.6)
	material("window_cool", Color(0.5, 0.75, 1.0), 1.4)
	for i in NEON.size():
		material("neon%d" % i, NEON[i], 4.0)
	textured("palm_trunk", "palm_tree_bark", Color(0.41, 0.32, 0.24), 1.5, 0.9)
	material("palm_leaf", Color(0.08, 0.35, 0.18), 0.3)
	material("water", Color(0.05, 0.2, 0.35), 0.4, 0.6, 0.05)
	material("glass", Color(0.06, 0.07, 0.12), 0.0, 0.8, 0.1)
	material("beam", Color(0.75, 0.9, 1.0, 0.35), 3.0, 0.0, 0.5, true)
	textured("carpet", "velour_velvet", Color(0.51, 0.28, 0.43), 1.5, 0.9)
	add_glow("carpet", Color(0.35, 0.05, 0.12), 0.2)
	material("red", Color(0.8, 0.1, 0.12), 0.8)
	material("blue", Color(0.15, 0.3, 0.9), 0.8)
	_strip()
	await step(0.10)
	_city_fill()
	await step(0.20)
	_lake_and_fountains()
	await step(0.30)
	_paris()
	await step(0.40)
	_casino_interior()
	await step(0.50)
	_high_roller()
	await step(0.60)
	_service_tunnel()
	await step(0.70)
	_excalibur()
	await step(0.80)
	_luxor()
	await step(0.90)
	_welcome_sign()


# --- The Strip ---------------------------------------------------------------

func _on_strip(local: Vector3) -> bool:
	return local.z < 75.0 and local.x > -450.0 and local.x < 135.0


func _strip() -> void:
	var half := track.road_width * 0.5
	var step := 3.0
	var d := 0.0
	var name_index := 0
	var last_tower := {-1.0: -1000.0, 1.0: -1000.0}
	while d < track.length:
		var center := track.curve.sample_baked(d)
		if _on_strip(center):
			for side in [-1.0, 1.0]:
				# Palms along the kerb every 18 m.
				if int(d / step) % 6 == 0:
					var palm_xf := at(d, side * (half + 5.0))
					if clear(palm_xf.origin, 1.0):
						_palm(palm_xf.origin, rng.randf_range(9.0, 14.0))
				# Casino towers set back from the road.
				if d - float(last_tower[side]) > 55.0:
					var w := rng.randf_range(34.0, 52.0)
					var depth := rng.randf_range(30.0, 46.0)
					var h := rng.randf_range(45.0, 150.0)
					var xf := at(d, side * (half + 18.0 + depth * 0.5))
					if clear_rect(xf, w, depth):
						_casino_tower(xf, w, depth, h, side, CASINO_NAMES[name_index % CASINO_NAMES.size()])
						name_index += 1
						last_tower[side] = d
		d += step
	# A tall observation tower closing the west end of the Strip.
	var tower := xform(Vector3(-480, 0, -200))
	add_cyl("concrete", 9.0, 230.0, tower, 12, 5.0)
	add_cyl("tower_light", 22.0, 18.0, xform(Vector3(-480, 225, -200)), 16)
	add_cyl("neon0", 22.5, 1.0, xform(Vector3(-480, 232, -200)), 16)
	add_cyl("neon1", 1.0, 40.0, xform(Vector3(-480, 243, -200)), 6)


func _casino_tower(xf: Transform3D, w: float, depth: float, h: float, side: float, title: String) -> void:
	add_box("tower", Vector3(w, h, depth), xf.translated_local(Vector3(0, h * 0.5, 0)))
	var neon := "neon%d" % rng.randi_range(0, NEON.size() - 1)
	var window := "window_warm" if rng.randf() < 0.6 else "window_cool"
	# Window bands on the road-facing side and the two ends.
	var floors := int(h / 6.0)
	for f in range(1, floors):
		if rng.randf() < 0.25:
			continue
		var y := f * 6.0
		# at() faces along the road with +X to the right, so the road-facing
		# wall of a tower on side `side` is at -side * w / 2.
		add_box(window, Vector3(0.3, 1.2, depth * 0.85), xf.translated_local(Vector3(-side * (w * 0.5 + 0.1), y, 0)))
		add_box(window, Vector3(w * 0.85, 1.2, 0.3), xf.translated_local(Vector3(0, y, depth * 0.5 + 0.1)))
		add_box(window, Vector3(w * 0.85, 1.2, 0.3), xf.translated_local(Vector3(0, y, -depth * 0.5 - 0.1)))
	# Neon crown and edge lines.
	_roof_outline(xf, w + 1.0, depth + 1.0, h + 0.4, neon)
	add_box(neon, Vector3(0.6, h, 0.6), xf.translated_local(Vector3(-side * w * 0.5, h * 0.5, depth * 0.5)))
	add_box(neon, Vector3(0.6, h, 0.6), xf.translated_local(Vector3(-side * w * 0.5, h * 0.5, -depth * 0.5)))
	# Big name sign facing the road, plus a glowing billboard.
	var sign_xf := xf.translated_local(Vector3(-side * (w * 0.5 + 0.6), minf(h - 8.0, 28.0), 0))
	sign_xf.basis = sign_xf.basis * Basis(Vector3.UP, -side * PI * 0.5)
	add_text(title, sign_xf, NEON[rng.randi_range(0, NEON.size() - 1)], 0.08, 110)
	if rng.randf() < 0.6:
		var board := xf.translated_local(Vector3(-side * (w * 0.5 + 0.4), 10.0, 0))
		add_box("neon%d" % rng.randi_range(0, NEON.size() - 1), Vector3(0.3, 9.0, depth * 0.6), board)


func _palm(pos: Vector3, h: float) -> void:
	add_palm(pos, h, "palm_trunk", "palm_leaf")


# --- background city -------------------------------------------------------------

func _city_fill() -> void:
	# Low blocks on a loose grid away from the Strip, kept off every road.
	var lo := Vector2(-900, -380)
	var hi := Vector2(900, 1000)
	var x := lo.x
	while x < hi.x:
		var z := lo.y
		while z < hi.y:
			var pos := Vector3(x + rng.randf_range(-15, 15), 0, z + rng.randf_range(-15, 15))
			if not _near_landmark(pos):
				var w := rng.randf_range(20, 45)
				var dd := rng.randf_range(20, 45)
				var h := rng.randf_range(8, 40) if not _on_strip(pos) else rng.randf_range(20, 70)
				var xf := xform(pos, rng.randf_range(-0.1, 0.1))
				if clear_rect(xf, w + 12.0, dd + 12.0):
					add_box("tower", Vector3(w, h, dd), xf.translated_local(Vector3(0, h * 0.5, 0)))
					if rng.randf() < 0.35:
						_roof_outline(xf, w, dd, h, "neon%d" % rng.randi_range(0, NEON.size() - 1))
			z += 70.0
		x += 70.0


## Thin neon outline around a roof edge.
func _roof_outline(xf: Transform3D, w: float, d: float, h: float, key: String) -> void:
	add_box(key, Vector3(w, 0.5, 0.5), xf.translated_local(Vector3(0, h, d * 0.5)))
	add_box(key, Vector3(w, 0.5, 0.5), xf.translated_local(Vector3(0, h, -d * 0.5)))
	add_box(key, Vector3(0.5, 0.5, d), xf.translated_local(Vector3(w * 0.5, h, 0)))
	add_box(key, Vector3(0.5, 0.5, d), xf.translated_local(Vector3(-w * 0.5, h, 0)))


func _near_landmark(pos: Vector3) -> bool:
	for p in [EIFFEL, BALLOON, WHEEL, CASTLE, PYRAMID, SPHINX]:
		if pos.distance_to(p) < 110.0:
			return true
	if pos.x > 390.0 and pos.x < 760.0 and pos.z > 60.0 and pos.z < 520.0:
		return true # the lake and its hotel
	return false


# --- Fountain lake ---------------------------------------------------------------

func _lake_and_fountains() -> void:
	add_box("water", Vector3(200, 0.4, 400), xform(LAKE + Vector3(0, 0.1, 0)))
	add_box("white_stone", Vector3(206, 1.2, 4), xform(LAKE + Vector3(0, 0.6, -202)))
	add_box("white_stone", Vector3(206, 1.2, 4), xform(LAKE + Vector3(0, 0.6, 202)))
	add_box("white_stone", Vector3(4, 1.2, 404), xform(LAKE + Vector3(-102, 0.6, 0)))
	# The grand hotel behind the lake.
	var hotel := xform(LAKE + Vector3(180, 0, 0))
	add_box("white_stone", Vector3(60, 90, 300), hotel.translated_local(Vector3(0, 45, 0)))
	for f in range(1, 14):
		add_box("window_warm", Vector3(0.4, 1.4, 270), hotel.translated_local(Vector3(-30.3, f * 6.5, 0)))
	add_box("gold", Vector3(62, 2, 302), hotel.translated_local(Vector3(0, 91, 0)))
	add_text("FOUNTAINS", xform(LAKE + Vector3(148, 70, 0), -PI * 0.5), Color(1.0, 0.85, 0.5), 0.18, 120)
	# Fountain jets that rise and fall (animated in game).
	var jets := Node3D.new()
	jets.name = "Fountains"
	add_node(jets)
	var jet_mat := StandardMaterial3D.new()
	jet_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.75)
	jet_mat.emission_enabled = true
	jet_mat.emission = Color(0.7, 0.85, 1.0)
	jet_mat.emission_energy_multiplier = 2.0
	jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var jet_mesh := CylinderMesh.new()
	jet_mesh.top_radius = 0.4
	jet_mesh.bottom_radius = 1.2
	jet_mesh.height = 1.0
	jet_mesh.radial_segments = 8
	jet_mesh.rings = 1
	var count := 18
	for i in count:
		var jet := MeshInstance3D.new()
		jet.mesh = jet_mesh
		jet.material_override = jet_mat
		var zz := lerpf(-165.0, 165.0, float(i) / (count - 1))
		jet.position = LAKE + Vector3(-55.0 + 10.0 * sin(i * 0.9), 0.5, zz)
		jet.scale = Vector3(1, 20.0, 1)
		jet.position.y = 10.0
		jets.add_child(jet)
		if not Engine.is_editor_hint():
			var tween := jet.create_tween().set_loops()
			var tall := 18.0 + 14.0 * sin(i * 0.7)
			tween.tween_interval(0.15 * i)
			tween.tween_property(jet, "scale:y", tall, 1.4).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(jet, "position:y", tall * 0.5, 1.4).set_trans(Tween.TRANS_SINE)
			tween.tween_property(jet, "scale:y", 3.0, 1.6).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(jet, "position:y", 1.5, 1.6).set_trans(Tween.TRANS_SINE)
	for i in 4:
		add_light(LAKE + Vector3(-65, 6, -140 + i * 93), Color(0.6, 0.8, 1.0), 4.0, 70.0)


# --- Paris ----------------------------------------------------------------------

func _paris() -> void:
	var base := xform(EIFFEL)
	# Four splayed legs meeting at the first platform, then two tapering stages.
	for i in 4:
		var yaw := PI * 0.25 + i * PI * 0.5
		var foot := base * Vector3(cos(yaw) * 22.0, 0, sin(yaw) * 22.0)
		var top := base * Vector3(cos(yaw) * 8.0, 40.0, sin(yaw) * 8.0)
		var dir := (top - foot)
		var leg := Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (foot + top) * 0.5)
		add_box("gold", Vector3(3.0, 3.0, dir.length()), leg)
	add_box("gold", Vector3(26, 2.5, 26), base.translated_local(Vector3(0, 40, 0)))
	add_cyl("gold", 9.0, 50.0, base.translated_local(Vector3(0, 41, 0)), 4, 4.0)
	add_box("gold", Vector3(12, 1.5, 12), base.translated_local(Vector3(0, 91, 0)))
	add_cyl("gold", 4.0, 45.0, base.translated_local(Vector3(0, 92, 0)), 4, 0.6)
	add_cyl("neon2", 0.5, 12.0, base.translated_local(Vector3(0, 137, 0)), 4)
	add_light(EIFFEL + Vector3(0, 60, 0), Color(1.0, 0.75, 0.35), 5.0, 90.0)
	var balloon := xform(BALLOON)
	add_cyl("tower", 5.0, 14.0, balloon, 10)
	add_sphere("neon4", 15.0, balloon.translated_local(Vector3(0, 28, 0)), 8, 14)
	add_text("PARIS", Transform3D(Basis(Vector3.UP, PI), BALLOON + Vector3(0, 28, -15.5)), Color(1, 1, 1), 0.09, 120)
	add_light(BALLOON + Vector3(0, 20, -20), Color(1.0, 0.4, 0.4), 4.0, 50.0)


# --- Casino interior ------------------------------------------------------------

func _casino_interior() -> void:
	var a := track.curve.get_closest_offset(CASINO_FROM)
	var b := track.curve.get_closest_offset(CASINO_TO)
	var half := track.road_width * 0.5
	var d := a
	var n := 0
	while d < b:
		var xf := at(d)
		# Roof slab, carpet beyond the barriers and gold pillars.
		add_box("tower", Vector3(track.road_width + 40.0, 1.0, 9.0), xf.translated_local(Vector3(0, 12.0, 0)))
		add_box("gold", Vector3(track.road_width + 40.0, 0.3, 0.4), xf.translated_local(Vector3(0, 11.4, 0)))
		for side in [-1.0, 1.0]:
			add_box("carpet", Vector3(18.0, 0.05, 9.0), xf.translated_local(Vector3(side * (half + 11.0), 0.03, 0)))
			if n % 3 == 0:
				add_box("gold", Vector3(1.2, 12.0, 1.2), xf.translated_local(Vector3(side * (half + 3.0), 6.0, 0)))
			# Rows of slot machines with glowing screens.
			if n % 2 == 0:
				for row in 2:
					var sx: float = side * (half + 7.0 + row * 7.0)
					add_box("tower_light", Vector3(1.6, 1.8, 6.0), xf.translated_local(Vector3(sx, 0.9, 0)))
					add_box("neon%d" % ((n + row) % NEON.size()), Vector3(1.7, 0.6, 5.4), xf.translated_local(Vector3(sx, 1.5, 0)))
		# Chandeliers over the road.
		if n % 4 == 1:
			var chandelier := xf.translated_local(Vector3(0, 8.5, 0))
			add_cyl("gold", 3.0, 1.6, chandelier, 10, 1.5)
			add_cyl("gold", 0.15, 2.0, chandelier.translated_local(Vector3(0, 1.6, 0)), 4)
			add_light((chandelier * Vector3(0, -0.5, 0)), Color(1.0, 0.8, 0.5), 3.0, 22.0)
		d += 9.0
		n += 1
	# Entrance arches with a sign.
	for off in [a, b]:
		var xf := at(off)
		add_box("gold", Vector3(track.road_width + 42.0, 3.0, 2.0), xf.translated_local(Vector3(0, 13.5, 0)))
		var sign_xf := xf.translated_local(Vector3(0, 13.6, 1.1 if off == a else -1.1))
		if off != a:
			sign_xf.basis = sign_xf.basis * Basis(Vector3.UP, PI)
		add_text("CASINO", sign_xf, Color(1.0, 0.85, 0.4), 0.05, 96)


# --- High Roller wheel ----------------------------------------------------------

func _high_roller() -> void:
	add_ferris_wheel(WHEEL, 42.0, "neon0", "concrete", "window_cool", "tower")
	add_light(WHEEL + Vector3(0, 50, 0), Color(1.0, 0.2, 0.75), 4.0, 90.0)


# --- Service tunnel -------------------------------------------------------------

func _service_tunnel() -> void:
	var a := track.curve.get_closest_offset(TUNNEL_FROM)
	var b := track.curve.get_closest_offset(TUNNEL_TO)
	var half := track.road_width * 0.5 + track.barrier_thickness
	var d := a
	var n := 0
	while d < b:
		var xf := at(d)
		add_box("concrete", Vector3(half * 2.0 + 2.0, 1.2, 6.2), xf.translated_local(Vector3(0, 8.0, 0)))
		for side in [-1.0, 1.0]:
			add_box("concrete", Vector3(1.0, 8.0, 6.2), xf.translated_local(Vector3(side * (half + 0.5), 4.0, 0)))
		# Strip lights along the ceiling, red over the lanes, white in the middle.
		add_box("window_cool", Vector3(0.6, 0.15, 4.5), xf.translated_local(Vector3(0, 7.35, 0)))
		if n % 2 == 0:
			add_box("neon4", Vector3(0.3, 0.15, 4.5), xf.translated_local(Vector3(-5.0, 7.35, 0)))
			add_box("neon4", Vector3(0.3, 0.15, 4.5), xf.translated_local(Vector3(5.0, 7.35, 0)))
		if n % 6 == 0:
			add_light(xf * Vector3(0, 6.5, 0), Color(1.0, 0.35, 0.3), 2.5, 18.0)
		d += 6.0
		n += 1
	for off in [a, b]:
		var xf := at(off)
		add_box("neon1", Vector3(half * 2.0 + 2.5, 0.8, 0.8), xf.translated_local(Vector3(0, 8.8, 0)))
		add_text("SERVICE TUNNEL", xf.translated_local(Vector3(0, 10.3, 0.5 if off == a else -0.5))
				* Transform3D(Basis(Vector3.UP, 0.0 if off == a else PI), Vector3.ZERO), Color(0.0, 0.9, 1.0), 0.05, 80)


# --- Excalibur ------------------------------------------------------------------

func _excalibur() -> void:
	var c := xform(CASTLE)
	add_box("white_stone", Vector3(150, 34, 46), c.translated_local(Vector3(0, 17, 0)))
	add_box("white_stone", Vector3(46, 34, 110), c.translated_local(Vector3(-70, 17, 30)))
	add_box("white_stone", Vector3(46, 34, 110), c.translated_local(Vector3(70, 17, 30)))
	var spires := [["red", Vector3(-78, 0, -26)], ["blue", Vector3(-40, 0, -26)], ["gold", Vector3(-6, 0, -26)],
			["red", Vector3(30, 0, -26)], ["blue", Vector3(66, 0, -26)], ["gold", Vector3(-80, 0, 70)], ["red", Vector3(80, 0, 70)]]
	for s in spires:
		var p: Vector3 = s[1]
		var h := 46.0 + rng.randf_range(0, 18)
		add_cyl("white_stone", 6.5, h, c.translated_local(p), 10)
		add_cone(s[0], 8.0, 16.0, c.translated_local(p + Vector3(0, h, 0)), 10)
	for f in range(1, 5):
		add_box("window_warm", Vector3(140, 1.2, 0.4), c.translated_local(Vector3(0, f * 7.0, -23.2)))
	add_text("EXCALIBUR", Transform3D(Basis(Vector3.UP, PI), CASTLE + Vector3(0, 28, -23.6)), Color(1.0, 0.8, 0.3), 0.12, 120)
	add_light(CASTLE + Vector3(0, 20, -50), Color(0.6, 0.6, 1.0), 4.0, 80.0)


# --- Luxor --------------------------------------------------------------------------

func _luxor() -> void:
	var p := xform(PYRAMID)
	add_pyramid("glass", PYRAMID_HALF, PYRAMID_HEIGHT, p)
	# Glowing edges.
	for i in 4:
		var yaw := PI * 0.25 + i * PI * 0.5
		var corner := PYRAMID + Vector3(cos(yaw) * PYRAMID_HALF * sqrt(2.0), 0, sin(yaw) * PYRAMID_HALF * sqrt(2.0))
		var top := PYRAMID + Vector3(0, PYRAMID_HEIGHT, 0)
		add_box("neon1", Vector3(0.8, 0.8, (top - corner).length()),
				Transform3D(Basis.looking_at((top - corner).normalized(), Vector3.UP), (corner + top) * 0.5))
	# The sky beam.
	add_cyl("beam", 3.0, 700.0, xform(PYRAMID + Vector3(0, PYRAMID_HEIGHT, 0)), 8, 1.5)
	# Inside: warm light so the shortcut through it reads.
	for i in 3:
		add_light(PYRAMID + Vector3(0, 10, -32 + i * 32), Color(1.0, 0.7, 0.35), 3.0, 34.0)
	# A sphinx guarding the approach.
	var s := xform(SPHINX, -0.6)
	add_box("white_stone", Vector3(10, 9, 38), s.translated_local(Vector3(0, 4.5, 0)))
	add_box("white_stone", Vector3(9, 11, 9), s.translated_local(Vector3(0, 12, -17)))
	add_box("gold", Vector3(10, 4, 8), s.translated_local(Vector3(0, 16, -17)))
	add_text("LUXOR", Transform3D(Basis(Vector3.UP, PI * 0.25), PYRAMID + Vector3(38, 16, 38)), Color(0.0, 0.9, 1.0), 0.12, 120)


# --- Welcome sign ------------------------------------------------------------------

func _welcome_sign() -> void:
	# Labels face +Z, which in at()'s frame is back toward the oncoming cars.
	var xf := at(track.start_line_offset - 150.0, track.road_width * 0.5 + 9.0)
	add_box("concrete", Vector3(0.8, 7.0, 0.8), xf.translated_local(Vector3(-3, 3.5, 0)))
	add_box("concrete", Vector3(0.8, 7.0, 0.8), xf.translated_local(Vector3(3, 3.5, 0)))
	add_box("white_stone", Vector3(14, 8, 0.6), xf.translated_local(Vector3(0, 10, 0)))
	add_box("neon2", Vector3(14.4, 0.4, 0.7), xf.translated_local(Vector3(0, 14.1, 0)))
	add_box("neon2", Vector3(14.4, 0.4, 0.7), xf.translated_local(Vector3(0, 5.9, 0)))
	add_box("neon4", Vector3(0.3, 4.0, 0.3), xf.translated_local(Vector3(0, 16.0, 0)))
	var front := xf.translated_local(Vector3(0, 0, 0.35))
	add_text("WELCOME TO", front.translated_local(Vector3(0, 12.3, 0)), Color(0.1, 0.3, 0.9), 0.025, 90)
	add_text("FABULOUS", front.translated_local(Vector3(0, 10.4, 0)), Color(0.9, 0.1, 0.2), 0.03, 110)
	add_text("LAS VEGAS", front.translated_local(Vector3(0, 8.2, 0)), Color(0.9, 0.1, 0.2), 0.035, 110)
	add_light(xf * Vector3(0, 10, 4), Color(1.0, 0.9, 0.7), 3.0, 20.0)
