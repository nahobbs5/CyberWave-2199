class_name SceneryTerrain
extends RefCounted
## Overgrown, waterlogged terrain for a TrackScenery (visual only; the track's
## flat collision slab stays). A noise heightmap over the layout bounds,
## flattened to just below road level near every road, split into a grass
## mesh (higher ground) and a mud mesh (low, wet ground), with one murky
## reflective water plane so the hollows read as flooded.


## bounds: track-local XZ rectangle. cell: grid size in metres. water_key ""
## skips the flood plane. carve (optional) is func(x, z) -> float, added to the
## height everywhere, even under roads (ravines under bridges).
static func build(scenery: TrackScenery, bounds: Rect2, cell: float = 7.0, amplitude: float = 2.2,
		water_level: float = -0.12, grass_key: String = "terrain_grass", mud_key: String = "terrain_mud",
		water_key: String = "terrain_water", seed_value: int = 1, carve: Callable = Callable()) -> void:
	var track := scenery.track
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var bank := track.road_width * 0.5 + track.barrier_thickness + 5.0
	var nx := int(bounds.size.x / cell) + 1
	var nz := int(bounds.size.y / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := bounds.position.x + ix * cell
			var z := bounds.position.y + iz * cell
			var h := noise.get_noise_2d(x, z) * amplitude + 0.35
			# Dry, level banks along the roads (just below the road surface).
			var off_road := scenery.edge_distance(Vector3(x, 0, z)) - (bank - track.road_width * 0.5)
			var t := clampf(off_road / 14.0, 0.0, 1.0)
			var final_h := lerpf(-0.04, h, t * t * (3.0 - 2.0 * t))
			if carve.is_valid():
				final_h += float(carve.call(x, z))
			heights[iz * nx + ix] = final_h
	# One grass and one mud mesh per chunk, so off-screen terrain is culled.
	var tools := {}
	for iz in nz - 1:
		for ix in nx - 1:
			var p := []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var gx: int = ix + c[0]
				var gz: int = iz + c[1]
				p.append(Vector3(bounds.position.x + gx * cell, heights[gz * nx + gx], bounds.position.y + gz * cell))
			var avg: float = (p[0].y + p[1].y + p[2].y + p[3].y) * 0.25
			var key := "%s@%d,%d" % ["g" if avg > 0.25 else "m", int(p[0].x / TrackScenery.CHUNK), int(p[0].z / TrackScenery.CHUNK)]
			if not tools.has(key):
				var nst := SurfaceTool.new()
				nst.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = nst
			var st: SurfaceTool = tools[key]
			_tri(st, p[0], p[2], p[1])
			_tri(st, p[0], p[3], p[2])
	for key in tools:
		var is_grass := (key as String).begins_with("g")
		scenery.add_mesh_instance((tools[key] as SurfaceTool).commit(),
				scenery.get_material(grass_key if is_grass else mud_key), "Terrain_" + (key as String).replace(",", "_"))
	if water_key == "":
		return
	var water := PlaneMesh.new()
	water.size = bounds.size
	var wi := scenery.add_mesh_instance(water, scenery.get_material(water_key), "FloodWater")
	wi.position = Vector3(bounds.get_center().x, water_level, bounds.get_center().y)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)
