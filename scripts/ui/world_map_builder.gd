class_name WorldMapBuilder
extends RefCounted
## A glowing neon world map for the garage door (VehiclePreview): filled
## continents with bright coastlines, a faint lat / lon grid (full detail
## only) and a pin on every track, coloured by its cup. Built as flat 3D
## meshes in the XY plane facing +Z, so it stays sharp at any size.
##
## Continents reuse TrophyIcon's outlines (USA, Europe, Asia, South America,
## Africa) plus the pieces below; all simplified, icon-level shapes.

## Map edges in degrees: west, east, south, north (no Antarctica).
const LON_MIN := -170.0
const LON_MAX := 180.0
const LAT_MIN := -57.0
const LAT_MAX := 84.0

## Map width / height.
static func aspect() -> float:
	return (LON_MAX - LON_MIN) / (LAT_MAX - LAT_MIN)


const CANADA_LON_LAT: Array[Vector2] = [
	Vector2(-123.0, 49.0), Vector2(-127.0, 50.5), Vector2(-130.0, 54.0), Vector2(-133.0, 57.5),
	Vector2(-137.0, 58.5), Vector2(-141.0, 60.0), Vector2(-146.0, 60.8), Vector2(-152.0, 59.0),
	Vector2(-154.0, 57.5), Vector2(-158.0, 56.5), Vector2(-164.0, 54.8), Vector2(-160.0, 58.5),
	Vector2(-162.0, 60.0), Vector2(-165.0, 62.5), Vector2(-161.0, 64.5), Vector2(-166.0, 65.5),
	Vector2(-163.0, 67.0), Vector2(-166.0, 68.8), Vector2(-156.5, 71.3), Vector2(-150.0, 70.4),
	Vector2(-141.0, 69.6), Vector2(-135.0, 69.0), Vector2(-128.0, 70.0), Vector2(-120.0, 69.0),
	Vector2(-114.0, 68.3), Vector2(-108.0, 68.0), Vector2(-100.0, 68.0), Vector2(-95.0, 71.0),
	Vector2(-90.0, 69.0), Vector2(-85.0, 69.5), Vector2(-82.0, 66.5), Vector2(-87.0, 64.5),
	Vector2(-93.0, 61.0), Vector2(-94.5, 59.0), Vector2(-92.5, 57.0), Vector2(-87.0, 55.5),
	Vector2(-82.3, 55.0), Vector2(-82.0, 52.5), Vector2(-79.5, 51.5), Vector2(-77.0, 55.5),
	Vector2(-77.0, 59.5), Vector2(-78.0, 62.3), Vector2(-73.0, 62.0), Vector2(-70.0, 61.0),
	Vector2(-65.0, 60.3), Vector2(-62.0, 57.0), Vector2(-58.0, 54.0), Vector2(-56.0, 52.0),
	Vector2(-59.5, 50.3), Vector2(-64.5, 50.0), Vector2(-64.5, 48.5), Vector2(-64.8, 47.0),
	Vector2(-61.0, 45.5), Vector2(-63.6, 44.5), Vector2(-66.0, 43.8), Vector2(-67.0, 44.8),
	Vector2(-67.8, 45.7), Vector2(-67.8, 47.1), Vector2(-69.2, 47.4), Vector2(-70.3, 45.9),
	Vector2(-71.5, 45.0), Vector2(-75.0, 45.0), Vector2(-76.5, 44.2), Vector2(-79.0, 43.3),
	Vector2(-79.0, 42.8), Vector2(-81.0, 42.3), Vector2(-83.1, 42.1), Vector2(-82.5, 43.0),
	Vector2(-83.2, 45.0), Vector2(-84.0, 45.9), Vector2(-84.8, 46.5), Vector2(-88.0, 47.2),
	Vector2(-89.6, 48.0), Vector2(-92.0, 48.4), Vector2(-94.8, 49.4), Vector2(-95.2, 49.0),
	Vector2(-110.0, 49.0),
]

