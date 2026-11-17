class_name ItemInventory
extends Node
## Two weapon slots (GDD 6.1). Crates fill the first empty slot; a full
## inventory can't collect. Multi-charge weapons (Triple Nitro) stay in their
## slot until every charge is used; a hit that strips items takes them all.
## After a weapon is used up, the other occupied slot is selected
## automatically. The player's keys (1 / 2 / Space) are read here;
## AI calls select() and request_use() directly.
##
## Crate pickups roll like a slot machine (GDD 6.1): the weapon is decided
## at pickup but the slot "spins" for ROULETTE_TIME and can't be used until
## it lands. Pressing the weapon button during a spin lands it immediately
## (that press doesn't fire).

signal changed
## Asks the WeaponManager to fire the selected weapon.
signal use_requested
## A spinning slot landed on its weapon.
signal revealed(slot: int, weapon: WeaponData)

const SLOT_COUNT := 2
const ROULETTE_TIME := 2.5

var slots: Array[WeaponData] = [null, null]
## Charges left per slot (0 when empty).
var charges: Array[int] = [0, 0]
var selected: int = 0
## Seconds of roulette left per slot (0 = not spinning).
var spin_left: Array[float] = [0.0, 0.0]

var _vehicle: VehicleController


func _ready() -> void:
	_vehicle = get_parent() as VehicleController


func has_space() -> bool:
	return slots.has(null)


func is_empty() -> bool:
	return slots.all(func(w: WeaponData) -> bool: return w == null)


## The selected weapon, or null while its slot is empty or still spinning.
func current() -> WeaponData:
	return null if is_spinning(selected) else slots[selected]


func is_spinning(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT and spin_left[slot] > 0.0


func any_spinning() -> bool:
	return spin_left.any(func(t: float) -> bool: return t > 0.0)


## Fraction of the spin done (0 just picked up .. 1 landed).
func spin_progress(slot: int) -> float:
	return 1.0 - clampf(spin_left[slot] / ROULETTE_TIME, 0.0, 1.0)


## True if `weapon` is a one-per-inventory weapon already held (or rolling).
func holds_unique(weapon: WeaponData) -> bool:
	return weapon != null and weapon.one_per_inventory and slots.has(weapon)


## `spin` = crate pickup: the slot rolls before the weapon can be used.
func add(weapon: WeaponData, spin: bool = false) -> bool:
	var slot := slots.find(null)
	if slot < 0 or weapon == null or holds_unique(weapon):
		return false
	var was_empty := is_empty()
	slots[slot] = weapon
	charges[slot] = maxi(weapon.charges, 1)
	spin_left[slot] = ROULETTE_TIME if spin else 0.0
	if was_empty or slots[selected] == null:
		selected = slot
	changed.emit()
	return true


func select(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slot == selected:
		return
	selected = slot
	changed.emit()


## Uses one charge of the selected weapon and returns it. When the slot runs
## out it empties and the other occupied slot is selected.
func take_selected() -> WeaponData:
	var weapon := current()
	if weapon == null:
		return null
	charges[selected] -= 1
	if charges[selected] > 0:
		changed.emit()
		return weapon
	_empty_selected()
	return weapon


func _empty_selected() -> void:
	slots[selected] = null
	charges[selected] = 0
	spin_left[selected] = 0.0
	var other := (selected + 1) % SLOT_COUNT
	if slots[other] != null:
		selected = other
	changed.emit()


## Knocks out a weapon after a hit (all its charges): the selected one, or
## the other if the selected slot is empty. Returns it, or null if empty.
func lose_item() -> WeaponData:
	if slots[selected] == null:
		var other := (selected + 1) % SLOT_COUNT
		if slots[other] == null:
			return null
		selected = other
	var weapon := slots[selected]
	_empty_selected()
	return weapon


## Fires the selected weapon - or, while anything is rolling, lands the
## roll instead (that press doesn't fire).
func request_use() -> void:
	if any_spinning():
		stop_spin()
		return
	use_requested.emit()


## Lands every spinning slot now.
func stop_spin() -> void:
	for i in SLOT_COUNT:
		if spin_left[i] > 0.0:
			_reveal(i)


func _reveal(slot: int) -> void:
	spin_left[slot] = 0.0
	changed.emit()
	revealed.emit(slot, slots[slot])


func _physics_process(delta: float) -> void:
	for i in SLOT_COUNT:
		if spin_left[i] > 0.0:
			spin_left[i] -= delta
			if spin_left[i] <= 0.0:
				_reveal(i)


func clear() -> void:
	slots = [null, null]
	charges = [0, 0]
	spin_left = [0.0, 0.0]
	selected = 0
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _vehicle == null or not _vehicle.player_controlled:
		return
	if event.is_action_pressed(_vehicle.action(&"select_slot_1")):
		select(0)
	elif event.is_action_pressed(_vehicle.action(&"select_slot_2")):
		select(1)
	elif event.is_action_pressed(_vehicle.action(&"use_weapon")):
		request_use()
	else:
		return
	get_viewport().set_input_as_handled()
