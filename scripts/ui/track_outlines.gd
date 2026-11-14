class_name TrackOutlines
extends Resource
## Every track's outline (its TrackCircuit control points seen from above),
## baked so menus can draw track cards without loading whole track scenes.
## Loading 15 scenes with all their textures and skies made the track screen
## slow everywhere and froze the picture on the web build.
## Rebake after moving a track's control points:
##   godot --headless --path . -s res://tests/tools/bake_track_outlines.gd
## (test_ui.gd fails while the baked copy is out of date.)

const PATH := "res://resources/ui/track_outlines.tres"

## Scene path -> PackedVector2Array of (x, z) points.
@export var outlines: Dictionary = {}


static func baked() -> TrackOutlines:
	return load(PATH) as TrackOutlines if ResourceLoader.exists(PATH) else null


## Reads the outline from the scene itself (slow: loads the whole scene).
## The scene is instantiated without entering the tree, so none of its
## building runs, then freed.
static func read_from_scene(scene_path: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return out
	var node := packed.instantiate()
	var track := node as TrackCircuit
	if track == null:
		var found := node.find_children("*", "TrackCircuit", true, false)
		track = found.front() if not found.is_empty() else null
	if track != null:
		for p in track.control_points:
			out.append(Vector2(p.x, p.z))
	node.free()
	return out


## Every scene the menus can show: each built track plus the test circuit.
static func scene_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for track in TrackCatalog.names():
		var path := TrackCatalog.scene_path(track)
		if not out.has(path):
			out.append(path)
	return out
