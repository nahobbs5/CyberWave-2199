class_name TrophyIcon
extends Control
## A cup's trophy, drawn in code: gold bowl, two handles, stem and a
## two-step base, with the cup's emblem on the bowl. "usa" is a silhouette
## of the lower 48 states; "europe" a map of Europe (with Britain, Ireland
## and Iceland); "south_america" the continent; "japan" a rising sun; "globe" a little globe. Locked cups
## are grey with a padlock.

const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.72, 0.5, 0.08)
const GOLD_LIGHT := Color(1.0, 0.95, 0.65)
const EMBLEM_BG := Color(0.08, 0.14, 0.42)

## Outline of the contiguous USA as (longitude, latitude), clockwise from
## the north-west corner of Washington state. Simplified; for an icon.
const USA_LON_LAT: Array[Vector2] = [
	Vector2(-124.7, 48.4), Vector2(-123.0, 49.0), Vector2(-110.0, 49.0), Vector2(-95.2, 49.0),
	Vector2(-94.8, 49.4), Vector2(-92.0, 48.4), Vector2(-89.6, 48.0), Vector2(-88.0, 47.2),
	Vector2(-84.8, 46.5), Vector2(-84.0, 45.9), Vector2(-83.2, 45.0), Vector2(-82.5, 43.0),
	Vector2(-83.1, 42.1), Vector2(-81.0, 42.3), Vector2(-79.0, 42.8), Vector2(-79.0, 43.3),
	Vector2(-76.5, 44.2), Vector2(-75.0, 45.0), Vector2(-71.5, 45.0), Vector2(-70.3, 45.9),
	Vector2(-69.2, 47.4), Vector2(-67.8, 47.1), Vector2(-67.8, 45.7), Vector2(-67.0, 44.8),
	Vector2(-68.8, 44.3), Vector2(-70.0, 43.7), Vector2(-70.7, 42.7), Vector2(-70.0, 41.8),
	Vector2(-71.0, 41.5), Vector2(-71.9, 41.3), Vector2(-73.7, 40.9), Vector2(-74.0, 40.5),
	Vector2(-74.1, 39.7), Vector2(-74.9, 38.9), Vector2(-75.1, 38.3), Vector2(-75.6, 37.6),
	Vector2(-76.0, 36.9), Vector2(-75.5, 35.6), Vector2(-75.6, 35.2), Vector2(-76.5, 34.7),
	Vector2(-77.9, 33.9), Vector2(-79.2, 33.2), Vector2(-80.4, 32.4), Vector2(-81.1, 31.7),
	Vector2(-81.4, 30.4), Vector2(-80.6, 28.4), Vector2(-80.0, 26.7), Vector2(-80.4, 25.2),
	Vector2(-81.1, 25.1), Vector2(-81.8, 26.1), Vector2(-82.6, 27.9), Vector2(-82.8, 29.2),
	Vector2(-84.0, 30.1), Vector2(-85.3, 29.7), Vector2(-86.5, 30.4), Vector2(-88.5, 30.4),
	Vector2(-89.6, 30.2), Vector2(-89.4, 29.0), Vector2(-90.1, 29.1), Vector2(-91.3, 29.3),
	Vector2(-93.8, 29.7), Vector2(-94.7, 29.4), Vector2(-96.5, 28.3), Vector2(-97.2, 27.6),
	Vector2(-97.4, 26.0), Vector2(-99.1, 26.4), Vector2(-99.5, 27.5), Vector2(-100.3, 28.6),
	Vector2(-101.4, 29.8), Vector2(-102.4, 29.8), Vector2(-103.1, 29.0), Vector2(-104.5, 29.6),
	Vector2(-106.5, 31.8), Vector2(-108.2, 31.8), Vector2(-108.2, 31.3), Vector2(-111.1, 31.3),
	Vector2(-114.8, 32.5), Vector2(-117.1, 32.5), Vector2(-118.5, 34.0), Vector2(-120.6, 34.6),
	Vector2(-121.9, 36.6), Vector2(-122.5, 37.8), Vector2(-123.7, 38.9), Vector2(-124.2, 40.4),
	Vector2(-124.2, 42.0), Vector2(-124.0, 43.7), Vector2(-124.0, 46.3),
]

