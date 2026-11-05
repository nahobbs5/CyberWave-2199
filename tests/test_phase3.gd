extends SceneTree
## Phase 3 headless checks: inventory, crates, targeting, each weapon, status
## effects, self-effect rules, stun protection, AI combat and a full race with
## weapons. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_phase3.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const W := {
	"railgun": "res://resources/weapons/railgun.tres",
	"drone": "res://resources/weapons/hunter_drone.tres",
	"emp": "res://resources/weapons/emp_pulse.tres",
	"spike": "res://resources/weapons/road_spike.tres",
	"nitro": "res://resources/weapons/nitro_overload.tres",
	"firewall": "res://resources/weapons/firewall.tres",
}

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	# Never touch the real profile or settings: races now pay out coins.
	PlayerProfile.save_path = "user://test_phase3_profile.json"
	GameSettings.path = "user://test_phase3_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	_test_inventory()
	_test_status_rules()
	_test_crate_odds()
	_test_targeting_priority()
	await _run("crates", _test_crates, {})
	await _run("slot keys and auto-select", _test_slot_keys, {})
	await _run("railgun: lock-on and hit", _test_railgun, {})
	await _run("hunter drone", _test_drone, {})
	await _run("EMP pulse", _test_emp, {})
	await _run("hits knock out items", _test_item_loss, {})
	await _run("HUD layout", _test_hud_layout, {})
	await _run("road spike and owner grace", _test_spike, {})
	await _run("nitro overload", _test_nitro, {})
	await _run("firewall and stun protection", _test_firewall_and_protection, {})
	await _run("finished racers are out of combat", _test_finished_immune, {})
	await _run("weapons can be disabled", _test_weapons_off, {"weapons": false})
	await _run("full race with weapons", _test_full_race, {"autopilot": true, "frozen": false})
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _weapon(key: String) -> WeaponData:
	return load(W[key]) as WeaponData


func _run(test_name: String, test: Callable, options: Dictionary) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.weapons_enabled = options.get("weapons", true)
	race.player_uses_autopilot = options.get("autopilot", false)
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	if options.get("frozen", true):
		_freeze_field(race)
	await test.call(race)
	for action in [&"accelerate", &"brake", &"steer_left", &"steer_right"]:
		Input.action_release(action)
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Stops every AI driving and fighting so tests can stage situations.
func _freeze_field(race: RaceManager) -> void:
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			ai.enabled = false
		var combat := racer.vehicle.get_node_or_null("AICombat")
		if combat != null:
			combat.set_physics_process(false)


func _rival(race: RaceManager, index: int) -> VehicleController:
	var rivals := race.racers.filter(func(r: RaceProgress) -> bool: return not r.is_player)
	return (rivals[index] as RaceProgress).vehicle


## Puts a car on the main straight at a track offset / lateral position, at rest.
func _place(race: RaceManager, car: VehicleController, offset: float, lateral: float = 0.0) -> void:
	car.teleport(race.track.get_safe_transform(offset, lateral))


