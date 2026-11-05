class_name RaceConfig
extends Resource
## Settings for one race (GDD 2.1 race setup). Built by the mode select screen
## or by a Championship for the next Grand Prix race, then read by RaceManager.

enum Mode { VERSUS, GRAND_PRIX, ELIMINATION }

const MODE_NAMES: Array[String] = ["Versus", "Grand Prix", "Elimination"]
const PLAYER_ID := -1

@export var mode: Mode = Mode.VERSUS
@export var difficulty: AIDifficulty
@export_range(1, 9) var total_laps: int = 3
@export var weapons_enabled: bool = true
## Track scene to race on. Null = the race scene's built-in track.
@export var track_scene: PackedScene
@export var track_name: String = "Test Circuit"
## Racer ids by grid slot (slot 0 = pole): PLAYER_ID or a rival roster index.
## Empty = rivals in roster order with the player last.
@export var grid_order: Array[int] = []
## Player's vehicle id; empty = the profile's selected vehicle.
@export var vehicle_id: String = ""
## Rival license plates by roster index, rolled once per series (a Versus /
## Elimination set or a Grand Prix). Empty = the roster's own plates.
@export var rival_plates: PackedStringArray = PackedStringArray()

## Grand Prix only: the championship this race belongs to.
var championship: Championship


static func default_grid(rival_count: int = 7) -> Array[int]:
	var grid: Array[int] = []
	for i in rival_count:
		grid.append(i)
	grid.append(PLAYER_ID)
	return grid


## `count` distinct random plates like "KRX-417", never equal to `avoid`
## (the player's plate).
static func random_plates(count: int, avoid: String = "") -> PackedStringArray:
	const LETTERS := "ABCDEFGHJKLMNPRSTUVWXYZ"
	var plates := PackedStringArray()
	while plates.size() < count:
		var plate := ""
		for i in 3:
			plate += LETTERS[randi() % LETTERS.length()]
		plate += "-%03d" % (randi() % 1000)
		if plate != avoid and not plates.has(plate):
			plates.append(plate)
	return plates


func is_elimination() -> bool:
	return mode == Mode.ELIMINATION


func is_grand_prix() -> bool:
	return mode == Mode.GRAND_PRIX and championship != null
