extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	for path in ["res://scenes/tracks/the_stacks.tscn"]:
		var t0 := Time.get_ticks_msec()
		var track := (load(path) as PackedScene).instantiate() as TrackCircuit
		root.add_child(track)
		var gens := track.find_children("Generated", "", true, false)
		var n := 0
		for g in gens: n += g.get_child_count()
		print("BUILD ", path.get_file(), " ", Time.get_ticks_msec() - t0, " ms, len ", track.length, " shortcut ", track.shortcuts.size(), " gen ", gens.size(), " children ", n)
		track.free()
	quit()
