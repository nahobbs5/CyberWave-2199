class_name PointedArch
extends RefCounted
## Swahili / Persian stonework shapes for a TrackScenery (Kilwa Kisiwani):
## two-centred pointed arches (an arcade wall with its spandrels, a niche),
## domes on an octagonal drum, and the stepped Omani merlons that crown
## the fort and mosque walls. Static helpers; geometry goes into the
## scenery's batches. Visual only.

## Intrado of a two-centred pointed arch: points from the left springer
## (-span/2, 0) up to the crown (0, rise) and down to (span/2, 0). rise must
## be at least span / 2 (equal = a round arch).
static func profile(span: float, rise: float, segments: int = 8) -> PackedVector2Array:
	var half := span * 0.5
	rise = maxf(rise, half)
	# Left arc: centre (c, 0) right of the axis, through (-half, 0) and (0, rise).
	var c := (rise * rise - half * half) / span
	var r := c + half
	var a_crown := atan2(rise, -c)
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(PI, a_crown, float(i) / segments)
		pts.append(Vector2(c + r * cos(a), r * sin(a)))
	for i in range(segments - 1, -1, -1):
		pts.append(Vector2(-pts[i].x, pts[i].y))
	return pts


## An arched opening in a wall: the spandrels between the arch and a flat
## top, `depth` thick. xf: ground centre of the opening, local X across it,
## Z through the wall. band_key (optional) adds a dressed-stone arch ring
## standing a little proud of both faces.
static func arch_wall(sc: TrackScenery, key: String, xf: Transform3D, span: float, spring: float, rise: float,
		top: float, depth: float, band_key: String = "", band: float = 0.45) -> void:
	var pts := profile(span, rise, 6)
	for i in pts.size() - 1:
		var a := pts[i] + Vector2(0, spring)
		var b := pts[i + 1] + Vector2(0, spring)
		if minf(a.y, b.y) >= top:
			continue
		var quad := PackedVector2Array([a, b, Vector2(b.x, top), Vector2(a.x, top)])
		sc.add_prism(key, quad, depth, xf)
	if band_key == "":
		return
	var n := pts.size()
	for i in n - 1:
		var a := pts[i] + Vector2(0, spring)
		var b := pts[i + 1] + Vector2(0, spring)
		var na := _outward(pts, i)
		var nb := _outward(pts, i + 1)
		var ring := PackedVector2Array([a, b, b + nb * band, a + na * band])
		sc.add_prism(band_key, ring, depth + 0.16, xf)


## A shallow pointed niche on a wall face: a dark recess panel with a
## dressed frame. xf: bottom centre on the wall face, local Z out of it.
static func niche(sc: TrackScenery, shade_key: String, frame_key: String, xf: Transform3D, width: float,
		height: float) -> void:
	var rise := width * 0.62
	var spring := maxf(0.2, height - rise)
	var poly := PackedVector2Array([Vector2(-width * 0.5, 0)])
	for p in profile(width, rise, 5):
		poly.append(p + Vector2(0, spring))
	poly.append(Vector2(width * 0.5, 0))
	sc.add_prism(shade_key, poly, 0.06, xf.translated_local(Vector3(0, 0, 0.03)))
	if frame_key != "":
		var pts := profile(width, rise, 5)
		for i in pts.size() - 1:
			var a := pts[i] + Vector2(0, spring)
			var b := pts[i + 1] + Vector2(0, spring)
			var ring := PackedVector2Array([a, b, b + _outward(pts, i + 1) * 0.22, a + _outward(pts, i) * 0.22])
			sc.add_prism(frame_key, ring, 0.14, xf.translated_local(Vector3(0, 0, 0.07)))
		for side in [-1.0, 1.0]:
			sc.add_box(frame_key, Vector3(0.22, spring, 0.14),
					xf.translated_local(Vector3(side * (width * 0.5 + 0.11), spring * 0.5, 0.07)))


static func _outward(pts: PackedVector2Array, i: int) -> Vector2:
	var prev := pts[maxi(i - 1, 0)]
	var next := pts[mini(i + 1, pts.size() - 1)]
	var t := (next - prev).normalized()
	var n := Vector2(-t.y, t.x)
	# Outward = away from the opening (up, or sideways at the springers).
	var mid := Vector2(0, pts[pts.size() / 2].y * 0.4)
	if n.dot(pts[i] - mid) < 0.0:
		n = -n
	return n


## A dome on an octagonal ring at `base` (its springing line), pointed a
## little at the top like the Kilwa domes. open_top > 0 leaves a ragged
## hole of that radius (a collapsed dome); the inside is visible too.
static func dome(sc: TrackScenery, key: String, base: Vector3, radius: float, height: float,
		open_top: float = 0.0, segments: int = 12, rings: int = 5) -> void:
	var rng := sc.rng
	var top_ring := rings
	if open_top > 0.0:
		# Stop where the shell's radius drops to the hole's.
		top_ring = rings
		for r in rings + 1:
			if radius * cos(PI * 0.5 * float(r) / rings) < open_top:
				top_ring = maxi(1, r)
				break
	var ring_pts: Array = []
	for r in top_ring + 1:
		var a := PI * 0.5 * float(r) / rings
		var row := []
		for s in segments:
			var yaw := TAU * float(s) / segments
			var rr := radius * cos(a)
			var y := height * sin(a)
			if open_top > 0.0 and r == top_ring:
				rr = maxf(rr, open_top) + rng.randf_range(-0.3, 0.6)
				y -= rng.randf_range(0.0, 0.8)
			row.append(base + Vector3(cos(yaw) * rr, y, sin(yaw) * rr))
		ring_pts.append(row)
	var inside := base + Vector3(0, height * 0.35, 0)
	for r in top_ring:
		for s in segments:
			var s1 := (s + 1) % segments
			sc.add_quad(key, ring_pts[r][s], ring_pts[r][s1], ring_pts[r + 1][s1], ring_pts[r + 1][s], inside)
	if open_top <= 0.0:
		# Closing cap with a small finial.
		var apex := base + Vector3(0, height * 1.08, 0)
		var row: Array = ring_pts[top_ring]
		for s in segments:
			sc.add_quad(key, row[s], row[(s + 1) % segments], apex, apex, inside)


## Stepped Omani merlons along a wall top from a to b (same height y = a.y):
## a wide lower block and a narrow upper one, every `pitch` metres.
static func crenellate(sc: TrackScenery, key: String, a: Vector3, b: Vector3, thickness: float,
		merlon_h: float = 1.1, pitch: float = 1.9) -> int:
	var dir := b - a
	var length := dir.length()
	if length < pitch:
		return 0
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var count := int(length / pitch)
	var start := (length - (count - 1) * pitch) * 0.5
	for i in count:
		var p := a + dir.normalized() * (start + pitch * i)
		var w := pitch * 0.55
		sc.add_box(key, Vector3(thickness, merlon_h * 0.6, w), Transform3D(basis, p + Vector3(0, merlon_h * 0.3, 0)))
		sc.add_box(key, Vector3(thickness, merlon_h * 0.4, w * 0.5),
				Transform3D(basis, p + Vector3(0, merlon_h * 0.8, 0)))
	return count
