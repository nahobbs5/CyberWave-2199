@tool
class_name CrazyHouseScenery
extends TrackScenery
## Crazy House (GDD 8.6b): a race inside Hang Nga's Crazy House in Da Lat,
## Vietnam, built to look like a hollowed-out tree. The whole lap runs
## inside one giant hollow trunk with no straight lines: melted grey and
## brown bark dripping with cream plaster, oval windows letting in daylight,
## winding staircases everywhere and bizarre bone-like branches. In driving
## order: the Root Hall (the start, between gnarled root columns); the
## Spiral Stair Well (a tall well ringed with helical staircases); the
## Animal Rooms (warm-lit rooms with a bear, an eagle and a giraffe); the
## Gingerbread Gables (the yellow timber house with steep ornate gables
## built into the trunk); the Lava Grotto (orange-red pitted walls and giant
## mushrooms); and the Bone Gallery (bone arches over the road, knotted
## branch railings and a giant spider web). The shortcut is the Rib Tunnel:
## a narrow passage lined with bone ribs. The road is flat (the stairs are
## scenery); positions are layout coordinates matching crazy_house.tscn.

const HOUSE_SHADER := preload("res://assets/shaders/crazy_house.gdshader")

const ROOT_FROM := Vector3(-300, 0, 25)
const WELL_FROM := Vector3(144, 0, -24)
const ROOMS_FROM := Vector3(300, 0, 132)
const GABLES_FROM := Vector3(564, 0, 360)
const LAVA_FROM := Vector3(420, 0, 600)
const BONES_FROM := Vector3(48, 0, 564)
const ROOF_CELL := 2.0
## Nothing hanging over a road comes lower than this.
const ROAD_CLEARANCE := 7.5
const BLEND := 50.0
## Sky windows in the roof (each with a shaft of daylight).
const SKY_WINDOWS := 8

## Zone shapes: wall distances beyond the road edge, roof height, noise,
## slow bulges and the wall material.
const ZONES := {
	"root": {"left": 14.0, "right": 14.0, "crown": 26.0, "rough": 0.8, "bulge": 1.0, "key": "trunk"},
	"well": {"left": 24.0, "right": 24.0, "crown": 46.0, "rough": 0.7, "bulge": 0.8, "key": "trunk"},
	"rooms": {"left": 13.0, "right": 13.0, "crown": 19.0, "rough": 0.9, "bulge": 1.2, "key": "trunk"},
	"gables": {"left": 12.0, "right": 26.0, "crown": 28.0, "rough": 0.8, "bulge": 1.0, "key": "trunk"},
	"lava": {"left": 14.0, "right": 14.0, "crown": 21.0, "rough": 1.0, "bulge": 1.4, "key": "lava"},
	"bones": {"left": 14.0, "right": 14.0, "crown": 24.0, "rough": 0.8, "bulge": 1.1, "key": "trunk"},
}
const ZONE_ORDER := ["root", "well", "rooms", "gables", "lava", "bones"]

var zone_offsets: Dictionary = {}
var stair_flights: int = 0
var step_count: int = 0
var window_shafts: int = 0
var bone_arches: int = 0
## Lowest point of any bone arch or rib over a road (tests).
var bone_arch_clearance: float = INF
var start_roof_height: float = 0.0

var _roof: Dictionary = {}
var _glow: Array[Vector4] = []
var _zone_list: Array = []
var _cave: CaveShellBuilder


func build() -> void:
	_roof.clear()
	_glow.clear()
	stair_flights = 0
	step_count = 0
	window_shafts = 0
	bone_arches = 0
	bone_arch_clearance = INF
	_setup_materials()
	var starts := [ROOT_FROM, WELL_FROM, ROOMS_FROM, GABLES_FROM, LAVA_FROM, BONES_FROM]
	_zone_list.clear()
	for i in ZONE_ORDER.size():
		zone_offsets[ZONE_ORDER[i]] = _off(starts[i])
		_zone_list.append([zone_offsets[ZONE_ORDER[i]], ZONE_ORDER[i]])
	var h := track.road_width * 0.5
	_cave = CaveShellBuilder.new(self, null, random_seed + 11)
	_cave.dims = _dims
	_cave.on_roof = mark_roof
	_cave.min_clear = 12.0
	await step(0.05)
	_cave.build(0.0, 0.0)
	start_roof_height = _roof_over_road(track.start_line_offset, h)
	await step(0.35)
	_sky_windows()
	_wall_windows()
	_lights()
	await step(0.45)
	_root_columns()
	_stair_well()
	_side_stairs()
	await step(0.6)
	_animal_rooms()
	_gables()
	await step(0.7)
	_mushrooms()
	_bone_gallery()
	await step(0.8)
	if not track.shortcuts.is_empty():
		_rib_tunnel(track.shortcuts[0])
	await step(0.9)
	_apply_glow()