## Europe as (longitude, latitude): the mainland with Scandinavia, then
## Great Britain, Ireland and Iceland. Simplified; for an icon.
const EUROPE_LON_LAT: Array = [
	[Vector2(-5.6, 36.0), Vector2(-8.9, 37.0), Vector2(-9.5, 38.8), Vector2(-8.8, 42.0), Vector2(-9.3, 43.0),
	Vector2(-1.8, 43.4), Vector2(-1.2, 46.2), Vector2(-4.5, 48.4), Vector2(-1.6, 49.6), Vector2(1.6, 50.9),
	Vector2(4.0, 51.8), Vector2(6.0, 53.4), Vector2(8.6, 53.9), Vector2(8.1, 56.8), Vector2(10.5, 57.7),
	Vector2(10.6, 55.0), Vector2(14.0, 54.0), Vector2(19.0, 54.5), Vector2(21.2, 55.8), Vector2(24.0, 57.0),
	Vector2(23.5, 59.3), Vector2(28.0, 59.7), Vector2(25.0, 60.2), Vector2(22.0, 60.3), Vector2(21.5, 62.5),
	Vector2(25.3, 65.0), Vector2(23.0, 65.8), Vector2(21.0, 64.0), Vector2(17.5, 62.3), Vector2(18.5, 60.0),
	Vector2(16.5, 57.0), Vector2(14.2, 55.4), Vector2(12.8, 56.3), Vector2(11.2, 58.9), Vector2(10.5, 59.5),
	Vector2(8.0, 58.0), Vector2(5.5, 59.0), Vector2(5.0, 61.5), Vector2(7.0, 62.8), Vector2(10.5, 64.5),
	Vector2(13.5, 67.0), Vector2(17.0, 69.2), Vector2(21.0, 70.2), Vector2(25.8, 71.1), Vector2(30.0, 70.2),
	Vector2(31.0, 69.5), Vector2(32.0, 60.0), Vector2(32.0, 52.0), Vector2(36.0, 47.0), Vector2(33.0, 46.0),
	Vector2(30.5, 46.5), Vector2(29.7, 45.2), Vector2(28.0, 43.5), Vector2(29.0, 41.1), Vector2(26.5, 40.6),
	Vector2(24.0, 40.7), Vector2(23.0, 39.5), Vector2(22.5, 37.0), Vector2(21.2, 37.9), Vector2(20.0, 39.6),
	Vector2(19.4, 41.8), Vector2(16.0, 43.5), Vector2(13.6, 45.6), Vector2(12.3, 45.4), Vector2(12.6, 44.0),
	Vector2(14.0, 42.5), Vector2(16.0, 41.5), Vector2(18.5, 40.1), Vector2(17.0, 39.0), Vector2(16.5, 38.0),
	Vector2(15.7, 38.0), Vector2(15.6, 40.0), Vector2(14.2, 40.8), Vector2(12.5, 41.7), Vector2(10.5, 43.0),
	Vector2(8.8, 44.4), Vector2(7.5, 43.8), Vector2(4.8, 43.4), Vector2(3.1, 43.0), Vector2(3.2, 41.9),
	Vector2(0.8, 40.8), Vector2(-0.3, 39.5), Vector2(0.2, 38.7), Vector2(-0.7, 37.6), Vector2(-2.1, 36.7),
	Vector2(-4.4, 36.7)],
	[Vector2(-5.7, 50.0), Vector2(1.4, 51.2), Vector2(1.7, 52.7), Vector2(0.0, 53.5), Vector2(-1.6, 55.6),
	Vector2(-2.0, 57.6), Vector2(-3.5, 58.6), Vector2(-5.0, 58.6), Vector2(-6.2, 56.5), Vector2(-4.9, 55.0),
	Vector2(-3.0, 53.9), Vector2(-4.6, 53.2), Vector2(-4.2, 51.6)],
	[Vector2(-10.0, 51.6), Vector2(-6.0, 52.2), Vector2(-6.0, 54.1), Vector2(-7.5, 55.3), Vector2(-10.0, 54.2)],
	[Vector2(-24.0, 65.5), Vector2(-22.0, 66.4), Vector2(-16.0, 66.5), Vector2(-13.6, 65.2), Vector2(-15.0, 64.3),
	Vector2(-18.7, 63.4), Vector2(-22.7, 63.8), Vector2(-22.0, 64.6), Vector2(-24.0, 64.9)],
]
## South America's outline (longitude, latitude), clockwise from Panama.
const SOUTH_AMERICA_LON_LAT := [
	Vector2(-77.5, 8.5), Vector2(-75.5, 10.8), Vector2(-71.5, 12.4), Vector2(-67, 10.6), Vector2(-62, 10.7), Vector2(-60, 8.5),
	Vector2(-57, 6), Vector2(-52, 5), Vector2(-50, 1.8), Vector2(-48, -1), Vector2(-44, -2.5), Vector2(-39.5, -3),
	Vector2(-35.3, -5.5), Vector2(-35, -9), Vector2(-37, -11), Vector2(-39, -15), Vector2(-39.5, -18), Vector2(-41, -22),
	Vector2(-43, -23), Vector2(-46, -24), Vector2(-48.5, -26.5), Vector2(-48.8, -28.5), Vector2(-51, -31), Vector2(-53, -33.7),
	Vector2(-55, -35), Vector2(-57.5, -35), Vector2(-57, -37), Vector2(-62, -39), Vector2(-62.3, -41), Vector2(-65, -42.5),
	Vector2(-64, -45), Vector2(-67.5, -46.5), Vector2(-65.8, -47.8), Vector2(-68.5, -51), Vector2(-68.5, -52.5), Vector2(-66, -55),
	Vector2(-70, -55.5), Vector2(-74, -52), Vector2(-75.5, -48), Vector2(-74, -44), Vector2(-73.5, -40), Vector2(-73.6, -37),
	Vector2(-71.6, -33), Vector2(-71.5, -28), Vector2(-70.5, -23), Vector2(-70.3, -18.3), Vector2(-72, -17), Vector2(-76, -14),
	Vector2(-77, -12), Vector2(-79.5, -7), Vector2(-81.2, -5), Vector2(-80, -2.5), Vector2(-80.5, 0), Vector2(-79, 1.5),
	Vector2(-77.5, 4), Vector2(-77.4, 7),
]

