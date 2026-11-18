class_name CarModelBuilder
extends RefCounted
## Builds a stylised car body from a CarDesigns entry (GDD 5.1, Phase 6
## vehicle models). The body and cabin are lofted through cross-section
## stations along the car (front = -Z), resampled with Catmull-Rom so the
## length curves; each body section is a rounded 24-point ring with smooth
## normals. Wheel arches, door shut lines and mirrors are added for every
## design; detail parts (grilles, light bars, wings, fins, pods) are boxes,
## wedges and cylinders with hard edges. Wheels come from WheelBuilder.
##
## Output, under the car's Body node:
##   Model/Paint, Glass, Trim, Chrome, Lights, Tail   (one mesh per material)
##   Model/TwoTone   second body colour (design "paint2"); not named Paint*,
##                   so paint cosmetics leave it alone
##   Model/NeonL, NeonR                               (underglow strips)
##   Model/PlateAnchor, DecalL, DecalR, ExhaustL, ExhaustR  (Marker3D)
## Meshes are cached per design, so eight cars on the grid share geometry.
##
## Coordinates match the shared car scene: wheels at x ±0.85, z ±1.35,
## radius 0.38; the body sits roughly between y -0.25 and +0.3 (cabin above).

const PARTS: Array[String] = ["Paint", "Glass", "Trim", "Chrome", "Lights", "Tail", "TwoTone"]
## The whole model sits this much lower than the design numbers...
const Y_SHIFT := -0.05
## ...and the sills reach this much further down, so the cars sit low over
## the wheels instead of riding like trucks.
const SILL_DROP := -0.12
## Catmull-Rom sub-steps between design stations (body and closed cabins).
const BODY_STEPS := 4
const CABIN_STEPS := 3
## Corner rounding of the body section, in metres along each edge.
const CORNER_R := 0.1
## Drawn wheel centre in model space (the showroom/race rest pose).
const WHEEL_Y := -0.29
const WHEEL_Z := 1.35
const ARCH_R := 0.44
const ARCH_LIP := 0.065
## How far the arch lip stands out from the flank.
const ARCH_OUT := 0.045
## Bodies narrower than this at the axles are open-wheelers (no arches).
const OPEN_WHEEL_FLANK := 0.75

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
		var paint: Color = design.get("paint", Color(0.2, 0.2, 0.25))
		mi.material_override = material_for(part, accent, design.get("paint2", paint) if part == "TwoTone" else paint)
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
	WheelBuilder.dress(car, data.wheel_offsets)
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
	WheelBuilder.undress(car)
	for part in ["Chassis", "Nose", "Cabin", "Spoiler", "StrutL", "StrutR", "NeonL", "NeonR",
			"HeadlightL", "HeadlightR", "Taillights"]:
		var node := car.get_node_or_null("Body/" + part) as Node3D
		if node != null:
			node.visible = true