func _press(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


# --- pure logic --------------------------------------------------------------

func _test_inventory() -> void:
	_current = "inventory"
	print("- inventory (no scene)")
	var inv := ItemInventory.new()
	var a := _weapon("railgun")
	var b := _weapon("nitro")
	var c := _weapon("emp")
	_check(inv.is_empty() and inv.current() == null, "starts empty")
	_check(inv.add(a) and inv.selected == 0, "first pickup fills slot 1 and selects it")
	_check(inv.add(b) and inv.slots[1] == b, "second pickup fills slot 2")
	_check(not inv.has_space() and not inv.add(c), "a full inventory can't collect")
	inv.select(1)
	_check(inv.current() == b, "selecting slot 2")
	_check(inv.take_selected() == b and inv.selected == 0, "after use, the other occupied slot is selected")
	_check(inv.slots[1] == null and inv.current() == a, "used slot is empty")
	inv.take_selected()
	_check(inv.is_empty() and inv.current() == null, "empty after using both")
	# Hits that strip items take the selected one (or the other if that's empty).
	_check(inv.lose_item() == null, "nothing to lose when empty")
	inv.add(a)
	inv.add(b)
	inv.select(1)
	_check(inv.lose_item() == b and inv.slots[0] == a and inv.current() == a,
			"a hit knocks out the selected item and keeps the other")
	inv.select(1)
	_check(inv.lose_item() == a and inv.is_empty(), "falls back to the other slot if the selected one is empty")
	inv.free()


func _test_status_rules() -> void:
	_current = "status rules"
	print("- status rules (no scene)")
	var s := StatusEffects.new()
	var dt := 1.0 / 60.0
	var tick := func(seconds: float) -> void:
		for i in int(round(seconds / dt)):
			s._physics_process(dt)
	_check(s.apply_attack(&"stun", 0.8), "stun lands")
	_check(s.is_stunned() and not s.can_drive() and not s.can_use_weapons(), "stunned: no driving, no weapons")
	_check(not s.apply_attack(&"stagger", 0.7), "can't stack a second hard stun")
	tick.call(0.85)
	_check(not s.is_stunned() and s.is_protected(), "stun ends, protection starts")
	_check(not s.apply_attack(&"stun", 0.8), "protection blocks a repeat stun (GDD 6.5)")
	_check(s.apply_attack(&"emp", 1.5), "protection doesn't block non-stun effects")
	_check(not s.can_use_weapons() and not s.can_charge_drift() and is_equal_approx(s.speed_multiplier(), 0.85),
			"EMP: no weapons, no drift charge, lower top speed")
	tick.call(1.6)
	_check(not s.is_protected() and s.apply_attack(&"stagger", 0.7), "after ~1.5 s, stuns land again")
	tick.call(3.0)
	s.apply_buff(&"shield", 10.0)
	_check(not s.apply_attack(&"stun", 0.8) and not s.has(&"shield"), "shield blocks one attack and is used up")
	_check(s.apply_attack(&"traction", 1.0) and s.grip_multiplier() < 0.5, "next attack lands (traction cuts grip)")
	s.apply_buff(&"shield", 10.0)
	tick.call(10.1)
	_check(not s.has(&"shield"), "shield expires after 10 s")
	# EMP jam: weapons stay offline after the EMP slowdown ends.
	s.apply_attack(&"emp", 1.5)
	s.apply_jam(5.0)
	tick.call(1.6)
	_check(not s.has(&"emp") and s.has(&"jammed"), "the EMP wears off but the jam remains")
	_check(not s.can_use_weapons() and s.can_charge_drift() and is_equal_approx(s.speed_multiplier(), 1.0),
			"jammed: no weapons, but drift and speed are back")
	tick.call(3.5)
	_check(s.can_use_weapons(), "weapons come back after ~5 s")
	s.free()


func _test_crate_odds() -> void:
	_current = "crate odds"
	print("- crate odds (no scene)")
	var wm := WeaponManager.new()
	for key in W:
		wm.weapons.append(_weapon(key))
	var counts := {1: {}, 8: {}}
	for position in [1, 8]:
		for i in 4000:
			var w := wm.roll_weapon(position)
			counts[position][w.id] = counts[position].get(w.id, 0) + 1
	for id in [&"hunter_drone", &"nitro_overload"]:
		_check(counts[1].get(id, 0) * 2 < counts[8].get(id, 0), "%s much rarer for the leader (%d vs %d)" % [id, counts[1].get(id, 0), counts[8].get(id, 0)])
	_check(counts[1].get(&"firewall", 0) > counts[8].get(&"firewall", 0), "leader gets more defensive Firewalls")
	_check(counts[1].size() == 6 and counts[8].size() == 6, "every weapon can drop anywhere")
	wm.free()


func _test_targeting_priority() -> void:
	_current = "targeting priority"
	print("- targeting priority (no scene)")
	# Built in a tiny world: me, a near car and a far car straight ahead.
	var world := Node3D.new()
	root.add_child(world)
	var cars: Array[VehicleController] = []
	for z in [0.0, -20.0, -60.0]:
		var car := (load("res://scenes/vehicles/placeholder_car.tscn") as PackedScene).instantiate() as VehicleController
		world.add_child(car)
		car.global_position = Vector3(0, 50, z)
		car.freeze = true
		cars.append(car)
	var me := cars[0]
	var near := cars[1]
	var far := cars[2]
	var ts := me.targeting
	ts.racers = cars
	var distances := {me: 100.0, near: 90.0, far: 200.0}
	ts.race_distance = func(v: VehicleController) -> float: return distances[v]
	_check(ts.find_best_candidate() == far, "prefers the racer ahead in the race over a nearer one behind")
	distances[near] = 150.0
	_check(ts.find_best_candidate() == near, "among racers ahead, the nearest")
	ts.is_eligible = func(v: VehicleController) -> bool: return v != near
	_check(ts.find_best_candidate() == far, "ineligible racers are skipped")
	_check(ts.find_best_candidate() != me, "never targets itself")
	world.queue_free()


# --- scene tests ---------------------------------------------------------------

func _test_crates(race: RaceManager) -> void:
	var wm := race.weapon_manager
	_check(wm.crates.size() == race.track.crate_row_offsets.size() * race.track.crate_lateral_positions.size(),
			"%d crates placed" % wm.crates.size())
	var car := race.player.vehicle
	var crate := wm.crates[0]
	car.teleport(crate.global_transform)
	await _frames(5)
	_check(car.inventory.slots[0] != null, "driving into a crate gives a weapon (%s)" % car.inventory.slots[0])
	_check(not crate.is_available(), "the crate is used up")
	car.inventory.add(_weapon("nitro"))
	var crate2 := wm.crates[1]
	car.teleport(crate2.global_transform)
	await _frames(5)
	_check(crate2.is_available(), "a full inventory leaves the crate in place")
	await _frames(int(wm.crate_respawn_time * 60) + 5)
	_check(crate.is_available(), "crate respawns after %.0f s" % wm.crate_respawn_time)


func _test_slot_keys(race: RaceManager) -> void:
	var inv := race.player.vehicle.inventory
	inv.add(_weapon("nitro"))
	inv.add(_weapon("firewall"))
	await _press(KEY_2)
	_check(inv.selected == 1, "2 selects slot 2")
	await _press(KEY_1)
	_check(inv.selected == 0, "1 selects slot 1")
	await _press(KEY_SPACE)
	await _frames(2)
	_check(inv.slots[0] == null and inv.selected == 1, "Space fires slot 1 and auto-selects slot 2")
	_check(race.player.vehicle.is_boosting(), "the Nitro fired")
	_check(race.race_hud.get_slot_text(0).contains("EMPTY") and race.race_hud.get_slot_text(1).contains("Firewall"),
			"HUD shows an empty slot and the Firewall (%s / %s)" % [race.race_hud.get_slot_text(0), race.race_hud.get_slot_text(1)])


func _test_railgun(race: RaceManager) -> void:
	var me := race.player.vehicle
	var target := _rival(race, 0)
	_place(race, me, 200.0)
	_place(race, target, 245.0)
	await _frames(30)
	me.inventory.add(_weapon("railgun"))
	await _frames(12)
	_check(not me.targeting.locked and me.targeting.candidate == target, "acquiring, not locked after 0.2 s")
	await _frames(18)
	_check(me.targeting.locked and me.targeting.get_target() == target, "locked after ~0.4 s")
	_check(race.weapon_manager.is_incoming(target), "the target gets an incoming warning")
	await _press(KEY_SPACE)
	await _frames(10)
	_check(target.status.has(&"stagger"), "railgun staggers the target")
	_check(not me.status.is_stunned(), "the shooter is unaffected")
	_check(not me.targeting.locked, "lock clears after firing")


func _test_drone(race: RaceManager) -> void:
	var me := race.player.vehicle
	var target := _rival(race, 1)
	_place(race, me, 200.0)
	_place(race, target, 270.0, 4.0)
	await _frames(30)
	me.inventory.add(_weapon("drone"))
	race.weapon_manager.use_weapon(me) # fires without waiting for a lock
	var hit := false
	for i in 240:
		await physics_frame
		if target.status.has(&"stun"):
			hit = true
			break
	_check(hit, "the drone finds and stuns a racer ahead without a lock")
	_check(not me.status.is_stunned(), "the drone never targets its owner")


func _test_emp(race: RaceManager) -> void:
	var me := race.player.vehicle
	var near_a := _rival(race, 0)
	var near_b := _rival(race, 1)
	var far := _rival(race, 2)
	_place(race, me, 200.0)
	_place(race, near_a, 212.0, 4.0)
	_place(race, near_b, 192.0, -4.0)
	_place(race, far, 290.0)
	await _frames(30)
	me.inventory.add(_weapon("emp"))
	race.weapon_manager.use_weapon(me)
	await _frames(2)
	_check(near_a.status.has(&"emp") and near_b.status.has(&"emp"), "nearby racers are hit (ahead and behind)")
	_check(not far.status.has(&"emp"), "racers out of range are not")
	_check(not me.status.has(&"emp"), "the EMP never affects its owner")
	near_a.inventory.add(_weapon("nitro"))
	_check(not race.weapon_manager.use_weapon(near_a), "an EMP'd racer can't use weapons")
	_check(near_a.inventory.slots[0] != null, "the EMP doesn't strip items")
	await _frames(180)
	_check(not near_a.status.has(&"emp") and not race.weapon_manager.use_weapon(near_a),
			"3 s later weapons are still jammed")
	await _frames(132)
	_check(race.weapon_manager.use_weapon(near_a), "after ~5 s the racer can fire again")


func _test_item_loss(race: RaceManager) -> void:
	var wm := race.weapon_manager
	var me := race.player.vehicle
	var rival := _rival(race, 0)
	var lost: Array = []
	wm.item_lost.connect(func(t: VehicleController, w: WeaponData, _by: WeaponData, _s: VehicleController) -> void:
		lost.append([t, w]))
	var nitro := _weapon("nitro")
	var spike := _weapon("spike")
	me.inventory.add(nitro)
	me.inventory.add(spike)
	me.inventory.select(1)
	_check(wm.apply_hit(me, _weapon("railgun"), rival), "railgun hit lands")
	_check(me.inventory.slots[1] == null and me.inventory.slots[0] == nitro and me.inventory.current() == nitro,
			"railgun knocks out the selected item, keeps the other")
	_check(lost.size() == 1 and lost[0][0] == me and lost[0][1] == spike, "item_lost reports it")
	await _frames(140) # stagger (0.7 s) + stun protection (1.5 s) wear off
	me.inventory.add(spike)
	_check(wm.apply_hit(me, _weapon("drone"), rival) and me.inventory.slots.count(null) == 1,
			"a hunter drone hit also knocks one out")
	# Within stun protection: blocked, nothing lost.
	await _frames(70)
	var before := me.inventory.slots.duplicate()
	_check(not wm.apply_hit(me, _weapon("railgun"), rival) and me.inventory.slots == before,
			"a hit blocked by stun protection costs nothing")
	await _frames(120)
	me.status.apply_buff(&"shield", 10.0)
	_check(not wm.apply_hit(me, _weapon("railgun"), rival) and me.inventory.slots == before,
			"a Firewall-blocked hit costs nothing")
	_check(wm.apply_hit(me, spike, rival) and me.inventory.slots == before, "road spikes don't strip items")


func _test_hud_layout(race: RaceManager) -> void:
	await _frames(2)
	var hud := race.race_hud
	var view := race.get_viewport().get_visible_rect().size
	var slot := hud._slot_panels[1].get_global_rect()
	_check(slot.end.x < view.x * 0.5 and slot.end.y < view.y * 0.25,
			"weapon slots are in the top left (%s in %s)" % [slot, view])
	var info := hud._standings_label.get_global_rect()
	_check(info.position.y >= slot.end.y, "race info sits below the slots")
	# The minimap owns the bottom-right corner; nothing else sits there.
	var corner := Rect2(view * 0.6, view * 0.4)
	var map := hud.minimap
	var map_rect := map.get_global_rect()
	_check(map.is_visible_in_tree() and corner.encloses(map_rect), "minimap in the bottom-right corner (%s)" % map_rect)
	var clashes: Array[String] = []
	for layer in [hud, race.get_node_or_null("PrototypeHUD")]:
		if layer == null:
			continue
		for node in (layer as Node).find_children("*", "Control", true, false):
			var c := node as Control
			var shows_something := (c is Label and (c as Label).text != "") or c is PanelContainer
			if shows_something and c.is_visible_in_tree() and c.get_global_rect().intersects(map_rect):
				clashes.append(c.name)
	_check(clashes.is_empty(), "nothing overlaps the minimap (%s)" % [clashes])
	_check(map.visible_racers().size() == 8, "a marker per racer")
	var p := map.world_to_map(race.player.vehicle.global_position)
	_check(Rect2(Vector2.ZERO, map.size).has_point(p), "the player is on the map (%s)" % p)
	# Weapon slots show the weapon's picture rather than its name.
	var weapons_ok := true
	for w in race.weapon_manager.weapons:
		weapons_ok = weapons_ok and w.icon != null
	_check(weapons_ok, "every weapon has an icon")
	var inv := race.player.vehicle.inventory
	inv.clear()
	inv.add(load(W["firewall"]))
	await _frames(2)
	_check(hud.get_slot_icon(0) == (load(W["firewall"]) as WeaponData).icon and hud.get_slot_icon(1) == null,
			"slot 1 shows the Firewall picture, slot 2 is empty")
	_check(not hud._slot_names[0].visible, "no weapon name text when there's a picture")
	inv.clear()


func _test_spike(race: RaceManager) -> void:
	var me := race.player.vehicle
	var victim := _rival(race, 0)
	_place(race, me, 200.0)
	_place(race, victim, 400.0)
	await _frames(30)
	me.inventory.add(_weapon("spike"))
	race.weapon_manager.use_weapon(me)
	await _frames(2)
	var spikes := race.weapon_manager.get_children().filter(func(n: Node) -> bool: return n is RoadSpike)
	_check(spikes.size() == 1, "a spike strip is dropped")
	if spikes.is_empty():
		return
	var spike := spikes[0] as RoadSpike
	var behind := race.track.wrapped_delta(race.track.get_offset_at(me.global_position), race.track.get_offset_at(spike.global_position))
	_check(behind < -2.0, "it lands behind the owner (%.1f m)" % behind)
	# Owner drives back over it inside the grace period: no effect.
	me.teleport(Transform3D(me.global_transform.basis, spike.global_position + Vector3.UP * 0.9))
	await _frames(10)
	_check(not me.status.has(&"traction") and is_instance_valid(spike), "owner is safe during the grace period")
	_place(race, me, 200.0)
	await _frames(60)
	# After the grace period it affects its owner like anyone else (GDD 6.4).
	me.teleport(Transform3D(me.global_transform.basis, spike.global_position + Vector3.UP * 0.9))
	await _frames(10)
	_check(me.status.has(&"traction"), "owner is affected once armed")
	_check(not is_instance_valid(spike), "the strip is used up")
	# A fresh strip catches an opponent.
	me.inventory.add(_weapon("spike"))
	_place(race, me, 300.0)
	await _frames(30)
	race.weapon_manager.use_weapon(me)
	await _frames(2)
	var spike2 := race.weapon_manager.get_children().filter(func(n: Node) -> bool: return n is RoadSpike)[0] as RoadSpike
	victim.teleport(Transform3D(victim.global_transform.basis, spike2.global_position + Vector3.UP * 0.9))
	await _frames(10)
	_check(victim.status.has(&"traction"), "an opponent driving over it loses traction")


func _test_nitro(race: RaceManager) -> void:
	var me := race.player.vehicle
	_place(race, me, 100.0)
	await _frames(30)
	me.inventory.add(_weapon("nitro"))
	race.weapon_manager.use_weapon(me)
	_check(me.is_boosting() and me.boost_label == "Nitro Overload", "nitro boost active")
	_check(me.get_speed_cap() > me.stats.top_speed + 5.0, "speed cap raised")
	me.player_controlled = false
	me.throttle_input = 1.0
	await _frames(170)
	_check(me.forward_speed > 30.0, "nitro accelerates hard (%.1f m/s in 2.8 s)" % me.forward_speed)
	await _frames(30)
	_check(not me.is_boosting(), "ends after 3 s")


func _test_firewall_and_protection(race: RaceManager) -> void:
	var me := race.player.vehicle
	var rival := _rival(race, 0)
	var wm := race.weapon_manager
	var railgun := _weapon("railgun")
	var drone := _weapon("drone")
	me.inventory.add(_weapon("firewall"))
	wm.use_weapon(me)
	_check(me.status.has(&"shield"), "Firewall raises a shield")
	_check(not wm.apply_hit(me, railgun, rival), "the shield blocks the railgun")
	_check(not me.status.has(&"shield"), "and is used up")
	# Stun, then immediate follow-ups: protection stops chain-stuns.
	_check(wm.apply_hit(me, drone, rival), "drone stun lands")
	me.player_controlled = false
	me.throttle_input = 1.0
	var speed_before := me.forward_speed
	await _frames(30)
	_check(me.forward_speed <= speed_before + 0.5, "a stunned car can't accelerate")
	await _frames(30)
	_check(not wm.apply_hit(me, railgun, rival), "protection blocks a stun right after the last one")
	await _frames(100)
	_check(wm.apply_hit(me, railgun, rival), "stuns land again after the protection window")


func _test_finished_immune(race: RaceManager) -> void:
	var wm := race.weapon_manager
	var rival := _rival(race, 0)
	var progress := race.progress_of(rival)
	progress.finished = true
	_check(not wm.is_targetable(rival), "finished racers can't be targeted")
	_check(not wm.apply_hit(rival, _weapon("railgun"), race.player.vehicle), "or hit")
	rival.inventory.add(_weapon("nitro"))
	_check(not wm.use_weapon(rival), "or use weapons")


func _test_weapons_off(race: RaceManager) -> void:
	_check(not race.combat_enabled(), "combat disabled")
	_check(race.weapon_manager.crates.is_empty(), "no crates placed")
	var inv := race.player.vehicle.inventory
	inv.add(_weapon("nitro"))
	inv.request_use()
	await _frames(2)
	_check(not race.player.vehicle.is_boosting(), "weapons do nothing")


func _test_full_race(race: RaceManager) -> void:
	var wm := race.weapon_manager
	var hits := [0]
	var recoveries := [0]
	wm.hit_resolved.connect(func(_t, _w, _s, by: StringName) -> void:
		if by == &"":
			hits[0] += 1)
	var stripped := [0]
	wm.item_lost.connect(func(_t, _w, _b, _s) -> void: stripped[0] += 1)
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var frames := 0
	while frames < 60 * 400 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var total_uses := 0
	for id in wm.uses:
		total_uses += wm.uses[id]
	print("    race took %.1f s simulated; uses %s; %d hits; %d items stripped; %d recoveries" % [frames / 60.0, wm.uses, hits[0], stripped[0], recoveries[0]])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 racers finished")
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.checkpoints_passed == 3 * race.track.checkpoint_count + 1),
			"every racer crossed every gate despite weapons")
	_check(total_uses >= 25, "AI used plenty of weapons (%d)" % total_uses)
	_check(wm.uses.size() == wm.weapons.size(), "all %d weapon types were used (%s)" % [wm.weapons.size(), wm.uses.keys()])
	_check(hits[0] >= 8, "weapons landed hits (%d)" % hits[0])
	_check(recoveries[0] <= 3, "combat doesn't leave cars stranded (%d recoveries)" % recoveries[0])
