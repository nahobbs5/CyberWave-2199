extends SceneTree
## Dev tool: renders the screenshot each race card shows on the cup screens
## (TrackCard) and saves it as assets/ui/tracks/<scene file name>.png.
## Needs a real display (not --headless). Run from the project root:
##   godot --path . --resolution 640x360 -s res://tests/tools/track_cards.gd
##   godot --path . --resolution 640x360 -s res://tests/tools/track_cards.gd -- vegas_overdrive hoia_baciu
## With no names, every built track in every cup is shot. Then open the
## editor (or run --import) so the new PNGs are imported.
##
## The camera sits on the road at SPOTS[name] = [lap fraction, height,
## metres back, metres to the side, metres ahead it looks at].

const OUT_DIR := "res://assets/ui/tracks/"
const DEFAULT_SPOT := [0.02, 6.0, 0.0, 3.0, 45.0]
const SPOTS := {
	"vegas_overdrive": [0.02, 6.0, 0.0, 3.0, 45.0],
}
## Frames to wait so deferred scenery finishes building.
const SETTLE_FRAMES := 180


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	GameSession.scene_changes_enabled = false
	var wanted := OS.get_cmdline_user_args()
	var scenes: PackedStringArray = []
	for cup in GrandPrixData.all_cups():
		for i in cup.track_names.size():
			if not cup.is_track_built(i):
				continue
			var scene := cup.track_scenes[i] if i < cup.track_scenes.size() else TrackCatalog.scene_path(cup.track_names[i])
			var key := scene.get_file().get_basename()
			if not scenes.has(scene) and (wanted.is_empty() or wanted.has(key)):
				scenes.append(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for scene in scenes:
		await _shoot(scene)
	quit()


func _shoot(scene_path: String) -> void:
	var key := scene_path.get_file().get_basename()
	var spot: Array = SPOTS.get(key, DEFAULT_SPOT)
	var node := (load(scene_path) as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
	var track := node as TrackCircuit
	if track == null:
		var found := node.find_children("*", "TrackCircuit", true, false)
		track = found.front() if not found.is_empty() else null
	if track == null:
		push_warning("%s: no TrackCircuit" % scene_path)
		node.queue_free()
		return
	var off := track.wrap_offset(float(spot[0]) * track.curve.get_baked_length())
	var right := track.get_tangent_at(off).cross(Vector3.UP).normalized()
	var cam := Camera3D.new()
	cam.fov = 62
	root.add_child(cam)
	cam.global_position = track.to_global(track.get_center_at(track.wrap_offset(off - float(spot[2])))) \
			+ Vector3.UP * float(spot[1]) + right * float(spot[3])
	cam.look_at(track.to_global(track.get_center_at(track.wrap_offset(off + float(spot[4])))) + Vector3.UP)
	cam.current = true
	for i in SETTLE_FRAMES:
		await process_frame
	var out := OUT_DIR + key + ".png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("saved ", out)
	cam.queue_free()
	node.queue_free()
	await process_frame
	await process_frame
