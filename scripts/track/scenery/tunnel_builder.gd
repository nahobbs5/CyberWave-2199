class_name TunnelBuilder
extends RefCounted
## Builds a stone barrel vault along a stretch of road (the main loop or a
## shortcut): walls, an arched ceiling, arch ribs and pilasters every bay,
## and what lines each wall: "skulls" (an ossuary wall of stacked bones with
## rows of real skulls), "tombs" (burial niches, slabs and sarcophagi),
## "pipes" (service pipes and red emergency lamps), "rock" (bare quarry rock
## and timber props) or plain "stone". Torches, candle clusters and light
## shafts through street grates light it.
##
## Corner-aware: wall pieces that would stand on another road (where a
## shortcut leaves or rejoins) are left out, but the vault always closes over
## the top, so every metre of road is roofed. Visual only: the track barriers
## do the colliding. Each span closes its ends with a stone face around its
## opening, so a low tunnel meeting a tall chamber reads as an archway.
##
## Materials expected on the scenery (keys): the wall / vault / rib keys given
## in the options, plus ossuary, rock, niche, slab, pipe, iron, wood, wax,
## flame, red_lamp, grate_glow and beam.

const STEP := 3.0
## Segments across the arch.
const ARCH_SEGMENTS := 10
const TORCH_COLOR := Color(1.0, 0.55, 0.24)
const SHAFT_COLOR := Color(0.7, 0.8, 1.0)

var scenery: TrackScenery
## null = the main loop.
var shortcut: TrackShortcut
## Called as on_roof(frame, from_lateral, to_lateral) for every vault section,
## so the scenery can keep a map of what is roofed.
var on_roof: Callable
## Called as place_skull(transform) for every skull (instanced by the scenery).
var place_skull: Callable

var _torches: int = 0
var _candle_clusters: int = 0


func _init(p_scenery: TrackScenery, p_shortcut: TrackShortcut = null) -> void:
	scenery = p_scenery
	shortcut = p_shortcut


func half_width() -> float:
	return (shortcut.road_width if shortcut != null else scenery.track.road_width) * 0.5


func route_length() -> float:
	return shortcut.length if shortcut != null else scenery.track.length


## Frame (track-local) at a distance along the route: -Z forward, X right.
func frame(d: float) -> Transform3D:
	if shortcut == null:
		return scenery.at(d)
	var t := shortcut.tangent_at(d)
	return Transform3D(Basis.looking_at(t, Vector3.UP), shortcut.point_at(d))


## Point on the arch: theta 0 = right springing, PI = left springing.
static func arch_point(wl: float, wr: float, wall_h: float, crown: float, theta: float) -> Vector2:
	var c := (wr - wl) * 0.5
	var a := (wr + wl) * 0.5
	return Vector2(c + a * cos(theta), wall_h + (crown - wall_h) * sin(theta))


## Height of the vault above a lateral position (wall height at the walls).
static func vault_height(wl: float, wr: float, wall_h: float, crown: float, lateral: float) -> float:
	var c := (wr - wl) * 0.5
	var a := (wr + wl) * 0.5
	var u := clampf((lateral - c) / a, -1.0, 1.0)
	return wall_h + (crown - wall_h) * sqrt(1.0 - u * u)


