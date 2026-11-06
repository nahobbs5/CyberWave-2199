class_name GrandPrixData
extends Resource
## A cup: a championship of three races (GDD 2.2), picked Mario Kart style
## for Grand Prix and Versus. A cup whose tracks aren't built yet is
## `locked` (shown as "coming soon", can't be picked).

## Every cup, in menu order.
const CUPS: Array[String] = [
	"res://resources/grand_prix/american_circuit.tres",
	"res://resources/grand_prix/world_circuit.tres",
]

@export var id: String = "grand_prix"
@export var display_name: String = "Grand Prix"
@export var track_names: PackedStringArray = PackedStringArray()
@export var locations: PackedStringArray = PackedStringArray()
## Scene path for each race.
@export var track_scenes: PackedStringArray = PackedStringArray()
@export_range(1, 9) var laps: int = 3
## Not playable yet (tracks still to be built).
@export var locked: bool = false
## Picture on the cup's trophy: "usa" (map of the USA) or "globe".
@export var emblem: String = ""


static func all_cups() -> Array[GrandPrixData]:
	var out: Array[GrandPrixData] = []
	for path in CUPS:
		out.append(load(path) as GrandPrixData)
	return out


static func cup_by_path(path: String) -> GrandPrixData:
	return load(path) as GrandPrixData if path in CUPS else null


func race_count() -> int:
	return track_names.size()
