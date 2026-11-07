class_name Slipstream
extends RefCounted
## Slipstream (drafting), Mario Kart style: tuck in close behind another car
## and a meter fills; when it's full you get a short boost that slingshots
## you past. Out of the tow the meter drains. Applies to every racer, AI
## included. RaceManager calls update() each physics step.

## The car ahead must be this far in front of you (metres)...
const MIN_GAP := 2.0
const MAX_GAP := 16.0
## ...and no more than this far to the side of your line.
const MAX_SIDE := 2.6
## Headings within this angle count as going the same way (cos 30 deg).
const SAME_WAY := 0.866
## No slipstream below this speed (m/s; 72 km/h).
const MIN_SPEED := 20.0
## Seconds to fill the meter at CLOSE_GAP, and at MAX_GAP.
const CLOSE_GAP := 6.0
const FILL_CLOSE := 1.4
const FILL_FAR := 2.2
## Out of the tow, the meter drains this many times faster than it filled.
const DRAIN_FACTOR := 2.0
## The boost when the meter is full: milder than a Cyan drift boost.
const BOOST_EXTRA := 4.5
const BOOST_TIME := 1.2
const BOOST_KICK := 2.5
const BOOST_COLOR := Color(0.75, 0.95, 1.0)
## No new meter for this long after a slipstream boost.
const COOLDOWN := 2.0

var _cooldowns: Dictionary = {}


## How much `me` is in the tow of `other`: 0 = not at all, else the fill
## rate in meter-per-second (faster when closer). Pure, for tests.
static func tow_rate(me: Transform3D, me_velocity: Vector3, other: Transform3D, other_velocity: Vector3) -> float:
	var forward := -me.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return 0.0
	forward = forward.normalized()
	var my_speed := me_velocity.dot(forward)
	if my_speed < MIN_SPEED:
		return 0.0
	var other_forward := -other.basis.z
	other_forward.y = 0.0
	if other_forward.normalized().dot(forward) < SAME_WAY or other_velocity.dot(forward) < MIN_SPEED * 0.5:
		return 0.0
	var to_other := other.origin - me.origin
	to_other.y = 0.0
	var ahead := to_other.dot(forward)
	if ahead < MIN_GAP or ahead > MAX_GAP:
		return 0.0
	var side := absf(to_other.dot(Vector3(-forward.z, 0.0, forward.x)))
	if side > MAX_SIDE:
		return 0.0
	var t := clampf((ahead - CLOSE_GAP) / (MAX_GAP - CLOSE_GAP), 0.0, 1.0)
	return 1.0 / lerpf(FILL_CLOSE, FILL_FAR, t)


## Fills or drains every racer's meter and fires the boost when full.
func update(racers: Array[RaceProgress], delta: float) -> void:
	for racer in racers:
		var car := racer.vehicle
		if not _can_draft(racer):
			if is_instance_valid(car):
				car.in_slipstream = false
				car.slipstream_charge = 0.0
			continue
		var cooldown: float = maxf(0.0, _cooldowns.get(car, 0.0) - delta)
		_cooldowns[car] = cooldown
		var rate := 0.0
		if cooldown <= 0.0 and not car.is_boosting() and car.grounded_wheels >= 2:
			for other in racers:
				if other == racer or not _is_leader(other):
					continue
				rate = maxf(rate, tow_rate(car.global_transform, car.linear_velocity,
						other.vehicle.global_transform, other.vehicle.linear_velocity))
		car.in_slipstream = rate > 0.0
		if rate > 0.0:
			car.slipstream_charge = minf(1.0, car.slipstream_charge + rate * delta)
			if car.slipstream_charge >= 1.0:
				car.slipstream_charge = 0.0
				car.in_slipstream = false
				_cooldowns[car] = COOLDOWN
				car.start_external_boost(BOOST_EXTRA, BOOST_TIME, BOOST_KICK, "Slipstream", BOOST_COLOR)
				car.slipstream_boost.emit()
		else:
			car.slipstream_charge = maxf(0.0, car.slipstream_charge - delta * DRAIN_FACTOR / FILL_CLOSE)


static func _can_draft(racer: RaceProgress) -> bool:
	var car := racer.vehicle
	return is_instance_valid(car) and car.visible and not car.is_recovering_hidden() and not racer.finished and not racer.eliminated


## A car you can draft behind: any car still on track (finished ones too,
## while they're still driving), on the ground.
static func _is_leader(racer: RaceProgress) -> bool:
	var car := racer.vehicle
	return is_instance_valid(car) and car.visible and not car.is_recovering_hidden() and not racer.eliminated \
			and car.grounded_wheels >= 2
