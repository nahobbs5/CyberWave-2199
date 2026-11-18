extends SceneTree
## Holo Decoy, System Glitch and Swarm Bots (GDD 6.3): data, status rules,
## the glitch screen overlay, the swarm leash, decoys soaking targeted
## attacks, and AI use. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_new_weapons.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const W := {
	"decoy": "res://resources/weapons/holo_decoy.tres",
	"glitch": "res://resources/weapons/system_glitch.tres",
	"swarm": "res://resources/weapons/swarm_bots.tres",
	"drone": "res://resources/weapons/hunter_drone.tres",
	"railgun": "res://resources/weapons/railgun.tres",
	"hunter_killer": "res://resources/weapons/hunter_killer.tres",
}
const DT := 1.0 / 60.0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_new_weapons_profile.json"
	GameSettings.path = "user://test_new_weapons_settings.cfg"
	PlayerProfile.delete_save()
	PodiumCeremony.instant = true
	CarUnlockScreen.instant = true
	_run_all.call_deferred()


func _run_all() -> void:
	_test_data()
	_test_status_rules()
	await _run("odds include the new weapons", _test_odds, {})
	await _run("system glitch hits everyone ahead", _test_glitch, {})
	await _run("glitch overlay: centre only, HUD untouched", _test_glitch_overlay, {})
	await _run("swarm bots leash the target", _test_swarm, {})
	await _run("swarm bots: firewall blocks", _test_swarm_firewall, {})
	await _run("holo decoy soaks a hunter drone", _test_decoy_drone, {})
	await _run("holo decoy soaks a railgun and swarm", _test_decoy_railgun_swarm, {})
	await _run("holo decoy: expiry, hunter-killer not fooled", _test_decoy_expiry_hk, {})
	await _run("AI uses the new weapons", _test_ai_use, {"autopilot": true, "frozen": false})
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _weapon(key: String) -> WeaponData:
	return load(W[key]) as WeaponData


func _run(test_name: String, test: Callable, options: Dictionary) -> void:
	# ONLY=<text> runs just the matching tests (quick iteration).
	var only := OS.get_environment("ONLY")
	if only != "" and not test_name.contains(only):
		return
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.weapons_enabled = true
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
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _freeze_field(race: RaceManager) -> void:
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			ai.enabled = false
		var combat := racer.vehicle.get_node_or_null("AICombat")
		if combat != null:
			combat.set_physics_process(false)
		# Rocket-start boosts would skew speed comparisons.
		racer.vehicle.boost_time_left = 0.0


func _rival(race: RaceManager, index: int) -> VehicleController:
	var rivals := race.racers.filter(func(r: RaceProgress) -> bool: return not r.is_player)
	return (rivals[index] as RaceProgress).vehicle


func _place(race: RaceManager, car: VehicleController, offset: float, lateral: float = 0.0) -> void:
	car.teleport(race.track.get_safe_transform(offset, lateral))


## `order` first (leader) to last along the straight; the rest well behind.
func _line_up(race: RaceManager, order: Array) -> void:
	var placed := {}
	for i in order.size():
		var car: VehicleController = order[i]
		_place(race, car, 200.0 - i * 15.0, -4.0 if i % 2 == 0 else 4.0)
		placed[car] = true
	var k := 0
	for racer in race.racers:
		if not placed.has(racer.vehicle):
			_place(race, racer.vehicle, 50.0 - k * 10.0, -5.0 if k % 2 == 0 else 5.0)
			k += 1
	await _frames(20)


func _decoy_blocks(race: RaceManager) -> Array:
	var blocks := []
	race.weapon_manager.hit_resolved.connect(func(t: VehicleController, w: WeaponData, _s: VehicleController, by: StringName) -> void:
		if by == &"decoy":
			blocks.append([t, w.id]))
	return blocks


# --- data and status rules (no scene) -------------------------------------------

