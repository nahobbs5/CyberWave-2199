extends SceneTree
## Bakes every track's outline into TrackOutlines.PATH for the menu cards.
##   godot --headless --path . -s res://tests/tools/bake_track_outlines.gd


func _initialize() -> void:
	var data := TrackOutlines.new()
	for path in TrackOutlines.scene_paths():
		var outline := TrackOutlines.read_from_scene(path)
		if outline.size() < 3:
			push_error("no outline for %s" % path)
			quit(1)
			return
		data.outlines[path] = outline
		print("%s: %d points" % [path, outline.size()])
	var err := ResourceSaver.save(data, TrackOutlines.PATH)
	print("saved %s (%s)" % [TrackOutlines.PATH, error_string(err)])
	quit(0 if err == OK else 1)