## Options: left_wall / right_wall (wall laterals from the centre, default
## half + 3), wall_h, crown, wall_key, vault_key, rib_key, left_style /
## right_style, bay (rib spacing), torch_every (m, 0 = none), candles_every,
## lamps_every (red emergency lamps on "pipes" walls), grates (route
## distances for light shafts), caps (close the span ends).
func build(from_d: float, to_d: float, opts: Dictionary = {}) -> void:
	var h := half_width()
	var wl := float(opts.get("left_wall", h + 3.0))
	var wr := float(opts.get("right_wall", h + 3.0))
	var wall_h := float(opts.get("wall_h", 4.0))
	var crown := float(opts.get("crown", 7.5))
	var wall_key := String(opts.get("wall_key", "wall"))
	var vault_key := String(opts.get("vault_key", "vault"))
	var rib_key := String(opts.get("rib_key", "rib"))
	var styles := {-1.0: String(opts.get("left_style", "stone")), 1.0: String(opts.get("right_style", "stone"))}
	var bay := float(opts.get("bay", 6.0))
	var torch_every := float(opts.get("torch_every", 20.0))
	var candles_every := float(opts.get("candles_every", 0.0))
	var lamps_every := float(opts.get("lamps_every", 24.0))
	var grates: Array = opts.get("grates", [])
	var span := _span(from_d, to_d)
	var n := maxi(1, int(ceil(span / STEP)))
	var step := span / n
	var frames: Array[Transform3D] = []
	var ok := {-1.0: [], 1.0: []}
	for k in n + 1:
		var f := frame(_at(from_d, step * k))
		frames.append(f)
		for side: float in [-1.0, 1.0]:
			var w := wr if side > 0.0 else wl
			# Another road nearer than our own edge: leave this wall out.
			ok[side].append(scenery.edge_distance(f * Vector3(side * w, 0, 0)) > (w - h) - 0.4)
	var profile := _profile(wl, wr, wall_h, crown)
	var next_torch := torch_every * 0.5
	var next_candles := candles_every * 0.5
	var next_lamp := lamps_every * 0.5
	var torch_side := 1.0
	for k in n:
		var f0 := frames[k]
		var f1 := frames[k + 1]
		var travelled := step * k
		var mid_d := _at(from_d, travelled + step * 0.5)
		# Vault (always), walls (where clear).
		for i in profile.size() - 1:
			var a: Vector2 = profile[i]
			var b: Vector2 = profile[i + 1]
			var is_wall := i == 0 or i == profile.size() - 2
			var side := 1.0 if i == 0 else -1.0
			if is_wall and not (ok[side][k] and ok[side][k + 1]):
				continue
			var key := vault_key
			if is_wall:
				key = _wall_key(styles[side], wall_key)
				# Ossuary bones only up to the stack's top; stone above.
				if styles[side] == "skulls" and wall_h > _bone_top(wall_h) + 0.2:
					var cut := _bone_top(wall_h)
					var lo := Vector2(a.x, -0.2)
					var hi := Vector2(a.x, wall_h)
					var mid := Vector2(a.x, cut)
					_surface(f0, f1, lo, mid, "ossuary", wl, wr, wall_h)
					_surface(f0, f1, mid, hi, wall_key, wl, wr, wall_h)
					continue
			_surface(f0, f1, a, b, key, wl, wr, wall_h)
		if on_roof.is_valid():
			on_roof.call(f0, -wl, wr)
		# Ribs and pilasters each bay.
		if fmod(travelled, bay) < step:
			_rib(f0, wl, wr, wall_h, crown, rib_key, ok[-1.0][k], ok[1.0][k])
		# Wall dressing.
		for side: float in [-1.0, 1.0]:
			if not (ok[side][k] and ok[side][k + 1]):
				continue
			var w := wr if side > 0.0 else wl
			match styles[side]:
				"skulls":
					_skull_rows(f0, side, w, wall_h)
				"tombs":
					if fmod(travelled, bay) < step:
						_niches(f0, side, w, wall_h, k)
					if fmod(travelled + bay * 0.5, bay * 2.0) < step:
						_sarcophagus(f0.translated_local(Vector3(side * (h + 2.0), 0, -1.5)))
				"pipes":
					_pipes(f0, side, w, wall_h)
					if lamps_every > 0.0 and travelled >= next_lamp:
						_red_lamp(f0, side, w, wall_h)
						next_lamp += lamps_every
				"rock":
					if fmod(travelled, bay) < step:
						_prop(f0, side, w, wall_h)
		if styles[-1.0] == "rock" and styles[1.0] == "rock" and fmod(travelled, bay) < step \
				and ok[-1.0][k] and ok[1.0][k]:
			scenery.add_box("wood", Vector3(wl + wr, 0.35, 0.4), f0.translated_local(Vector3((wr - wl) * 0.5, wall_h + 0.1, 0)))
		# Torches, alternating sides.
		if torch_every > 0.0 and travelled >= next_torch:
			if not ok[torch_side][k]:
				torch_side = -torch_side
			if ok[torch_side][k]:
				var w := wr if torch_side > 0.0 else wl
				torch(f0, torch_side, w, minf(wall_h - 0.6, 2.9) if styles[torch_side] != "skulls" else _bone_top(wall_h) + 0.8)
			torch_side = -torch_side
			next_torch += torch_every
		if candles_every > 0.0 and travelled >= next_candles:
			var side := 1.0 if _candle_clusters % 2 == 0 else -1.0
			var p := f0.translated_local(Vector3(side * (h + 1.9), 0, -scenery.rng.randf_range(0.0, step)))
			if ok[side][k] and scenery.edge_distance(p.origin) > 1.4:
				candles(p, scenery.rng.randi_range(4, 8), _candle_clusters % 3 == 0)
				if styles[side] == "skulls" or styles[side] == "tombs":
					skull_pile(p.translated_local(Vector3(side * 0.4, 0, 0.6)), 5)
			_candle_clusters += 1
			next_candles += candles_every
		for g in grates:
			if absf(_delta(mid_d, float(g))) <= step * 0.5:
				shaft(f0, 0.0, vault_height(wl, wr, wall_h, crown, 0.0))
	if opts.get("caps", true):
		_cap(frame(_at(from_d, 0.05)), wl, wr, wall_h, crown, wall_key, 1.0)
		_cap(frame(_at(from_d, span - 0.05)), wl, wr, wall_h, crown, wall_key, -1.0)