func _test_data() -> void:
	_current = "data"
	print("- data")
	var decoy := _weapon("decoy")
	var glitch := _weapon("glitch")
	var swarm := _weapon("swarm")
	_check(decoy.kind == WeaponData.Kind.DECOY and is_equal_approx(decoy.lifetime, 8.0), "Holo Decoy lasts 8 s")
	_check(glitch.kind == WeaponData.Kind.GLITCH and glitch.effect == &"glitch" and is_equal_approx(glitch.effect_duration, 4.5),
			"System Glitch lasts 4.5 s")
	_check(swarm.kind == WeaponData.Kind.SWARM and swarm.targeted and swarm.effect == &"leash"
			and is_equal_approx(swarm.effect_duration, 5.0), "Swarm Bots: targeted, 5 s leash")
	_check(not swarm.strips_item and not glitch.strips_item, "neither strips an item")
	for w in [decoy, glitch, swarm]:
		_check(w.icon != null and not w.can_affect_owner, "%s has an icon and never hits its owner" % w.display_name)


func _test_status_rules() -> void:
	_current = "status rules"
	print("- status rules")
	var status := StatusEffects.new()
	_check(status.apply_attack(&"glitch", 4.5), "glitch lands")
	_check(is_equal_approx(status.speed_multiplier(), 1.0) and is_equal_approx(status.accel_multiplier(), 1.0)
			and is_equal_approx(status.grip_multiplier(), 1.0) and status.can_drive() and status.can_use_weapons(),
			"glitch changes no physics (visual for humans)")
	_check(status.apply_attack(&"leash", 5.0), "leash lands")
	_check(is_equal_approx(status.speed_multiplier(), 0.66) and is_equal_approx(status.accel_multiplier(), 0.35),
			"leash: 66% top speed, 35% acceleration")
	status.apply_attack(&"override", 3.0)
	_check(is_equal_approx(status.speed_multiplier(), 0.66 * 0.75) and is_equal_approx(status.accel_multiplier(), 0.35 * 0.7),
			"leash stacks with an override")
	status.clear_all()
	status.apply_buff(&"shield", 10.0)
	_check(not status.apply_attack(&"glitch", 4.5) and not status.has(&"glitch"), "a Firewall blocks a glitch")
	status.apply_buff(&"overdrive", 5.0)
	_check(not status.apply_attack(&"leash", 5.0) and not status.apply_attack(&"glitch", 4.5), "Overdrive ignores both")
	status.clear_all()
	status.apply_attack(&"stun", 0.01)
	status._physics_process(0.05)
	_check(status.is_protected() and status.apply_attack(&"glitch", 4.5), "stun protection doesn't stop a glitch")
	status.free()


func _test_odds(race: RaceManager) -> void:
	var wm := race.weapon_manager
	var ids := wm.weapons.map(func(w: WeaponData) -> StringName: return w.id)
	_check(ids.has(&"holo_decoy") and ids.has(&"system_glitch") and ids.has(&"swarm_bots"),
			"race weapons include all three (%d weapons)" % ids.size())
	for position in range(1, 9):
		var sum := 0.0
		for w in wm.weapons:
			sum += w.chance_for(position, 8)
		_check(is_equal_approx(sum, 100.0), "P%d odds add up to 100%% (%.1f)" % [position, sum])
	var counts := {}
	for i in 20000:
		var w := wm.roll_weapon(1, 8)
		counts[w.id] = counts.get(w.id, 0) + 1
	_check(absf(100.0 * counts.get(&"holo_decoy", 0) / 20000.0 - 8.0) < 1.0, "the leader rolls a Holo Decoy ~8%% (%s)" % counts.get(&"holo_decoy", 0))
	_check(counts.get(&"system_glitch", 0) == 0 and counts.get(&"swarm_bots", 0) == 0, "no Glitch / Swarm for the leader")


# --- System Glitch -----------------------------------------------------------------

