class_name TrackCatalog
extends RefCounted
## Every raceable track (GDD 8). Tracks still to be built in Phase 6 race on
## the test circuit under their own name until their scene exists.

const TEST_CIRCUIT := "res://scenes/tracks/test_circuit.tscn"

## [name, scene path or "" (not built yet), location]
const TRACKS := [
	["Vegas Overdrive", "res://scenes/tracks/vegas_overdrive.tscn", "Las Vegas, Nevada"],
	["Test Circuit", TEST_CIRCUIT, "Graybox"],
]


static func names() -> Array[String]:
	var out: Array[String] = []
	for t in TRACKS:
		out.append(t[0])
	return out


static func scene_path(track_name: String) -> String:
	for t in TRACKS:
		if t[0] == track_name and t[1] != "":
			return t[1]
	return TEST_CIRCUIT


static func scene(track_name: String) -> PackedScene:
	return load(scene_path(track_name)) as PackedScene


static func is_built(track_name: String) -> bool:
	for t in TRACKS:
		if t[0] == track_name:
			return t[1] != ""
	return false
