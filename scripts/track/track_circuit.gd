@tool
class_name TrackCircuit
extends Node3D
## Graybox circuit generated from a closed loop of control points.
##
## Builds the road surface, edge and centre markings, collidable barriers with
## neon strips, a ground slab, a start gantry, trackside lights and chevron
## signs on sharp corners. It also answers track-space questions (nearest
## offset, safe respawn transforms) for recovery, checkpoints, the starting
## grid and AI racing lines.
##
## Children: TrackShortcut nodes add alternate routes (roads, barriers with
## openings at the junctions, copies of bypassed checkpoint gates), and
## TrackFeature nodes (boost pads, rings, hazards...) are placed by offset.
## Positions on a shortcut map onto the main loop, so every query below
## works on either route.
##
## Generated nodes are rebuilt on load and are not saved into the scene, so
## edit the exported values (or control points) rather than the generated
## children. Runs in the editor too so the layout is visible while editing.

const GENERATED_PREFIX := "_Gen"

## Emitted when a vehicle enters checkpoint gate index (0 = start/finish line).
signal checkpoint_crossed(index: int, body: Node3D)

## Centre-line control points in local space (closed loop, driven in order).
## The first point is distance 0; the start line sits start_line_offset after it.
## Scenes override this (test_circuit.tscn holds the real layout); the default
## is a simple oval so a bare TrackCircuit still builds something drivable.
@export var control_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, 0, 120), Vector3(0, 0, -120), Vector3(40, 0, -160), Vector3(80, 0, -120),
	Vector3(80, 0, 120), Vector3(40, 0, 160),
]):
	set(value):
		control_points = value
		_queue_rebuild()
@export var road_width: float = 18.0:
	set(value):
		road_width = value
		_queue_rebuild()
@export var sample_spacing: float = 3.0
@export var barrier_height: float = 1.4
## Invisible collision height of the barriers. Taller than the visible wall so
## a car hitting it sideways can't climb over and leave the circuit.
@export var barrier_collision_height: float = 4.0
@export var barrier_thickness: float = 1.0
## Distance along the circuit where the start/finish line sits.
@export var start_line_offset: float = 60.0
## Where the free-drive car spawns, measured back from the start line.
@export var spawn_distance_behind_line: float = 15.0

@export_group("Checkpoints")
## Evenly spaced gates; gate 0 is the start/finish line (GDD 14.3).
@export var checkpoint_count: int = 8
@export var checkpoint_depth: float = 4.0

@export_group("Weapon Crates")
## Track offsets of each row of crates (layout-specific; set in the scene).
@export var crate_row_offsets: PackedFloat32Array = PackedFloat32Array()
## Lateral positions (metres right of centre) of the crates in each row.
@export var crate_lateral_positions: PackedFloat32Array = PackedFloat32Array([-6.0, -2.0, 2.0, 6.0])

