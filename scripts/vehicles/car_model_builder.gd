class_name CarModelBuilder
extends RefCounted
## Builds a stylised low-poly car body from a CarDesigns entry (GDD 5.1,
## Phase 6 vehicle models). The body and cabin are lofted through
## cross-section stations along the car (front = -Z); detail parts (grilles,
## light bars, wings, fins, pods) are boxes, wedges and cylinders.
##
## Output, under the car's Body node:
##   Model/Paint, Glass, Trim, Chrome, Lights, Tail   (one mesh per material)
##   Model/NeonL, NeonR                               (underglow strips)
##   Model/PlateAnchor, DecalL, DecalR, ExhaustL, ExhaustR  (Marker3D)
## Meshes are cached per design, so eight cars on the grid share geometry.
##
## Coordinates match the shared car scene: wheels at x ±0.85, z ±1.35,
## radius 0.38; the body sits roughly between y -0.25 and +0.3 (cabin above).

const PARTS: Array[String] = ["Paint", "Glass", "Trim", "Chrome", "Lights", "Tail"]
## The whole model sits this much lower than the design numbers...
const Y_SHIFT := -0.05
## ...and the sills reach this much further down, so the cars sit low over
## the wheels instead of riding like trucks.
const SILL_DROP := -0.12

static var _cache: Dictionary = {}


## Replaces the placeholder body parts with the designed model.
static func build(car: Node3D, design_id: String) -> Node3D:
	var body := car.get_node_or_null("Body") as Node3D
	if body == null:
		return null
	var design := CarDesigns.get_design(design_id)
	if design.is_empty():
		return null
	remove_model(car)
	hide_placeholder(car)
	body.scale = Vector3.ONE
	var data := _get_cached(design_id, design)
	var model := Node3D.new()
	model.name = "Model"
	model.set_meta("design", design_id)
	model.position.y = Y_SHIFT
	body.add_child(model)
	var accent: Color = design.get("accent", Color.WHITE)
	for part in PARTS:
		var mesh: ArrayMesh = data.meshes.get(part)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = mesh
		mi.material_override = material_for(part, accent, design.get("paint", Color(0.2, 0.2, 0.25)))
		model.add_child(mi)
	for side in [-1.0, 1.0]:
		var neon := MeshInstance3D.new()
		neon.name = "NeonL" if side < 0.0 else "NeonR"
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, data.neon_length)
		neon.mesh = box
		neon.position = Vector3(side * data.neon_x, data.neon_y, data.neon_z)
		neon.material_override = material_for("Lights", accent, Color.WHITE)
		model.add_child(neon)
	for anchor_name in data.anchors:
		var marker := Marker3D.new()
		marker.name = anchor_name
		marker.transform = data.anchors[anchor_name]
		model.add_child(marker)
	return model


static func remove_model(car: Node3D) -> void:
	var old := car.get_node_or_null("Body/Model")
	if old != null:
		old.free()


## Hides the Phase 1 box car (kept in the scene as a fallback).
static func hide_placeholder(car: Node3D) -> void:
	for part in ["Chassis", "Nose", "Cabin", "Spoiler", "StrutL", "StrutR", "NeonL", "NeonR",
			"HeadlightL", "HeadlightR", "Taillights"]:
		var node := car.get_node_or_null("Body/" + part) as Node3D
		if node != null:
			node.visible = false


static func show_placeholder(car: Node3D) -> void:
	for part in ["Chassis", "Nose", "Cabin", "Spoiler", "StrutL", "StrutR", "NeonL", "NeonR",
			"HeadlightL", "HeadlightR", "Taillights"]:
		var node := car.get_node_or_null("Body/" + part) as Node3D
		if node != null:
			node.visible = true


