class_name ItemInventory
extends Node
## Two weapon slots (GDD 6.1). Crates fill the first empty slot; a full
## inventory can't collect. Multi-charge weapons (Triple Nitro) stay in their
## slot until every charge is used; a hit that strips items takes them all.
## After a weapon is used up, the other occupied slot is selected
## automatically. The player's keys (1 / 2 / Space) are read here;
## AI calls select() and request_use() directly.

signal changed
## Asks the WeaponManager to fire the selected weapon.
signal use_requested

const SLOT_COUNT := 2

var slots: Array[WeaponData] = [null, null]
## Charges left per slot (0 when empty).
var charges: Array[int] = [0, 0]
var selected: int = 0

var _vehicle: VehicleController


func _ready() -> void:
	_vehicle = get_parent() as VehicleController


func has_space() -> bool:
	return slots.has(null)


func is_empty() -> bool:
	return slots.all(func(w: WeaponData) -> bool: return w == null)


func current() -> WeaponData:
	return slots[selected]


func add(weapon: WeaponData) -> bool:
	var slot := slots.find(null)
	if slot < 0 or weapon == null:
		return false
	var was_empty := is_empty()
	slots[slot] = weapon
	charges[slot] = maxi(weapon.charges, 1)
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
	var weapon := slots[selected]
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


func request_use() -> void:
	use_requested.emit()


func clear() -> void:
	slots = [null, null]
	charges = [0, 0]
	selected = 0
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _vehicle == null or not _vehicle.player_controlled:
		return
	if event.is_action_pressed("select_slot_1"):
		select(0)
	elif event.is_action_pressed("select_slot_2"):
		select(1)
	elif event.is_action_pressed("use_weapon"):
		request_use()
	else:
		return
	get_viewport().set_input_as_handled()