func torch_count() -> int:
	return _torches


# --- pieces --------------------------------------------------------------------------

## A wall torch: iron bracket, wooden handle, a flame and a softly wobbling light.
func torch(f: Transform3D, side: float, w: float, height: float) -> void:
	var base := f.translated_local(Vector3(side * (w - 0.05), height, 0))
	scenery.add_box("iron", Vector3(0.5, 0.08, 0.08), base.translated_local(Vector3(-side * 0.25, 0, 0)))
	scenery.add_box("iron", Vector3(0.1, 0.25, 0.1), base.translated_local(Vector3(-side * 0.48, 0.05, 0)))
	var handle := base.translated_local(Vector3(-side * 0.48, -0.25, 0)).rotated_local(Vector3.FORWARD, side * 0.25)
	scenery.add_cyl("wood", 0.05, 0.55, handle, 5, 0.07)
	var tip := base.translated_local(Vector3(-side * 0.55, 0.3, 0))
	scenery.add_cone("flame", 0.13, 0.42, tip, 6)
	scenery.add_sphere("flame", 0.1, tip.translated_local(Vector3(0, 0.08, 0)), 3, 5)
	var light := scenery.add_flicker_light(tip.translated_local(Vector3(-side * 0.5, 0.25, 0)).origin, TORCH_COLOR, 3.6, 20.0, 0.0)
	light.flame = true
	_torches += 1


## A cluster of church candles on the floor, optionally with a faint light.
func candles(xf: Transform3D, count: int, lit: bool) -> void:
	for i in count:
		var p := xf.translated_local(Vector3(scenery.rng.randf_range(-0.35, 0.35), 0, scenery.rng.randf_range(-0.5, 0.5)))
		var tall := scenery.rng.randf_range(0.08, 0.4)
		var r := scenery.rng.randf_range(0.03, 0.06)
		scenery.add_cyl("wax", r, tall, p, 6)
		scenery.add_sphere("flame", 0.025, p.translated_local(Vector3(0, tall + 0.04, 0)), 2, 4)
	if lit:
		var light := scenery.add_flicker_light(xf.origin + Vector3(0, 0.6, 0), Color(1.0, 0.65, 0.3), 0.7, 5.0, 0.0)
		light.flame = true


## A heap of skulls on the floor.
func skull_pile(xf: Transform3D, count: int) -> void:
	if not place_skull.is_valid():
		return
	for i in count:
		var ring := i % 4
		var p := xf.translated_local(Vector3(cos(i * 1.7) * 0.22 * ring, int(i / 4.0) * 0.14, sin(i * 1.7) * 0.22 * ring))
		place_skull.call(Transform3D(xf.basis.rotated(Vector3.UP, scenery.rng.randf_range(-0.8, 0.8)), p.origin))


## A shaft of pale light through an iron street grate in the vault.
func shaft(f: Transform3D, lateral: float, top: float) -> void:
	var c := f.translated_local(Vector3(lateral, top - 0.2, 0))
	scenery.add_box("grate_glow", Vector3(2.0, 0.05, 2.0), c.translated_local(Vector3(0, 0.12, 0)))
	for i in 5:
		var o := -0.8 + i * 0.4
		scenery.add_box("iron", Vector3(2.2, 0.1, 0.08), c.translated_local(Vector3(0, 0, o)))
		scenery.add_box("iron", Vector3(0.08, 0.1, 2.2), c.translated_local(Vector3(o, 0, 0)))
	scenery.add_cyl("beam", 1.9, top - 0.3, f.translated_local(Vector3(lateral, 0.02, 0)), 12, 1.0)
	var spot := SpotLight3D.new()
	spot.position = c.origin
	spot.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	spot.light_color = SHAFT_COLOR
	spot.light_energy = 7.0
	spot.spot_range = top + 4.0
	spot.spot_angle = 20.0
	spot.light_volumetric_fog_energy = 4.0
	scenery.add_node(spot)


# --- internals -----------------------------------------------------------------------