static func material_for(part: String, accent: Color, paint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match part:
		"Paint":
			mat.albedo_color = paint
			mat.metallic = 0.55
			mat.roughness = 0.3
		"Glass":
			mat.albedo_color = Color(0.03, 0.05, 0.09)
			mat.metallic = 0.6
			mat.roughness = 0.05
		"Trim":
			mat.albedo_color = Color(0.03, 0.03, 0.04)
			mat.roughness = 0.6
		"Chrome":
			mat.albedo_color = Color(0.86, 0.88, 0.92)
			mat.metallic = 0.7
			mat.roughness = 0.18
		"Lights":
			mat.albedo_color = accent
			mat.emission_enabled = true
			mat.emission = accent
			mat.emission_energy_multiplier = 3.5
		"Tail":
			mat.albedo_color = Color(1.0, 0.05, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.05, 0.15)
			mat.emission_energy_multiplier = 3.5
	return mat


# --- stripes (used by VehicleCosmetics) ---------------------------------------

## Racing stripes following the top of the body and cabin at lateral lanes.
static func stripe_mesh(design_id: String, lanes: Array[float], width: float) -> ArrayMesh:
	var design := CarDesigns.get_design(design_id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations: Array = design.body
	var z0: float = stations[0][0]
	var z1: float = stations[stations.size() - 1][0]
	var steps := 40
	for lane in lanes:
		var prev := Vector3.ZERO
		var prev_ok := false
		for i in steps + 1:
			var z := lerpf(z0 + 0.05, z1 - 0.05, float(i) / steps)
			var y := top_height(design, z, lane)
			var ok := not is_nan(y)
			var p := Vector3(lane, y + 0.012, z)
			if ok and prev_ok:
				var hw := width * 0.5
				_quad(st, prev + Vector3(-hw, 0, 0), prev + Vector3(hw, 0, 0),
						p + Vector3(hw, 0, 0), p + Vector3(-hw, 0, 0), Vector3(lane, -1.0, z))
			prev = p
			prev_ok = ok
	return st.commit()


## Side flash stripe along both flanks at mid-height.
static func side_stripe_mesh(design_id: String) -> ArrayMesh:
	var design := CarDesigns.get_design(design_id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations: Array = design.body
	for side in [-1.0, 1.0]:
		for i in stations.size() - 1:
			var a: Array = stations[i]
			var b: Array = stations[i + 1]
			var ya := lerpf(a[2], a[3], 0.55)
			var yb := lerpf(b[2], b[3], 0.55)
			var xa: float = side * (a[1] + 0.006)
			var xb: float = side * (b[1] + 0.006)
			_quad(st, Vector3(xa, ya - 0.04, a[0]), Vector3(xb, yb - 0.04, b[0]),
					Vector3(xb, yb + 0.04, b[0]), Vector3(xa, ya + 0.04, a[0]), Vector3(0.0, (ya + yb) * 0.5, (a[0] + b[0]) * 0.5))
	return st.commit()


## Height of the top surface at (z, x): cabin roof where there is one, else
## the body's flat top. NAN where the lane falls off the top surface.
static func top_height(design: Dictionary, z: float, x: float) -> float:
	var s := _station_at(design.body, z)
	if s.is_empty():
		return NAN
	var top_half: float = s[1] * s[4]
	var y := NAN
	if absf(x) <= top_half:
		y = s[3]
	var cabin: Array = design.get("cabin", [])
	if cabin.size() >= 2 and z >= cabin[0][0] and z <= cabin[cabin.size() - 1][0]:
		var c := _station_at(cabin, z)
		if not c.is_empty() and absf(x) <= c[1]:
			y = c[2] if is_nan(y) else maxf(y, c[2])
	return y


static func _station_at(stations: Array, z: float) -> Array:
	for i in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		if z >= a[0] and z <= b[0]:
			var t: float = (z - a[0]) / maxf(b[0] - a[0], 0.0001)
			var out: Array = []
			for k in a.size():
				out.append(lerpf(a[k], b[k], t) if k > 0 else z)
			return out
	return []


# --- building -----------------------------------------------------------------

static func _get_cached(id: String, design: Dictionary) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var tools := {}
	for part in PARTS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[part] = st
	var stations: Array = design.body
	_loft_body(tools, stations)
	if design.has("cabin"):
		_loft_cabin(tools, design.cabin, stations, design.get("open_cabin", false))
	for part_spec in design.get("parts", []):
		_add_part(tools, part_spec)
	var meshes := {}
	for part in PARTS:
		var mesh := (tools[part] as SurfaceTool).commit()
		if mesh.get_surface_count() > 0:
			meshes[part] = mesh
	var first: Array = stations[0]
	var last: Array = stations[stations.size() - 1]
	var anchors := {}
	var rear_y: float = lerpf(last[2], last[3], 0.3)
	anchors["PlateAnchor"] = design.get("plate_anchor",
			Transform3D(Basis.IDENTITY, Vector3(0.0, rear_y, last[0] + 0.012)))
	# Door decals: mid-flank ahead of the rear wheel unless the design says otherwise.
	var decal_z := -0.35
	var door := _station_at(stations, decal_z)
	var decal: Vector3 = design.get("decal", Vector3(door[1] + 0.012, lerpf(door[2] + SILL_DROP, door[3], 0.55), decal_z))
	anchors["DecalL"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-decal.x, decal.y, decal.z))
	anchors["DecalR"] = Transform3D(Basis(Vector3.UP, PI * 0.5), decal)
	var ex: float = last[1] * 0.5
	anchors["ExhaustL"] = Transform3D(Basis.IDENTITY, Vector3(-ex, last[2] + 0.07, last[0] + 0.02))
	anchors["ExhaustR"] = Transform3D(Basis.IDENTITY, Vector3(ex, last[2] + 0.07, last[0] + 0.02))
	var min_w := INF
	for s in stations:
		if s[0] > -1.2 and s[0] < 1.2:
			min_w = minf(min_w, s[1])
	var data := {
		"meshes": meshes,
		"anchors": anchors,
		"neon_x": min_w * 0.82,
		"neon_y": -0.22 + SILL_DROP,
		"neon_z": (first[0] + last[0]) * 0.5,
		"neon_length": (last[0] - first[0]) * 0.6,
	}
	_cache[id] = data
	return data


## Cross-section ring (8 points, bottom-left going round) for a body station
## [z, half_width, bottom_y, top_y, top_fraction].
static func _ring(s: Array) -> Array[Vector3]:
	var z: float = s[0]
	var w: float = s[1]
	var yb: float = s[2] + SILL_DROP
	var yt: float = s[3]
	var tf: float = s[4]
	var h := yt - yb
	var pts: Array[Vector3] = [
		Vector3(-w * 0.86, yb, z),
		Vector3(-w, yb + h * 0.32, z),
		Vector3(-w * 0.97, yb + h * 0.78, z),
		Vector3(-w * tf, yt, z),
		Vector3(w * tf, yt, z),
		Vector3(w * 0.97, yb + h * 0.78, z),
		Vector3(w, yb + h * 0.32, z),
		Vector3(w * 0.86, yb, z),
	]
	return pts


static func _loft_body(tools: Dictionary, stations: Array) -> void:
	var paint: SurfaceTool = tools.Paint
	var trim: SurfaceTool = tools.Trim
	for i in stations.size() - 1:
		var a := _ring(stations[i])
		var b := _ring(stations[i + 1])
		var center := Vector3(0.0, (stations[i][2] + stations[i][3]) * 0.5, (stations[i][0] + stations[i + 1][0]) * 0.5)
		for k in 8:
			var k2 := (k + 1) % 8
			# Edge 7 -> 0 is the underside; the lowest side band is dark trim.
			var st := trim if k == 7 or k == 0 or k == 6 else paint
			_quad(st, a[k], a[k2], b[k2], b[k], center)
	# End caps.
	for end in [0, stations.size() - 1]:
		var ring := _ring(stations[end])
		var c := Vector3(0.0, (stations[end][2] + stations[end][3]) * 0.5, stations[end][0])
		var inside := c + Vector3(0.0, 0.0, 1.0 if end == 0 else -1.0)
		for k in 8:
			_tri(paint, c, ring[k], ring[(k + 1) % 8], inside)


## Cabin stations: [z, roof_half_width, roof_y]. The base follows the body top.
static func _loft_cabin(tools: Dictionary, cabin: Array, body: Array, open: bool) -> void:
	var glass: SurfaceTool = tools.Glass
	var paint: SurfaceTool = tools.Paint
	var rings: Array = []
	for c in cabin:
		var s := _station_at(body, c[0])
		var base_y: float = s[3] - 0.01
		var base_w: float = s[1] * s[4] * 0.96
		rings.append([
			Vector3(-base_w, base_y, c[0]), Vector3(-c[1], c[2], c[0]),
			Vector3(c[1], c[2], c[0]), Vector3(base_w, base_y, c[0]),
		])
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var center := Vector3(0.0, (a[0].y + a[1].y) * 0.5 - 0.2, (a[0].z + b[0].z) * 0.5)
		# Sides are windows (open cabins skip them).
		if not open:
			_quad(glass, a[0], a[1], b[1], b[0], center)
			_quad(glass, a[2], a[3], b[3], b[2], center)
		# Top: steep segments are wind screens, flat ones are roof.
		var rise := absf(b[1].y - a[1].y) / maxf(absf(b[1].z - a[1].z), 0.001)
		if open:
			if i == 0:
				_quad(glass, a[1], a[2], b[2], b[1], center)
			continue
		_quad(glass if rise > 0.45 else paint, a[1], a[2], b[2], b[1], center)


static func _add_part(tools: Dictionary, spec: Array) -> void:
	# [kind, material, size/params, position, rotation_degrees]
	var kind: String = spec[0]
	var st: SurfaceTool = tools[spec[1]]
	var pos: Vector3 = spec[3]
	var rot: Vector3 = spec[4] if spec.size() > 4 else Vector3.ZERO
	var basis := Basis.from_euler(rot * PI / 180.0)
	var xf := Transform3D(basis, pos)
	match kind:
		"box":
			_box(st, spec[2], xf)
		"wedge":
			_wedge(st, spec[2], xf)
		"cyl":
			var p: Vector3 = spec[2] # radius, length, segments
			_cylinder(st, p.x, p.y, int(p.z), xf)
		"mirror_box":
			_box(st, spec[2], xf)
			_box(st, spec[2], _mirror(xf))
		"mirror_wedge":
			_wedge(st, spec[2], xf)
			_wedge(st, spec[2], _mirror(xf))
		"mirror_cyl":
			var p2: Vector3 = spec[2]
			_cylinder(st, p2.x, p2.y, int(p2.z), xf)
			_cylinder(st, p2.x, p2.y, int(p2.z), _mirror(xf))


static func _mirror(xf: Transform3D) -> Transform3D:
	var m := Basis.from_scale(Vector3(-1, 1, 1))
	return Transform3D(m * xf.basis * m, Vector3(-xf.origin.x, xf.origin.y, xf.origin.z))


# --- primitives -----------------------------------------------------------------

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
		var t := b
		b = c
		c = t
	# Godot's front faces wind clockwise when seen from outside.
	for v in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_tri(st, a, b, c, inside)
	_tri(st, a, c, d, inside)


static func _box(st: SurfaceTool, size: Vector3, xf: Transform3D) -> void:
	var h := size * 0.5
	var c := xf.origin
	var p := []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], c)