@export_group("Track Coins")
## Distance along the track of each coin (GDD 9.2: up to 10 per lap keeps a
## 3-lap race at the 30-coin cap).
@export var coin_offsets: PackedFloat32Array = PackedFloat32Array()
## Sideways offset of each coin from the racing line (m, + = right).
@export var coin_laterals: PackedFloat32Array = PackedFloat32Array()
@export_group("Starting Grid")
## Distance from the start line back to the pole position slot.
@export var grid_first_row_gap: float = 8.0
@export var grid_row_spacing: float = 9.0
## Extra setback of the right-hand slot in each row (staggered grid).
@export var grid_stagger: float = 4.5
@export var grid_lateral: float = 4.0
@export_group("Look")
@export var road_color: Color = Color(0.13, 0.13, 0.16)
@export var edge_line_color: Color = Color(0.0, 0.85, 1.0)
@export var ground_color: Color = Color(0.05, 0.05, 0.08)
@export var barrier_color: Color = Color(0.22, 0.22, 0.27)
## Glow of the barrier-top neon strips and the road edge lines (lower them on
## dark, gritty tracks, but keep them visible: they mark the racing edge).
@export var neon_energy: float = 3.0
@export var edge_line_energy: float = 1.5
## Faded centre markings: most dashes worn away, the rest dull.
@export var faded_markings: bool = false
## Draw the centre dashes at all (off for dirt roads).
@export var centre_markings: bool = true
## Hide the flat ground slab's visual (scenery supplies its own terrain);
## the collision slab always stays.
@export var ground_visible: bool = true
@export var neon_left_color: Color = Color(0.0, 0.9, 1.0)
@export var neon_right_color: Color = Color(1.0, 0.1, 0.8)
@export var light_colors: PackedColorArray = PackedColorArray([Color(0.0, 0.85, 1.0), Color(1.0, 0.2, 0.85)])
@export var light_energy: float = 3.0
## Chevron boards on the outside of corners tighter than this radius (m).
## 0 turns them off.
@export var corner_sign_radius: float = 140.0
@export var corner_sign_color: Color = Color(1.0, 0.15, 0.8)
## Board width and its gap from the barrier (narrow boards for tunnels).
@export var corner_sign_width: float = 4.0
@export var corner_sign_gap: float = 1.2
## Optional Poly Haven texture set names (assets/textures/polyhaven/<name>/)
## for the road, the barrier walls and the ground. Tinted by the colours above.
@export var road_texture: String = ""
@export var barrier_texture: String = ""
@export var ground_texture: String = ""
@export_group("")
## Ground extends this far beyond the layout's bounds on every side.
@export var ground_margin: float = 300.0
@export var light_spacing: float = 90.0

var curve: Curve3D
var length: float = 0.0
var shortcuts: Array[TrackShortcut] = []

var _rebuild_queued: bool = false


## Set while the loading screen adds a track: _ready then leaves the build to
## it, so it can run build_base() and each placeable in steps with a progress bar.
static var defer_build: bool = false


func _ready() -> void:
	if not defer_build:
		rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	if not build_base():
		return
	for node in placeables():
		node.place_on_track(self)


## Builds the curve, road, barriers, gantry, lights, signs and checkpoints, but
## not the placeables. False if the curve is empty (nothing to place on).
func build_base() -> bool:
	_rebuild_queued = false
	_build_curve()
	for child in get_children():
		if child.name.begins_with(GENERATED_PREFIX):
			remove_child(child)
			child.queue_free()
	if length <= 0.0:
		return false
	shortcuts.clear()
	for child in get_children():
		if child is TrackShortcut:
			(child as TrackShortcut).build_route(self)
			if (child as TrackShortcut).is_valid():
				shortcuts.append(child)
	_build_ground()
	_build_road()
	_build_barriers()
	_build_start_gantry()
	_build_lights()
	_build_corner_signs()
	_build_checkpoints()
	return true


## Children that dress themselves along the road (features, scenery).
func placeables() -> Array[Node]:
	var out: Array[Node] = []
	for child in get_children():
		if child.has_method("place_on_track"):
			out.append(child)
	return out


# --- Track-space queries -------------------------------------------------

func wrap_offset(offset: float) -> float:
	return fposmod(offset, length) if length > 0.0 else 0.0


## Shortest signed distance along the loop from one offset to another.
func wrapped_delta(from_offset: float, to_offset: float) -> float:
	if length <= 0.0:
		return 0.0
	return fposmod(to_offset - from_offset + length * 0.5, length) - length * 0.5