func _off(p: Vector3) -> float:
	return track.curve.get_closest_offset(p)


# --- shape --------------------------------------------------------------------------------

func _dims(d: float) -> Dictionary:
	var h := track.road_width * 0.5
	var idx := _zone_at(d)
	var cur: Dictionary = ZONES[_zone_list[idx][1]]
	var prev: Dictionary = ZONES[_zone_list[(idx - 1 + _zone_list.size()) % _zone_list.size()][1]]
	var t := smoothstep(0.0, BLEND, fposmod(d - float(_zone_list[idx][0]), track.length))
	var out := {}
	for k in ["left", "right", "crown", "rough", "bulge"]:
		out[k] = lerpf(float(prev[k]), float(cur[k]), t)
	out["left_wall"] = h + float(out["left"])
	out["right_wall"] = h + float(out["right"])
	out["key"] = cur["key"]
	out["zone"] = _zone_list[idx][1]
	return out


func _zone_at(d: float) -> int:
	var best := 0
	var best_into := INF
	for i in _zone_list.size():
		var into := fposmod(d - float(_zone_list[i][0]), track.length)
		if into < best_into:
			best_into = into
			best = i
	return best


func _zone_span(zone: String) -> Array[float]:
	var i := ZONE_ORDER.find(zone)
	var from := float(zone_offsets[zone])
	var to := float(zone_offsets[ZONE_ORDER[(i + 1) % ZONE_ORDER.size()]])
	return [from, fposmod(to - from, track.length)]


## Roof height above a lateral position in a cross-section (0 if none).
func _ceiling_at(pr: PackedVector2Array, lat: float) -> float:
	var best := 0.0
	for i in pr.size() - 1:
		var a := pr[i]
		var b := pr[i + 1]
		if (a.x - lat) * (b.x - lat) <= 0.0 and absf(b.x - a.x) > 0.001:
			best = maxf(best, lerpf(a.y, b.y, (lat - a.x) / (b.x - a.x)))
	return best


func _ceiling(d: float, lat: float) -> float:
	return _ceiling_at(_cave.profile(d, _dims(d), track.road_width * 0.5), lat)


func _roof_over_road(d: float, h: float) -> float:
	var pr := _cave.profile(d, _dims(d), h)
	var low := INF
	for p in pr:
		if absf(p.x) <= h and p.y > 0.0:
			low = minf(low, p.y)
	return low


# --- roof map -----------------------------------------------------------------------------

func mark_roof(f: Transform3D, from_lateral: float, to_lateral: float) -> void:
	var along := 0.0
	while along <= CaveShellBuilder.STEP:
		var lat := from_lateral
		while lat <= to_lateral:
			var p := f * Vector3(lat, 0, -along)
			_roof[Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL)))] = true
			lat += 1.0
		along += 1.0


func is_roofed(p: Vector3) -> bool:
	return _roof.has(Vector2i(int(floor(p.x / ROOF_CELL)), int(floor(p.z / ROOF_CELL))))


# --- materials ----------------------------------------------------------------------------