## A box whose top slopes down toward -Z (size.y at the back, 0 at the front).
static func _wedge(st: SurfaceTool, size: Vector3, xf: Transform3D) -> void:
	var h := size * 0.5
	var c := xf * Vector3(0, -h.y * 0.4, h.z * 0.2)
	var b0 := xf * Vector3(-h.x, -h.y, -h.z)
	var b1 := xf * Vector3(h.x, -h.y, -h.z)
	var b2 := xf * Vector3(h.x, -h.y, h.z)
	var b3 := xf * Vector3(-h.x, -h.y, h.z)
	var t2 := xf * Vector3(h.x, h.y, h.z)
	var t3 := xf * Vector3(-h.x, h.y, h.z)
	_quad(st, b0, b1, b2, b3, c)
	_quad(st, b0, b1, t2, t3, c)
	_quad(st, b3, b2, t2, t3, c)
	_tri(st, b0, b3, t3, c)
	_tri(st, b1, b2, t2, c)


## Cylinder along local Z.
static func _cylinder(st: SurfaceTool, radius: float, length: float, segments: int, xf: Transform3D) -> void:
	var c := xf.origin
	var h := length * 0.5
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0)
		var f0 := xf * (p0 + Vector3(0, 0, -h))
		var f1 := xf * (p1 + Vector3(0, 0, -h))
		var r0 := xf * (p0 + Vector3(0, 0, h))
		var r1 := xf * (p1 + Vector3(0, 0, h))
		_quad(st, f0, f1, r1, r0, c)
		_tri(st, xf * Vector3(0, 0, -h), f0, f1, c + xf.basis.z * h)
		_tri(st, xf * Vector3(0, 0, h), r0, r1, c - xf.basis.z * h)
