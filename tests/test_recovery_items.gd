extends SceneTree
## Falling off the track (or a manual reset) empties the weapon slots;
## automatic resets on the road keep them. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_recovery_items.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const RAILGUN := "res://resources/weapons/railgun.tres"
const FIREWALL := "res://resources/weapons/firewall.tres"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_recovery_items_profile.json"
	GameSettings.path = "user://test_recovery_items_settings.cfg"
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
	_check(VehicleRecovery.loses_items("out of bounds") and VehicleRecovery.loses_items("water")
			and VehicleRecovery.loses_items("off track") and VehicleRecovery.loses_items("manual"),
			"falling off and manual resets cost items")
	_check(not VehicleRecovery.loses_items("overturned") and not VehicleRecovery.loses_items("stuck")
			and not VehicleRecovery.loses_items("no progress") and not VehicleRecovery.loses_items("overdrive"),
			"automatic resets on the road keep items")

	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.weapons_enabled = true
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	var me: VehicleController = race.player.vehicle
	var inv := me.inventory
	_check(inv != null, "the player has an inventory")
	if inv != null:
		await _recover(me, "out of bounds", true)
		await _recover(me, "manual", true)
		await _recover(me, "stuck", false)
		await _recover(me, "overturned", false)

	race.queue_free()
	await process_frame
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Fills both slots, recovers for `reason`, and checks the slots after.
func _recover(car: VehicleController, reason: String, should_lose: bool) -> void:
	var inv := car.inventory
	inv.clear()
	inv.add(load(RAILGUN) as WeaponData)
	inv.add(load(FIREWALL) as WeaponData)
	_check(car.recovery.request_recovery(reason), "a %s recovery starts" % reason)
	# Sequence (2.2 s) plus the cooldown.
	await _frames(60 * 4)
	if should_lose:
		_check(inv.is_empty(), "%s empties both slots" % reason)
	else:
		_check(inv.slots[0] != null and inv.slots[1] != null, "%s keeps the items" % reason)