func _setup_materials() -> void:
	register_material("trunk", _house_material(0.0, 0.18))
	register_material("lava", _house_material(0.85, 0.1))
	register_material("bark", _house_material(0.0, 0.1))
	textured("bone", "white_plaster_rough_01", Color(1.6, 1.6, 1.6), 1.5, 0.55)
	add_glow("bone", Color(0.92, 0.87, 0.74), 0.06)
	textured("step", "white_plaster_rough_01", Color(1.27, 1.24, 1.37), 2.0, 0.8)
	textured("trim", "hinoki_planks", Color(0.53, 0.41, 0.31), 2.0, 0.7)
	textured("planks", "hinoki_planks", Color(1.0, 0.82, 0.48), 2.5, 0.7)
	material("window", Color(1.0, 0.8, 0.5), 3.0)
	material("sky_window", Color(0.9, 0.95, 1.0), 4.0)
	textured("cap", "white_plaster_rough_01", Color(1.8, 0.81, 0.47), 2.0, 0.6)
	add_glow("cap", Color(0.88, 0.36, 0.16), 0.1)
	textured("cap_cream", "white_plaster_rough_01", Color(1.6, 1.6, 1.6), 2.0, 0.6)
	add_glow("cap_cream", Color(0.95, 0.9, 0.78), 0.1)
	material("fur", Color(0.36, 0.24, 0.15), 0.0, 0.0, 0.9)
	material("giraffe", Color(0.9, 0.72, 0.38), 0.0, 0.0, 0.7)
	material("eagle", Color(0.42, 0.3, 0.2), 0.0, 0.0, 0.8)


