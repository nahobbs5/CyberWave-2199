class_name RaceRewards
extends RefCounted
## Coin rewards for one race (GDD 9.3). Additive: completing pays 25, a
## podium adds +15 / +25 / +40, winning a Grand Prix adds +100, plus every
## coin collected on track. Eliminated racers didn't complete the race, so
## they only keep their track coins.

const COMPLETE := 25
const PLACEMENT := {1: 40, 2: 25, 3: 15}
const GRAND_PRIX_WIN := 100


## Returns { "lines": [[label, amount], ...], "total": int }.
static func compute(position: int, completed: bool, track_coins: int, won_grand_prix: bool = false) -> Dictionary:
	var lines: Array = []
	if track_coins > 0:
		lines.append(["Track coins", track_coins])
	if completed:
		lines.append(["Race complete", COMPLETE])
		if PLACEMENT.has(position):
			lines.append(["Finished P%d" % position, PLACEMENT[position]])
	if won_grand_prix:
		lines.append(["Grand Prix win", GRAND_PRIX_WIN])
	var total := 0
	for line in lines:
		total += int(line[1])
	return {"lines": lines, "total": total}
