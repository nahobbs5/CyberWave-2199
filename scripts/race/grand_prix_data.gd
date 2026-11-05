class_name GrandPrixData
extends Resource
## One championship of three races (GDD 2.2). Every race uses the test
## circuit until the real tracks are built (Phase 6); only the names differ.

@export var id: String = "grand_prix"
@export var display_name: String = "Grand Prix"
@export var track_names: PackedStringArray = PackedStringArray()
@export var locations: PackedStringArray = PackedStringArray()
## Scene path for each race.
@export var track_scenes: PackedStringArray = PackedStringArray()
@export_range(1, 9) var laps: int = 3


func race_count() -> int:
	return track_names.size()