## Mexico and Central America down to Panama, with Baja California.
const MEXICO_LON_LAT: Array[Vector2] = [
	Vector2(-117.1, 32.5), Vector2(-114.8, 32.5), Vector2(-111.1, 31.3), Vector2(-108.2, 31.3),
	Vector2(-108.2, 31.8), Vector2(-106.5, 31.8), Vector2(-104.5, 29.6), Vector2(-103.1, 29.0),
	Vector2(-102.4, 29.8), Vector2(-101.4, 29.8), Vector2(-100.3, 28.6), Vector2(-99.5, 27.5),
	Vector2(-99.1, 26.4), Vector2(-97.4, 26.0), Vector2(-97.7, 24.0), Vector2(-97.5, 21.5),
	Vector2(-96.0, 19.0), Vector2(-94.5, 18.2), Vector2(-92.0, 18.6), Vector2(-90.5, 19.5),
	Vector2(-90.4, 21.0), Vector2(-87.0, 21.5), Vector2(-87.5, 19.0), Vector2(-88.2, 16.0),
	Vector2(-86.0, 15.9), Vector2(-83.3, 15.0), Vector2(-83.6, 11.0), Vector2(-82.0, 9.0),
	Vector2(-79.5, 9.5), Vector2(-77.5, 8.5), Vector2(-78.0, 7.3), Vector2(-80.0, 7.3),
	Vector2(-83.0, 8.3), Vector2(-85.7, 10.0), Vector2(-87.5, 13.0), Vector2(-91.5, 14.0),
	Vector2(-94.5, 16.0), Vector2(-96.5, 15.7), Vector2(-101.0, 17.3), Vector2(-105.5, 20.0),
	Vector2(-105.2, 21.8), Vector2(-106.5, 23.2), Vector2(-109.0, 25.5), Vector2(-112.5, 29.8),
	Vector2(-114.6, 31.7), Vector2(-113.5, 29.0), Vector2(-112.0, 27.0), Vector2(-110.3, 24.2),
	Vector2(-109.9, 22.9), Vector2(-112.0, 24.8), Vector2(-114.0, 27.5), Vector2(-115.8, 30.3),
]

## Russia west of the Urals, joining TrophyIcon's Europe and Asia.
const EASTERN_EUROPE_LON_LAT: Array[Vector2] = [
	Vector2(31.0, 69.5), Vector2(32.0, 60.0), Vector2(32.0, 52.0), Vector2(36.0, 47.0),
	Vector2(38.5, 47.0), Vector2(37.5, 45.0), Vector2(41.5, 41.5), Vector2(47.0, 43.0),
	Vector2(51.5, 47.0), Vector2(59.0, 52.0), Vector2(60.0, 60.0), Vector2(65.0, 69.5),
	Vector2(58.0, 68.8), Vector2(54.0, 68.5), Vector2(44.0, 68.3), Vector2(41.0, 66.3),
	Vector2(35.0, 66.5), Vector2(33.0, 69.3),
]