func _test_glitch(race: RaceManager) -> void:
	var me := race.player.vehicle
	var order: Array = [_rival(race, 0), _rival(race, 1), _rival(race, 2), _rival(race, 3), me,
			_rival(race, 4), _rival(race, 5)]
	await _line_up(race, order)
	_check(race.progress_of(me).position == 5, "player is 5th (%d)" % race.progress_of(me).position)
	_rival(race, 1).status.apply_buff(&"shield", 10.0)
	me.inventory.add(_weapon("glitch"))
	race.weapon_manager.use_weapon(me)
	var hit := 0
	for i in 4:
		if order[i].status.has(&"glitch"):
			hit += 1
	_check(hit == 3 and not _rival(race, 1).status.has(&"glitch") and not _rival(race, 1).status.has(&"shield"),
			"1st-4th glitched except the Firewall (%d)" % hit)
	_check(not me.status.has(&"glitch") and not order[5].status.has(&"glitch") and not order[6].status.has(&"glitch"),
			"the user and everyone behind are untouched")
	_check(absf(order[0].status.time_left(&"glitch") - 4.5) < 0.05, "4.5 s (%.2f)" % order[0].status.time_left(&"glitch"))
	_check(is_equal_approx(order[0].status.speed_multiplier(), 1.0) and is_equal_approx(order[0].status.accel_multiplier(), 1.0),
			"no speed change")
	# Glitched AI weave and lift off: they steer off the clean line.
	var victim: VehicleController = order[0]
	var ai := race.get_ai(race.progress_of(victim))
	ai.enabled = true
	var deviates := false
	var base_ai := race.get_ai(race.progress_of(order[3]))
	await _frames(60)
	for i in 120:
		await physics_frame
		if victim.throttle_input > AIController.GLITCH_THROTTLE + 0.001:
			deviates = false
			break
		deviates = true
	_check(deviates, "glitched AI never goes past %.2f throttle" % AIController.GLITCH_THROTTLE)
	_check(base_ai != null, "AI controller found")
	await _frames(int(4.0 * 60))
	_check(not victim.status.has(&"glitch"), "glitch over after 4.5 s")


func _test_glitch_overlay(race: RaceManager) -> void:
	var me := race.player.vehicle
	var hud := race.race_hud
	var overlay := hud.glitch
	# (HudScaler moves the HUD's controls under one HudScaleRoot.)
	_check(overlay != null and overlay.get_index() == 0 and (overlay.get_parent() == hud or overlay.get_parent().get_parent() == hud),
			"the overlay is the HUD's back-most control")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it never takes mouse input")
	await process_frame
	await process_frame
	_check(not overlay.visible and overlay.intensity() == 0.0, "hidden when not glitched")
	var panels: Array[Control] = [hud.info, hud.items, hud.minimap, hud.info.lap_block]
	var before := panels.map(func(c: Control) -> Array: return [c.visible, c.global_position, c.modulate])
	me.status.apply_attack(&"glitch", 4.5)
	await _frames(30)
	await process_frame
	await process_frame
	_check(overlay.visible and overlay.intensity() > 0.5, "scrambles the screen while glitched (%.2f)" % overlay.intensity())
	var sign := hud.glitch_indicator
	_check(sign != null and sign.visible and sign.timer_label.text.ends_with("s") and sign.bar.fraction > 0.7 and sign.bar.fraction < 1.0,
			"SYSTEM GLITCH indicator with a countdown (%s, %.2f)" % [sign.timer_label.text, sign.bar.fraction])
	var sign_rect := sign.get_global_rect()
	var view := hud.get_viewport().get_visible_rect().size
	_check(sign_rect.position.y < view.y * 0.15 and absf(sign_rect.get_center().x - view.x * 0.5) < 2.0, "indicator sits top centre (%s)" % sign_rect)
	var after := panels.map(func(c: Control) -> Array: return [c.visible, c.global_position, c.modulate])
	# (The items column grows by the effects line "GLITCH n.ns", as for any status.)
	var same := true
	for i in panels.size():
		same = same and before[i][0] == after[i][0] and before[i][2] == after[i][2]
	same = same and before[0][1] == after[0][1] and before[3][1] == after[3][1]
	_check(same, "HUD panels untouched (visible, colour; position and laps in place)\n%s\n%s" % [before, after])
	await _frames(int(4.6 * 60))
	await process_frame
	await process_frame
	await process_frame
	_check(not overlay.visible, "gone when the glitch ends (%.2f)" % overlay.intensity())
	await _frames(15)
	await process_frame
	_check(not hud.glitch_indicator.visible, "indicator gone when the glitch ends")


