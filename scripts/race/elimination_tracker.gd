class_name EliminationTracker
extends RefCounted
## Checkpoint-based elimination (GDD 2.3). At the midpoint gate of laps 1, 2
## and 3, racers qualify in the order they cross. As soon as the qualifying
## places are filled, every other active racer is eliminated. The start /
## finish line never eliminates anyone. There is no timer.

## Racers left after each event (lap 1, 2, 3 midpoints).
const SCHEDULE: Array[int] = [6, 4, 2]

## Checkpoint index of the elimination gate (the lap midpoint).
var gate_index: int
## Next unresolved event (0..SCHEDULE.size()).
var event: int = 0
## Racers that have qualified, per event.
var qualified: Array = [[], [], []]
## Set by on_crossing: did this crossing qualify, and how many places remain.
var just_qualified: bool = false
var just_spots_left: int = 0

var _racers: Array[RaceProgress]


func _init(racers: Array[RaceProgress], p_gate_index: int) -> void:
	_racers = racers
	gate_index = p_gate_index


func is_done() -> bool:
	return event >= SCHEDULE.size()


func active_racers() -> Array[RaceProgress]:
	var out: Array[RaceProgress] = []
	for racer in _racers:
		if not racer.eliminated:
			out.append(racer)
	return out


## Lap whose midpoint is the next elimination (1-based), or 0 when done.
func next_event_lap() -> int:
	return event + 1 if not is_done() else 0


func spots_left() -> int:
	return SCHEDULE[event] - (qualified[event] as Array).size() if not is_done() else 0


func has_qualified(racer: RaceProgress) -> bool:
	return not is_done() and (qualified[event] as Array).has(racer)


## Call for every valid checkpoint crossing. Returns the racers eliminated by
## it (empty unless this crossing filled the last qualifying place).
func on_crossing(racer: RaceProgress, index: int) -> Array[RaceProgress]:
	var none: Array[RaceProgress] = []
	just_qualified = false
	if index != gate_index or racer.eliminated or racer.finished:
		return none
	var e := racer.lap - 1 # lap 1 midpoint = event 0
	if e < event or e >= SCHEDULE.size():
		return none
	var list: Array = qualified[e]
	if list.has(racer):
		return none
	list.append(racer)
	just_qualified = true
	just_spots_left = SCHEDULE[e] - list.size()
	if list.size() < SCHEDULE[e]:
		return none
	# Places filled: everyone still active who didn't qualify for this event is
	# out (this also settles any earlier event a lapped field left open).
	var out: Array[RaceProgress] = []
	for other in active_racers():
		if not list.has(other):
			out.append(other)
	event = e + 1
	return out
