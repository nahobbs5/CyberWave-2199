extends SceneTree
## Dev tool: rendering cost of a race on a track (needs a display).
##   godot --path . -s res://tests/tools/perf_probe.gd -- res://scenes/tracks/x.tscn [frames]
## Prints draw calls, primitives and visible objects per frame (averaged over
## the last frames, chase camera on the grid), node count and build time.

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var track_path := args[0] if args.size() > 0 else "res://scenes/tracks/test_circuit.tscn"
	var frames := int(args[1]) if args.size() > 1 else 60
	GameSession.scene_changes_enabled = false
	var t0 := Time.get_ticks_msec()
	var race := (load("res://scenes/race/race.tscn") as PackedScene).instantiate() as RaceManager
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres")
	config.track_scene = load(track_path)
	race.config = config
	race.player_uses_autopilot = true
	root.add_child(race)
	var build_ms := Time.get_ticks_msec() - t0
	var draws := 0
	var prims := 0
	var objs := 0
	var counted := 0
	for i in frames:
		await process_frame
		if i >= frames - mini(20, frames / 2):
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			counted += 1
	print("PERF %s: build %d ms, nodes %d, draw calls %d, primitives %d, objects %d" % [track_path.get_file(),
			build_ms, race.get_tree().get_node_count(), draws / counted, prims / counted, objs / counted])
	quit()
