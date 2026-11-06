extends SceneTree
## Dev tool: renders a scene and saves PNG screenshots (needs a real or
## virtual display, not --headless). Usage:
##   godot --path . -s res://tests/tools/screenshot.gd -- <scene.tscn> <out.png> [frames]
## Optional env SHOT_CAMERA="x,y,z;tx,ty,tz" places a camera looking at a target.
## Optional env SHOT_CAR_CAM="dx,dy,dz" (race scenes) puts the camera at that
## offset in the player car's local space, looking at the car.
## SHOT_TRACK / SHOT_AUTOPILOT / SHOT_PLAYERS: see below. SHOT_EVERY=n saves a numbered shot
## every n frames (out.png -> out_001.png ...).

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/menu/main_menu.tscn"
	var out := args[1] if args.size() > 1 else "user://shot.png"
	var frames := int(args[2]) if args.size() > 2 else 30
	GameSession.scene_changes_enabled = false
	var node := (load(scene_path) as PackedScene).instantiate()
	# SHOT_TRACK=res://scenes/tracks/x.tscn races on that track; SHOT_AUTOPILOT=1
	# lets the AI drive the player's car (use with --fixed-fps 60).
	if node is RaceManager:
		var config := RaceConfig.new()
		config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
		var track_path := OS.get_environment("SHOT_TRACK")
		if track_path != "":
			config.track_scene = load(track_path) as PackedScene
		# SHOT_PLAYERS=2..4 races in split screen (keyboard + pads 0-2).
		var players := int(OS.get_environment("SHOT_PLAYERS")) if OS.get_environment("SHOT_PLAYERS") != "" else 1
		if players > 1:
			config.player_devices = PackedInt32Array([-1, 0, 1, 2]).slice(0, players)
			for i in players:
				config.player_vehicle_ids.append(VehicleCatalog.all()[i].id)
		(node as RaceManager).config = config
		(node as RaceManager).player_uses_autopilot = OS.get_environment("SHOT_AUTOPILOT") != ""
	root.add_child(node)
	var cam_spec := OS.get_environment("SHOT_CAMERA")
	if cam_spec != "":
		var parts := cam_spec.split(";")
		var p := parts[0].split_floats(",")
		var t := parts[1].split_floats(",")
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(t[0], t[1], t[2]))
		cam.current = true
	# SHOT_WEAPONS=railgun,triple_nitro puts those weapons in the player's slots.
	if node is RaceManager and OS.get_environment("SHOT_WEAPONS") != "":
		await process_frame
		for id in OS.get_environment("SHOT_WEAPONS").split(","):
			(node as RaceManager).player.vehicle.inventory.add(load("res://resources/weapons/%s.tres" % id))
	var every := int(OS.get_environment("SHOT_EVERY")) if OS.get_environment("SHOT_EVERY") != "" else 0
	for i in frames:
		await process_frame
		if every > 0 and i > 0 and i % every == 0:
			await _save(node, out.replace(".png", "_%03d.png" % (i / every)))
	await _save(node, out)
	quit()


func _save(node: Node, out: String) -> void:
	var car_cam := OS.get_environment("SHOT_CAR_CAM")
	if car_cam != "" and node is RaceManager:
		var car := (node as RaceManager).player.vehicle
		var o := car_cam.split_floats(",")
		var cam2 := Camera3D.new()
		root.add_child(cam2)
		cam2.global_position = car.global_transform * Vector3(o[0], o[1], o[2])
		cam2.look_at(car.global_position + Vector3.UP * 0.3)
		cam2.fov = 50
		cam2.current = true
		await process_frame
		await process_frame
		var img2 := root.get_texture().get_image()
		img2.save_png(out)
		print("saved ", out)
		cam2.current = false
		(node as RaceManager).camera.current = true
		cam2.queue_free()
		return
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