static func material_for(part: String, accent: Color, paint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match part:
		"Paint", "TwoTone":
			mat.albedo_color = paint
			mat.metallic = 0.55
			mat.roughness = 0.3
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
			mat.clearcoat_roughness = 0.1
		"Glass":
			mat.albedo_color = Color(0.025, 0.04, 0.075)
			mat.metallic = 0.9
			mat.roughness = 0.03
			mat.metallic_specular = 0.8
		"Trim":
			mat.albedo_color = Color(1, 1, 1)
			mat.albedo_texture = carbon_texture()
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE * 7.0
			mat.metallic = 0.2
			mat.roughness = 0.45
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


static var _carbon: ImageTexture

## Small twill-weave texture for trim (carbon fibre look), built once.
static func carbon_texture() -> ImageTexture:
	if _carbon != null:
		return _carbon
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# 2x2 twill: tows run diagonally, alternating direction per cell.
			var cell := (x / 4 + y / 4) % 2
			var along := float((x if cell == 0 else y) % 4) / 3.0
			var v := 0.035 + 0.035 * sin(along * PI)
			if cell == 1:
				v *= 0.75
			img.set_pixel(x, y, Color(v, v, v * 1.1))
	img.generate_mipmaps()
	_carbon = ImageTexture.create_from_image(img)
	return _carbon


# --- stripes (used by VehicleCosmetics) ---------------------------------------

## Racing stripes following the top of the body and cabin at lateral lanes.
static func stripe_mesh(design_id: String, lanes: Array[float], width: float) -> ArrayMesh:
	var design := CarDesigns.get_design(design_id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations: Array = smooth_body(design)
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
	var stations: Array = smooth_body(design)
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
	var s := _station_at(smooth_body(design), z)
	if s.is_empty():
		return NAN
	var top_half: float = s[1] * s[4]
	var y := NAN
	if absf(x) <= top_half:
		y = s[3]
	var cabin: Array = smooth_cabin(design)
	if cabin.size() >= 2 and z >= cabin[0][0] and z <= cabin[cabin.size() - 1][0]:
		var c := _station_at(cabin, z)
		if not c.is_empty() and absf(x) <= c[1]:
			y = c[2] if is_nan(y) else maxf(y, c[2])
	return y


## Body stations resampled along the car (what the mesh is lofted through).
static func smooth_body(design: Dictionary) -> Array:
	return _smooth(design.body, BODY_STEPS)


static func smooth_cabin(design: Dictionary) -> Array:
	var cabin: Array = design.get("cabin", [])
	if cabin.size() < 3 or design.get("open_cabin", false):
		return cabin
	return _smooth(cabin, CABIN_STEPS)


## Catmull-Rom resample of station rows: z stays linear (so it can't fold
## back), every other field curves through the design values.
static func _smooth(stations: Array, steps: int) -> Array:
	var n := stations.size()
	if n < 3:
		return stations
	var out: Array = []
	for i in n - 1:
		var p0: Array = stations[maxi(i - 1, 0)]
		var p1: Array = stations[i]
		var p2: Array = stations[i + 1]
		var p3: Array = stations[mini(i + 2, n - 1)]
		for k in steps:
			var t := float(k) / steps
			var row: Array = [lerpf(p1[0], p2[0], t)]
			for f in range(1, p1.size()):
				row.append(_catmull(p0[f], p1[f], p2[f], p3[f], t))
			out.append(row)
	out.append((stations[n - 1] as Array).duplicate())
	return out


static func _catmull(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2 := t * t
	return 0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
			+ (3.0 * b - a - 3.0 * c + d) * t2 * t)


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
	var stations: Array = smooth_body(design)
	_loft_body(tools, stations)
	if design.has("cabin"):
		_loft_cabin(tools, smooth_cabin(design), stations, design.get("open_cabin", false))
	var wheel_offsets := _add_details(tools, design, stations)
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
		"wheel_offsets": wheel_offsets,
	}
	_cache[id] = data
	return data


## Control polygon (8 points, bottom-left going round) for a body station
## [z, half_width, bottom_y, top_y, top_fraction].
static func _ring8(s: Array) -> Array[Vector3]:
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


## Rounded section: every control corner becomes three points (in, apex
## blend, out), so 24 points, same order as _ring8.
static func _ring(s: Array) -> Array[Vector3]:
	var c := _ring8(s)
	var out: Array[Vector3] = []
	for i in 8:
		var v := c[i]
		var prev := c[(i + 7) % 8]
		var next := c[(i + 1) % 8]
		var a := v + (prev - v).normalized() * minf(CORNER_R, 0.45 * v.distance_to(prev))
		var b := v + (next - v).normalized() * minf(CORNER_R, 0.45 * v.distance_to(next))
		out.append(a)
		out.append(a * 0.25 + v * 0.5 + b * 0.25)
		out.append(b)
	return out


static func _loft_body(tools: Dictionary, stations: Array) -> void:
	var paint: SurfaceTool = tools.Paint
	var trim: SurfaceTool = tools.Trim
	var rings: Array = []
	var centers: Array[Vector3] = []
	for s in stations:
		rings.append(_ring(s))
		centers.append(Vector3(0.0, (s[2] + SILL_DROP + s[3]) * 0.5, s[0]))
	var count := rings.size()
	var m: int = (rings[0] as Array).size()
	# Smooth vertex normals from the grid (ring tangent x length tangent).
	var normals: Array = []
	for i in count:
		var ring: Array = rings[i]
		var before: Array = rings[maxi(i - 1, 0)]
		var after: Array = rings[mini(i + 1, count - 1)]
		var ns: Array[Vector3] = []
		for k in m:
			var t_ring: Vector3 = ring[(k + 1) % m] - ring[(k + m - 1) % m]
			var t_len: Vector3 = after[k] - before[k]
			var n := t_ring.cross(t_len).normalized()
			if n.dot(ring[k] - centers[i]) < 0.0:
				n = -n
			ns.append(n)
		normals.append(ns)
	for i in count - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var na: Array = normals[i]
		var nb: Array = normals[i + 1]
		var s: Array = stations[i]
		var yb: float = s[2] + SILL_DROP
		var trim_top: float = yb + (s[3] - yb) * 0.3
		var center := (centers[i] + centers[i + 1]) * 0.5
		for k in m:
			var k2 := (k + 1) % m
			# The underside and the lowest side band are dark trim.
			var st := trim if (a[k].y + a[k2].y) * 0.5 < trim_top else paint
			_tri_n(st, a[k], a[k2], b[k2], na[k], na[k2], nb[k2], center)
			_tri_n(st, a[k], b[k2], b[k], na[k], nb[k2], nb[k], center)
	# End caps (hard edge).
	for end in [0, count - 1]:
		var ring: Array = rings[end]
		var c: Vector3 = centers[end]
		var inside := c + Vector3(0.0, 0.0, 1.0 if end == 0 else -1.0)
		for k in m:
			_tri(paint, c, ring[k], ring[(k + 1) % m], inside)


## Cabin stations: [z, roof_half_width, roof_y]. The base follows the body top.
static func _loft_cabin(tools: Dictionary, cabin: Array, body: Array, open: bool) -> void:
	var glass: SurfaceTool = tools.Glass
	var paint: SurfaceTool = tools.Paint
	var rings: Array = []
	for c in cabin:
		var s := _station_at(body, c[0])
		# Base sunk into the body so the rounded shoulder never shows a gap.
		var base_y: float = s[3] - 0.05
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


## Generated on every design: wheel arches, door shut lines, mirrors.
## Returns the outward wheel shift per axle so tyres sit flush with the arches.
static func _add_details(tools: Dictionary, design: Dictionary, stations: Array) -> Dictionary:
	var offsets := {}
	for zc in [-WHEEL_Z, WHEEL_Z]:
		var flank := 0.0
		for dz in [-0.35, 0.0, 0.35]:
			var s := _station_at(stations, zc + dz)
			if not s.is_empty():
				flank = maxf(flank, s[1])
		if flank < OPEN_WHEEL_FLANK:
			# Open-wheel body (the wheels stand clear of it): no arches.
			offsets["front" if zc < 0.0 else "rear"] = 0.0
			continue
		# Tyre face (wheel x 0.85 + half width 0.16) just inside the lip.
		offsets["front" if zc < 0.0 else "rear"] = clampf(flank + ARCH_OUT * 0.5 - 1.01, 0.0, 0.12)
		for side in [-1.0, 1.0]:
			_arch(tools, stations, zc, side)
	var cabin: Array = design.get("cabin", [])
	if cabin.size() >= 2:
		var c0: float = cabin[0][0]
		var c1: float = cabin[cabin.size() - 1][0]
		var doors: Array[float] = [maxf(c0 + 0.2, -WHEEL_Z + ARCH_R + ARCH_LIP + 0.08), lerpf(c0, c1, 0.5)]
		for dz in doors:
			var ds := _station_at(stations, dz)
			if not ds.is_empty() and ds[1] < OPEN_WHEEL_FLANK:
				continue
			if dz < WHEEL_Z - ARCH_R - ARCH_LIP - 0.08:
				for side in [-1.0, 1.0]:
					_shut_line(tools.Trim, stations, dz, side)
		if not design.get("open_cabin", false):
			_mirrors(tools, design, stations)
	return offsets


## Flank x of a station at height y (on the straight side band).
static func _flank_x(s: Array, y: float) -> float:
	var yb: float = s[2] + SILL_DROP
	var h: float = s[3] - yb
	var t := clampf((y - (yb + h * 0.32)) / (h * 0.46), 0.0, 1.0)
	return s[1] * lerpf(1.0, 0.97, t)


## Wheel arch on one flank: a dark well disc behind the wheel and a raised
## paint lip round it, flattened under the shoulder on low bodies.
static func _arch(tools: Dictionary, stations: Array, zc: float, side: float) -> void:
	var paint: SurfaceTool = tools.Paint
	var trim: SurfaceTool = tools.Trim
	var segs := 14
	var r_in := ARCH_R
	var r_out := ARCH_R + ARCH_LIP
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	var prev_base_in := Vector3.ZERO
	var prev_base_out := Vector3.ZERO
	var centre := Vector3.ZERO
	for i in segs + 1:
		var a := deg_to_rad(lerpf(-14.0, 194.0, float(i) / segs))
		var z_in := zc + cos(a) * r_in
		var z_out := zc + cos(a) * r_out
		var s_in := _station_at(stations, z_in)
		var s_out := _station_at(stations, z_out)
		if s_in.is_empty() or s_out.is_empty():
			prev_in = Vector3.INF
			continue
		# Arches stay under the flank's crease, but always clear the tyre
		# (low noses get a flare that bulges above the hood).
		var cap_out := maxf(_shoulder_y(s_out), WHEEL_Y + WheelBuilder.RADIUS + ARCH_LIP + 0.02)
		var y_out := minf(WHEEL_Y + sin(a) * r_out, cap_out)
		var y_in := minf(WHEEL_Y + sin(a) * r_in, cap_out - ARCH_LIP)
		var x_in := _flank_x(s_in, y_in)
		var x_out := _flank_x(s_out, y_out)
		var p_in := Vector3(side * (x_in + ARCH_OUT), y_in, z_in)
		var p_out := Vector3(side * (x_out + ARCH_OUT), y_out, z_out)
		var b_in := Vector3(side * (x_in - 0.03), y_in, z_in)
		var b_out := Vector3(side * (x_out - 0.03), y_out, z_out)
		var s_c := _station_at(stations, zc)
		centre = Vector3(side * (_flank_x(s_c, WHEEL_Y) - 0.2), WHEEL_Y, zc)
		if i > 0 and prev_in != Vector3.INF:
			var well := Vector3(side * (_flank_x(s_c, WHEEL_Y) + 0.004), WHEEL_Y, zc)
			# Well: dark disc on the flank inside the lip.
			_tri(trim, well, prev_base_in + Vector3(side * 0.034, 0, 0), b_in + Vector3(side * 0.034, 0, 0), centre)
			# Lip face (paint) faces out from the flank.
			_quad(paint, prev_in, prev_out, p_out, p_in, centre)
			# Outer rim (paint) faces away from the axle; inner rim (trim) towards it.
			var mid_out := (prev_out + p_out) * 0.5
			_quad(paint, prev_out, prev_base_out, b_out, p_out, Vector3(mid_out.x, WHEEL_Y, zc))
			var mid_in := (prev_in + p_in) * 0.5
			var axle := Vector3(mid_in.x, WHEEL_Y, zc)
			_quad(trim, prev_in, prev_base_in, b_in, p_in, mid_in + (mid_in - axle).normalized() * 0.3)
		prev_in = p_in
		prev_out = p_out
		prev_base_in = b_in
		prev_base_out = b_out


## Height of the flank's upper crease (arches stay below it).
static func _shoulder_y(s: Array) -> float:
	var yb: float = s[2] + SILL_DROP
	return yb + (s[3] - yb) * 0.76


## Thin dark seam down the flank at z, following the section.
static func _shut_line(st: SurfaceTool, stations: Array, z: float, side: float) -> void:
	var s := _station_at(stations, z)
	if s.is_empty():
		return
	var yb: float = s[2] + SILL_DROP
	var h: float = s[3] - yb
	var y0 := yb + h * 0.3
	var y1 := yb + h * 0.74
	var steps := 4
	for i in steps:
		var ya := lerpf(y0, y1, float(i) / steps)
		var yb2 := lerpf(y0, y1, float(i + 1) / steps)
		var xa := side * (_flank_x(s, ya) + 0.003)
		var xb := side * (_flank_x(s, yb2) + 0.003)
		var inside := Vector3(0.0, (ya + yb2) * 0.5, z)
		_quad(st, Vector3(xa, ya, z - 0.007), Vector3(xa, ya, z + 0.007),
				Vector3(xb, yb2, z + 0.007), Vector3(xb, yb2, z - 0.007), inside)


static func _mirrors(tools: Dictionary, design: Dictionary, stations: Array) -> void:
	var cabin: Array = design.cabin
	var z: float = cabin[0][0] + 0.32
	var s := _station_at(stations, z)
	if s.is_empty():
		return
	var base_x: float = s[1] * s[4] * 0.96
	var y: float = s[3] + 0.1
	for side in [-1.0, 1.0]:
		var stalk := Transform3D(Basis.IDENTITY, Vector3(side * (base_x + 0.04), y - 0.05, z + 0.02))
		_box(tools.Trim, Vector3(0.1, 0.03, 0.05), stalk)
		var head := Transform3D(Basis(Vector3.UP, side * deg_to_rad(-8.0)), Vector3(side * (base_x + 0.12), y, z))
		_box(tools.Paint, Vector3(0.15, 0.09, 0.07), head)
		_box(tools.Glass, Vector3(0.12, 0.068, 0.01), head.translated_local(Vector3(0, 0, 0.037)))


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
		"flare":
			var p3: Vector3 = spec[2] # inner radius, outer radius, width
			_flare(st, p3.x, p3.y, p3.z, xf)
		"mirror_flare":
			var p4: Vector3 = spec[2]
			_flare(st, p4.x, p4.y, p4.z, xf)
			_flare(st, p4.x, p4.y, p4.z, _mirror(xf))


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


## Triangle with per-vertex (smooth) normals, wound to face away from `inside`.
static func _tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	# Godot's front faces wind clockwise when seen from outside.
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nc)
	st.add_vertex(c)
	st.set_normal(nb)
	st.add_vertex(b)


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