# --- Swarm Bots ------------------------------------------------------------------

func _swarm(race: RaceManager) -> SwarmBots:
	for node in race.weapon_manager.get_children():
		if node is SwarmBots and not node.is_queued_for_deletion():
			return node
	return null


func _test_swarm(race: RaceManager) -> void:
	var me := race.player.vehicle
	var target := _rival(race, 0)
	await _line_up(race, [target, me])
	me.inventory.add(_weapon("swarm"))
	race.weapon_manager.use_weapon(me)
	var swarm := _swarm(race)
	_check(swarm != null and swarm.target == target, "the swarm hunts the racer ahead")
	_check(race.weapon_manager.is_incoming(target), "the target sees INCOMING")
	var frames := 0
	while not target.status.has(&"leash") and frames < 300:
		await physics_frame
		frames += 1
	_check(target.status.has(&"leash"), "the swarm latches on (%.2f s)" % (frames * DT))
	_check(absf(target.status.time_left(&"leash") - 5.0) < 0.1, "a 5 s leash")
	_check(target.get_node_or_null(SwarmLeash.NODE_NAME) != null, "bots cling to the car")
	_check(is_equal_approx(target.status.speed_multiplier(), 0.66), "top speed cut to 66%")
	_check(target.inventory != null, "no item lost (not a hard stun)")
	# A leashed car accelerates far slower than a free one.
	var clean := _rival(race, 1)
	for car: VehicleController in [target, clean]:
		race.get_ai(race.progress_of(car)).set_physics_process(false)
		car.player_controlled = false
		car.throttle_input = 1.0
	_place(race, target, 500.0, -4.0)
	_place(race, clean, 500.0, 4.0)
	await _frames(90)
	_check(target.forward_speed < clean.forward_speed * 0.6,
			"leashed car is much slower (%.1f vs %.1f m/s)" % [target.forward_speed, clean.forward_speed])
	await _frames(int(4.0 * 60))
	await process_frame
	await process_frame
	_check(not target.status.has(&"leash") and target.get_node_or_null(SwarmLeash.NODE_NAME) == null,
			"leash and bots gone after 5 s")


func _test_swarm_firewall(race: RaceManager) -> void:
	var me := race.player.vehicle
	var target := _rival(race, 0)
	await _line_up(race, [target, me])
	target.status.apply_buff(&"shield", 10.0)
	me.inventory.add(_weapon("swarm"))
	race.weapon_manager.use_weapon(me)
	for i in 300:
		await physics_frame
		if _swarm(race) == null:
			break
	_check(not target.status.has(&"leash") and not target.status.has(&"shield"), "a Firewall blocks the swarm (and is used up)")


# --- Holo Decoy --------------------------------------------------------------------

func _test_decoy_drone(race: RaceManager) -> void:
	var me := race.player.vehicle
	var chaser := _rival(race, 0)
	await _line_up(race, [me, chaser])
	var wm := race.weapon_manager
	var blocks := _decoy_blocks(race)
	me.inventory.add(_weapon("decoy"))
	wm.use_weapon(me)
	await _frames(30)
	var decoy := wm.decoy_of(me)
	_check(decoy != null, "a decoy is out")
	if decoy == null:
		return
	var mesh_count := decoy.find_children("*", "MeshInstance3D", true, false).size()
	_check(mesh_count >= 4, "it's a copy of the car (%d meshes)" % mesh_count)
	var local := me.global_transform.affine_inverse() * decoy.global_position
	_check(local.z > 3.0 and absf(local.x) > 1.5, "it rides behind and to one side (%s)" % local)
	chaser.inventory.add(_weapon("drone"))
	wm.use_weapon(chaser)
	for i in 300:
		await physics_frame
		if not is_instance_valid(decoy) or decoy.is_queued_for_deletion():
			break
	_check(not me.status.is_stunned(), "the owner isn't stunned")
	_check(wm.decoy_of(me) == null, "the decoy popped")
	_check(blocks.size() == 1 and blocks[0][0] == me and blocks[0][1] == &"hunter_drone", "reported as a decoy block (%s)" % [blocks])