const SUN_RED := Color(0.85, 0.12, 0.15)

var emblem: String = ""
var locked: bool = false


func _init(p_emblem: String = "", p_locked: bool = false, side: float = 120.0) -> void:
	emblem = p_emblem
	locked = p_locked
	custom_minimum_size = Vector2.ONE * side
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The USA outline projected (x = lon * cos 38 deg, y = -lat) and fitted
## into `rect`, keeping its shape.
static func usa_polygon(rect: Rect2) -> PackedVector2Array:
	return outline_polygons([USA_LON_LAT], rect, 38.0)[0]


## South America fitted into `rect`.
static func south_america_polygon(rect: Rect2) -> PackedVector2Array:
	return outline_polygons([SOUTH_AMERICA_LON_LAT], rect, -20.0)[0]


## Europe's outlines (mainland, Britain, Ireland, Iceland) fitted into `rect`.
static func europe_polygons(rect: Rect2) -> Array[PackedVector2Array]:
	return outline_polygons(EUROPE_LON_LAT, rect, 52.0)


## Map outlines given as (longitude, latitude) lists, projected (x = lon *
## cos lat0, y = -lat) and fitted together into `rect`, keeping their shape.
static func outline_polygons(shapes: Array, rect: Rect2, lat0: float) -> Array[PackedVector2Array]:
	var squash := cos(deg_to_rad(lat0))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var raw: Array[PackedVector2Array] = []
	for shape in shapes:
		var pts := PackedVector2Array()
		for p: Vector2 in shape:
			var q := Vector2(p.x * squash, -p.y)
			pts.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
		raw.append(pts)
	var span := hi - lo
	var s := minf(rect.size.x / span.x, rect.size.y / span.y)
	var offset := rect.position + (rect.size - span * s) * 0.5
	var out: Array[PackedVector2Array] = []
	for pts in raw:
		var fitted := PackedVector2Array()
		for q in pts:
			fitted.append(offset + (q - lo) * s)
		out.append(fitted)
	return out