## Fender flare: a half ring over a wheel (slightly past horizontal at both
## ends) in the local YZ plane, `width` thick along X.
static func _flare(st: SurfaceTool, inner: float, outer: float, width: float, xf: Transform3D) -> void:
	var segments := 14
	var start := -0.12
	var sweep := PI + 0.24
	var hw := width * 0.5
	var mid := (inner + outer) * 0.5
	for i in segments:
		var a0 := start + sweep * i / segments
		var a1 := start + sweep * (i + 1) / segments
		var d0 := Vector3(0, sin(a0), cos(a0))
		var d1 := Vector3(0, sin(a1), cos(a1))
		var dm := Vector3(0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
		var c := xf * (dm * mid)
		var o0 := d0 * outer
		var o1 := d1 * outer
		var i0 := d0 * inner
		var i1 := d1 * inner
		var x := Vector3(hw, 0, 0)
		_quad(st, xf * (o0 - x), xf * (o0 + x), xf * (o1 + x), xf * (o1 - x), c)
		_quad(st, xf * (i0 - x), xf * (i0 + x), xf * (i1 + x), xf * (i1 - x), c)
		_quad(st, xf * (i0 + x), xf * (o0 + x), xf * (o1 + x), xf * (i1 + x), c)
		_quad(st, xf * (i0 - x), xf * (o0 - x), xf * (o1 - x), xf * (i1 - x), c)
	for a: float in [start, start + sweep]:
		var d := Vector3(0, sin(a), cos(a))
		var x2 := Vector3(hw, 0, 0)
		# A point just inside the ring from this end cap.
		var b := a + (0.1 if a == start else -0.1)
		var inside := xf * (Vector3(0, sin(b), cos(b)) * mid)
		_quad(st, xf * (d * inner - x2), xf * (d * inner + x2), xf * (d * outer + x2), xf * (d * outer - x2), inside)


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
