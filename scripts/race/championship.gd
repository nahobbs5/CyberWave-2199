class_name Championship
extends RefCounted
## Grand Prix state (GDD 2.2): which race is next, every finishing order so
## far, cumulative points, and the next starting grid. Saved to disk between
## races so an unfinished championship can be continued from the menu.
##
## Racers are identified by id: RaceConfig.PLAYER_ID for the player, or the
## rival's index in the roster, so AI identities stay the same all season.

const POINTS: Array[int] = [15, 12, 10, 8, 6, 4, 2, 1]
const SAVE_VERSION := 1
const DIFFICULTY_PATH := "res://resources/ai/%s.tres"

## Tests point this somewhere else.
static var save_path: String = "user://grand_prix_save.json"

var gp: GrandPrixData
## Index of the next race to run (== race count when complete).
var race_index: int = 0
## One finishing order (ids, winner first) per completed race.
var results: Array = []
## id -> cumulative points.
var points: Dictionary = {}
## Ids by grid slot for the next race (slot 0 = pole).
var next_grid: Array[int] = []
var vehicle_id: String = "placeholder_gt"
## Rival names in roster order, so a save shows who raced.
var rival_names: PackedStringArray = PackedStringArray()
## Coins are Phase 5; kept in the save format already (GDD 2.2).
var coins_awarded: int = 0
var difficulty_id: String = "normal"
var weapons_enabled: bool = true


static func create(p_gp: GrandPrixData, p_difficulty_id: String, p_weapons: bool,
		roster: RivalRoster) -> Championship:
	var c := Championship.new()
	c.gp = p_gp
	c.difficulty_id = p_difficulty_id
	c.weapons_enabled = p_weapons
	var count := 7
	if roster != null:
		count = mini(roster.rivals.size(), 7)
		for profile in roster.rivals:
			c.rival_names.append(profile.display_name)
	# Race 1: the seven rivals fill slots 1-7, the player starts eighth.
	c.next_grid = RaceConfig.default_grid(count)
	for id in c.next_grid:
		c.points[id] = 0
	return c


static func points_for(position: int) -> int:
	return POINTS[position - 1] if position >= 1 and position <= POINTS.size() else 0


func race_count() -> int:
	return gp.race_count() if gp != null else 0


func is_complete() -> bool:
	return race_index >= race_count()


func current_track_name() -> String:
	return gp.track_names[mini(race_index, race_count() - 1)]


## Records a finished race (ids in finishing order) and sets the next grid to
## that order: grids follow the previous race, not the points (GDD 2.2).
func record_race(order: Array[int]) -> void:
	results.append(order.duplicate())
	for i in order.size():
		points[order[i]] = int(points.get(order[i], 0)) + points_for(i + 1)
	next_grid = order.duplicate()
	race_index += 1


## Points earned in one completed race.
func points_in_race(race: int, id: int) -> int:
	return points_for((results[race] as Array).find(id) + 1)


func finishes_at(id: int, position: int) -> int:
	var count := 0
	for order in results:
		if (order as Array).find(id) == position - 1:
			count += 1
	return count


## Ids ranked by points, then wins, then second places, then the finishing
## order of the most recent race (GDD 2.2 proposed tiebreaker).
func standings() -> Array[int]:
	var ids: Array[int] = []
	for id in points:
		ids.append(int(id))
	var last: Array = results[results.size() - 1] if not results.is_empty() else next_grid
	ids.sort_custom(func(a: int, b: int) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		for place in [1, 2]:
			var fa := finishes_at(a, place)
			var fb := finishes_at(b, place)
			if fa != fb:
				return fa > fb
		return last.find(a) < last.find(b))
	return ids


func make_race_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = RaceConfig.Mode.GRAND_PRIX
	config.difficulty = load(DIFFICULTY_PATH % difficulty_id) as AIDifficulty
	config.weapons_enabled = weapons_enabled
	config.total_laps = gp.laps
	var index := mini(race_index, race_count() - 1)
	config.track_name = gp.track_names[index]
	if index < gp.track_scenes.size() and gp.track_scenes[index] != "":
		config.track_scene = load(gp.track_scenes[index]) as PackedScene
	config.grid_order = next_grid.duplicate()
	config.championship = self
	return config


# --- saving (GDD 2.2 Championship Saving) --------------------------------------

func to_dict() -> Dictionary:
	var pts := {}
	for id in points:
		pts[str(id)] = points[id]
	return {
		"version": SAVE_VERSION,
		"championship": gp.resource_path,
		"race_index": race_index,
		"results": results,
		"points": pts,
		"next_grid": next_grid,
		"vehicle": vehicle_id,
		"rivals": Array(rival_names),
		"coins_awarded": coins_awarded,
		"difficulty": difficulty_id,
		"weapons": weapons_enabled,
	}


static func from_dict(data: Dictionary) -> Championship:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return null
	var gp_res := load(str(data.get("championship", ""))) as GrandPrixData
	if gp_res == null:
		return null
	var c := Championship.new()
	c.gp = gp_res
	c.race_index = int(data.get("race_index", 0))
	for order in data.get("results", []):
		var ids: Array[int] = []
		for id in order:
			ids.append(int(id))
		c.results.append(ids)
	var pts: Dictionary = data.get("points", {})
	for key in pts:
		c.points[int(key)] = int(pts[key])
	for id in data.get("next_grid", []):
		c.next_grid.append(int(id))
	c.vehicle_id = str(data.get("vehicle", c.vehicle_id))
	c.rival_names = PackedStringArray(data.get("rivals", []))
	c.coins_awarded = int(data.get("coins_awarded", 0))
	c.difficulty_id = str(data.get("difficulty", "normal"))
	c.weapons_enabled = bool(data.get("weapons", true))
	return c


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't save the Grand Prix to %s" % save_path)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func has_save() -> bool:
	return load_saved() != null


static func load_saved() -> Championship:
	if not FileAccess.file_exists(save_path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return null
	var c := from_dict(data)
	return c if c != null and not c.is_complete() else null


static func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
