class_name TimeTrialCatalog
extends RefCounted
## Time Trial (GDD 2.5): every track's rival car and its expert reward.
## Always 3 laps, 150cc (CC), forward, no crates: every car (you and the ghosts)
## starts with one Triple Nitro to use at any point in the race.
##   Rival ghost   a locked car, set so a clean run in any starter car can
##                 win. Beat it: the car is yours, unless it's won from a
##                 cup or Elimination (UnlockCatalog.time_trial_unlocks).
##   Expert ghost  the same car, much faster (clean tricks, drift timing and
##                 shortcuts). Beat it: that car's signature paint or animated
##                 underglow, or EXPERT_COINS when this track's car has
##                 already given both elsewhere.
## Ghosts are baked by tests/tools/bake_ghosts.gd into GHOST_DIR.

const LAPS := 3
## Engine class every Time Trial runs at (ghosts were baked at it).
const CC := 150
## The one item every car starts a Time Trial with.
const STARTING_ITEM := "res://resources/weapons/triple_nitro.tres"
const GHOST_DIR := "res://resources/ghosts/"
## Your own best run on each track (saved when you set a new best).
const PLAYER_GHOST_DIR := "user://ghosts/"
## Where rival / expert ghosts load from (tests point it at user://).
static var ghost_dir: String = GHOST_DIR
## Where your best ghosts are kept (tests point it elsewhere).
static var player_ghost_dir: String = PLAYER_GHOST_DIR
## An expert win that has no cosmetic left to give.
const EXPERT_COINS := 500

enum Ghost { RIVAL, EXPERT, BEST, NONE }
const GHOST_NAMES: Array[String] = ["Rival", "Expert", "Your Best", "No Ghost"]

## [track name, rival vehicle id, expert reward cosmetic id or ""]
const TRACKS := [
	["Vegas Overdrive", "empyrean_s", "sig_paint_empyrean_s"],
	["The Stacks", "valkyrie_r", "sig_paint_valkyrie_r"],
	["Six Flags New Orleans", "orbiter", "sig_paint_orbiter"],
	["Marble Canyon", "nexus_x", "sig_paint_nexus_x"],
	["Hoia Baciu Run", "cipher_evo", "sig_paint_cipher_evo"],
	["Catacombs Descent", "nexus_x", "sig_glow_nexus_x"],
	["Vatnajökull Glacier", "empyrean_s", "sig_glow_empyrean_s"],
	["Arashiyama Circuit", "switchback", "sig_paint_switchback"],
	["Crazy House", "valkyrie_r", "sig_glow_valkyrie_r"],
	["Gardens by the Bay", "orbiter", "sig_glow_orbiter"],
	["Parque Quinta Normal", "high_roller", "sig_paint_high_roller"],
	["Vale da Lua", "afterimage", "sig_paint_afterimage"],
	["Choquequirao", "cipher_evo", "sig_glow_cipher_evo"],
	["Kilwa Kisiwani Ruins", "interceptor", "sig_paint_interceptor"],
	["Fires of Nyiragongo", "revenant", "sig_paint_revenant"],
	["Chefchaouen", "valkyrie_r", ""],
]

## Playtest tuning without re-baking: track name -> [rival s, expert s]
## (0 = keep the baked ghost's target time).
const TARGET_OVERRIDES := {}


static func starting_item() -> WeaponData:
	return load(STARTING_ITEM) as WeaponData


## Track names in menu order.
static func tracks() -> Array[String]:
	var out: Array[String] = []
	for row in TRACKS:
		out.append(row[0])
	return out


static func has_track(track_name: String) -> bool:
	return _row(track_name).size() > 0


## The rival car's vehicle id on a track ("" if it has no Time Trial).
static func rival_vehicle(track_name: String) -> String:
	var row := _row(track_name)
	return row[1] if row.size() > 0 else ""


## Cosmetic id the expert ghost gives ("" = coins).
static func expert_reward(track_name: String) -> String:
	var row := _row(track_name)
	return row[2] if row.size() > 0 else ""


## Tracks where `vehicle_id` is the rival.
static func tracks_for_rival(vehicle_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for row in TRACKS:
		if row[1] == vehicle_id:
			out.append(row[0])
	return out


## "vegas_overdrive" (the track scene's file name).
static func slug(track_name: String) -> String:
	return TrackCatalog.scene_path(track_name).get_file().get_basename()


static func ghost_path(track_name: String, kind: Ghost) -> String:
	match kind:
		Ghost.RIVAL:
			return ghost_dir + slug(track_name) + "_rival.res"
		Ghost.EXPERT:
			return ghost_dir + slug(track_name) + "_expert.res"
		Ghost.BEST:
			return player_ghost_dir + slug(track_name) + ".res"
	return ""


## The ghost to race, or null (none baked / no saved best). Rival and expert
## ghosts get their target time from TARGET_OVERRIDES when one is set.
static func load_ghost(track_name: String, kind: Ghost) -> GhostData:
	var path := ghost_path(track_name, kind)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ghost := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GhostData
	if ghost == null:
		return null
	var o: Array = TARGET_OVERRIDES.get(track_name, [])
	if kind != Ghost.BEST and o.size() == 2:
		var t := float(o[0] if kind == Ghost.RIVAL else o[1])
		if t > 0.0:
			ghost.target_time = t
	return ghost


## Target time to beat (seconds), or 0 when the ghost doesn't exist.
static func target_time(track_name: String, kind: Ghost) -> float:
	var ghost := load_ghost(track_name, kind)
	return ghost.finish_time() if ghost != null else 0.0


static func _row(track_name: String) -> Array:
	for row in TRACKS:
		if row[0] == track_name:
			return row
	return []