func _span(from_d: float, to_d: float) -> float:
	if shortcut != null:
		return clampf(to_d - from_d, 0.0, shortcut.length)
	var s := fposmod(to_d - from_d, scenery.track.length)
	return s if s > 0.0 else scenery.track.length


func _at(from_d: float, along: float) -> float:
	if shortcut != null:
		return clampf(from_d + along, 0.0, shortcut.length)
	return scenery.track.wrap_offset(from_d + along)


func _delta(a: float, b: float) -> float:
	if shortcut != null:
		return b - a
	return scenery.track.wrapped_delta(a, b)


func _bone_top(wall_h: float) -> float:
	return minf(2.4, wall_h - 0.4)


func _wall_key(style: String, wall_key: String) -> String:
	match style:
		"skulls":
			return "ossuary"
		"rock":
			return "rock"
	return wall_key


## Cross-section, right wall foot -> right springing -> arch -> left springing -> left wall foot.
func _profile(wl: float, wr: float, wall_h: float, crown: float) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(wr, -0.2)]
	for i in ARCH_SEGMENTS + 1:
		out.append(arch_point(wl, wr, wall_h, crown, PI * i / ARCH_SEGMENTS))
	out.append(Vector2(-wl, -0.2))
	return out


## One strip between two profile points, swept from frame f0 to f1, facing the axis.
func _surface(f0: Transform3D, f1: Transform3D, a: Vector2, b: Vector2, key: String,
		wl: float, wr: float, wall_h: float) -> void:
	var p0 := f0 * Vector3(a.x, a.y, 0)
	var p1 := f0 * Vector3(b.x, b.y, 0)
	var p2 := f1 * Vector3(b.x, b.y, 0)
	var p3 := f1 * Vector3(a.x, a.y, 0)
	var centroid := (p0 + p1 + p2 + p3) * 0.25
	var axis := f0 * Vector3((wr - wl) * 0.5, minf((a.y + b.y) * 0.5, wall_h), 0)
	var st := scenery._st(key, centroid)
	scenery._quad(st, p0, p1, p2, p3, centroid * 2.0 - axis)


func _rib(f: Transform3D, wl: float, wr: float, wall_h: float, crown: float, key: String, left_ok: bool, right_ok: bool) -> void:
	var inset := 0.3
	var prev := arch_point(wl - inset, wr - inset, wall_h, crown - inset, 0.0)
	for i in range(1, ARCH_SEGMENTS + 1):
		var cur := arch_point(wl - inset, wr - inset, wall_h, crown - inset, PI * i / ARCH_SEGMENTS)
		var a := f * Vector3(prev.x, prev.y, 0)
		var b := f * Vector3(cur.x, cur.y, 0)
		var z := (b - a).normalized()
		var x := -f.basis.z
		var y := z.cross(x).normalized()
		x = y.cross(z)
		scenery.add_box(key, Vector3(0.7, 0.5, a.distance_to(b) + 0.15), Transform3D(Basis(x, y, z), (a + b) * 0.5))
		prev = cur
	for side: float in [-1.0, 1.0]:
		if (side < 0.0 and not left_ok) or (side > 0.0 and not right_ok):
			continue
		var w := wr if side > 0.0 else wl
		scenery.add_box(key, Vector3(0.6, wall_h + 0.2, 0.8), f.translated_local(Vector3(side * (w - 0.25), wall_h * 0.5 - 0.1, 0)))


## Three rows of real skulls set into the bone wall, and a row on its top ledge.
func _skull_rows(f: Transform3D, side: float, w: float, wall_h: float) -> void:
	if not place_skull.is_valid():
		return
	var top := _bone_top(wall_h)
	var face := f.basis * Vector3(-side, 0, 0)
	var look := Basis.looking_at(face, Vector3.UP)
	scenery.add_box("slab", Vector3(0.45, 0.12, STEP + 0.05), f.translated_local(Vector3(side * (w - 0.2), top, -STEP * 0.5)))
	for row: float in [0.8, top + 0.06]:
		var inset := 0.12 if row < top else 0.28
		var s := scenery.rng.randf_range(0.0, 0.1)
		while s < STEP:
			var p := f * Vector3(side * (w - inset), row, -s)
			var b := look.rotated(Vector3.UP, scenery.rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * scenery.rng.randf_range(0.9, 1.15))
			place_skull.call(Transform3D(b, p))
			s += scenery.rng.randf_range(0.27, 0.33)