## Islands and the rest: Greenland, the Canadian Arctic, the Caribbean,
## Australia, New Zealand, New Guinea, Java, the Philippines and Taiwan.
const OTHER_LON_LAT: Array = [
	[Vector2(-73.0, 78.5), Vector2(-66.0, 81.0), Vector2(-55.0, 82.3), Vector2(-35.0, 83.6), Vector2(-20.0, 82.0),
	Vector2(-18.0, 80.0), Vector2(-19.0, 77.0), Vector2(-21.0, 74.0), Vector2(-22.0, 70.5), Vector2(-26.0, 68.5),
	Vector2(-32.0, 68.0), Vector2(-38.0, 65.5), Vector2(-41.0, 63.0), Vector2(-43.0, 60.0), Vector2(-46.0, 60.5),
	Vector2(-49.0, 62.0), Vector2(-51.0, 64.0), Vector2(-53.0, 66.5), Vector2(-54.0, 69.5), Vector2(-52.0, 71.0),
	Vector2(-56.0, 73.5), Vector2(-58.0, 75.8), Vector2(-66.0, 76.2), Vector2(-72.0, 77.5)],
	[Vector2(-80.0, 73.5), Vector2(-72.0, 72.0), Vector2(-68.0, 70.5), Vector2(-62.0, 67.0), Vector2(-64.0, 65.0),
	Vector2(-66.0, 62.0), Vector2(-72.0, 63.5), Vector2(-78.0, 64.5), Vector2(-74.0, 67.0), Vector2(-82.0, 69.5),
	Vector2(-90.0, 72.0), Vector2(-84.0, 73.8)],
	[Vector2(-118.0, 72.5), Vector2(-108.0, 73.5), Vector2(-100.0, 73.0), Vector2(-102.0, 69.5),
	Vector2(-112.0, 69.0), Vector2(-118.0, 70.5)],
	[Vector2(-92.0, 81.0), Vector2(-80.0, 83.0), Vector2(-65.0, 82.0), Vector2(-75.0, 79.0), Vector2(-80.0, 76.0),
	Vector2(-90.0, 76.5)],
	[Vector2(-85.0, 21.8), Vector2(-82.0, 23.2), Vector2(-77.5, 22.0), Vector2(-74.2, 20.2), Vector2(-77.5, 19.8),
	Vector2(-80.0, 21.7), Vector2(-84.5, 21.3)],
	[Vector2(-74.4, 19.8), Vector2(-72.8, 19.9), Vector2(-69.0, 19.6), Vector2(-68.4, 18.6), Vector2(-71.5, 17.6),
	Vector2(-74.4, 18.3)],
	[Vector2(113.5, -22.0), Vector2(114.0, -26.5), Vector2(115.0, -34.0), Vector2(117.5, -35.0), Vector2(123.0, -34.0),
	Vector2(129.0, -31.6), Vector2(132.0, -32.0), Vector2(135.5, -34.8), Vector2(138.0, -35.5), Vector2(140.0, -38.0),
	Vector2(144.0, -38.3), Vector2(146.5, -39.0), Vector2(150.0, -37.5), Vector2(151.3, -33.8), Vector2(153.5, -28.5),
	Vector2(153.0, -25.0), Vector2(149.5, -22.0), Vector2(146.0, -18.5), Vector2(145.3, -15.0), Vector2(143.5, -14.0),
	Vector2(142.5, -10.7), Vector2(141.5, -13.5), Vector2(141.5, -17.0), Vector2(139.5, -17.5), Vector2(136.5, -15.5),
	Vector2(136.8, -12.2), Vector2(132.5, -11.5), Vector2(130.0, -13.0), Vector2(129.0, -15.0), Vector2(126.0, -14.0),
	Vector2(122.5, -17.0), Vector2(121.0, -19.5), Vector2(117.0, -20.7)],
	[Vector2(144.6, -40.7), Vector2(148.3, -40.9), Vector2(148.0, -43.2), Vector2(146.5, -43.6), Vector2(145.2, -42.2)],
	[Vector2(172.7, -34.4), Vector2(174.5, -36.0), Vector2(176.0, -37.6), Vector2(178.5, -37.7), Vector2(177.9, -39.2),
	Vector2(176.8, -40.0), Vector2(175.3, -41.6), Vector2(174.6, -41.2), Vector2(175.0, -39.8), Vector2(173.8, -39.2),
	Vector2(174.6, -38.0), Vector2(173.0, -35.5)],
	[Vector2(172.6, -40.5), Vector2(174.3, -41.7), Vector2(173.0, -43.6), Vector2(171.2, -44.5), Vector2(170.5, -46.0),
	Vector2(168.5, -46.6), Vector2(166.5, -46.0), Vector2(166.7, -45.0), Vector2(168.3, -44.0), Vector2(171.0, -42.4)],
	[Vector2(131.0, -1.4), Vector2(134.0, -0.8), Vector2(138.0, -1.6), Vector2(141.0, -2.6), Vector2(145.8, -4.8),
	Vector2(147.5, -6.5), Vector2(150.0, -10.5), Vector2(147.0, -10.0), Vector2(143.5, -9.0), Vector2(141.0, -9.1),
	Vector2(138.0, -8.3), Vector2(137.8, -5.5), Vector2(134.0, -4.0), Vector2(132.0, -2.8)],
	[Vector2(105.2, -6.8), Vector2(108.0, -6.3), Vector2(111.0, -6.4), Vector2(114.5, -7.8), Vector2(114.4, -8.7),
	Vector2(108.0, -7.8), Vector2(106.0, -7.4)],
	[Vector2(120.5, 18.5), Vector2(122.3, 18.4), Vector2(122.0, 16.0), Vector2(124.0, 13.0), Vector2(126.0, 9.5),
	Vector2(126.5, 7.0), Vector2(125.5, 6.0), Vector2(123.5, 7.5), Vector2(122.0, 7.0), Vector2(122.0, 10.5),
	Vector2(120.0, 14.5)],
	[Vector2(120.1, 23.0), Vector2(121.0, 25.2), Vector2(122.0, 25.0), Vector2(121.0, 22.0)],
]

