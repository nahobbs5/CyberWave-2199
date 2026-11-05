extends SceneTree
func _initialize() -> void:
	for path in ["res://scenes/tracks/the_stacks.tscn"]:
		var t0 := Time.get_ticks_msec()
		var track := (load(path) as PackedScene).instantiate() as TrackCircuit
		root.add_child(track)
		var gen := track.get_node("Scenery/Generated")
		print("BUILD ", path.get_file(), " ", Time.get_ticks_msec() - t0, " ms, len ", track.length, " shortcut ", track.shortcuts.size(), " gen nodes ", gen.get_child_count())
		track.free()
	quit()
