class_name SandstoneArchBuilder
extends RefCounted
## A natural rock window (Marble Canyon, after 'reference files/Marble
## Canyon 5.webp'): a thick fin of sandstone standing across the road with a
## tall, irregular opening the road drives through. Built in a frame whose
## origin is the road centre under the fin, x = right, y = up, z = along the
## road. The opening and the fin's outline are rounded superellipses with
## lumpy noise; the throat flares out towards both faces. The fin gets a
## trimesh collider (StaticBody3D "WindowCollider").
##
## Clearances (tests read them): the opening is at least `hole_half_width`
## wide either side of the centre up to `clear_height` above the road.

## Half width of the opening at road level (m).
var hole_half_width: float = 15.0
## Height of the top of the opening above the road (m).
var hole_top: float = 32.0
## How far the opening reaches below the road (hidden under it).
var hole_bottom: float = -12.0
## Half width and top of the fin's outline.
var outer_half_width: float = 32.0
var outer_top: float = 64.0
var outer_bottom: float = -16.0
## Thickness along the road (m).
var thickness: float = 18.0
## Squareness of the shapes (2 = ellipse, higher = boxier).
var hole_power: float = 2.8
var outer_power: float = 2.4
## Lumpiness (m) of the outline and the opening (the opening only bulges out).
var outer_noise: float = 6.0
var hole_noise: float = 2.2
var segments: int = 72
var slices: int = 6
var seed_value: int = 4

var _noise := FastNoiseLite.new()


## Point on the opening's outline at angle t (radians, 0 = right, PI/2 = top),
## before flaring.
func hole_point(t: float) -> Vector2:
	var c := Vector2(0.0, (hole_top + hole_bottom) * 0.5)
	var r := Vector2(hole_half_width, (hole_top - hole_bottom) * 0.5)
	var p := c + _superellipse(t, r, hole_power)
	# Bulge outwards only, so the clear opening is never smaller than asked.
	var n := maxf(0.0, _noise.get_noise_2d(cos(t) * 40.0, sin(t) * 40.0)) * hole_noise
	return p + (p - c).normalized() * n


func outer_point(t: float) -> Vector2:
	var c := Vector2(0.0, (outer_top + outer_bottom) * 0.5)
	var r := Vector2(outer_half_width, (outer_top - outer_bottom) * 0.5)
	var p := c + _superellipse(t, r, outer_power)
	var n := _noise.get_noise_2d(cos(t) * 60.0 + 300.0, sin(t) * 60.0) * outer_noise
	return p + (p - c).normalized() * n


## Builds the fin into the scenery's batches under `key` (track-local frame
## `xf`), plus its collider.
func build(scenery: TrackScenery, key: String, xf: Transform3D) -> void:
	_noise.seed = seed_value
	_noise.frequency = 0.02
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var rings_h: Array[PackedVector3Array] = []
	var rings_o: Array[PackedVector3Array] = []
	for s in slices + 1:
		var u := float(s) / float(slices) # 0..1 along the road
		var z := (u - 0.5) * thickness
		var e := absf(u - 0.5) * 2.0 # 0 in the middle, 1 at the faces
		var flare := 1.0 + 0.22 * e * e
		var shrink := 1.0 - 0.12 * e * e
		var rh := PackedVector3Array()
		var ro := PackedVector3Array()
		for i in segments:
			var t := TAU * float(i) / float(segments)
			var h := hole_point(t)
			var hc := Vector2(0.0, (hole_top + hole_bottom) * 0.5)
			h = hc + (h - hc) * flare
			var o := outer_point(t)
			var oc := Vector2(0.0, (outer_top + outer_bottom) * 0.5)
			o = oc + (o - oc) * shrink
			# Faces bulge and sag a little (not a sliced loaf).
			var wob := _noise.get_noise_2d(float(i) * 7.0, float(s) * 13.0) * 1.2
			rh.append(Vector3(h.x, h.y, z))
			ro.append(Vector3(o.x, o.y, z + wob * e))
		rings_h.append(rh)
		rings_o.append(ro)
	var mid := Vector3(0.0, (outer_top + hole_top) * 0.5, 0.0)
	for s in slices:
		for i in segments:
			var j := (i + 1) % segments
			# Throat (normals face into the opening, towards its axis).
			_quad(st, faces, xf, rings_h[s][i], rings_h[s][j], rings_h[s + 1][j], rings_h[s + 1][i],
					Vector3(0.0, (hole_top + hole_bottom) * 0.5, rings_h[s][i].z), true)
			# Outside of the fin.
			_quad(st, faces, xf, rings_o[s][i], rings_o[s][j], rings_o[s + 1][j], rings_o[s + 1][i],
					Vector3(0.0, (outer_top + outer_bottom) * 0.5, rings_o[s][i].z), false)
	# The two faces: rings between the opening and the outline.
	for s in [0, slices]:
		for i in segments:
			var j := (i + 1) % segments
			var inside := Vector3(0.0, mid.y, 0.0)
			_quad(st, faces, xf, rings_h[s][i], rings_h[s][j], rings_o[s][j], rings_o[s][i], inside, false)
	var mesh := st.commit()
	var mi := scenery.add_mesh_instance(mesh, scenery.get_material(key), "RockWindow")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var body := StaticBody3D.new()
	body.name = "WindowCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	scenery.add_node(body)


## Smallest clear half width of the opening between road level and `height`
## above it (before flaring, i.e. at the middle of the throat).
func clear_half_width(height: float, samples: int = 360) -> float:
	_noise.seed = seed_value
	_noise.frequency = 0.02
	var best := INF
	for i in samples:
		var p := hole_point(TAU * float(i) / float(samples))
		if p.y >= 0.0 and p.y <= height:
			best = minf(best, absf(p.x))
	return best


## Lowest point of the opening's top (above the road) within `half_width`
## of the centre.
func clear_height(half_width: float, samples: int = 360) -> float:
	_noise.seed = seed_value
	_noise.frequency = 0.02
	var best := INF
	for i in samples:
		var p := hole_point(TAU * float(i) / float(samples))
		if p.y > 0.0 and absf(p.x) <= half_width:
			best = minf(best, p.y) if p.y > (hole_top + hole_bottom) * 0.5 else best
	return best


static func _superellipse(t: float, r: Vector2, power: float) -> Vector2:
	var c := cos(t)
	var s := sin(t)
	return Vector2(r.x * signf(c) * pow(absf(c), 2.0 / power), r.y * signf(s) * pow(absf(s), 2.0 / power))


func _quad(st: SurfaceTool, faces: PackedVector3Array, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, ref: Vector3, toward: bool) -> void:
	_tri(st, faces, xf, a, b, c, ref, toward)
	_tri(st, faces, xf, a, c, d, ref, toward)


## Normals point away from `ref` (or towards it when `toward`).
func _tri(st: SurfaceTool, faces: PackedVector3Array, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3,
		ref: Vector3, toward: bool) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var away := n.dot((a + b + c) / 3.0 - ref) > 0.0
	if away == toward:
		n = -n
		var tmp := b
		b = c
		c = tmp
	var wn := (xf.basis * n).normalized()
	for v in [a, c, b]:
		st.set_normal(wn)
		st.add_vertex(xf * v)
		faces.append(xf * v)