## Where each track is (longitude, latitude), by track name.
const TRACK_LON_LAT := {
	"Marble Canyon": Vector2(-111.6, 36.8),
	"Six Flags New Orleans": Vector2(-89.9, 30.05),
	"The Stacks": Vector2(-77.0, 38.9),
	"Hoia Baciu Run": Vector2(23.5, 46.8),
	"Catacombs Descent": Vector2(2.35, 48.86),
	"Vatnajökull Glacier": Vector2(-16.8, 64.4),
	"Arashiyama Circuit": Vector2(135.7, 35.0),
	"Crazy House": Vector2(108.4, 11.9),
	"Gardens by the Bay": Vector2(103.86, 1.28),
	"Parque Quinta Normal": Vector2(-70.7, -33.45),
	"Vale da Lua": Vector2(-47.5, -14.1),
	"Choquequirao": Vector2(-72.9, -13.4),
	"Kilwa Kisiwani Ruins": Vector2(39.5, -8.96),
	"Fires of Nyiragongo": Vector2(29.25, -1.52),
	"Chefchaouen": Vector2(-5.26, 35.17),
}

## Pin colour per cup emblem.
const CUP_COLORS := {
	"usa": Color(1.0, 0.82, 0.25),
	"europe": Color(0.4, 0.5, 1.0),
	"asia": Color(1.0, 0.3, 0.5),
	"south_america": Color(0.35, 1.0, 0.55),
	"africa": Color(1.0, 0.55, 0.15),
}

const FILL_COLOR := Color(0.16, 0.32, 0.55)
const LINE_COLOR := Color(0.3, 0.95, 1.0)
const GRID_COLOR := Color(0.32, 0.18, 0.55)
const SCREEN_COLOR := Color(0.035, 0.025, 0.08)


## Every landmass as (longitude, latitude) outlines.
static func landmasses() -> Array:
	var out: Array = []
	out.append(TrophyIcon.USA_LON_LAT)
	out.append_array(TrophyIcon.EUROPE_LON_LAT)
	out.append_array(TrophyIcon.ASIA_LON_LAT)
	out.append(TrophyIcon.SOUTH_AMERICA_LON_LAT)
	out.append_array(TrophyIcon.AFRICA_LON_LAT)
	out.append(CANADA_LON_LAT)
	out.append(MEXICO_LON_LAT)
	out.append(EASTERN_EUROPE_LON_LAT)
	out.append_array(OTHER_LON_LAT)
	return out


## (track name, longitude/latitude, colour) for every track of every cup
## that has a known location.
static func pins() -> Array:
	var out: Array = []
	for cup in GrandPrixData.all_cups():
		var color: Color = CUP_COLORS.get(cup.emblem, Color.WHITE)
		for track in cup.track_names:
			if TRACK_LON_LAT.has(track):
				out.append([track, TRACK_LON_LAT[track], color])
	return out


## Map position (metres, centred) of a longitude / latitude on a map this wide.
static func project(lon_lat: Vector2, width: float) -> Vector2:
	var s := width / (LON_MAX - LON_MIN)
	return Vector2((lon_lat.x - (LON_MIN + LON_MAX) * 0.5) * s, (lon_lat.y - (LAT_MIN + LAT_MAX) * 0.5) * s)


