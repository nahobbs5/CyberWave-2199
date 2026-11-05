class_name VehicleCosmetics
extends RefCounted
## Gives the shared car scene a vehicle's model and its equipped cosmetics
## (GDD 5.1, 9.4, 9.5). Purely visual.
##
## Model: VehicleData.model_scene (an imported .glb, see README "Vehicle
## models") if set, else the procedural CarModelBuilder design for the
## vehicle id, else the Phase 1 box car scaled by the vehicle's proportions.
## Cosmetics attach to the model's anchors (PlateAnchor, DecalL/R,
## ExhaustL/R, NeonL/R). Everything added lives under Body/Cosmetics, so
## applying again rebuilds it cleanly (garage try-on).


## Full player look: proportions, paint, finish, stripes, decal, wheels,
## plate + frame, underglow, exhaust.
static func apply(car: Node3D, vehicle: VehicleData, loadout: Dictionary, plate_text: String) -> void:
	var body := car.get_node_or_null("Body") as Node3D
	if body == null:
		return
	if vehicle != null:
		apply_model(car, vehicle)
	var root := _fresh_root(body)
	var factory := vehicle.factory_color if vehicle != null else Color(0.1, 0.12, 0.22)
	var paint: CosmeticItem = loadout.get(CosmeticItem.Category.PAINT)
	var finish: CosmeticItem = loadout.get(CosmeticItem.Category.FINISH)
	var color := factory if paint == null or paint.style == "factory" else paint.color
	_apply_paint(car, color, finish.style if finish != null else "gloss")
	_add_stripes(car, loadout.get(CosmeticItem.Category.STRIPES))
	_add_decal(car, root, loadout.get(CosmeticItem.Category.DECAL))
	_apply_wheels(car, loadout.get(CosmeticItem.Category.WHEELS))
	add_plate(car, plate_text, loadout.get(CosmeticItem.Category.PLATE_FRAME))
	_apply_underglow(car, root, loadout.get(CosmeticItem.Category.UNDERGLOW))
	_add_exhaust(car, root, loadout.get(CosmeticItem.Category.EXHAUST))


## Puts the vehicle's model on the car (see the class notes for the order).
static func apply_model(car: Node3D, vehicle: VehicleData) -> void:
	var body := car.get_node_or_null("Body") as Node3D
	if body == null or vehicle == null:
		return
	if vehicle.model_scene != null:
		CarModelBuilder.remove_model(car)
		CarModelBuilder.hide_placeholder(car)
		body.scale = Vector3.ONE
		var model := vehicle.model_scene.instantiate() as Node3D
		model.name = "Model"
		body.add_child(model)
	elif CarDesigns.has_design(vehicle.id):
		CarModelBuilder.build(car, vehicle.id)
	else:
		CarModelBuilder.remove_model(car)
		CarModelBuilder.show_placeholder(car)
		apply_proportions(car, vehicle)


## Design id of the procedural model on this car, or "" (box car / .glb).
static func model_design(car: Node3D) -> String:
	var model := car.get_node_or_null("Body/Model")
	return str(model.get_meta("design", "")) if model != null else ""


## Plain paint colour on whatever body the car has (AI cars).
static func paint_body(car: Node3D, color: Color) -> void:
	_apply_paint(car, color, "gloss")


static func apply_proportions(car: Node3D, vehicle: VehicleData) -> void:
	var body := car.get_node_or_null("Body") as Node3D
	if body == null:
		return
	body.scale = vehicle.body_scale
	var cabin := body.get_node_or_null("Cabin") as Node3D
	if cabin != null:
		cabin.scale = vehicle.cabin_scale
		# Keep a lowered cabin sitting on the chassis.
		cabin.position.y = 0.21 + 0.21 * vehicle.cabin_scale.y
	var has_spoiler := vehicle.spoiler_scale.length() > 0.01
	for part in ["Spoiler", "StrutL", "StrutR"]:
		var node := body.get_node_or_null(part) as Node3D
		if node == null:
			continue
		node.visible = has_spoiler
		if has_spoiler:
			node.scale = vehicle.spoiler_scale if part == "Spoiler" else Vector3(1.0, vehicle.spoiler_scale.y, 1.0)


