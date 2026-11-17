extends SceneTree
## Crate roulette (GDD 6.1): a crate pickup rolls like a slot machine before
## the weapon can be used; pressing fire lands it at once without firing.
## Overdrive Protocol and System Override are one per inventory. Run from the
## project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_weapon_roulette.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const RAILGUN := "res://resources/weapons/railgun.tres"
const FIREWALL := "res://resources/weapons/firewall.tres"
const OVERDRIVE := "res://resources/weapons/overdrive_protocol.tres"
const OVERRIDE := "res://resources/weapons/system_override.tres"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_weapon_roulette_profile.json"
	GameSettings.path = "user://test_weapon_roulette_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s" % message)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run_all() -> void:
	var railgun := load(RAILGUN) as WeaponData
	var firewall := load(FIREWALL) as WeaponData
	var overdrive := load(OVERDRIVE) as WeaponData
	var override := load(OVERRIDE) as WeaponData
	_check(overdrive.one_per_inventory and override.one_per_inventory,
			"Overdrive and System Override are one per inventory")
	_check(not railgun.one_per_inventory and not firewall.one_per_inventory, "ordinary weapons stack")

	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.weapons_enabled = true
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	var manager := race.weapon_manager
	var me: VehicleController = race.player.vehicle
	var inv := me.inventory
	# Freeze the field so nobody fires at the player or picks things up.
	for racer in race.racers:
		var combat := racer.vehicle.get_node_or_null("AICombat")
		if combat != null:
			combat.set_physics_process(false)
	_check(manager.roulette_enabled, "the roulette is on by default")

	await _test_roulette(race, manager, me, inv)
	await _test_stop_press(manager, me, inv)
	await _test_unique(manager, me, inv, overdrive, override, railgun, firewall)
	await _test_strip_and_clear(inv, railgun)
	await _test_ai(race, manager, railgun)

	race.queue_free()
	await process_frame
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_roulette(race: RaceManager, manager: WeaponManager, me: VehicleController, inv: ItemInventory) -> void:
	inv.clear()
	var items := race.race_hud.items
	await process_frame
	await process_frame
	var anims_before := items.pickup_anims
	var revealed: Array = []
	var on_reveal := func(slot: int, w: WeaponData) -> void: revealed.append([slot, w])
	inv.revealed.connect(on_reveal)
	var used: Array = []
	var on_used := func(v: VehicleController, w: WeaponData) -> void:
		if v == me:
			used.append(w)
	manager.weapon_used.connect(on_used)

	_check(manager.try_give_weapon(me), "a crate gives a weapon")
	_check(inv.is_spinning(0), "the slot is rolling after a crate pickup")
	_check(inv.slots[0] != null, "the weapon is already decided under the roll")
	_check(inv.current() == null, "a rolling slot has no current weapon")
	_check(not manager.use_weapon(me), "can't fire while it rolls")
	await _frames(30)
	await process_frame
	await process_frame
	_check(items.captions[0].text == "ROLLING", "HUD caption says ROLLING (%s)" % items.captions[0].text)
	_check(items.icons[0].texture != null, "HUD shows a cycling icon")
	_check(items.spin_flicks[0] >= 2, "HUD icon flicks through weapons (%d)" % items.spin_flicks[0])
	_check(items.pickup_anims == anims_before, "no pickup pop until it lands")
	_check(revealed.is_empty(), "not revealed early")
	await _frames(int(ItemInventory.ROULETTE_TIME * 60.0) + 5)
	_check(not inv.is_spinning(0), "the roll lands after %.1f s" % ItemInventory.ROULETTE_TIME)
	_check(revealed.size() == 1 and revealed[0][0] == 0 and revealed[0][1] == inv.slots[0],
			"revealed fires once with the weapon (%d)" % revealed.size())
	_check(inv.current() == inv.slots[0], "the weapon is usable once landed")
	await process_frame
	await process_frame
	_check(items.pickup_anims == anims_before + 1, "pickup pop plays when it lands")
	_check(items.icons[0].texture == inv.slots[0].icon, "HUD shows the real weapon icon")
	_check(used.is_empty(), "nothing was fired")
	inv.revealed.disconnect(on_reveal)
	manager.weapon_used.disconnect(on_used)


