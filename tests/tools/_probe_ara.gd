extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var track := (load("res://scenes/tracks/arashiyama_circuit.tscn") as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var ms := Time.get_ticks_msec() - t0
	var sc := track.get_node("Scenery") as ArashiyamaScenery
	print("build ms ", ms, " length ", track.length, " culms ", sc.bamboo.culm_count(), " sprays ", sc.bamboo.spray_count())
	var covered := 0
	var total := 0
	var d := 0.0
	while d < track.length:
		total += 1
		if sc.is_covered(track.to_local(track.get_safe_transform(d, 0.0, 0.0).origin)):
			covered += 1
		d += 3.0
	print("coverage ", float(covered) / total)
	var gen := track.get_node("Scenery/Generated")
	print("generated children ", gen.get_child_count(), " multimesh ", track.find_children("Bamboo_*", "MultiMeshInstance3D", true, false).size())
	quit()