## Rear license plate with its text and frame (GDD 9.5). AI cars use this
## on its own with their predefined plates.
static func add_plate(car: Node3D, text: String, frame: CosmeticItem) -> void:
	var old := car.find_child("Plate", true, false)
	if old != null:
		old.free()
	var parent := car.get_node_or_null("Body/Model/PlateAnchor") as Node3D
	var plate := Node3D.new()
	plate.name = "Plate"
	if parent == null:
		parent = car.get_node_or_null("Body/Chassis") as Node3D
		plate.position = Vector3(0.0, -0.07, 2.104)
	if parent == null:
		return
	parent.add_child(plate)
	var frame_color := frame.color if frame != null else Color(0.05, 0.05, 0.06)
	var frame_style := frame.style if frame != null else "basic"
	var frame_mesh := _box(Vector3(0.62, 0.2, 0.01), _material(frame_color, frame_style))
	frame_mesh.name = "Frame"
	plate.add_child(frame_mesh)
	var board := _box(Vector3(0.54, 0.13, 0.012), _material(Color(0.9, 0.92, 0.95), "plate"))
	board.name = "Board"
	board.position.z = 0.003
	plate.add_child(board)
	var label := Label3D.new()
	label.name = "Text"
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0028
	label.outline_size = 0
	label.modulate = Color(0.04, 0.04, 0.1)
	label.double_sided = false
	label.position.z = 0.011
	plate.add_child(label)


static func get_plate_text(car: Node3D) -> String:
	var plate := car.find_child("Plate", true, false)
	var label := plate.get_node_or_null("Text") as Label3D if plate != null else null
	return label.text if label != null else ""


# --- parts ----------------------------------------------------------------------

static func _fresh_root(body: Node3D) -> Node3D:
	var old := body.get_node_or_null("Cosmetics")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "Cosmetics"
	# Line up with the model so anchors and stripes match it.
	var model := body.get_node_or_null("Model") as Node3D
	if model != null:
		root.position = model.position
	body.add_child(root)
	return root


