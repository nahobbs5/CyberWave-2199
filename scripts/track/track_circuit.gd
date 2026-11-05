@tool
class_name TrackCircuit
extends Node3D
## Graybox circuit generated from a closed loop of control points.
##
## Builds the road surface, edge and centre markings, collidable barriers with
## neon strips, a ground slab, a start gantry and trackside lights. It also
## answers track-space questions (nearest offset, safe respawn transforms) for
## recovery, checkpoints, the starting grid and AI racing lines.
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

@export_group("Starting Grid")
## Distance from the start line back to the pole position slot.
@export var grid_first_row_gap: float = 8.0
@export var grid_row_spacing: float = 9.0
## Extra setback of the right-hand slot in each row (staggered grid).
@export var grid_stagger: float = 4.5
@export var grid_lateral: float = 4.0
@export_group("")
## Ground extends this far beyond the layout's bounds on every side.
@export var ground_margin: float = 300.0
@export var light_spacing: float = 90.0

var curve: Curve3D
var length: float = 0.0

var _rebuild_queued: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	_build_curve()
	for child in get_children():
		if child.name.begins_with(GENERATED_PREFIX):
			remove_child(child)
			child.queue_free()
	if length <= 0.0:
		return
	_build_ground()
	_build_road()
	_build_barriers()
	_build_start_gantry()
	_build_lights()
	_build_checkpoints()


# --- Track-space queries -------------------------------------------------

func wrap_offset(offset: float) -> float:
	return fposmod(offset, length) if length > 0.0 else 0.0


## Shortest signed distance along the loop from one offset to another.
func wrapped_delta(from_offset: float, to_offset: float) -> float:
	if length <= 0.0:
		return 0.0
	return fposmod(to_offset - from_offset + length * 0.5, length) - length * 0.5


func get_offset_at(world_pos: Vector3) -> float:
	return wrap_offset(curve.get_closest_offset(to_local(world_pos)))


func get_center_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(wrap_offset(offset)))


func get_tangent_at(offset: float) -> Vector3:
	var a := curve.sample_baked(wrap_offset(offset - 1.0))
	var b := curve.sample_baked(wrap_offset(offset + 1.0))
	var local_dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return (global_transform.basis * local_dir).normalized()


## Horizontal distance from the centre line.
func get_lateral_distance(world_pos: Vector3) -> float:
	var local := to_local(world_pos)
	var closest := curve.get_closest_point(local)
	return Vector2(local.x - closest.x, local.z - closest.z).length()


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


func _add_generated(node: Node, node_name: String) -> void:
	node.name = GENERATED_PREFIX + node_name
	add_child(node)


func _build_ground() -> void:
	# Size the slab to the layout's bounds plus a margin on every side.
	var points := curve.get_baked_points()
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
	plane.material = _material(Color(0.05, 0.05, 0.08), 0.0, 0.95)
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(center.x, 0.0, center.y)
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
		if i % 4 < 2:
			_strip_quad(dashes, s0, s1, -0.15, 0.15, 0.04)

	var holder := Node3D.new()
	_add_generated(holder, "Road")
	_add_mesh(holder, "Surface", road, _material(Color(0.13, 0.13, 0.16), 0.0, 0.7))
	_add_mesh(holder, "EdgeLines", edges, _material(Color(0.0, 0.85, 1.0), 1.5))
	_add_mesh(holder, "CentreDashes", dashes, _material(Color(0.85, 0.85, 0.9), 0.4))


func _add_mesh(parent: Node, node_name: String, st: SurfaceTool, mat: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)


func _build_barriers() -> void:
	var samples := _samples()
	var count := samples.size()
	var edge := road_width * 0.5 + barrier_thickness * 0.5

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.1
	body.physics_material_override = physics_material
	_add_generated(body, "Barriers")

	var wall_transforms: Array[Transform3D] = []
	var wall_lengths: Array[float] = []
	var left_count := 0
	for side in [-1.0, 1.0]:
		if side > 0.0:
			left_count = wall_transforms.size()
		for i in count:
			var s0 := samples[i]
			var s1 := samples[(i + 1) % count]
			var p0: Vector3 = s0.center + s0.right * edge * side
			var p1: Vector3 = s1.center + s1.right * edge * side
			var dir := p1 - p0
			dir.y = 0.0
			var seg_length := dir.length()
			if seg_length < 0.01:
				continue
			var mid := (p0 + p1) * 0.5 + Vector3(0.0, barrier_height * 0.5, 0.0)
			var xf := Transform3D(Basis.looking_at(dir / seg_length, Vector3.UP), mid)
			# Overlap neighbours slightly so outer-curve joints have no gaps.
			var padded := seg_length + barrier_thickness * 0.6
			wall_transforms.append(xf)
			wall_lengths.append(padded)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(barrier_thickness, barrier_collision_height, padded)
			shape.shape = box
			shape.transform = xf.translated(Vector3(0.0, (barrier_collision_height - barrier_height) * 0.5, 0.0))
			body.add_child(shape)

	# Visuals: one multimesh for walls and one per neon colour for the top strips.
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(barrier_thickness, barrier_height, 1.0)
	var walls := _multimesh(wall_mesh, _material(Color(0.22, 0.22, 0.27), 0.0, 0.6), wall_transforms, wall_lengths)
	walls.name = "Walls"
	body.add_child(walls)

	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(barrier_thickness * 0.5, 0.12, 1.0)
	var half_count := left_count
	var strip_up := Vector3(0.0, barrier_height * 0.5 + 0.06, 0.0)
	var left_xf: Array[Transform3D] = []
	var right_xf: Array[Transform3D] = []
	for i in wall_transforms.size():
		var xf := wall_transforms[i].translated(strip_up)
		if i < half_count:
			left_xf.append(xf)
		else:
			right_xf.append(xf)
	var left_strip := _multimesh(strip_mesh, _material(Color(0.0, 0.9, 1.0), 3.0), left_xf, wall_lengths.slice(0, half_count))
	left_strip.name = "NeonLeft"
	body.add_child(left_strip)
	var right_strip := _multimesh(strip_mesh, _material(Color(1.0, 0.1, 0.8), 3.0), right_xf, wall_lengths.slice(half_count))
	right_strip.name = "NeonRight"
	body.add_child(right_strip)


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
	light.light_color = Color(1.0, 0.4, 0.9)
	light.light_energy = 4.0
	light.omni_range = 26.0
	light.position = Vector3(0.0, 6.0, 0.0)
	holder.add_child(light)


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
		light.light_color = Color(0.0, 0.85, 1.0) if i % 2 == 0 else Color(1.0, 0.2, 0.85)
		light.light_energy = 3.0
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


func _on_checkpoint_body_entered(body: Node3D, index: int) -> void:
	checkpoint_crossed.emit(index, body)
