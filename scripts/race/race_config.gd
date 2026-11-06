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
## Rival car (vehicle id) by roster index, rolled once per series like the
## plates. Empty = the V8 Specter.
@export var rival_vehicles: PackedStringArray = PackedStringArray()

## Split screen: one input device per human player (-1 = keyboard, else a
## gamepad id). Empty or one entry = single player.
@export var player_devices: PackedInt32Array = PackedInt32Array()
## Split screen: each human's vehicle id, by player slot.
@export var player_vehicle_ids: PackedStringArray = PackedStringArray()
## Split screen: each human's license plate, by player slot ("" = default).
@export var player_plates: PackedStringArray = PackedStringArray()
## Split screen: fill the grid to eight with AI rivals; off = humans only.
@export var ai_rivals: bool = true

## Grand Prix only: the championship this race belongs to.
var championship: Championship


## Rivals first, then the humans at the back (player 1 last).
static func default_grid(rival_count: int = 7, humans: int = 1) -> Array[int]:
	var grid: Array[int] = []
	for i in rival_count:
		grid.append(i)
	for i in range(humans - 1, -1, -1):
		grid.append(human_id(i))
	return grid


## Racer id of split-screen player `slot` (0 = player 1 = PLAYER_ID).
static func human_id(slot: int) -> int:
	return PLAYER_ID - slot


static func is_human_id(id: int) -> bool:
	return id < 0


## Player slot of a human racer id.
static func human_slot(id: int) -> int:
	return PLAYER_ID - id


func is_multiplayer() -> bool:
	return player_devices.size() > 1


func human_count() -> int:
	return maxi(1, player_devices.size())


## Rivals on the grid: enough to make eight cars, or none in a humans-only
## split-screen race.
func rival_count() -> int:
	return rivals_for(human_count(), ai_rivals)


static func rivals_for(humans: int, ai: bool) -> int:
	return 8 - humans if humans <= 1 or ai else 0


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


## `count` random cars from the catalogue (each rival picks on its own, so
## two may drive the same model).
static func random_vehicles(count: int) -> PackedStringArray:
	var all := VehicleCatalog.all()
	var ids := PackedStringArray()
	for i in count:
		ids.append(all[randi() % all.size()].id)
	return ids


func is_elimination() -> bool:
	return mode == Mode.ELIMINATION


func is_grand_prix() -> bool:
	return mode == Mode.GRAND_PRIX and championship != null
