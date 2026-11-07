extends SceneTree
## Scratch probe for the Crazy House build (temporary).
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	create_timer(200.0).timeout.connect(func() -> void: quit(2))
	# Warm-up load so the timing isn't the one-time engine load.
	var warm := (load("res://scenes/tracks/test_circuit.tscn") as PackedScene).instantiate()
	root.add_child(warm)
	warm.queue_free()
	await process_frame
	var t0 := Time.get_ticks_msec()
	var track := (load("res://scenes/tracks/crazy_house.tscn") as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	print("build ms ", Time.get_ticks_msec() - t0, " length ", track.length)
	var s := track.get_node("Scenery") as CrazyHouseScenery
	var gaps := []
	var d := 0.0
	while d < track.length:
		for lat in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if not s.is_roofed(track.to_local(track.get_safe_transform(d, lat, 0.0).origin)):
				gaps.append(int(d))
		d += 3.0
	var sc := track.shortcuts[0]
	var sg := []
	d = 0.0
	while d < sc.length:
		if not s.is_roofed(sc.point_at(d)):
			sg.append(int(d))
		d += 3.0
	print("gaps ", gaps.slice(0, 8), " n=", gaps.size(), " tunnel gaps ", sg.slice(0, 8), " n=", sg.size())
	print("stairs ", s.stair_flights, " steps ", s.step_count, " shafts ", s.window_shafts, " arches ", s.bone_arches, " clearance ", s.bone_arch_clearance, " start roof ", s.start_roof_height)
	print("zones ", s.zone_offsets, " signs ", track.get_node("_GenCornerSigns").get_child_count())
	var font := load("res://assets/fonts/Rajdhani-SemiBold.ttf") as FontFile
	var ox := load("res://assets/fonts/Oxanium-Variable.ttf") as FontFile
	print("glyphs Rajdhani ", font.has_char("Đ".unicode_at(0)), font.has_char("à".unicode_at(0)), font.has_char("ạ".unicode_at(0)), " Oxanium ", ox.has_char("Đ".unicode_at(0)), ox.has_char("à".unicode_at(0)), ox.has_char("ạ".unicode_at(0)))
	quit()
