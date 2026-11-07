class_name GrandPrixData
extends Resource
## A cup: a championship of its tracks' races (GDD 2.2; most cups have three), picked Mario Kart style
## for Grand Prix and Versus. A cup whose tracks aren't built yet is
## `locked` (shown as "coming soon", can't be picked).

## Every cup, in menu order.
const CUPS: Array[String] = [
	"res://resources/grand_prix/american_circuit.tres",
	# The Europe Cup (the file keeps its old World Cup name so saved results carry over).
	"res://resources/grand_prix/world_circuit.tres",
	"res://resources/grand_prix/asia_circuit.tres",
	"res://resources/grand_prix/south_america_circuit.tres",
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
## Picture on the cup's trophy: "usa", "europe" (maps), "japan" (rising
## sun) or "globe".
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


## True if this track of the cup has its own scene (not the test circuit).
func is_track_built(index: int) -> bool:
	return TrackCatalog.is_built(track_names[index])


## Whether the cup can be picked: Grand Prix needs it unlocked; Versus only
## needs one built track (a locked cup's finished tracks are raceable).
func is_open(grand_prix: bool) -> bool:
	if not locked:
		return true
	if grand_prix:
		return false
	for i in track_names.size():
		if is_track_built(i):
			return true
	return false