func _house_material(lava: float, drips: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HOUSE_SHADER
	m.set_shader_parameter("lava_amount", lava)
	m.set_shader_parameter("drip_amount", drips)
	# Real bark grain under the melted look (Poly Haven bark_brown_02).
	shader_detail(m, "bark_brown_02", 2.5, 0.5, 0.1, 0.8)
	return m


func _add_glow(p: Vector3, reach: float) -> void:
	if _glow.size() < 12:
		_glow.append(Vector4(p.x, p.y, p.z, reach))


func _apply_glow() -> void:
	var arr := PackedVector4Array()
	for g in _glow:
		arr.append(g)
	while arr.size() < 12:
		arr.append(Vector4(0, -1000, 0, 1))
	for key in ["trunk", "lava", "bark"]:
		var m := get_material(key) as ShaderMaterial
		m.set_shader_parameter("glow_points", arr)
		m.set_shader_parameter("glow_count", _glow.size())


# --- organic geometry (no straight lines) --------------------------------------------------

## A tube swept along a path (bones, branches, railings): radius r0 at the
## start to r1 at the end, rounded knobs on the ends when `knobs`.
func add_tube(key: String, pts: PackedVector3Array, r0: float, r1: float, sides: int = 7, knobs: bool = false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var prev_side := Vector3.ZERO
	var rings: Array[PackedVector3Array] = []
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side: Vector3
		if prev_side == Vector3.ZERO:
			side = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		else:
			side = (prev_side - t * t.dot(prev_side)).normalized()
		prev_side = side
		var up := t.cross(side)
		var r := lerpf(r0, r1, float(i) / (n - 1))
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			ring.append(pts[i] + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)
	for i in n - 1:
		var st := _st(key, pts[i])
		for s in sides:
			var s2 := (s + 1) % sides
			_quad(st, rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s], (pts[i] + pts[i + 1]) * 0.5)
	if knobs:
		add_sphere(key, r0 * 1.7, Transform3D(Basis(), pts[0]), 4, 7)
		add_sphere(key, r1 * 1.7, Transform3D(Basis(), pts[n - 1]), 4, 7)


## Catmull-Rom through `ctrl`, `per` samples per span.
static func smooth(ctrl: PackedVector3Array, per: int = 5) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out


## A squashed blob (sphere scaled per axis).
func add_blob(key: String, centre: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	add_sphere(key, 1.0, Transform3D(Basis(Vector3.UP, yaw).scaled(size), centre), 5, 9)


# --- light ---------------------------------------------------------------------------------

## Oval windows in the roof letting daylight onto the road (no visible
## beam or fog cone: they read as UFO lights).
func _sky_windows() -> void:
	for i in SKY_WINDOWS:
		var o := track.wrap_offset(track.start_line_offset + 120.0 + track.length * i / SKY_WINDOWS)
		var lat := rng.randf_range(-3.0, 3.0)
		var top := _ceiling(o, lat)
		var f := at(o)
		var c := f.translated_local(Vector3(lat, top - 0.5, 0))
		add_cyl("sky_window", 2.6, 0.4, Transform3D(c.basis.scaled(Vector3(1.0, 1.0, 1.6)), c.origin), 14)
		var spot := SpotLight3D.new()
		spot.name = "WindowShaft%d" % (i + 1)
		spot.position = f * Vector3(lat, top - 1.0, 0)
		spot.basis = Basis(Vector3.RIGHT, -PI * 0.5)
		spot.light_color = Color(1.0, 0.95, 0.85)
		spot.light_energy = 6.0
		spot.spot_range = top + 6.0
		spot.spot_angle = 20.0
		spot.light_volumetric_fog_energy = 0.0
		add_node(spot)
		window_shafts += 1
		_add_glow(f * Vector3(lat, top, 0), 18.0)


## Warm oval windows set into the walls.
func _wall_windows() -> void:
	var h := track.road_width * 0.5
	var d := 20.0
	while d < track.length:
		var dm := _dims(d)
		var pr := _cave.profile(d, dm, h)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var best := Vector2.ZERO
		for p in pr:
			if signf(p.x) == side and p.y > 5.0 and p.y < 15.0 and absf(p.x) > h + 6.0:
				best = p
				break
		if best != Vector2.ZERO:
			var f := at(d)
			var pos := f * Vector3(best.x - side * 0.6, best.y, 0)
			var centre := f * Vector3(0, best.y, 0)
			var basis := Basis.looking_at((centre - pos).normalized(), Vector3.UP)
			add_sphere("window", 1.0, Transform3D(basis.scaled(Vector3(1.1, 1.7, 0.2)), pos), 5, 10)
		d += rng.randf_range(22.0, 34.0)


func _lights() -> void:
	var d := 40.0
	while d < track.length:
		var y := minf(float(_dims(d)["crown"]) * 0.5, 13.0)
		add_light(at(d) * Vector3(0, y, 0), Color(1.0, 0.8, 0.55), 1.6, 50.0)
		d += 105.0


# --- set pieces ------------------------------------------------------------------------------

## Gnarled root columns in the Root Hall, floor to roof, with roots spreading
## at their feet.
func _root_columns() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("root")
	var d := 15.0
	while d < span[1] - 10.0:
		var o := track.wrap_offset(span[0] + d)
		var dm := _dims(o)
		for side: float in [-1.0, 1.0]:
			var wall := float(dm["left_wall" if side < 0.0 else "right_wall"])
			var lat := side * rng.randf_range(h + 5.0, wall - 4.0)
			var f := at(o)
			var base := f * Vector3(lat, 0, 0)
			if not clear(base, 3.0):
				continue
			var top := _ceiling(o, lat)
			if top < 6.0:
				continue
			var ctrl := PackedVector3Array()
			for k in 6:
				var y := top * k / 5.0
				ctrl.append(base + Vector3(sin(k * 1.7 + d) * 1.4, y + 0.3, cos(k * 1.3 + d) * 1.4))
			add_tube("bark", smooth(ctrl, 4), 1.6, 2.2, 9)
			for r in 4:
				var a := TAU * r / 4 + rng.randf()
				var dir := Vector3(cos(a), 0, sin(a))
				var root := PackedVector3Array([base + Vector3(0, 2.5, 0), base + dir * 2.0 + Vector3(0, 1.0, 0), base + dir * 4.5 + Vector3(0, 0.1, 0)])
				if clear(base + dir * 4.5, 1.0):
					add_tube("bark", smooth(root, 4), 0.8, 0.25, 6)
		d += 34.0


## A helical staircase climbing `height` around a twisted central post, with
## rounded steps, a bone banister and knobs every few steps.
func stair_flight(base: Vector3, radius: float, height: float, start_angle: float, turn: float = 1.0) -> void:
	var steps := int(height / 0.34)
	if steps < 8:
		return
	var rail := PackedVector3Array()
	for i in steps:
		var a := start_angle + turn * i * 0.32
		var dir := Vector3(cos(a), 0, sin(a))
		var p := base + dir * radius + Vector3(0, 0.3 + i * 0.34, 0)
		var basis := Basis(Vector3.UP, -a).scaled(Vector3(1.6, 1.0, 0.8))
		add_cyl("step", 0.85, 0.16, Transform3D(basis, p), 9)
		rail.append(base + dir * (radius + 1.25) + Vector3(0, 1.3 + i * 0.34, 0))
		if i % 8 == 0:
			add_sphere("bone", 0.22, Transform3D(Basis(), rail[rail.size() - 1]), 3, 6)
	step_count += steps
	add_tube("bone", rail, 0.07, 0.07, 5, true)
	var post := PackedVector3Array()
	for k in 7:
		post.append(base + Vector3(sin(k * 1.1) * 0.25, height * k / 6.0, cos(k * 0.9) * 0.25))
	add_tube("bark", smooth(post, 3), 0.75, 0.45, 8)
	# A lit doorway at the top.
	var top := base + Vector3(cos(start_angle + turn * steps * 0.32), 0, sin(start_angle + turn * steps * 0.32)) * (radius + 0.2) + Vector3(0, steps * 0.34 + 1.4, 0)
	add_sphere("window", 1.0, Transform3D(Basis().scaled(Vector3(0.7, 1.2, 0.7)), top), 4, 8)
	stair_flights += 1


## The Spiral Stair Well: staircases all round the walls.
func _stair_well() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("well")
	var d := 12.0
	var side := 1.0
	while d < span[1] - 8.0:
		var o := track.wrap_offset(span[0] + d)
		var wall := float(_dims(o)["left_wall" if side < 0.0 else "right_wall"])
		var lat := side * (wall - rng.randf_range(6.0, 9.0))
		var base := at(o) * Vector3(lat, 0, 0)
		if clear(base, 5.0):
			var top := _ceiling(o, lat)
			stair_flight(base, rng.randf_range(3.2, 4.4), clampf(top - 4.0, 6.0, 30.0), rng.randf() * TAU, side)
			if stair_flights % 2 == 0:
				add_light(base + Vector3(0, minf(top - 4.0, 30.0) * 0.6, 0), Color(1.0, 0.75, 0.45), 1.4, 22.0)
		side = -side
		d += rng.randf_range(16.0, 24.0)


## Smaller staircases elsewhere around the house.
func _side_stairs() -> void:
	var h := track.road_width * 0.5
	var well := _zone_span("well")
	var d := 0.0
	var side := -1.0
	while d < track.length:
		if fposmod(d - well[0], track.length) > well[1] + 20.0:
			var dm := _dims(d)
			var wall := float(dm["left_wall" if side < 0.0 else "right_wall"])
			if wall - h > 10.0:
				var lat := side * (wall - 5.0)
				var base := at(d) * Vector3(lat, 0, 0)
				if clear(base, 4.0):
					stair_flight(base, 2.8, clampf(_ceiling(d, lat) - 3.0, 5.0, 14.0), rng.randf() * TAU, side)
		side = -side
		d += 140.0


## The Animal Rooms: lit alcoves with a bear, an eagle and a giraffe.
func _animal_rooms() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("rooms")
	for i in 3:
		var o := track.wrap_offset(span[0] + span[1] * (i + 0.6) / 3.4)
		var side := -1.0 if i % 2 == 0 else 1.0
		var wall := float(_dims(o)["left_wall" if side < 0.0 else "right_wall"])
		var f := at(o)
		var base := f * Vector3(side * (wall - 5.0), 0, 0)
		if not clear(base, 3.0):
			continue
		var yaw := atan2(-(f.basis.x * side).x, -(f.basis.x * side).z)
		match i:
			0:
				# Bear: body, head, ears and snout.
				add_blob("fur", base + Vector3(0, 1.6, 0), Vector3(2.0, 1.5, 1.3), yaw)
				var head := base + Vector3(0, 3.4, 0) - f.basis.x * side * 1.2
				add_blob("fur", head, Vector3(0.9, 0.8, 0.9))
				add_sphere("fur", 0.3, Transform3D(Basis(), head + Vector3(0, 0.8, 0) + f.basis.z * 0.5), 3, 6)
				add_sphere("fur", 0.3, Transform3D(Basis(), head + Vector3(0, 0.8, 0) - f.basis.z * 0.5), 3, 6)
			1:
				# Eagle on a branch perch, wings spread.
				var perch := PackedVector3Array([base + Vector3(0, 0, 0), base + Vector3(0.4, 2.5, 0.2), base + Vector3(-0.3, 4.2, 0)])
				add_tube("bark", smooth(perch, 4), 0.35, 0.2, 7)
				var body := base + Vector3(0, 5.0, 0)
				add_blob("eagle", body, Vector3(0.7, 1.1, 0.6))
				add_sphere("cap_cream", 0.42, Transform3D(Basis(), body + Vector3(0, 1.2, 0)), 4, 7)
				for w: float in [-1.0, 1.0]:
					var wing := PackedVector3Array([body, body + f.basis.z * w * 1.6 + Vector3(0, 0.8, 0), body + f.basis.z * w * 3.2 + Vector3(0, 0.3, 0)])
					add_tube("eagle", smooth(wing, 4), 0.35, 0.08, 6)
			2:
				# Giraffe: body, long neck, head and legs.
				var body := base + Vector3(0, 3.2, 0)
				add_blob("giraffe", body, Vector3(1.0, 0.9, 1.8), yaw)
				var neck := PackedVector3Array([body + f.basis.z * 1.2, body + f.basis.z * 1.6 + Vector3(0, 2.5, 0), body + f.basis.z * 1.9 + Vector3(0, 4.6, 0)])
				add_tube("giraffe", smooth(neck, 4), 0.42, 0.25, 7)
				add_blob("giraffe", neck[2] + Vector3(0, 0.3, 0) + f.basis.z * 0.4, Vector3(0.4, 0.4, 0.8))
				for leg: Vector3 in [Vector3(0.6, 0, 1.2), Vector3(-0.6, 0, 1.2), Vector3(0.6, 0, -1.2), Vector3(-0.6, 0, -1.2)]:
					var top := body + f.basis * leg * 0.8
					add_tube("giraffe", PackedVector3Array([top, Vector3(top.x, 0.0, top.z)]), 0.18, 0.14, 5)
		add_sphere("window", 1.0, Transform3D(Basis().scaled(Vector3(1.6, 2.4, 1.6)), f * Vector3(side * (wall - 1.0), 4.5, 0)), 5, 9)
		add_light(base + Vector3(0, 5.0, 0) - f.basis.x * side * 3.0, Color(1.0, 0.72, 0.42), 2.2, 18.0)


## The Gingerbread Gables: the yellow timber house built into the trunk,
## with steep curling gables, dark trim and warm windows.
func _gables() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("gables")
	var d := 25.0
	while d < span[1] - 25.0:
		var o := track.wrap_offset(span[0] + d)
		var wall := float(_dims(o)["right_wall"])
		var f := at(o)
		var lat := minf(h + 14.0, wall - 4.0)
		var base := f.translated_local(Vector3(lat, 0, 0))
		if clear(base.origin, 5.0):
			var xf := Transform3D(base.basis * Basis(Vector3.UP, PI * 0.5), base.origin)
			var w := 11.0
			var wall_h := 7.0
			var peak := wall_h + rng.randf_range(7.0, 10.0)
			add_panel("planks", w, wall_h, xf)
			var st := _st("planks", xf.origin)
			var a := xf * Vector3(-w * 0.55, wall_h, 0)
			var b := xf * Vector3(w * 0.55, wall_h, 0)
			var c := xf * Vector3(0, peak, 0)
			_tri(st, a, b, c, xf * Vector3(0, wall_h + 2.0, 1.0))
			# Trim along the gable edges, curling out at the eaves and tip.
			add_tube("trim", smooth(PackedVector3Array([xf * Vector3(-w * 0.75, wall_h - 0.9, 0.3), a + xf.basis.z * 0.3, c + xf.basis.z * 0.3 + Vector3(0, 0.6, 0)]), 6), 0.22, 0.14, 6)
			add_tube("trim", smooth(PackedVector3Array([xf * Vector3(w * 0.75, wall_h - 0.9, 0.3), b + xf.basis.z * 0.3, c + xf.basis.z * 0.3 + Vector3(0, 0.6, 0)]), 6), 0.22, 0.14, 6)
			add_sphere("trim", 0.45, Transform3D(Basis(), c + Vector3(0, 1.4, 0)), 4, 7)
			for k in 3:
				var wx := -w * 0.3 + w * 0.3 * k
				add_sphere("window", 1.0, Transform3D(xf.basis.scaled(Vector3(0.9, 1.3, 0.15)), xf * Vector3(wx, 3.6, 0.15)), 4, 8)
			add_sphere("window", 1.0, Transform3D(xf.basis.scaled(Vector3(0.8, 1.2, 0.15)), xf * Vector3(0, wall_h + 2.5, 0.15)), 4, 8)
			add_light(xf * Vector3(0, 5.0, 4.0), Color(1.0, 0.78, 0.48), 1.8, 22.0)
		d += 32.0


## Giant mushrooms in the Lava Grotto.
func _mushrooms() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("lava")
	var d := 8.0
	while d < span[1]:
		var o := track.wrap_offset(span[0] + d)
		var dm := _dims(o)
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				continue
			var wall := float(dm["left_wall" if side < 0.0 else "right_wall"])
			var lat := side * rng.randf_range(h + 4.0, wall - 3.0)
			var base := at(o) * Vector3(lat, 0, 0)
			var giant := rng.randf() < 0.25
			var stem_h := rng.randf_range(5.0, 9.0) if giant else rng.randf_range(1.2, 3.5)
			var cap_r := stem_h * rng.randf_range(0.5, 0.7)
			if not clear(base, cap_r):
				continue
			add_cyl("cap_cream", stem_h * 0.12, stem_h, Transform3D(Basis(), base), 8, stem_h * 0.08)
			add_blob("cap" if rng.randf() < 0.7 else "cap_cream", base + Vector3(0, stem_h, 0), Vector3(cap_r, cap_r * 0.42, cap_r))
		d += 9.0


## The Bone Gallery: bone arches over the road, knotted branch railings and a
## giant spider web.
func _bone_gallery() -> void:
	var h := track.road_width * 0.5
	var span := _zone_span("bones")
	var d := 15.0
	while d < span[1] - 10.0:
		var o := track.wrap_offset(span[0] + d)
		bone_arch(at(o), h, _ceiling(o, 0.0))
		d += rng.randf_range(28.0, 40.0)
	# Knotted branch railings beyond both barriers, through the gallery and the hall.
	for zone in ["bones", "root"]:
		var zs := _zone_span(zone)
		for side: float in [-1.0, 1.0]:
			var run := PackedVector3Array()
			var dd := 0.0
			while dd <= zs[1]:
				var o := track.wrap_offset(zs[0] + dd)
				var p := at(o) * Vector3(side * (h + 1.8), 1.3 + 0.45 * sin(dd * 0.21 + side), 0)
				if edge_distance(Vector3(p.x, 0, p.z)) < 1.2:
					if run.size() > 2:
						add_tube("bone", run, 0.11, 0.11, 5, true)
					run = PackedVector3Array()
				else:
					run.append(p)
					if fmod(dd, 6.0) < 2.0:
						var post := PackedVector3Array([Vector3(p.x, 0.0, p.z), p + Vector3(0.25, -0.6, 0.0), p])
						add_tube("bone", smooth(post, 3), 0.09, 0.07, 5)
				dd += 2.0
				if run.size() >= 16:
					add_tube("bone", run, 0.11, 0.11, 5, true)
					run = PackedVector3Array([run[run.size() - 1]])
			if run.size() > 2:
				add_tube("bone", run, 0.11, 0.11, 5, true)
	# The spider web, on the gallery wall.
	var o := track.wrap_offset(span[0] + span[1] * 0.55)
	var wall := float(_dims(o)["left_wall"])
	var f := at(o)
	var centre := f * Vector3(-(wall - 3.0), 11.0, 0)
	var basis := Basis.looking_at((f * Vector3(0, 11.0, 0) - centre).normalized(), Vector3.UP)
	var spokes := 10
	var rings := 5
	for s in spokes:
		var a := TAU * s / spokes
		add_tube("bone", PackedVector3Array([centre, centre + basis * Vector3(cos(a), sin(a), 0) * 8.0]), 0.08, 0.05, 4)
	for r in range(1, rings + 1):
		var ring := PackedVector3Array()
		for s in spokes + 1:
			var a := TAU * s / spokes
			ring.append(centre + basis * Vector3(cos(a), sin(a), 0) * (8.0 * r / rings) * (0.92 + 0.08 * sin(s * 2.0)))
		add_tube("bone", ring, 0.05, 0.05, 4)
	add_blob("trim", centre + basis * Vector3(1.5, -1.0, 0.4), Vector3(0.7, 0.55, 0.9))


## One bone arch over the road: feet beyond the barriers, a knobbly joint at
## the top, never lower than ROAD_CLEARANCE over the road.
func bone_arch(f: Transform3D, h: float, roof: float) -> void:
	var foot := h + 3.2
	if not (clear(f * Vector3(-foot, 0, 0), 0.4) and clear(f * Vector3(foot, 0, 0), 0.4)):
		return
	var apex := clampf(roof * 0.6, ROAD_CLEARANCE + 2.5, maxf(ROAD_CLEARANCE + 2.5, roof - 1.5))
	var tilt := rng.randf_range(-1.5, 1.5)
	# Upright legs beyond the barriers, shoulders above the road edges.
	var ctrl := PackedVector3Array([
		f * Vector3(-foot, 0.0, 0), f * Vector3(-foot - 0.3, apex * 0.5, tilt * 0.3), f * Vector3(-h - 0.6, apex - 1.0, tilt * 0.7),
		f * Vector3(0, apex, tilt), f * Vector3(h + 0.6, apex - 1.2, tilt * 0.7), f * Vector3(foot + 0.3, apex * 0.5, tilt * 0.3), f * Vector3(foot, 0.0, 0)])
	var pts := smooth(ctrl, 5)
	var r := 0.5
	add_tube("bone", pts, 0.7, 0.55, 8)
	add_sphere("bone", 1.0, Transform3D(Basis(), f * Vector3(0, apex, tilt)), 4, 8)
	add_sphere("bone", 1.1, Transform3D(Basis(), f * Vector3(-foot, 0.4, 0)), 4, 8)
	add_sphere("bone", 1.1, Transform3D(Basis(), f * Vector3(foot, 0.4, 0)), 4, 8)
	_note_clearance(pts, 0.72, h)
	bone_arches += 1


func _note_clearance(pts: PackedVector3Array, radius: float, _h: float) -> void:
	for p in pts:
		if edge_distance(Vector3(p.x, 0, p.z)) < 0.0:
			bone_arch_clearance = minf(bone_arch_clearance, p.y - radius)


## The Rib Tunnel: a narrow passage lined with bone ribs.
func _rib_tunnel(sc: TrackShortcut) -> void:
	var main_h := track.road_width * 0.5
	var t0 := 0.0
	var t1 := sc.length
	var d := 0.0
	while d < sc.length * 0.5:
		if _main_distance(sc.point_at(d)) > main_h + 6.0:
			break
		t0 = d
		d += 3.0
	d = sc.length
	while d > sc.length * 0.5:
		if _main_distance(sc.point_at(d)) > main_h + 6.0:
			break
		t1 = d
		d -= 3.0
	var h := sc.road_width * 0.5
	var tube := CaveShellBuilder.new(self, sc, random_seed + 77)
	tube.min_clear = 9.6
	tube.dims = func(td: float) -> Dictionary:
		var flare := 1.0 + 0.6 * (1.0 - smoothstep(0.0, 18.0, minf(td - t0, t1 - td)))
		return {"left_wall": (h + 3.0) * flare, "right_wall": (h + 3.0) * flare, "crown": 10.5 * flare,
				"rough": 0.4, "bulge": 0.6, "key": "trunk"}
	tube.on_roof = mark_roof
	tube.build(t0, t1)
	var rd := t0 + 20.0
	while rd < t1 - 20.0:
		var f := tube.frame(rd)
		var foot := h + 2.2
		var apex := 8.9
		var ctrl := PackedVector3Array([f * Vector3(-foot, 0.0, 0), f * Vector3(-foot - 0.2, 5.0, 0), f * Vector3(-h - 0.4, apex - 0.5, 0),
				f * Vector3(0, apex, 0), f * Vector3(h + 0.4, apex - 0.5, 0), f * Vector3(foot + 0.2, 5.0, 0), f * Vector3(foot, 0.0, 0)])
		var pts := smooth(ctrl, 4)
		add_tube("bone", pts, 0.38, 0.38, 6)
		_note_clearance(pts, 0.4, h)
		rd += 6.0
	var mid := 0.2
	while mid < 1.0:
		add_light(sc.point_at(lerpf(t0, t1, mid)) + Vector3(0, 6.0, 0), Color(1.0, 0.76, 0.48), 1.4, 24.0)
		mid += 0.2
	_add_glow(sc.point_at(t1) + Vector3(0, 4.0, 0), 22.0)


func _main_distance(p: Vector3) -> float:
	var q := track.curve.get_closest_point(p)
	return Vector2(p.x - q.x, p.z - q.z).length()