func get_offset_at(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var sc := _shortcut_at_local(local)
	if sc != null:
		return wrap_offset(sc.to_main_offset(sc.local_offset(local)))
	return wrap_offset(curve.get_closest_offset(local))


## The shortcut a position is on (off the main road, on the shortcut road), or null.
func get_shortcut_at(world_pos: Vector3) -> TrackShortcut:
	return _shortcut_at_local(to_local(world_pos))


## Driving direction at a position (follows a shortcut when on one).
func get_direction_at(world_pos: Vector3) -> Vector3:
	var local := to_local(world_pos)
	var sc := _shortcut_at_local(local)
	if sc != null:
		return (global_transform.basis * sc.tangent_at(sc.local_offset(local))).normalized()
	return get_tangent_at(curve.get_closest_offset(local))


func _shortcut_at_local(local: Vector3) -> TrackShortcut:
	if shortcuts.is_empty():
		return null
	var closest := curve.get_closest_point(local)
	var main_lateral := Vector2(local.x - closest.x, local.z - closest.z).length()
	if main_lateral <= road_width * 0.5:
		return null
	for sc in shortcuts:
		if sc.lateral_distance(local) <= sc.road_width * 0.5 + barrier_thickness:
			return sc
	return null


func get_center_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(wrap_offset(offset)))


func get_tangent_at(offset: float) -> Vector3:
	var a := curve.sample_baked(wrap_offset(offset - 1.0))
	var b := curve.sample_baked(wrap_offset(offset + 1.0))
	var local_dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return (global_transform.basis * local_dir).normalized()


