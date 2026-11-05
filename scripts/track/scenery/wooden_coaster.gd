class_name WoodenCoaster
extends RefCounted
## A large wooden lattice roller coaster built along a 3D path (track-local
## points, y = rail height). Twin rails on ties, a catwalk, and timber
## "bents" (two posts with ledgers and X-bracing) down to the ground every
## few metres. Where a bent would stand on a road, a steel gantry spans the
## road instead, with legs outside the barriers. Sections can be left broken.
##
## Materials (registered on the scenery): wood_key for timber, rail_key for
## the rails, steel_key for gantries.


static func build(scenery: TrackScenery, path: PackedVector3Array, wood_key: String, rail_key: String,
		steel_key: String, bent_spacing: float = 4.0, broken: Array = []) -> void:
	var travelled := 0.0
	var next_bent := 0.0
	var next_gantry := 0.0
	for i in path.size() - 1:
		var p0 := path[i]
		var p1 := path[i + 1]
		var seg := p1 - p0
		var length := seg.length()
		if length < 0.01:
			continue
		var dir := seg / length
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		var right := flat.cross(Vector3.UP).normalized()
		var is_broken := false
		for r in broken:
			if i >= int(r.x) and i <= int(r.y):
				is_broken = true
		var basis := Basis.looking_at(dir, Vector3.UP)
		var mid := (p0 + p1) * 0.5
		if not is_broken:
			for side in [-0.75, 0.75]:
				scenery.add_box(rail_key, Vector3(0.22, 0.28, length + 0.1), Transform3D(basis, mid + right * float(side)))
			# Ties every metre and a catwalk plank on one side.
			var ties := int(length)
			for t in ties:
				var q := p0 + dir * (t + 0.5)
				scenery.add_box(wood_key, Vector3(2.4, 0.18, 0.25), Transform3D(basis, q - Vector3(0, 0.22, 0)))
			scenery.add_box(wood_key, Vector3(0.7, 0.08, length + 0.1), Transform3D(basis, mid + right * 1.7 - Vector3(0, 0.3, 0)))
			scenery.add_box(wood_key, Vector3(0.08, 0.08, length + 0.1), Transform3D(basis, mid + right * 2.0 + Vector3(0, 0.8, 0)))
		# Structure below the track.
		var d := 0.0
		while d < length:
			if travelled + d >= next_bent:
				var at := p0 + dir * d
				var foot := Vector3(at.x, 0.0, at.z)
				if scenery.clear(foot + right * 1.8, 0.8) and scenery.clear(foot - right * 1.8, 0.8):
					_bent(scenery, at, right, flat, wood_key)
				elif travelled + d >= next_gantry:
					_gantry(scenery, at, right, steel_key)
					next_gantry = travelled + d + 14.0
				next_bent = travelled + d + bent_spacing
			d += 0.5
		travelled += length


## Two posts with horizontal ledgers and X-bracing, plus a diagonal back-brace.
static func _bent(scenery: TrackScenery, at: Vector3, right: Vector3, forward: Vector3, wood_key: String) -> void:
	var h := at.y - 0.35
	if h < 1.0:
		return
	var half := 1.8
	for side in [-1.0, 1.0]:
		var base: Vector3 = Vector3(at.x, 0, at.z) + right * half * side
		scenery.add_box(wood_key, Vector3(0.3, h, 0.3), Transform3D(Basis.looking_at(forward, Vector3.UP), base + Vector3(0, h * 0.5, 0)))
	var level := 0.0
	while level < h:
		var top := minf(level + 4.0, h)
		var y0 := level
		var y1 := top
		var c := Vector3(at.x, 0, at.z)
		scenery.add_box(wood_key, Vector3(0.15, 0.2, 0.15), Transform3D(Basis.IDENTITY, c + Vector3(0, y1, 0))) # knot
		var ledger := Transform3D(Basis.looking_at(right, Vector3.UP), c + Vector3(0, y1, 0))
		scenery.add_box(wood_key, Vector3(0.12, 0.2, half * 2.0), ledger)
		# X-bracing between the posts.
		for diag in [-1.0, 1.0]:
			var a: Vector3 = c + right * half * diag + Vector3(0, y0, 0)
			var b: Vector3 = c - right * half * diag + Vector3(0, y1, 0)
			var v: Vector3 = b - a
			scenery.add_box(wood_key, Vector3(0.1, 0.1, v.length()), Transform3D(Basis.looking_at(v.normalized(), Vector3.UP), (a + b) * 0.5))
		level = top


## Steel portal spanning a road: legs found outward until they're clear of it.
static func _gantry(scenery: TrackScenery, at: Vector3, right: Vector3, steel_key: String) -> void:
	var legs: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var found := false
		for step in range(2, 40, 2):
			var p: Vector3 = Vector3(at.x, 0, at.z) + right * side * step
			if scenery.clear(p, 1.2):
				legs.append(p)
				found = true
				break
		if not found:
			return
	var beam_y := at.y - 1.0
	for leg in legs:
		scenery.add_box(steel_key, Vector3(0.8, beam_y, 0.8), Transform3D(Basis.IDENTITY, leg + Vector3(0, beam_y * 0.5, 0)))
	var span := legs[1] - legs[0]
	var beam_mid := (legs[0] + legs[1]) * 0.5 + Vector3(0, beam_y, 0)
	scenery.add_box(steel_key, Vector3(0.9, 1.2, span.length() + 1.0), Transform3D(Basis.looking_at(span.normalized(), Vector3.UP), beam_mid))
