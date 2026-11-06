class_name PlayerProfile
extends RefCounted
## Persistent player progress (GDD 13.1, 14.2 ProgressionManager / SaveManager):
## coins, owned and equipped cosmetics, the global license plate, the selected
## vehicle, personal bests, Grand Prix results and the last race setup.
## Settings, bindings and the camera view live in GameSettings instead.
##
## Saved as versioned JSON with an atomic write. Access through
## PlayerProfile.get_profile(); it loads on first use and stays in memory.

const SAVE_VERSION := 1
const PLATE_MAX := 8
const DEFAULT_PLATE := "CW-2199"
const DEFAULT_VEHICLE := "v8_specter"

## Tests point this somewhere else.
static var save_path: String = "user://profile.json"
static var _instance: PlayerProfile

var coins: int = 0
var owned: Array[String] = []
## vehicle id -> { category name: item id }
var equipped: Dictionary = {}
var plate_text: String = DEFAULT_PLATE
var selected_vehicle: String = DEFAULT_VEHICLE
## "track|laps" -> { "race": seconds, "lap": seconds }
var personal_bests: Dictionary = {}
## One entry per completed championship.
var gp_results: Array = []
## Last race setup screen choices (GDD 11.3 "remembered").
var last_setup: Dictionary = {}


static func get_profile() -> PlayerProfile:
	if _instance == null:
		_instance = load_from_disk()
	return _instance


## Drops the in-memory copy so the next access reads the file again (as if
## the game had been restarted).
static func reload_from_disk() -> PlayerProfile:
	_instance = null
	return get_profile()


static func load_from_disk() -> PlayerProfile:
	var p := PlayerProfile.new()
	var text := SaveUtil.read_text(save_path)
	if text != "":
		# A damaged file just means a fresh profile (parse quietly).
		var json := JSON.new()
		var data: Variant = json.data if json.parse(text) == OK else null
		if data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
			p._read(data)
	p._ensure_free_items()
	return p


static func delete_save() -> void:
	SaveUtil.remove(save_path)
	_instance = null


func save() -> bool:
	return SaveUtil.write_atomic(save_path, JSON.stringify(_to_dict(), "\t"))


# --- coins and the shop ---------------------------------------------------------

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)


func owns(id: String) -> bool:
	return owned.has(id)


func can_buy(item: CosmeticItem) -> bool:
	return item != null and not owns(item.id) and coins >= item.price


## Spends coins and adds the item permanently (GDD 9.4). Saves on success.
func buy(item: CosmeticItem) -> bool:
	if not can_buy(item):
		return false
	coins -= item.price
	owned.append(item.id)
	save()
	return true


func equip(vehicle_id: String, item: CosmeticItem) -> bool:
	if item == null or not owns(item.id):
		return false
	var loadout: Dictionary = equipped.get(vehicle_id, {})
	loadout[CosmeticItem.CATEGORY_NAMES[item.category]] = item.id
	equipped[vehicle_id] = loadout
	save()
	return true


func equipped_item(vehicle_id: String, category: CosmeticItem.Category) -> CosmeticItem:
	var loadout: Dictionary = equipped.get(vehicle_id, {})
	var item := CosmeticCatalog.by_id(str(loadout.get(CosmeticItem.CATEGORY_NAMES[category], "")))
	return item if item != null and owns(item.id) else CosmeticCatalog.default_for(category)


## category -> CosmeticItem for every category.
func loadout_for(vehicle_id: String) -> Dictionary:
	var out := {}
	for category in CosmeticItem.Category.values():
		out[category] = equipped_item(vehicle_id, category)
	return out


## Unowned items the player can now afford but couldn't before (results
## screen "newly available cosmetics", GDD 11.7).
func newly_affordable(coins_before: int) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for item in CosmeticCatalog.items():
		if not owns(item.id) and item.price > coins_before and item.price <= coins:
			out.append(item)
	return out


# --- plate, vehicle ---------------------------------------------------------------

## Upper-case letters, digits, spaces and dashes, at most 8 characters (GDD 9.5).
static func sanitize_plate(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "-":
			out += ch
	return out.substr(0, PLATE_MAX)


func set_plate(text: String) -> void:
	plate_text = sanitize_plate(text)
	save()


func set_selected_vehicle(id: String) -> void:
	selected_vehicle = id
	save()


# --- records -----------------------------------------------------------------------

static func best_key(track_name: String, laps: int) -> String:
	return "%s|%d" % [track_name, laps]


func best_for(track_name: String, laps: int) -> Dictionary:
	return personal_bests.get(best_key(track_name, laps), {})


## Records a finished race. Returns { "race": bool, "lap": bool } for which
## personal bests were beaten. Doesn't save (the caller saves once).
func record_race_time(track_name: String, laps: int, race_time: float, best_lap: float) -> Dictionary:
	var key := best_key(track_name, laps)
	var best: Dictionary = personal_bests.get(key, {})
	var result := {"race": false, "lap": false}
	if race_time > 0.0 and (not best.has("race") or race_time < float(best.race)):
		best["race"] = race_time
		result.race = true
	if best_lap > 0.0 and (not best.has("lap") or best_lap < float(best.lap)):
		best["lap"] = best_lap
		result.lap = true
	personal_bests[key] = best
	return result


## Track renames: best times saved under an old name move to the new one.
const TRACK_RENAMES := {"The Stacks Grand Prix": "The Stacks"}


func _rename_track_bests() -> void:
	for key in personal_bests.keys():
		var parts := str(key).split("|")
		if parts.size() == 2 and TRACK_RENAMES.has(parts[0]):
			var new_key := best_key(TRACK_RENAMES[parts[0]], int(parts[1]))
			if not personal_bests.has(new_key):
				personal_bests[new_key] = personal_bests[key]
			personal_bests.erase(key)


func record_grand_prix(gp_id: String, position: int, points: int) -> void:
	gp_results.append({"championship": gp_id, "position": position, "points": points,
			"date": Time.get_date_string_from_system()})


## Best championship finish so far (0 = never completed).
func best_grand_prix(gp_id: String) -> int:
	var best := 0
	for entry in gp_results:
		if str(entry.get("championship", "")) == gp_id:
			var p := int(entry.get("position", 0))
			if best == 0 or p < best:
				best = p
	return best


# --- serialisation -----------------------------------------------------------------

func _ensure_free_items() -> void:
	for id in CosmeticCatalog.free_ids():
		if not owned.has(id):
			owned.append(id)


func _to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins,
		"owned": owned,
		"equipped": equipped,
		"plate": plate_text,
		"vehicle": selected_vehicle,
		"personal_bests": personal_bests,
		"grand_prix_results": gp_results,
		"last_setup": last_setup,
	}


func _read(data: Dictionary) -> void:
	coins = maxi(0, int(data.get("coins", 0)))
	for id in data.get("owned", []):
		if CosmeticCatalog.by_id(str(id)) != null and not owned.has(str(id)):
			owned.append(str(id))
	var eq: Variant = data.get("equipped", {})
	if eq is Dictionary:
		equipped = eq
	plate_text = sanitize_plate(str(data.get("plate", DEFAULT_PLATE)))
	selected_vehicle = str(data.get("vehicle", DEFAULT_VEHICLE))
	var pb: Variant = data.get("personal_bests", {})
	if pb is Dictionary:
		personal_bests = pb
		_rename_track_bests()
	var gp: Variant = data.get("grand_prix_results", [])
	if gp is Array:
		gp_results = gp
	var setup: Variant = data.get("last_setup", {})
	if setup is Dictionary:
		last_setup = setup
