class_name UnlockCatalog
extends RefCounted
## Which cars you start with and how the others are unlocked (GDD 9.1a).
## Every route is data here, so a new car only needs rows:
##   STARTERS            owned from the start.
##   CUP_UNLOCKS         win the cup's Grand Prix (1st overall, any engine
##                       class, forward or Mirror). The cups, in menu order,
##                       give the last five of the original eight cars in
##                       list order. This is their only route.
##   ELIMINATION_UNLOCK  win an Elimination race (the first of the five
##                       newer cars).
##   MIRROR_PODIUM_UNLOCK  finish in the top 3 of a Mirror race.
##   TOP_CC_WIN_UNLOCK   win a race at 200cc.
##   PRACTICE_LAP_UNLOCK  find the developer track (PRACTICE_LAP_TRACK) in
##                       Practice and run a full lap of it (free drive).
##   Time Trial          every other car: beat the rival ghost on any track
##                       where the car is the rival (TimeTrialCatalog.TRACKS).
##                       Cars with another route are still rival ghosts
##                       (expert prizes), but beating them doesn't unlock them.
## Each car has one route. Race routes count in single player or split
## screen (any player's result unlocks the car for the profile).
## AI rivals still drive every car, so locked cars show up out on track.

const STARTERS: Array[String] = ["v8_specter", "aurora_gt", "riviera_88"]

## GrandPrixData id -> vehicle id.
const CUP_UNLOCKS := {
	"american_circuit": "empyrean_s",
	"world_circuit": "nexus_x",
	"asia_circuit": "orbiter",
	"south_america_circuit": "valkyrie_r",
	"africa_circuit": "cipher_evo",
}

## The car an Elimination win unlocks.
const ELIMINATION_UNLOCK := "switchback"
## The car a top-MIRROR_PODIUM_PLACES finish in a Mirror race unlocks.
const MIRROR_PODIUM_UNLOCK := "afterimage"
const MIRROR_PODIUM_PLACES := 3
## The car winning a race at TOP_CC unlocks.
const TOP_CC_WIN_UNLOCK := "high_roller"
const TOP_CC := 200
## The car a full free-drive lap of PRACTICE_LAP_TRACK unlocks (Practice only).
const PRACTICE_LAP_UNLOCK := "interceptor"
const PRACTICE_LAP_TRACK := "Vegas Overdrive"


static func is_starter(vehicle_id: String) -> bool:
	return vehicle_id in STARTERS


## True if beating this car's rival ghost unlocks it: not a starter and
## no other route.
static func time_trial_unlocks(vehicle_id: String) -> bool:
	return vehicle_id != "" and not is_starter(vehicle_id) and not vehicle_id in CUP_UNLOCKS.values() \
			and not vehicle_id in [ELIMINATION_UNLOCK, MIRROR_PODIUM_UNLOCK, TOP_CC_WIN_UNLOCK, PRACTICE_LAP_UNLOCK]


## The car winning `cup_id` unlocks ("" = none).
static func cup_unlock(cup_id: String) -> String:
	return str(CUP_UNLOCKS.get(cup_id, ""))


## Every way to unlock a car, one line each ("Win the Asia Cup Grand Prix",
## "Beat its rival ghost in Time Trial on Vale da Lua").
static func how_to_unlock(vehicle_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	if is_starter(vehicle_id):
		return out
	var tracks := TimeTrialCatalog.tracks_for_rival(vehicle_id)
	if not tracks.is_empty() and time_trial_unlocks(vehicle_id):
		out.append("Beat its rival ghost in Time Trial on " + join_or(tracks))
	for cup_id in CUP_UNLOCKS:
		if CUP_UNLOCKS[cup_id] == vehicle_id:
			out.append("Win the %s Grand Prix" % _cup_name(cup_id))
	if ELIMINATION_UNLOCK == vehicle_id:
		out.append("Win an Elimination race")
	if MIRROR_PODIUM_UNLOCK == vehicle_id:
		out.append("Finish in the top %d of a Mirror race" % MIRROR_PODIUM_PLACES)
	if TOP_CC_WIN_UNLOCK == vehicle_id:
		out.append("Win a race at %dcc" % TOP_CC)
	if PRACTICE_LAP_UNLOCK == vehicle_id:
		out.append("Find the developer's discarded versus rough draft and run a complete lap")
	return out


## "A", "A or B", "A, B or C".
static func join_or(items: PackedStringArray) -> String:
	if items.size() <= 1:
		return "".join(items)
	return ", ".join(items.slice(0, items.size() - 1)) + " or " + items[items.size() - 1]


static func _cup_name(cup_id: String) -> String:
	for cup in GrandPrixData.all_cups():
		if cup.id == cup_id:
			return cup.display_name
	return cup_id