## The map, `width` metres wide, centred on its origin and facing +Z.
## lite: no grid and thinner coastlines (the small split-screen cards).
static func build(width: float, lite: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "WorldMap"
	var height := width / aspect()
	var pad := width * 0.035
	var line_w := width * (0.0028 if lite else 0.0022)

	# Dark screen behind the map.
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = Vector2(width + pad * 2.0, height + pad * 2.0)
	screen.mesh = quad
	screen.material_override = _flat(WeaponManager.glow_material(SCREEN_COLOR, 0.0))
	root.add_child(screen)

	if not lite:
		var grid := SurfaceTool.new()
		grid.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lon := -150.0
		while lon <= LON_MAX:
			var x := project(Vector2(lon, 0.0), width).x
			_quad(grid, Vector2(x, -height * 0.5), Vector2(x, height * 0.5), line_w * 0.45, 0.002)
			lon += 30.0
		var lat := -30.0
		while lat <= 60.0:
			var y := project(Vector2(0.0, lat), width).y
			_quad(grid, Vector2(-width * 0.5, y), Vector2(width * 0.5, y), line_w * (0.9 if lat == 0.0 else 0.45), 0.002)
			lat += 30.0
		_add_mesh(root, "Grid", grid, WeaponManager.glow_material(GRID_COLOR, 1.2))

	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coast := SurfaceTool.new()
	coast.begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape: Array in landmasses():
		var pts := PackedVector2Array()
		for p: Vector2 in shape:
			pts.append(project(p, width))
		var tris := Geometry2D.triangulate_polygon(pts)
		for i in tris:
			fill.add_vertex(Vector3(pts[i].x, pts[i].y, 0.004))
		for i in pts.size():
			_quad(coast, pts[i], pts[(i + 1) % pts.size()], line_w, 0.008)
	_add_mesh(root, "Land", fill, WeaponManager.glow_material(FILL_COLOR, 0.45))
	_add_mesh(root, "Coast", coast, WeaponManager.glow_material(LINE_COLOR, 1.7))

	# Pins: a coloured disc with a white-hot centre, one mesh per cup colour.
	var by_color := {}
	var dots := SurfaceTool.new()
	dots.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pin_r := width * 0.011
	for pin: Array in pins():
		var c: Color = pin[2]
		if not by_color.has(c):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_color[c] = st
		var at := project(pin[1], width)
		_disc(by_color[c], at, pin_r, 0.012)
		_disc(dots, at, pin_r * 0.4, 0.016)
	var n := 0
	for c: Color in by_color:
		_add_mesh(root, "Pins%d" % n, by_color[c], WeaponManager.glow_material(c, 2.6))
		n += 1
	_add_mesh(root, "PinDots", dots, WeaponManager.glow_material(Color(1.0, 0.97, 0.9), 2.2))
	root.set_meta("pin_count", pins().size())
	root.set_meta("width", width)
	return root


## A flat strip from a to b, `w` wide, at depth z.
static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, w: float, z: float) -> void:
	var d := b - a
	if d.length_squared() < 1e-10:
		return
	var n := Vector2(-d.y, d.x).normalized() * w * 0.5
	# Stretch past the ends so neighbouring strips meet at corners.
	var e := d.normalized() * w * 0.5
	var p := [a - e + n, b + e + n, b + e - n, a - e - n]
	for i in [0, 2, 1, 0, 3, 2]:
		st.add_vertex(Vector3(p[i].x, p[i].y, z))


static func _disc(st: SurfaceTool, c: Vector2, r: float, z: float) -> void:
	var seg := 16
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		st.add_vertex(Vector3(c.x, c.y, z))
		st.add_vertex(Vector3(c.x + cos(a1) * r, c.y + sin(a1) * r, z))
		st.add_vertex(Vector3(c.x + cos(a0) * r, c.y + sin(a0) * r, z))


static func _add_mesh(root: Node3D, mesh_name: String, st: SurfaceTool, mat: StandardMaterial3D) -> void:
	var m := MeshInstance3D.new()
	m.name = mesh_name
	m.mesh = st.commit()
	_flat(mat)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)


## Drawn from both sides (the outlines' winding varies); the glow is emission.
static func _flat(mat: StandardMaterial3D) -> StandardMaterial3D:
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
