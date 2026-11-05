extends SceneTree
## Dev tool: renders every vehicle model in a lit row and saves screenshots.
##   godot --path . -s res://tests/tools/car_showroom.gd -- <out_prefix> [view]
## view: front (3/4 front), rear, side, top, single:<id> (one car, 4 angles)

const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "/tmp/showroom"
	var view := args[1] if args.size() > 1 else "front"
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.2, 0.45)
	sky_mat.sky_horizon_color = Color(0.7, 0.45, 0.7)
	sky_mat.ground_horizon_color = Color(0.4, 0.3, 0.45)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.14)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	floor.mesh = plane
	floor.position.y = -0.72
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.24)
	floor.material_override = fm
	world.add_child(floor)
	var ids: Array[String] = []
	for v in VehicleCatalog.all():
		ids.append(v.id)
	var single := ""
	if view.begins_with("single:"):
		single = view.substr(7)
		ids = [single]
	for i in ids.size():
		var car := (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
		car.freeze = true
		car.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(car)
		car.position = Vector3((i - (ids.size() - 1) * 0.5) * 3.2, 0, 0)
		for child in car.get_children():
			if child.name.begins_with("Wheel"):
				(child.get_node("Pivot") as Node3D).position.y = -0.34
		var vehicle := VehicleCatalog.by_id(ids[i])
		var loadout := PlayerProfile.get_profile().loadout_for(vehicle.id)
		if OS.get_environment("SHOWROOM_DRESSED") != "":
			# Second item of every category (stripes, decal, rims, glow, ...).
			for c in CosmeticItem.Category.values():
				var items := CosmeticCatalog.in_category(c)
				loadout[c] = items[mini(1 + i % 3, items.size() - 1)]
		VehicleCosmetics.apply(car, vehicle, loadout, "CW-2199")
		var label := Label3D.new()
		label.text = vehicle.display_name
		label.font_size = 64
		label.pixel_size = 0.006
		label.position = Vector3(0, 1.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		car.add_child(label)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var shots: Array = []
	if single != "":
		shots = [["front", Vector3(4.5, 1.8, -5.0)], ["rear", Vector3(-4.5, 1.8, 5.0)],
				["side", Vector3(7.0, 0.8, 0.0)], ["top", Vector3(0.01, 8.0, 0.5)]]
		cam.fov = 40
	else:
		var span := ids.size() * 3.2
		match view:
			"rear":
				shots = [["rear", Vector3(-4, 4.0, span * 0.62)]]
			"side":
				shots = [["side", Vector3(0, 1.2, span * 0.7)]]
			"top":
				shots = [["top", Vector3(0.01, span * 0.55, 0.5)]]
			_:
				shots = [["front", Vector3(4, 4.0, -span * 0.62)]]
		cam.fov = 50
	for shot in shots:
		cam.position = shot[1]
		var target := Vector3(0, 0.0, 0)
		if shot[0] == "side" and single == "":
			cam.position = Vector3(0, 1.0, 12)
		cam.look_at(target)
		for f in 8:
			await process_frame
		var path := "%s_%s.png" % [prefix, shot[0]]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()