## Horizontal distance from the centre line, in main-road terms: on a
## shortcut it's scaled so road_width * 0.5 is that road's edge too.
func get_lateral_distance(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var closest := curve.get_closest_point(local)
	var lateral := Vector2(local.x - closest.x, local.z - closest.z).length()
	for sc in shortcuts:
		var d := sc.lateral_distance(local) + (road_width - sc.road_width) * 0.5
		lateral = minf(lateral, d)
	return lateral


func is_on_road(world_pos: Vector3) -> bool:
	return get_lateral_distance(world_pos) <= road_width * 0.5


## Upright transform facing the driving direction, lateral metres to the right.
func get_safe_transform(offset: float, lateral: float = 0.0, height: float = 0.9) -> Transform3D:
	var tangent := get_tangent_at(offset)
	var right := tangent.cross(Vector3.UP).normalized()
	var pos := get_center_at(offset) + right * lateral + Vector3.UP * height
	return Transform3D(Basis.looking_at(tangent, Vector3.UP), pos)


func get_spawn_offset() -> float:
	return wrap_offset(start_line_offset - spawn_distance_behind_line)


func get_spawn_transform() -> Transform3D:
	return get_safe_transform(get_spawn_offset())


func get_checkpoint_offset(index: int) -> float:
	return wrap_offset(start_line_offset + float(index) * length / float(checkpoint_count))


## Grid slot 0 is pole position; slots alternate left/right, rows going back.
func get_grid_offset(slot: int) -> float:
	var row := slot / 2
	var setback := grid_first_row_gap + float(row) * grid_row_spacing + (grid_stagger if slot % 2 == 1 else 0.0)
	return wrap_offset(start_line_offset - setback)


func get_grid_transform(slot: int) -> Transform3D:
	var lateral := grid_lateral if slot % 2 == 1 else -grid_lateral
	return get_safe_transform(get_grid_offset(slot), lateral)


# --- Generation ------------------------------------------------------------

func _build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 1.0
	var n := control_points.size()
	if n < 3:
		length = 0.0
		return
	# Catmull-Rom handles give a smooth closed loop through every point.
	for i in n + 1:
		var p := control_points[i % n]
		var prev := control_points[(i - 1 + n) % n]
		var next := control_points[(i + 1) % n]
		var handle := (next - prev) / 6.0
		curve.add_point(p, -handle, handle)
	length = curve.get_baked_length()


func _samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := maxi(8, int(length / sample_spacing))
	for i in count:
		var offset := length * float(i) / float(count)
		var center := curve.sample_baked(offset)
		var a := curve.sample_baked(wrap_offset(offset - 1.0))
		var b := curve.sample_baked(wrap_offset(offset + 1.0))
		var tangent := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var right := tangent.cross(Vector3.UP).normalized()
		result.append({"offset": offset, "center": center, "tangent": tangent, "right": right})
	return result


func _material(color: Color, emission: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


## Plain colour, or a world-mapped texture tinted by the colour.
func _surface_material(texture_name: String, color: Color, metres_per_tile: float, roughness: float) -> StandardMaterial3D:
	if texture_name == "":
		return _material(color, 0.0, roughness)
	return TrackScenery.texture_material(texture_name, color, metres_per_tile, roughness)


func _add_generated(node: Node, node_name: String) -> void:
	node.name = GENERATED_PREFIX + node_name
	add_child(node)


func _build_ground() -> void:
	# Size the slab to the layout's bounds plus a margin on every side.
	var points := curve.get_baked_points()
	for sc in shortcuts:
		points.append_array(sc.curve.get_baked_points())
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var center := (lo + hi) * 0.5
	var extent := (hi - lo) + Vector2.ONE * ground_margin * 2.0

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(extent.x, 2.0, extent.y)
	shape.shape = box
	shape.position = Vector3(center.x, -1.0, center.y)
	body.add_child(shape)

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = extent
	plane.material = _surface_material(ground_texture, ground_color, 6.0, 0.95)
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(center.x, 0.0, center.y)
	mesh_instance.visible = ground_visible
	body.add_child(mesh_instance)
	_add_generated(body, "Ground")


## Adds a flat strip quad between lateral offsets [inner, outer] for a sample pair.
func _strip_quad(st: SurfaceTool, s0: Dictionary, s1: Dictionary, inner: float, outer: float, y: float) -> void:
	var lift := Vector3(0.0, y, 0.0)
	var a: Vector3 = s0.center + s0.right * inner + lift
	var b: Vector3 = s0.center + s0.right * outer + lift
	var c: Vector3 = s1.center + s1.right * outer + lift
	var d: Vector3 = s1.center + s1.right * inner + lift
	for v in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


func _build_road() -> void:
	var samples := _samples()
	var count := samples.size()
	var half := road_width * 0.5

	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dashes := SurfaceTool.new()
	dashes.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in count:
		var s0 := samples[i]
		var s1 := samples[(i + 1) % count]
		_strip_quad(road, s0, s1, -half, half, 0.02)
		_strip_quad(edges, s0, s1, -half, -half + 0.4, 0.04)
		_strip_quad(edges, s0, s1, half - 0.4, half, 0.04)
		if centre_markings and i % 4 < 2 and (not faded_markings or (i * 7919) % 13 < 5):
			_strip_quad(dashes, s0, s1, -0.15, 0.15, 0.04)

	# Shortcut roads sit a few millimetres higher where they overlap the main one.
	for sc in shortcuts:
		var ss := _shortcut_samples(sc)
		var sh := sc.road_width * 0.5
		for i in ss.size() - 1:
			_strip_quad(road, ss[i], ss[i + 1], -sh, sh, 0.03)
			_strip_quad(edges, ss[i], ss[i + 1], -sh, -sh + 0.3, 0.05)
			_strip_quad(edges, ss[i], ss[i + 1], sh - 0.3, sh, 0.05)

	var holder := Node3D.new()
	_add_generated(holder, "Road")
	_add_mesh(holder, "Surface", road, _surface_material(road_texture, road_color, 5.0, 0.55))
	_add_mesh(holder, "EdgeLines", edges, _material(edge_line_color, edge_line_energy))
	if faded_markings:
		_add_mesh(holder, "CentreDashes", dashes, _material(Color(0.42, 0.41, 0.38), 0.0, 0.9))
	else:
		_add_mesh(holder, "CentreDashes", dashes, _material(Color(0.85, 0.85, 0.9), 0.4))


func _add_mesh(parent: Node, node_name: String, st: SurfaceTool, mat: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)


func _build_barriers() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.1
	body.physics_material_override = physics_material

	var walls: Array[Transform3D] = []
	var lengths: Array[float] = []
	var left: Array[Transform3D] = []
	var left_lengths: Array[float] = []
	var right: Array[Transform3D] = []
	var right_lengths: Array[float] = []
	# Main loop: walls are left out where a shortcut road crosses them.
	var main := _samples()
	var edge := road_width * 0.5 + barrier_thickness * 0.5
	for side in [-1.0, 1.0]:
		for i in main.size():
			var s0 := main[i]
			var s1 := main[(i + 1) % main.size()]
			var p0: Vector3 = s0.center + s0.right * edge * side
			var p1: Vector3 = s1.center + s1.right * edge * side
			if _inside_shortcut((p0 + p1) * 0.5, null):
				continue
			_add_wall(body, p0, p1, walls, lengths, left if side < 0.0 else right, left_lengths if side < 0.0 else right_lengths)
	# Shortcuts: walls are left out inside the main road (the junctions).
	for sc in shortcuts:
		var ss := _shortcut_samples(sc)
		var sc_edge := sc.road_width * 0.5 + barrier_thickness * 0.5
		for side in [-1.0, 1.0]:
			for i in ss.size() - 1:
				var p0: Vector3 = ss[i].center + ss[i].right * sc_edge * side
				var p1: Vector3 = ss[i + 1].center + ss[i + 1].right * sc_edge * side
				var mid := (p0 + p1) * 0.5
				if _main_lateral(mid) < road_width * 0.5 + barrier_thickness * 1.5 or _inside_shortcut(mid, sc):
					continue
				_add_wall(body, p0, p1, walls, lengths, left if side < 0.0 else right, left_lengths if side < 0.0 else right_lengths)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(barrier_thickness, barrier_height, 1.0)
	var wall_visual := _multimesh(wall_mesh, _surface_material(barrier_texture, barrier_color, 2.5, 0.8), walls, lengths)
	wall_visual.name = "Walls"
	body.add_child(wall_visual)
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(barrier_thickness * 0.5, 0.12, 1.0)
	var strip_up := Vector3(0.0, barrier_height * 0.5 + 0.06, 0.0)
	var lx: Array[Transform3D] = []
	for xf in left:
		lx.append(xf.translated(strip_up))
	var rx: Array[Transform3D] = []
	for xf in right:
		rx.append(xf.translated(strip_up))
	var left_strip := _multimesh(strip_mesh, _material(neon_left_color, neon_energy), lx, left_lengths)
	left_strip.name = "NeonLeft"
	body.add_child(left_strip)
	var right_strip := _multimesh(strip_mesh, _material(neon_right_color, neon_energy), rx, right_lengths)
	right_strip.name = "NeonRight"
	body.add_child(right_strip)
	# Added last: adding shapes to a body already in the tree rebuilds its
	# physics shape every time (seconds for a whole lap).
	_add_generated(body, "Barriers")


func _add_wall(body: StaticBody3D, p0: Vector3, p1: Vector3, walls: Array[Transform3D], lengths: Array[float],
		side_walls: Array[Transform3D], side_lengths: Array[float]) -> void:
	var dir := p1 - p0
	dir.y = 0.0
	var seg_length := dir.length()
	if seg_length < 0.01:
		return
	var mid := (p0 + p1) * 0.5 + Vector3(0.0, barrier_height * 0.5, 0.0)
	var xf := Transform3D(Basis.looking_at(dir / seg_length, Vector3.UP), mid)
	# Overlap neighbours slightly so outer-curve joints have no gaps.
	var padded := seg_length + barrier_thickness * 0.6
	walls.append(xf)
	lengths.append(padded)
	side_walls.append(xf)
	side_lengths.append(padded)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(barrier_thickness, barrier_collision_height, padded)
	shape.shape = box
	shape.transform = xf.translated(Vector3(0.0, (barrier_collision_height - barrier_height) * 0.5, 0.0))
	body.add_child(shape)


func _main_lateral(local: Vector3) -> float:
	var closest := curve.get_closest_point(local)
	return Vector2(local.x - closest.x, local.z - closest.z).length()


## True if a point lies on a shortcut road (other than `except`).
func _inside_shortcut(local: Vector3, except: TrackShortcut) -> bool:
	for sc in shortcuts:
		if sc != except and sc.lateral_distance(local) < sc.road_width * 0.5 + barrier_thickness:
			return true
	return false


## Open polyline samples along a shortcut (same format as _samples()).
func _shortcut_samples(sc: TrackShortcut) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := maxi(2, int(sc.length / sample_spacing) + 1)
	for i in count:
		var d := sc.length * float(i) / float(count - 1)
		var tangent := sc.tangent_at(d)
		result.append({"offset": d, "center": sc.point_at(d), "tangent": tangent,
				"right": tangent.cross(Vector3.UP).normalized()})
	return result


func _multimesh(mesh: Mesh, mat: Material, transforms: Array[Transform3D], z_scales: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var xf := transforms[i]
		xf.basis = xf.basis * Basis.from_scale(Vector3(1.0, 1.0, z_scales[i]))
		mm.set_instance_transform(i, xf)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = mat
	return instance


const START_LIGHTS_TEXTURE := "res://assets/ui/Racing Start Light Assembly.png"
const START_LIGHTS_SHADER := "res://assets/ui/start_lights.gdshader"
const GANTRY_IDLE_COLOR := Color(1.0, 0.4, 0.9)
## Where the solid housing sits inside the start-light image (UV): its bottom
## edge, and the ends of the side pipes (x from the edge, y = pipe centre).
const BOARD_HOUSING_BOTTOM_UV := 0.753
const BOARD_PIPE_UV := Vector2(0.04, 0.43)

var _start_board: ShaderMaterial
var _gantry_light: OmniLight3D
var _start_lights: int = 0


## Start lights on the gantry: 0 = all off, 1-3 = red lamps lit, 4 = green
## (go). The gantry's light follows (red, then green, then back to neon).
func set_start_lights(count: int) -> void:
	_start_lights = clampi(count, 0, 4)
	if _start_board != null:
		_start_board.set_shader_parameter("lit_count", _start_lights)
	if _gantry_light != null:
		match _start_lights:
			0:
				_gantry_light.light_color = GANTRY_IDLE_COLOR
			4:
				_gantry_light.light_color = Color(0.2, 1.0, 0.35)
			_:
				_gantry_light.light_color = Color(1.0, 0.12, 0.08)


func start_lights() -> int:
	return _start_lights


func _build_start_gantry() -> void:
	var holder := Node3D.new()
	_add_generated(holder, "StartGantry")
	var center := curve.sample_baked(wrap_offset(start_line_offset))
	var a := curve.sample_baked(wrap_offset(start_line_offset - 1.0))
	var b := curve.sample_baked(wrap_offset(start_line_offset + 1.0))
	var tangent := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	holder.transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), center)

	var span := road_width + barrier_thickness * 2.0 + 2.0
	# Checkered start/finish line.
	var tiles := 12
	var tile_w := road_width / float(tiles)
	for row in 2:
		for col in tiles:
			var tile := MeshInstance3D.new()
			var quad := BoxMesh.new()
			quad.size = Vector3(tile_w, 0.02, 1.0)
			tile.mesh = quad
			var white := (row + col) % 2 == 0
			tile.material_override = _material(Color(0.95, 0.95, 1.0) if white else Color(0.02, 0.02, 0.03), 0.6 if white else 0.0)
			tile.position = Vector3(-road_width * 0.5 + tile_w * (col + 0.5), 0.05, -0.5 + row)
			holder.add_child(tile)

	var pillar_mat := _material(Color(0.15, 0.15, 0.2), 0.0, 0.4)
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 8.0, 1.0)
		pillar.mesh = box
		pillar.material_override = pillar_mat
		pillar.position = Vector3(side * span * 0.5, 4.0, 0.0)
		holder.add_child(pillar)
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(span + 1.0, 1.4, 1.2)
	beam.mesh = beam_mesh
	beam.material_override = pillar_mat
	beam.position = Vector3(0.0, 8.0, 0.0)
	holder.add_child(beam)
	var sign_strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(span - 2.0, 0.5, 0.1)
	sign_strip.mesh = strip_mesh
	sign_strip.material_override = _material(Color(1.0, 0.15, 0.85), 4.0)
	sign_strip.position = Vector3(0.0, 8.0, 0.65)
	holder.add_child(sign_strip)
	var light := OmniLight3D.new()
	light.light_color = GANTRY_IDLE_COLOR
	light.light_energy = 4.0
	light.omni_range = 26.0
	light.position = Vector3(0.0, 6.0, 0.0)
	holder.add_child(light)
	_gantry_light = light
	# The start-light board on top of the beam, facing the grid (+Z, behind
	# the line).
	var board := MeshInstance3D.new()
	board.name = "StartLights"
	var quad := QuadMesh.new()
	var board_w := minf(span * 0.9, 16.0)
	var board_h := board_w / 3.0
	quad.size = Vector2(board_w, board_h)
	board.mesh = quad
	# The image has transparent margins: rest the housing itself on the beam.
	var beam_top := 8.7
	board.position = Vector3(0.0, beam_top + board_h * (BOARD_HOUSING_BOTTOM_UV - 0.5), 0.62)
	# Posts from the beam up to the board's side pipes.
	var pipe_y := board.position.y + board_h * (0.5 - BOARD_PIPE_UV.y)
	for side in [-1.0, 1.0]:
		var strut := MeshInstance3D.new()
		var strut_mesh := BoxMesh.new()
		strut_mesh.size = Vector3(0.35, pipe_y - beam_top + 0.2, 0.35)
		strut.mesh = strut_mesh
		strut.material_override = pillar_mat
		strut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strut.position = Vector3(side * board_w * (0.5 - BOARD_PIPE_UV.x), (beam_top + pipe_y + 0.2) * 0.5, 0.45)
		holder.add_child(strut)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_start_board = ShaderMaterial.new()
	_start_board.shader = load(START_LIGHTS_SHADER) as Shader
	_start_board.set_shader_parameter("board", load(START_LIGHTS_TEXTURE) as Texture2D)
	_start_board.set_shader_parameter("lit_count", _start_lights)
	board.material_override = _start_board
	holder.add_child(board)