func _test_stop_press(manager: WeaponManager, me: VehicleController, inv: ItemInventory) -> void:
	inv.clear()
	var used: Array = []
	var on_used := func(v: VehicleController, w: WeaponData) -> void:
		if v == me:
			used.append(w)
	manager.weapon_used.connect(on_used)
	var revealed_by_manager: Array = []
	var on_rev := func(v: VehicleController, w: WeaponData) -> void:
		if v == me:
			revealed_by_manager.append(w)
	manager.weapon_revealed.connect(on_rev)
	manager.try_give_weapon(me)
	await _frames(10)
	_check(inv.is_spinning(0), "still rolling after 10 frames")
	inv.request_use()
	_check(not inv.is_spinning(0), "fire press lands the roll at once")
	_check(used.is_empty(), "that press doesn't fire")
	_check(revealed_by_manager.size() == 1, "WeaponManager re-emits weapon_revealed")
	_check(inv.current() != null, "weapon ready after the press")
	inv.request_use()
	_check(used.size() == 1, "a second press fires")
	# Two rolling slots: one press lands both.
	inv.clear()
	manager.try_give_weapon(me)
	manager.try_give_weapon(me)
	_check(inv.is_spinning(0) and inv.is_spinning(1), "both slots can roll at once")
	inv.request_use()
	_check(not inv.any_spinning(), "one press lands both")
	manager.weapon_used.disconnect(on_used)
	manager.weapon_revealed.disconnect(on_rev)
	# A new roll in slot 2 doesn't steal the selection from a ready slot 1.
	inv.clear()
	inv.add(load(RAILGUN) as WeaponData)
	manager.try_give_weapon(me)
	_check(inv.selected == 0 and inv.current() != null, "the ready weapon stays selected while slot 2 rolls")
	inv.clear()


func _test_unique(manager: WeaponManager, me: VehicleController, inv: ItemInventory,
		overdrive: WeaponData, override: WeaponData, railgun: WeaponData, firewall: WeaponData) -> void:
	var saved := manager.weapons.duplicate()
	# Only Overdrive + Railgun in the crates: with Overdrive held, every roll
	# must give the Railgun.
	var pos := manager.race.progress_of(me).position
	var count := manager.race.racers.size()
	var other: WeaponData = null
	for w in saved:
		if not w.one_per_inventory and w.chance_for(pos, count) > 0.0:
			other = w
			break
	_check(other != null, "some ordinary weapon can roll at P%d" % pos)
	for unique in [overdrive, override]:
		manager.weapons.assign([unique, other])
		var dupes := 0
		for spin_first in [false, true]:
			for n in 200:
				inv.clear()
				inv.add(unique, spin_first)
				manager.try_give_weapon(me)
				if inv.slots[1] == unique:
					dupes += 1
		_check(dupes == 0, "never two %s at once (%d dupes)" % [unique.display_name, dupes])
		inv.clear()
		inv.add(unique)
		manager.try_give_weapon(me)
		_check(inv.slots[1] == other, "the other weapons fill the odds (%s)" % [inv.slots[1].display_name if inv.slots[1] else "none"])
		# Only the unique weapon in the crates: the crate gives nothing.
		manager.weapons.assign([unique])
		inv.clear()
		inv.add(unique)
		_check(not manager.try_give_weapon(me), "no %s roll when it's the only option" % unique.display_name)
		_check(not inv.add(unique), "add() refuses a second %s" % unique.display_name)
		# It can still come back after the first is used.
		inv.clear()
		_check(inv.add(unique), "a %s again after the first is gone" % unique.display_name)
	# Overdrive + System Override together is fine.
	inv.clear()
	_check(inv.add(overdrive) and inv.add(override), "Overdrive and System Override can share")
	# roll_weapon's exclude list scales the rest up.
	manager.weapons.assign(saved)
	var hits := 0
	for n in 500:
		if manager.roll_weapon(8, 8, [overdrive, override]) in [overdrive, override]:
			hits += 1
	_check(hits == 0, "roll_weapon never picks excluded weapons (%d)" % hits)
	inv.clear()


func _test_strip_and_clear(inv: ItemInventory, railgun: WeaponData) -> void:
	inv.clear()
	inv.add(railgun, true)
	var lost := inv.lose_item()
	_check(lost == railgun and not inv.any_spinning() and inv.is_empty(), "a hit can strip a rolling item")
	inv.add(railgun, true)
	inv.clear()
	_check(not inv.any_spinning(), "clear() stops the roll")
	await _frames(int(ItemInventory.ROULETTE_TIME * 60.0) + 5)
	_check(inv.is_empty(), "nothing lands after clear()")


func _test_ai(race: RaceManager, manager: WeaponManager, railgun: WeaponData) -> void:
	# An AI racer with a rolling Railgun doesn't fire it before it lands.
	var ai_racer: RaceProgress = null
	for racer in race.racers:
		if racer != race.player:
			ai_racer = racer
			break
	var car := ai_racer.vehicle
	var combat := car.get_node_or_null("AICombat")
	_check(combat != null, "AI has combat")
	if combat == null:
		return
	var fired: Array = []
	var on_used := func(v: VehicleController, w: WeaponData) -> void:
		if v == car:
			fired.append(Time.get_ticks_msec())
	manager.weapon_used.connect(on_used)
	car.inventory.clear()
	car.inventory.add(railgun, true)
	combat.set_physics_process(true)
	await _frames(int(ItemInventory.ROULETTE_TIME * 60.0) - 10)
	_check(fired.is_empty(), "AI never fires a rolling weapon")
	_check(car.inventory.slots[0] == railgun, "AI still holds it")
	combat.set_physics_process(false)
	manager.weapon_used.disconnect(on_used)
