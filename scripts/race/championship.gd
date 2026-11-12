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
var vehicle_id: String = PlayerProfile.DEFAULT_VEHICLE
## Rival names in roster order, so a save shows who raced.
var rival_names: PackedStringArray = PackedStringArray()
## Rival plates and cars by roster index, the same for the whole championship.
var rival_plates: PackedStringArray = PackedStringArray()
var rival_vehicles: PackedStringArray = PackedStringArray()
## Coins already paid out this championship (GDD 13.2 rewards issued).
var coins_awarded: int = 0
var difficulty_id: String = "normal"
var weapons_enabled: bool = true
## Split screen (never saved): each human's device and car, and whether AI
## rivals fill the grid. Humans are RaceConfig.human_id(slot).
var player_devices: PackedInt32Array = PackedInt32Array()
var player_vehicle_ids: PackedStringArray = PackedStringArray()
var player_plates: PackedStringArray = PackedStringArray()
var ai_rivals: bool = true
## Versus series (Mario Kart style "number of races"): how many races, 0 for
## a cup Grand Prix. Tracks are picked one race at a time (add_track), and
## the series lives in memory only.
var series_races: int = 0
## Versus or Elimination: the race type of every race in a series.
var series_mode: RaceConfig.Mode = RaceConfig.Mode.VERSUS


static func create(p_gp: GrandPrixData, p_difficulty_id: String, p_weapons: bool,
		roster: RivalRoster, p_vehicle_id: String = PlayerProfile.DEFAULT_VEHICLE,
		p_devices: PackedInt32Array = PackedInt32Array(), p_vehicles: PackedStringArray = PackedStringArray(),
		p_ai_rivals: bool = true) -> Championship:
	var c := Championship.new()
	c.gp = p_gp
	c.vehicle_id = p_vehicle_id
	c.player_devices = p_devices.duplicate()
	c.player_vehicle_ids = p_vehicles.duplicate()
	c.ai_rivals = p_ai_rivals
	c.difficulty_id = p_difficulty_id
	c.weapons_enabled = p_weapons
	var count := 7
	if roster != null:
		count = mini(roster.rivals.size(), 7)
		for profile in roster.rivals:
			c.rival_names.append(profile.display_name)
	c.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	c.rival_vehicles = RaceConfig.random_vehicles(7)
	if c.is_multiplayer():
		count = mini(count, RaceConfig.rivals_for(c.player_devices.size(), p_ai_rivals))
	# Race 1: the seven rivals fill slots 1-7, the player starts eighth
	# (split screen: the humans fill the back of the grid).
	c.next_grid = RaceConfig.default_grid(count, maxi(1, c.player_devices.size()))
	for id in c.next_grid:
		c.points[id] = 0
	return c


## A Versus series of `count` races with the settings in `template` (mode,
## laps, weapons, player car, rival plates and cars, split-screen players).
static func create_series(count: int, template: RaceConfig, p_difficulty_id: String,
		roster: RivalRoster) -> Championship:
	var cup := GrandPrixData.new()
	cup.id = "versus"
	cup.display_name = "Versus"
	cup.laps = template.total_laps
	var c := create(cup, p_difficulty_id, template.weapons_enabled, roster, template.vehicle_id,
			template.player_devices, template.player_vehicle_ids, template.ai_rivals)
	c.series_races = maxi(1, count)
	c.series_mode = template.mode
	c.player_plates = template.player_plates.duplicate()
	if template.rival_plates.size() >= 7:
		c.rival_plates = template.rival_plates
	if template.rival_vehicles.size() >= 7:
		c.rival_vehicles = template.rival_vehicles
	return c


func is_series() -> bool:
	return series_races > 0


## Series: the track for the next race (picked on the track screen).
func add_track(track_name: String) -> void:
	gp.track_names.append(track_name)
	gp.locations.append(TrackCatalog.location(track_name))
	gp.track_scenes.append(TrackCatalog.scene_path(track_name))


static func points_for(position: int) -> int:
	return POINTS[position - 1] if position >= 1 and position <= POINTS.size() else 0


func is_multiplayer() -> bool:
	return player_devices.size() > 1


## The best-placed human in the standings (any player wins the cup).
func human_won() -> bool:
	var ranking := standings()
	return not ranking.is_empty() and RaceConfig.is_human_id(ranking[0])


func race_count() -> int:
	if series_races > 0:
		return series_races
	return gp.race_count() if gp != null else 0


func is_complete() -> bool:
	return race_index >= race_count()


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
	config.mode = series_mode if is_series() else RaceConfig.Mode.GRAND_PRIX
	config.difficulty = load(DIFFICULTY_PATH % difficulty_id) as AIDifficulty
	config.weapons_enabled = weapons_enabled
	config.total_laps = gp.laps
	var index := mini(race_index, gp.track_names.size() - 1)
	config.track_name = gp.track_names[index]
	if index < gp.track_scenes.size() and gp.track_scenes[index] != "":
		config.track_scene = load(gp.track_scenes[index]) as PackedScene
	config.grid_order = next_grid.duplicate()
	config.championship = self
	config.vehicle_id = vehicle_id
	config.rival_plates = rival_plates
	config.rival_vehicles = rival_vehicles
	config.player_devices = player_devices.duplicate()
	config.player_vehicle_ids = player_vehicle_ids.duplicate()
	config.player_plates = player_plates.duplicate()
	config.ai_rivals = ai_rivals
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
		"plates": Array(rival_plates),
		"vehicles": Array(rival_vehicles),
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
	c.rival_plates = PackedStringArray(data.get("plates", []))
	if c.rival_plates.size() < 7: # saved before plates were random
		c.rival_plates = RaceConfig.random_plates(7, PlayerProfile.get_profile().plate_text)
	c.rival_vehicles = PackedStringArray(data.get("vehicles", []))
	if c.rival_vehicles.size() < 7: # saved before rivals picked cars
		c.rival_vehicles = RaceConfig.random_vehicles(7)
	c.coins_awarded = int(data.get("coins_awarded", 0))
	c.difficulty_id = str(data.get("difficulty", "normal"))
	c.weapons_enabled = bool(data.get("weapons", true))
	return c


func save() -> bool:
	if is_multiplayer() or is_series():
		return false # split-screen and Versus series live in memory only
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