func _build_lights() -> void:
	var holder := Node3D.new()
	_add_generated(holder, "TracksideLights")
	var count := maxi(1, int(length / light_spacing))
	for i in count:
		var offset := length * float(i) / float(count)
		var center := curve.sample_baked(offset)
		var a := curve.sample_baked(wrap_offset(offset - 1.0))
		var b := curve.sample_baked(wrap_offset(offset + 1.0))
		var right := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized().cross(Vector3.UP)
		var side := 1.0 if i % 2 == 0 else -1.0
		var light := OmniLight3D.new()
		light.light_color = light_colors[i % light_colors.size()] if not light_colors.is_empty() else Color.WHITE
		light.light_energy = light_energy
		light.omni_range = 32.0
		light.position = center + right * side * (road_width * 0.5 + 2.0) + Vector3(0.0, 6.0, 0.0)
		holder.add_child(light)


func _build_checkpoints() -> void:
	var holder := Node3D.new()
	_add_generated(holder, "Checkpoints")
	for i in checkpoint_count:
		var offset := get_checkpoint_offset(i)
		var center := curve.sample_baked(offset)
		var a := curve.sample_baked(wrap_offset(offset - 1.0))
		var b := curve.sample_baked(wrap_offset(offset + 1.0))
		var tangent := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var gate := Area3D.new()
		gate.name = "Checkpoint%d" % i
		gate.collision_layer = 0
		gate.collision_mask = 2 # vehicles
		gate.monitorable = false
		gate.transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), center + Vector3(0.0, 2.5, 0.0))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Wider than the road so a car scraping the barrier still registers.
		box.size = Vector3(road_width + barrier_thickness * 2.0 + 4.0, 6.0, checkpoint_depth)
		shape.shape = box
		gate.add_child(shape)
		holder.add_child(gate)
		if not Engine.is_editor_hint():
			gate.body_entered.connect(_on_checkpoint_body_entered.bind(i))
		# The same gate on any shortcut that bypasses it, so either route counts.
		for sc in shortcuts:
			if not sc.contains_main_offset(self, offset):
				continue
			var d: float = sc.from_main_offset(self, offset)
			var copy := Area3D.new()
			copy.name = "Checkpoint%d_%s" % [i, sc.name]
			copy.collision_layer = 0
			copy.collision_mask = 2
			copy.monitorable = false
			copy.transform = Transform3D(Basis.looking_at(sc.tangent_at(d), Vector3.UP), sc.point_at(d) + Vector3(0.0, 2.5, 0.0))
			var copy_shape := CollisionShape3D.new()
			var copy_box := BoxShape3D.new()
			copy_box.size = Vector3(sc.road_width + barrier_thickness * 2.0 + 2.0, 6.0, checkpoint_depth)
			copy_shape.shape = copy_box
			copy.add_child(copy_shape)
			holder.add_child(copy)
			if not Engine.is_editor_hint():
				copy.body_entered.connect(_on_checkpoint_body_entered.bind(i))