func _test_decoy_railgun_swarm(race: RaceManager) -> void:
	var me := race.player.vehicle
	var shooter := _rival(race, 0)
	var wm := race.weapon_manager
	var blocks := _decoy_blocks(race)
	_place(race, me, 220.0, 0.0)
	_place(race, shooter, 185.0, 0.0)
	await _frames(20)
	me.inventory.add(_weapon("decoy"))
	wm.use_weapon(me)
	shooter.inventory.add(_weapon("railgun"))
	await _frames(40)
	_check(shooter.targeting.get_target() == me, "the shooter locks on to the decoy's owner")
	wm.use_weapon(shooter)
	await _frames(30)
	_check(not me.status.has(&"stagger"), "the railgun doesn't stagger the owner")
	_check(blocks.size() == 1 and blocks[0][1] == &"railgun", "the decoy took the shot (%s)" % [blocks])
	# A fresh decoy draws a swarm off too.
	me.inventory.add(_weapon("decoy"))
	wm.use_weapon(me)
	shooter.inventory.add(_weapon("swarm"))
	await _frames(20)
	wm.use_weapon(shooter)
	for i in 300:
		await physics_frame
		if _swarm(race) == null:
			break
	_check(not me.status.has(&"leash"), "the swarm doesn't leash the owner")
	_check(blocks.size() == 2 and blocks[1][1] == &"swarm_bots", "the decoy took the swarm (%s)" % [blocks])


func _test_decoy_expiry_hk(race: RaceManager) -> void:
	var me := race.player.vehicle
	var leader := _rival(race, 0)
	var wm := race.weapon_manager
	await _line_up(race, [leader, _rival(race, 1), me])
	leader.inventory.add(_weapon("decoy"))
	wm.use_weapon(leader)
	me.inventory.add(_weapon("hunter_killer"))
	wm.use_weapon(me)
	var hit := false
	for i in 400:
		await physics_frame
		if leader.status.has(&"stun"):
			hit = true
			break
	_check(hit and wm.decoy_of(leader) != null, "the Hunter-Killer ignores the decoy (and leaves it)")
	# Expires after 8 s.
	me.inventory.clear()
	var decoy := wm.decoy_of(me)
	me.inventory.add(_weapon("decoy"))
	wm.use_weapon(me)
	decoy = wm.decoy_of(me)
	await _frames(int(7.8 * 60))
	_check(wm.decoy_of(me) == decoy, "still out at 7.8 s")
	await _frames(20)
	_check(wm.decoy_of(me) == null, "gone after 8 s")


# --- AI ------------------------------------------------------------------------------

func _test_ai_use(race: RaceManager) -> void:
	var used := {}
	race.weapon_manager.weapon_used.connect(func(_car: VehicleController, w: WeaponData) -> void:
		used[w.id] = used.get(w.id, 0) + 1)
	var keys := ["decoy", "glitch", "swarm"]
	for t in 1800:
		if t % 120 == 0:
			for i in race.racers.size():
				var racer := race.racers[i]
				if racer.is_player or racer.vehicle.inventory == null:
					continue
				if racer.vehicle.inventory.has_space():
					racer.vehicle.inventory.add(_weapon(keys[(i + t / 120) % 3]))
		await physics_frame
	_check(used.get(&"holo_decoy", 0) > 0 and used.get(&"system_glitch", 0) > 0 and used.get(&"swarm_bots", 0) > 0,
			"rivals use all three (%s)" % [used])