static func paint_material(color: Color, finish: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	match finish:
		"matte":
			mat.metallic = 0.0
			mat.roughness = 0.9
		"metallic":
			mat.metallic = 1.0
			mat.roughness = 0.35
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
		"chrome":
			mat.albedo_color = color.lerp(Color(0.85, 0.87, 0.9), 0.55)
			mat.metallic = 1.0
			mat.roughness = 0.04
		_: # gloss
			mat.metallic = 0.55
			mat.roughness = 0.28
	return mat


static func _apply_paint(car: Node3D, color: Color, finish: String) -> void:
	var mat := paint_material(color, finish)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var model := car.get_node_or_null("Body/Model")
	if model != null:
		# Procedural Paint mesh, or any .glb mesh whose name starts with "Paint".
		for node in model.find_children("Paint*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = mat
		return
	for path in ["Body/Chassis", "Body/Nose"]:
		var mesh := car.get_node_or_null(path) as MeshInstance3D
		if mesh != null:
			mesh.material_override = mat


static func _add_stripes(car: Node3D, item: CosmeticItem) -> void:
	for path in ["Body/Chassis", "Body/Nose", "Body/Cabin"]:
		var part := car.get_node_or_null(path)
		if part != null and part.get_node_or_null("Stripes") != null:
			part.get_node("Stripes").free()
	var cos_root := car.get_node_or_null("Body/Cosmetics")
	if cos_root != null and cos_root.get_node_or_null("Stripes") != null:
		cos_root.get_node("Stripes").free()
	if item == null or item.style == "none" or item.style == "":
		return
	var mat := _material(item.color, "stripe")
	var design := model_design(car)
	if design != "" or car.get_node_or_null("Body/Model") != null:
		# Model cars: stripes follow the procedural body; .glb models skip them.
		if design == "" or cos_root == null:
			return
		var stripes := MeshInstance3D.new()
		stripes.name = "Stripes"
		stripes.material_override = mat
		if item.style == "side":
			stripes.mesh = CarModelBuilder.side_stripe_mesh(design)
		else:
			var model_lanes: Array[float] = [0.0]
			if item.style != "center":
				model_lanes = [-0.22, 0.22]
			stripes.mesh = CarModelBuilder.stripe_mesh(design, model_lanes, 0.3 if item.style == "center" else 0.16)
		cos_root.add_child(stripes)
		return
	var chassis := car.get_node_or_null("Body/Chassis") as Node3D
	var nose := car.get_node_or_null("Body/Nose") as Node3D
	var cabin := car.get_node_or_null("Body/Cabin") as Node3D
	if item.style == "side":
		var group := _group(chassis)
		for side in [-1.0, 1.0]:
			var s := _box(Vector3(0.012, 0.08, 3.0), mat)
			s.position = Vector3(side * 0.956, 0.04, 0.2)
			group.add_child(s)
		return
	var lanes: Array[float] = [0.0]
	if item.style != "center":
		lanes = [-0.22, 0.22]
	var width := 0.3 if item.style == "center" else 0.16
	# Each stripe runs over the nose, the cabin roof and the rear deck.
	for lane in lanes:
		if nose != null:
			var a := _box(Vector3(width, 0.01, 1.1), mat)
			a.position = Vector3(lane, 0.085, 0.0)
			_group(nose).add_child(a)
		if cabin != null:
			var b := _box(Vector3(width * 0.9, 0.01, 1.9), mat)
			b.position = Vector3(lane, 0.215, 0.0)
			_group(cabin).add_child(b)
		if chassis != null:
			var c := _box(Vector3(width, 0.01, 0.85), mat)
			c.position = Vector3(lane, 0.215, 1.65)
			_group(chassis).add_child(c)


static func _add_decal(car: Node3D, root: Node3D, item: CosmeticItem) -> void:
	if item == null or item.style == "":
		return
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		var anchor := car.get_node_or_null("Body/Model/Decal%s" % ("L" if side < 0.0 else "R")) as Node3D
		label.text = item.style
		label.font_size = 72
		label.pixel_size = 0.0045
		label.outline_size = 8
		label.modulate = item.color
		label.double_sided = false
		if anchor != null:
			# Model and Cosmetics are both children of Body.
			label.transform = anchor.transform
		else:
			label.position = Vector3(side * 0.958, 0.0, 0.35)
			label.rotation.y = side * PI * 0.5
		root.add_child(label)


static func _apply_wheels(car: Node3D, item: CosmeticItem) -> void:
	for child in car.get_children():
		if not child.name.begins_with("Wheel"):
			continue
		var mesh := child.get_node_or_null("Pivot/Mesh") as Node3D
		if mesh == null:
			continue
		var old := mesh.get_node_or_null("Rim")
		if old != null:
			old.free()
		if item == null:
			continue
		var rim := MeshInstance3D.new()
		rim.name = "Rim"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.25
		cyl.height = 0.335
		cyl.radial_segments = 16
		cyl.rings = 1
		rim.mesh = cyl
		rim.material_override = _material(item.color, item.style)
		mesh.add_child(rim)


static func _apply_underglow(car: Node3D, root: Node3D, item: CosmeticItem) -> void:
	var on := item != null and item.style != "none"
	var neon_mat: Material = _material(item.color, "neon") if on else null
	var has_model := car.get_node_or_null("Body/Model") != null
	for path in (["Body/Model/NeonL", "Body/Model/NeonR"] if has_model else ["Body/NeonL", "Body/NeonR"]):
		var strip := car.get_node_or_null(path) as MeshInstance3D
		if strip == null:
			continue
		if neon_mat != null:
			strip.material_override = neon_mat
		elif has_model:
			strip.visible = false # underglow strips only show with an underglow item
		else:
			strip.material_override = null
		if neon_mat != null:
			strip.visible = true
	if not on:
		return
	var light := OmniLight3D.new()
	light.name = "Underglow"
	light.light_color = item.color
	light.light_energy = 2.2
	light.omni_range = 3.6
	light.position = Vector3(0.0, -0.42, 0.0)
	root.add_child(light)


static func _add_exhaust(car: Node3D, root: Node3D, item: CosmeticItem) -> void:
	if item == null:
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	sphere.radial_segments = 8
	sphere.rings = 4
	for side in [-1.0, 1.0]:
		var tip := MeshInstance3D.new()
		tip.name = "ExhaustL" if side < 0.0 else "ExhaustR"
		tip.mesh = sphere
		tip.material_override = _material(item.color, "chrome" if item.style == "metal" else "neon")
		var anchor := car.get_node_or_null("Body/Model/Exhaust%s" % ("L" if side < 0.0 else "R")) as Node3D
		tip.position = anchor.position if anchor != null else Vector3(side * 0.45, -0.05, 2.13)
		root.add_child(tip)


# --- helpers --------------------------------------------------------------------

static func _group(parent: Node3D) -> Node3D:
	var group := parent.get_node_or_null("Stripes") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "Stripes"
		parent.add_child(group)
	return group


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	return mesh


static func _material(color: Color, style: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	match style:
		"chrome":
			mat.metallic = 0.7
			mat.roughness = 0.18
		"neon":
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 3.0
		"plate":
			mat.roughness = 0.5
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.25 # readable at night
		"stripe":
			mat.roughness = 0.35
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.3
		_:
			mat.metallic = 0.5
			mat.roughness = 0.45
	return mat