## Chevron boards on the outside of every corner tighter than
## corner_sign_radius, pointing the way through (GDD 15.3 direction).
func _build_corner_signs() -> void:
	if corner_sign_radius <= 0.0:
		return
	var holder := Node3D.new()
	_add_generated(holder, "CornerSigns")
	var board_mat := _material(Color(0.04, 0.03, 0.07), 0.0, 0.6)
	var chevron_mat := _material(corner_sign_color, 4.0)
	var step := 6.0
	var count := int(length / step)
	var curv: Array[float] = []
	for i in count:
		var d := i * step
		var t0 := get_tangent_at(d - 8.0)
		var t1 := get_tangent_at(d + 8.0)
		curv.append(t0.signed_angle_to(t1, Vector3.UP) / 16.0)
	var limit := 1.0 / corner_sign_radius
	var i := 0
	while i < count:
		if absf(curv[i]) < limit:
			i += 1
			continue
		var j := i
		while j < count and absf(curv[j]) >= limit and signf(curv[j]) == signf(curv[i]):
			j += 1
		# Turning left (positive yaw) puts the outside on the right.
		var outside := 1.0 if curv[i] > 0.0 else -1.0
		var mid := (i + j) / 2
		for k in [-1, 0, 1]:
			var d := clampf((mid + k * 3) * step, i * step, j * step)
			var sign_xf := get_safe_transform(d, outside * (road_width * 0.5 + barrier_thickness + corner_sign_gap), 0.0)
			sign_xf.basis = sign_xf.basis.rotated(Vector3.UP, PI) # face the oncoming cars
			var board := Node3D.new()
			board.transform = sign_xf
			holder.add_child(board)
			var panel := MeshInstance3D.new()
			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(corner_sign_width, 1.6, 0.2)
			panel.mesh = panel_mesh
			panel.material_override = board_mat
			panel.position = Vector3(0, 1.6, 0)
			board.add_child(panel)
			# Two chevrons pointing toward the inside of the corner.
			for c in 2:
				for arm in [-1.0, 1.0]:
					var bar := MeshInstance3D.new()
					var bar_mesh := BoxMesh.new()
					bar_mesh.size = Vector3(0.18, 0.85, 0.06)
					bar.mesh = bar_mesh
					bar.material_override = chevron_mat
					var x := (float(c) - 0.5) * 1.3
					bar.position = Vector3(x + outside * 0.0, 1.6 + arm * 0.27, -0.13)
					bar.rotation.z = arm * outside * 0.6
					board.add_child(bar)
		i = j


func _on_checkpoint_body_entered(body: Node3D, index: int) -> void:
	checkpoint_crossed.emit(index, body)