func _draw() -> void:
	var w := minf(size.x, size.y)
	var o := (size - Vector2.ONE * w) * 0.5
	var gold := GOLD if not locked else Color(0.55, 0.55, 0.6)
	var dark := GOLD_DARK if not locked else Color(0.35, 0.35, 0.4)
	var light := GOLD_LIGHT if not locked else Color(0.8, 0.8, 0.85)
	# Handles behind the bowl.
	for side in [-1.0, 1.0]:
		var c := o + Vector2(w * (0.5 + side * 0.33), w * 0.3)
		draw_arc(c, w * 0.11, 0.0, TAU, 28, dark, w * 0.045, true)
		draw_arc(c, w * 0.11, 0.0, TAU, 28, gold, w * 0.025, true)
	# Bowl: a cup shape narrowing to the stem.
	var bowl := PackedVector2Array()
	var top := w * 0.1
	var bottom := w * 0.6
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(0.2, 0.8, t)
		var bulge := sin(t * PI)
		var y := top + (bottom - top) * (0.15 + 0.85 * bulge)
		bowl.append(o + Vector2(w * x, y if i != 0 and i != 16 else top))
	bowl.reverse()
	bowl.append(o + Vector2(w * 0.2, top))
	bowl.append(o + Vector2(w * 0.8, top))
	draw_colored_polygon(bowl, gold)
	draw_polyline(bowl + PackedVector2Array([bowl[0]]), dark, maxf(1.5, w * 0.015), true)
	# Rim and shine.
	draw_rect(Rect2(o + Vector2(w * 0.18, top - w * 0.025), Vector2(w * 0.64, w * 0.05)), light)
	draw_line(o + Vector2(w * 0.235, top + w * 0.06), o + Vector2(w * 0.255, top + w * 0.26), Color(light, 0.8), maxf(1.5, w * 0.02), true)
	# Stem and base.
	draw_rect(Rect2(o + Vector2(w * 0.45, bottom - w * 0.02), Vector2(w * 0.1, w * 0.16)), dark)
	draw_rect(Rect2(o + Vector2(w * 0.32, w * 0.74), Vector2(w * 0.36, w * 0.08)), gold)
	draw_rect(Rect2(o + Vector2(w * 0.26, w * 0.82), Vector2(w * 0.48, w * 0.1)), dark)
	draw_rect(Rect2(o + Vector2(w * 0.26, w * 0.82), Vector2(w * 0.48, w * 0.025)), gold)
	# Emblem on the bowl.
	var badge := Rect2(o + Vector2(w * 0.265, w * 0.14), Vector2(w * 0.47, w * 0.32))
	match emblem:
		"usa":
			var poly := usa_polygon(badge.grow(-w * 0.015))
			var fill := EMBLEM_BG if not locked else Color(0.25, 0.25, 0.3)
			draw_colored_polygon(poly, fill)
			draw_polyline(poly + PackedVector2Array([poly[0]]), light, maxf(1.0, w * 0.01), true)
		"south_america":
			var poly := south_america_polygon(badge.grow(-w * 0.015))
			var fill := EMBLEM_BG if not locked else Color(0.25, 0.25, 0.3)
			draw_colored_polygon(poly, fill)
			draw_polyline(poly + PackedVector2Array([poly[0]]), light, maxf(1.0, w * 0.01), true)
		"europe":
			var fill := EMBLEM_BG if not locked else Color(0.25, 0.25, 0.3)
			for poly in europe_polygons(badge.grow(-w * 0.015)):
				draw_colored_polygon(poly, fill)
				draw_polyline(poly + PackedVector2Array([poly[0]]), light, maxf(1.0, w * 0.008), true)
		"japan":
			# Rising sun: red rays around a red disc on white.
			var c := badge.get_center() + Vector2(0, badge.size.y * 0.08)
			var r := minf(badge.size.x, badge.size.y) * 0.5
			var white := Color(0.97, 0.96, 0.92) if not locked else Color(0.75, 0.75, 0.78)
			var red := SUN_RED if not locked else Color(0.4, 0.4, 0.45)
			draw_circle(c, r, white)
			var rays := 16
			for i in rays:
				if i % 2 == 1:
					continue
				var a0 := TAU * i / rays
				var a1 := TAU * (i + 1) / rays
				var ray := PackedVector2Array([c])
				for k in 5:
					var a := lerpf(a0, a1, k / 4.0)
					ray.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(ray, red)
			draw_circle(c, r * 0.38, red)
			draw_arc(c, r, 0.0, TAU, 32, light, maxf(1.0, w * 0.01), true)
		"globe":
			var c := badge.get_center()
			var r := minf(badge.size.x, badge.size.y) * 0.5
			draw_circle(c, r, EMBLEM_BG if not locked else Color(0.25, 0.25, 0.3))
			var line_w := maxf(1.0, w * 0.01)
			draw_arc(c, r, 0.0, TAU, 32, light, line_w, true)
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), light, line_w, true)
			for k in [0.45, 0.85]:
				var pts := PackedVector2Array()
				for i in 17:
					var a := -PI * 0.5 + PI * float(i) / 16.0
					pts.append(c + Vector2(cos(a) * r * k, sin(a) * r))
				draw_polyline(pts, light, line_w, true)
				var mirrored := PackedVector2Array()
				for p in pts:
					mirrored.append(Vector2(2.0 * c.x - p.x, p.y))
				draw_polyline(mirrored, light, line_w, true)
	if locked:
		var lc := o + Vector2(w * 0.5, w * 0.52)
		draw_arc(lc - Vector2(0, w * 0.06), w * 0.07, PI, TAU, 16, Color(0.9, 0.9, 0.95), w * 0.025, true)
		draw_rect(Rect2(lc - Vector2(w * 0.1, w * 0.06), Vector2(w * 0.2, w * 0.15)), Color(0.9, 0.9, 0.95))