## Burial niches in three rows: most sealed with slabs, a few open with a skull inside.
func _niches(f: Transform3D, side: float, w: float, wall_h: float, k: int) -> void:
	var face := Basis.looking_at(f.basis * Vector3(-side, 0, 0), Vector3.UP)
	for row in 3:
		var y := 0.55 + row * 0.8
		if y + 0.4 > wall_h - 0.2:
			break
		for col in 2:
			var z := -1.0 - col * 1.6
			var c := f.translated_local(Vector3(side * (w - 0.04), y, z))
			scenery.add_box("niche", Vector3(0.08, 0.55, 1.3), c)
			if (row + col + k) % 3 == 0:
				if place_skull.is_valid():
					place_skull.call(Transform3D(face, (f * Vector3(side * (w - 0.18), y - 0.2, z))))
			else:
				scenery.add_box("slab", Vector3(0.1, 0.6, 1.4), c.translated_local(Vector3(-side * 0.05, 0, 0)))


func _sarcophagus(xf: Transform3D) -> void:
	if scenery.edge_distance(xf.origin) < 1.6:
		return
	scenery.add_box("slab", Vector3(0.95, 0.7, 2.2), xf.translated_local(Vector3(0, 0.35, 0)))
	scenery.add_box("rib", Vector3(1.1, 0.16, 2.35), xf.translated_local(Vector3(0, 0.78, 0)))
	scenery.add_box("rib", Vector3(0.12, 0.06, 1.3), xf.translated_local(Vector3(0, 0.89, 0)))
	scenery.add_box("rib", Vector3(0.7, 0.06, 0.12), xf.translated_local(Vector3(0, 0.89, -0.25)))


func _pipes(f: Transform3D, side: float, w: float, wall_h: float) -> void:
	for i in 3:
		var y := wall_h - 0.5 - i * 0.38
		var r := 0.16 if i == 0 else 0.1
		var p := f.translated_local(Vector3(side * (w - 0.3 - r), y, 0)).rotated_local(Vector3.RIGHT, -PI * 0.5)
		scenery.add_cyl("pipe", r, STEP + 0.05, p, 6)
	scenery.add_box("iron", Vector3(0.5, 0.06, 0.1), f.translated_local(Vector3(side * (w - 0.25), wall_h - 1.4, 0)))


func _red_lamp(f: Transform3D, side: float, w: float, wall_h: float) -> void:
	var p := f.translated_local(Vector3(side * (w - 0.15), wall_h - 0.2, 0))
	scenery.add_box("iron", Vector3(0.3, 0.3, 0.45), p)
	scenery.add_box("red_lamp", Vector3(0.12, 0.2, 0.35), p.translated_local(Vector3(-side * 0.18, 0, 0)))
	scenery.add_flicker_light(p.translated_local(Vector3(-side * 0.8, -0.3, 0)).origin, Color(1.0, 0.12, 0.08), 1.8, 11.0, 0.15, "red_lamp")


## Timber pit prop against a quarry wall.
func _prop(f: Transform3D, side: float, w: float, wall_h: float) -> void:
	scenery.add_box("wood", Vector3(0.35, wall_h + 0.3, 0.35), f.translated_local(Vector3(side * (w - 0.45), (wall_h + 0.3) * 0.5, 0)))
	scenery.add_box("wood", Vector3(0.9, 0.3, 0.35), f.translated_local(Vector3(side * (w - 0.6), wall_h - 0.1, 0)))


## Stone face around a span's end opening (dir 1 = faces back down the route).
func _cap(f: Transform3D, wl: float, wr: float, wall_h: float, crown: float, key: String, dir: float) -> void:
	var profile := _profile(wl, wr, wall_h, crown)
	var axis := Vector2((wr - wl) * 0.5, wall_h * 0.5)
	var ring := 10.0
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		var ao := a + (Vector2(signf(a.x - axis.x), 0.0) if i == 0 or i == profile.size() - 1 else (a - axis).normalized()) * ring
		var bo := b + (Vector2(signf(b.x - axis.x), 0.0) if i + 1 == profile.size() - 1 else (b - axis).normalized()) * ring
		var pts: Array[Vector3] = [f * Vector3(a.x, a.y, 0), f * Vector3(b.x, b.y, 0), f * Vector3(bo.x, bo.y, 0), f * Vector3(ao.x, ao.y, 0)]
		var blocked := false
		for p in [pts[2], pts[3]]:
			if scenery.edge_distance(p) < 1.0:
				blocked = true
		if blocked:
			continue
		var centroid := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
		# Face the side the span is on.
		scenery._quad(scenery._st(key, centroid), pts[0], pts[1], pts[2], pts[3], centroid + f.basis.z * dir)
