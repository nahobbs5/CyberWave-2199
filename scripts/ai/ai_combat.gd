class_name AICombat
extends Node
## AI weapon decisions (GDD 7.4, 14.2 AICombatLogic).
##
## Every "think" interval (difficulty.weapon_reaction) the AI scores each held
## weapon for the current situation and uses the best one that's worth it.
## Targeted weapons are selected early so the lock can build. Unused weapons
## are eventually spent anyway; aggressive rivals spend them sooner.

var vehicle: VehicleController
var manager: WeaponManager
var line: RacingLine
var profile: RacerProfile
var difficulty: AIDifficulty

var _think: float = 0.0
var _held: Array[float] = [0.0, 0.0]
## Seconds since this car last dropped a hazard (spaces out a Triple Spike).
var _since_hazard: float = 99.0
## Minimum gap between hazard drops.
const HAZARD_GAP := 1.5
var _rng := RandomNumberGenerator.new()


func setup(p_vehicle: VehicleController, p_manager: WeaponManager, p_line: RacingLine,
		p_profile: RacerProfile, p_difficulty: AIDifficulty, seed_value: int) -> void:
	vehicle = p_vehicle
	manager = p_manager
	line = p_line
	profile = p_profile if p_profile != null else RacerProfile.new()
	difficulty = p_difficulty if p_difficulty != null else AIDifficulty.new()
	_rng.seed = seed_value


func _physics_process(delta: float) -> void:
	if vehicle == null or manager == null or vehicle.inventory == null:
		return
	var inventory := vehicle.inventory
	for i in ItemInventory.SLOT_COUNT:
		_held[i] = _held[i] + delta if inventory.slots[i] != null else 0.0
	_since_hazard += delta
	if not manager.can_fight(vehicle) or inventory.is_empty():
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = difficulty.weapon_reaction * _rng.randf_range(0.7, 1.3)
	# Less skilled AI sometimes miss their chance.
	if _rng.randf() > difficulty.weapon_skill:
		return

	var best_slot := -1
	var best_score := 0.0
	for i in ItemInventory.SLOT_COUNT:
		var weapon := inventory.slots[i]
		if weapon == null:
			continue
		var score := _score(weapon, i == inventory.selected, _held[i])
		if score > best_score:
			best_score = score
			best_slot = i
	if best_slot >= 0 and best_score >= 1.0:
		inventory.select(best_slot)
		if inventory.slots[best_slot].kind == WeaponData.Kind.HAZARD:
			_since_hazard = 0.0
		inventory.request_use()
		return
	# Nothing to fire yet: keep a targeted weapon selected so a lock can build.
	for i in ItemInventory.SLOT_COUNT:
		var weapon := inventory.slots[i]
		if weapon != null and weapon.targeted and vehicle.targeting != null \
				and vehicle.targeting.find_best_candidate() != null:
			inventory.select(i)
			return


## >= 1 means "use it now".
func _score(weapon: WeaponData, selected: bool, held: float) -> float:
	# Aggressive rivals spend weapons sooner; cautious ones hold longer.
	var patience := lerpf(1.5, 0.6, profile.aggression)
	match weapon.kind:
		WeaponData.Kind.PROJECTILE:
			if selected and vehicle.targeting != null and vehicle.targeting.locked:
				return 1.5
			return 1.0 if held > 18.0 * patience else 0.0
		WeaponData.Kind.GUIDED:
			if selected and vehicle.targeting != null and vehicle.targeting.locked:
				return 1.5
			if held > 8.0 * patience and manager.find_target_ahead(vehicle.global_position, vehicle, 100.0) != null:
				return 1.2
			return 0.0
		WeaponData.Kind.AREA:
			return 1.3 if _opponents_within(weapon.radius * 0.85) > 0 else 0.0
		WeaponData.Kind.HAZARD:
			if _since_hazard < HAZARD_GAP:
				return 0.0
			if _opponent_behind(40.0):
				return 1.2
			return 1.0 if held > 20.0 * patience else 0.0
		WeaponData.Kind.SELF_BOOST:
			# One Nitro at a time: a Triple Nitro waits for the last burst to end.
			if _straight_ahead() and not vehicle.drift.is_drifting() and not vehicle.is_boosting() \
					and vehicle.forward_speed > 20.0:
				return 1.1
			return 0.0
		WeaponData.Kind.SHIELD:
			if manager.is_incoming(vehicle):
				return 2.0
			return 1.0 if held > 30.0 * patience else 0.0
	return 0.0


func _opponents_within(radius: float) -> int:
	var count := 0
	for racer in manager.race.racers:
		var other := racer.vehicle
		if other != vehicle and manager.is_targetable(other) \
				and other.global_position.distance_to(vehicle.global_position) <= radius:
			count += 1
	return count


func _opponent_behind(max_distance: float) -> bool:
	var forward := -vehicle.global_transform.basis.z
	var right := vehicle.global_transform.basis.x
	for racer in manager.race.racers:
		var other := racer.vehicle
		if other == vehicle or not manager.is_targetable(other):
			continue
		var rel := other.global_position - vehicle.global_position
		var ahead := rel.dot(forward)
		if ahead < -3.0 and ahead > -max_distance and absf(rel.dot(right)) < 5.0:
			return true
	return false


func _straight_ahead() -> bool:
	var offset := manager.track.get_offset_at(vehicle.global_position)
	var top := vehicle.stats.top_speed
	for d in range(0, 160, 20):
		if line.speed_at(offset + d) < top * 0.97:
			return false
	return true
