extends SceneTree
## Advanced weapons (docs/Cyberwave_2199_Advanced_Weapons.md): crate odds,
## System Override, the Hunter-Killer Drone and Overdrive Protocol, plus AI
## use. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_weapons_advanced.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const W := {
	"hunter_killer": "res://resources/weapons/hunter_killer.tres",
	"overdrive": "res://resources/weapons/overdrive_protocol.tres",
	"override": "res://resources/weapons/system_override.tres",
	"firewall": "res://resources/weapons/firewall.tres",
	"railgun": "res://resources/weapons/railgun.tres",
	"nitro": "res://resources/weapons/nitro_overload.tres",
}
const DT := 1.0 / 60.0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_weapons_adv_profile.json"
	GameSettings.path = "user://test_weapons_adv_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	_test_status_rules()
	await _run("crate odds", _test_odds, {})
	await _run("system override", _test_override, {})
	await _run("hunter-killer drone", _test_hunter_killer, {})
	await _run("hunter-killer: firewall, waiting, timeout", _test_hunter_killer_counters, {})
	await _run("overdrive protocol", _test_overdrive, {})
	await _run("overdrive: cancel and elimination", _test_overdrive_cancel, {})
	await _run("AI uses the advanced items", _test_ai_use, {"autopilot": true, "frozen": false})
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


func _place(race: RaceManager, car: VehicleController, offset: float, lateral: float = 0.0) -> void:
	car.teleport(race.track.get_safe_transform(offset, lateral))


## Lines every car up along the straight: `order` first (leader) to last;
## the rest are parked well behind.
func _line_up(race: RaceManager, order: Array) -> void:
	var placed := {}
	for i in order.size():
		var car: VehicleController = order[i]
		# Within 1.5 checkpoint segments of the last gate, so race distance
		# (and so the standings) follows the order here.
		_place(race, car, 200.0 - i * 15.0, -4.0 if i % 2 == 0 else 4.0)
		placed[car] = true
	var k := 0
	for racer in race.racers:
		if not placed.has(racer.vehicle):
			_place(race, racer.vehicle, 50.0 - k * 10.0, -5.0 if k % 2 == 0 else 5.0)
			k += 1
	await _frames(20)


# --- status rules (no scene) ---------------------------------------------------

func _test_status_rules() -> void:
	_current = "status rules"
	print("- status rules")
	var status := StatusEffects.new()
	_check(status.apply_attack(&"override", 2.5), "override lands")
	_check(is_equal_approx(status.speed_multiplier(), 0.75) and is_equal_approx(status.accel_multiplier(), 0.7),
			"override: 75% top speed, 70% acceleration")
	_check(not status.can_charge_drift() and status.can_use_weapons(),
			"override: no drift charging, weapons still usable")
	_check(not status.apply_attack(&"override", 1.0), "a second override doesn't land")
	status.apply_attack(&"override", 9.0)
	_check(is_equal_approx(status.time_left(&"override"), 2.5), "doesn't stack: a repeat hit neither cuts nor extends it")
	status.apply_buff(&"overdrive", 6.0)
	_check(not status.has(&"override"), "starting an Overdrive clears an override")
	_check(not status.apply_attack(&"override", 2.5) and not status.apply_attack(&"stun", 1.5),
			"an Overdrive ignores every attack")
	status.remove(&"overdrive")
	status.apply_buff(&"shield", 10.0)
	_check(not status.apply_attack(&"override", 2.5) and not status.has(&"shield"), "a Firewall soaks an override")
	status.free()


# --- odds ------------------------------------------------------------------------

func _test_odds(race: RaceManager) -> void:
	var wm := race.weapon_manager
	var specials := {&"hunter_killer": 0, &"overdrive_protocol": 0, &"system_override": 0}
	var expected := {
		1: [0, 0, 0], 2: [0, 0, 0], 3: [0, 0, 2], 5: [4, 6, 8], 8: [8, 25, 31],
	}
	var back_three := {&"overdrive_protocol": 0.0, &"system_override": 0.0, &"triple_nitro": 0.0}
	for position in range(1, 9):
		var sum := 0.0
		for w in wm.weapons:
			sum += w.chance_for(position, 8)
		_check(is_equal_approx(sum, 100.0), "P%d crate odds add up to 100%% (%.1f)" % [position, sum])
		for w in wm.weapons:
			if w.id == &"road_spike" and position >= 4:
				_check(w.chance_for(position, 8) == 0.0, "no single Road Spike at P%d (top 3 only)" % position)
			if w.id == &"firewall" and position >= 6:
				_check(w.chance_for(position, 8) == 0.0, "no Firewall at P%d (top 5 only)" % position)
			if w.id in back_three and position >= 7:
				back_three[w.id] += w.chance_for(position, 8)
	var back_total: float = back_three.values().reduce(func(a, b): return a + b, 0.0)
	_check(back_total >= 2.0 * 65.0, "7th-8th mostly get Overdrive / Override / Triple Nitro (%.0f%% over two places)" % back_total)
	for position: int in expected:
		var counts := [0, 0, 0]
		var rolls := 20000
		for i in rolls:
			var w := wm.roll_weapon(position, 8)
			match w.id:
				&"hunter_killer":
					counts[0] += 1
				&"overdrive_protocol":
					counts[1] += 1
				&"system_override":
					counts[2] += 1
		var want: Array = expected[position]
		var ok := true
		for k in 3:
			var pct: float = 100.0 * float(counts[k]) / rolls
			ok = ok and absf(pct - float(want[k])) < 1.0
		_check(ok, "P%d odds near drone %d%% / overdrive %d%% / override %d%% (got %s of %d)"
				% [position, want[0], want[1], want[2], counts, rolls])
	for w in wm.weapons:
		if w.id in specials:
			_check(w.is_special() and w.icon != null, "%s is a rare item with an icon" % w.display_name)


# --- System Override ---------------------------------------------------------------

func _test_override(race: RaceManager) -> void:
	var me := race.player.vehicle
	var order: Array = [_rival(race, 0), _rival(race, 1), _rival(race, 2), _rival(race, 3), me,
			_rival(race, 4), _rival(race, 5), _rival(race, 6)]
	await _line_up(race, order)
	_check(race.progress_of(me).position == 5, "player is 5th (%d)" % race.progress_of(me).position)
	_rival(race, 1).status.apply_buff(&"shield", 10.0)
	me.inventory.add(_weapon("override"))
	race.weapon_manager.use_weapon(me)
	var hit_ahead := 0
	for i in 4:
		if order[i].status.has(&"override"):
			hit_ahead += 1
	_check(hit_ahead == 3 and not _rival(race, 1).status.has(&"override") and not _rival(race, 1).status.has(&"shield"),
			"1st-4th hacked, except the one whose Firewall soaked it (%d)" % hit_ahead)
	var behind_clean := not me.status.has(&"override")
	for i in range(5, 8):
		behind_clean = behind_clean and not order[i].status.has(&"override")
	_check(behind_clean, "the user and everyone behind are untouched")
	var victim: VehicleController = order[0]
	_check(victim.get_node_or_null("OverrideSparks") != null, "red arcs on a victim")
	_check(is_equal_approx(victim.get_speed_cap(), victim.stats.top_speed * 0.75), "victim's top speed is cut by 25%")
	# Time hacked follows position at activation: 1st 12 s ... 4th 7.5 s.
	_check(absf(victim.status.time_left(&"override") - 12.0) < 0.1,
			"the leader is hacked for 12 s (%.2f)" % victim.status.time_left(&"override"))
	_check(absf(order[3].status.time_left(&"override") - 7.5) < 0.1,
			"4th is hacked for 7.5 s (%.2f)" % order[3].status.time_left(&"override"))
	_check(not victim.status.can_charge_drift() and victim.status.can_use_weapons(),
			"hacked: no drift charge, weapons still work")
	# A second Override from further back doesn't extend anyone already hacked.
	var before: float = victim.status.time_left(&"override")
	var rear: VehicleController = order[6]
	rear.inventory.add(_weapon("override"))
	race.weapon_manager.use_weapon(rear)
	_check(victim.status.time_left(&"override") <= before, "a repeat Override doesn't extend the leader's hack")
	_check(me.status.has(&"override") and absf(me.status.time_left(&"override") - 6.0) < 0.1,
			"the earlier user (5th) is now hacked for 6 s")
	# A hacked car really does accelerate slower.
	var clean: VehicleController = order[7]
	for car: VehicleController in [victim, clean]:
		# Stop the (disabled) AI from zeroing the inputs each frame.
		race.get_ai(race.progress_of(car)).set_physics_process(false)
		car.player_controlled = false
		car.throttle_input = 1.0
	_place(race, victim, 500.0, -4.0)
	_place(race, clean, 500.0, 4.0)
	await _frames(60)
	_check(victim.forward_speed < clean.forward_speed * 0.85,
			"hacked car accelerates slower (%.1f vs %.1f m/s)" % [victim.forward_speed, clean.forward_speed])
	# Wait out 4th place's 7.5 s: they recover while the leader is still hacked.
	var fourth: VehicleController = order[3]
	var frames := 0
	while fourth.status.has(&"override") and frames < 600:
		await physics_frame
		frames += 1
	_check(not fourth.status.has(&"override") and is_equal_approx(fourth.status.accel_multiplier(), 1.0)
			and is_equal_approx(fourth.status.speed_multiplier(), 1.0), "4th back to normal when the timer ends")
	_check(victim.status.has(&"override"), "the leader is still hacked")


# --- Hunter-Killer Drone ---------------------------------------------------------

func _hunter(race: RaceManager) -> HunterKillerDrone:
	for node in race.weapon_manager.get_children():
		if node is HunterKillerDrone:
			return node
	return null


func _test_hunter_killer(race: RaceManager) -> void:
	var me := race.player.vehicle
	var leader := _rival(race, 0)
	var second := _rival(race, 1)
	await _line_up(race, [leader, second, _rival(race, 2), me])
	_check(race.get_standings()[0].vehicle == leader, "rival 0 leads")
	me.inventory.add(_weapon("hunter_killer"))
	race.weapon_manager.use_weapon(me)
	var drone := _hunter(race)
	_check(drone != null and drone.target == leader, "the drone locks on to the leader")
	_check(race.weapon_manager.is_incoming(leader), "the leader sees INCOMING")
	# The leader drops to 2nd: the drone keeps hunting them.
	_place(race, second, 215.0)
	await _frames(10)
	var dbg := race.get_standings().slice(0, 3).map(func(r: RaceProgress) -> String:
		return "%s %.0f cp%d" % [r.display_name, r.race_distance, r.next_checkpoint])
	_check(race.get_standings()[0].vehicle == second and drone.target == leader,
			"keeps its target after they lose the lead (%s, target ok %s)" % [dbg, drone.target == leader])
	var warned_at := -1.0
	var hit_at := -1.0
	var t := 0.0
	for i in 600:
		await physics_frame
		t += DT
		if warned_at < 0.0 and is_instance_valid(drone) and drone.is_warning():
			warned_at = t
		if leader.status.has(&"stun"):
			hit_at = t
			break
	_check(hit_at > 0.0, "the drone strikes the target (%.2f s)" % hit_at)
	_check(warned_at > 0.0 and hit_at - warned_at >= 1.15,
			"a 1.2 s warning first (%.2f s)" % (hit_at - warned_at))
	_check(absf(leader.status.time_left(&"stun") - 1.5) < 0.05, "1.5 s spin-out")
	_check(not second.status.has(&"stun") and not me.status.has(&"stun"), "nobody else is hit")
	await _frames(2)
	_check(_hunter(race) == null, "the drone is spent")


func _test_hunter_killer_counters(race: RaceManager) -> void:
	var me := race.player.vehicle
	var leader := _rival(race, 0)
	await _line_up(race, [leader, _rival(race, 1), me])
	var wm := race.weapon_manager
	# A Firewall doesn't stop it: the blast goes straight through (shield kept).
	leader.status.apply_buff(&"shield", 10.0)
	me.inventory.add(_weapon("hunter_killer"))
	wm.use_weapon(me)
	for i in 600:
		await physics_frame
		if _hunter(race) == null:
			break
	_check(leader.status.has(&"stun") and leader.status.has(&"shield"), "a Firewall doesn't block the blast (and isn't used up)")
	leader.status.remove(&"shield")
	await _frames(150)
	# A Nitro fired too early doesn't help: the drone keeps hunting.
	var dodges := [0]
	var count_dodge := func(t: VehicleController, _w: WeaponData, _s: VehicleController, by: StringName) -> void:
		if t == leader and by == &"dodge":
			dodges[0] += 1
	wm.hit_resolved.connect(count_dodge)
	leader.inventory.clear()
	me.inventory.add(_weapon("hunter_killer"))
	wm.use_weapon(me)
	var drone := _hunter(race)
	leader.inventory.add(_weapon("nitro"))
	wm.use_weapon(leader)
	_check(dodges[0] == 0 and is_instance_valid(drone) and not drone.in_dodge_window(), "an early Nitro doesn't dodge")
	# Fired in the last moment of the warning: the drone misses.
	var t := 0
	while is_instance_valid(drone) and not drone.in_dodge_window() and t < 600:
		await physics_frame
		t += 1
	_check(is_instance_valid(drone) and drone.is_warning() and wm.can_dodge_drone(leader), "the dodge window opens late in the warning")
	leader.inventory.add(_weapon("nitro"))
	wm.use_weapon(leader)
	_check(dodges[0] == 1 and not wm.is_incoming(leader), "a well-timed Nitro dodges the drone")
	await _frames(60)
	_check(_hunter(race) == null and not leader.status.has(&"stun"), "the dodged drone fizzles without a hit")
	wm.hit_resolved.disconnect(count_dodge)
	await _frames(100)
	# The target is mid-recovery: the drone hovers and waits instead of striking.
	await _frames(120)
	me.inventory.add(_weapon("hunter_killer"))
	wm.use_weapon(me)
	drone = _hunter(race)
	leader.recovery.request_recovery("test")
	var struck_while_hidden := false
	for i in 60:
		await physics_frame
		if leader.recovery.is_hidden() and leader.status.has(&"stun"):
			struck_while_hidden = true
	_check(not struck_while_hidden and is_instance_valid(drone), "waits while the target is recovering")
	# The target finishes: the drone burns out.
	race.progress_of(leader).finished = true
	await _frames(3)
	_check(_hunter(race) == null, "burns out when the target finishes")
	race.progress_of(leader).finished = false
	# Lifetime: a target it can never reach (flying for good) times it out.
	me.inventory.add(_weapon("hunter_killer"))
	wm.use_weapon(me)
	drone = _hunter(race)
	drone.weapon = drone.weapon.duplicate()
	drone.weapon.lifetime = 0.5
	leader.fly_to(leader.global_transform, Vector3.ZERO)
	await _frames(40)
	_check(_hunter(race) == null and not leader.status.has(&"stun"), "times out (lifetime)")
	leader.end_flight(0.0)


# --- Overdrive Protocol ------------------------------------------------------------

func _test_overdrive(race: RaceManager) -> void:
	var me := race.player.vehicle
	var track := race.track
	var progress := race.progress_of(me)
	# Start on the grid like a real race so gates count from the line.
	var passed_before := progress.checkpoints_passed
	var other := _rival(race, 3)
	me.inventory.add(_weapon("overdrive"))
	race.weapon_manager.use_weapon(me)
	var od := me.overdrive
	_check(od != null and od.is_active() and me.is_flying(), "Overdrive takes off")
	_check(me.status.has(&"overdrive") and not me.can_control(), "untouchable and on autopilot")
	var max_height := 0.0
	var max_speed := 0.0
	var states: Array[int] = []
	od.state_changed.connect(func(s: OverdriveController.State) -> void: states.append(s))
	var dropped_on := false
	var drop_spot := Vector3.ZERO
	var max_shove := 0.0
	var attacked := false
	var recovered := false
	me.recovery.recovered.connect(func(_r: String) -> void: recovered = true)
	for i in 600:
		await physics_frame
		var road_y := track.get_center_at(track.get_offset_at(me.global_position)).y
		max_height = maxf(max_height, me.global_position.y - road_y)
		max_speed = maxf(max_speed, me.forward_speed)
		if od.state == OverdriveController.State.FLIGHT and not attacked:
			attacked = true
			_check(not race.weapon_manager.apply_hit(me, _weapon("railgun"), other), "attacks are ignored in flight")
			_check(not me.recovery.request_recovery("manual"), "no reset while flying")
			# Put a car in the flight path: it gets nudged aside.
			var ahead := track.get_offset_at(me.global_position) + 25.0
			_place(race, other, ahead, 0.0)
			drop_spot = race.track.get_safe_transform(ahead, 0.0).origin
			dropped_on = true
		if dropped_on:
			max_shove = maxf(max_shove, Vector2(other.global_position.x - drop_spot.x, other.global_position.z - drop_spot.z).length())
		if not od.is_active():
			break
	_check(states.size() >= 4 and states[0] == OverdriveController.State.ASCENDING and states.back() == OverdriveController.State.NORMAL,
			"activate, ascend, fly, descend, land (%s)" % [states])
	_check(max_height > 2.5 and max_height < 5.0, "flies 3-5 m up (%.1f m)" % max_height)
	_check(max_speed > me.stats.top_speed * 1.9, "at about 2x top speed (%.0f vs top %.0f)" % [max_speed, me.stats.top_speed])
	_check(dropped_on and max_shove > 1.0, "a car in the way is pushed aside (%.1f m)" % max_shove)
	await _frames(5)
	_check(not me.is_flying() and me.can_control() and not me.status.has(&"overdrive"), "lands and hands back control")
	await _frames(20)
	_check(track.is_on_road(me.global_position) and me.grounded_wheels >= 2,
			"on the road, wheels down (on road %s, wheels %d, %.1f m/s)" % [track.is_on_road(me.global_position), me.grounded_wheels, me.forward_speed])
	_check(progress.checkpoints_passed > passed_before + 1, "gates still count in flight (%d -> %d)"
			% [passed_before, progress.checkpoints_passed])
	_check(not recovered, "no recovery fired during the flight")
	await _frames(2)
	var pods := me.get_children().filter(func(n: Node) -> bool:
		return n is MeshInstance3D and (n as MeshInstance3D).mesh is CapsuleMesh and not n.is_queued_for_deletion())
	_check(pods.is_empty(), "thruster pods retract")
	_check(me.find_children("*", "CPUParticles3D", false, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size() <= 3,
			"thruster effects are cleaned up")


func _test_overdrive_cancel(race: RaceManager) -> void:
	var rival := _rival(race, 2)
	await _frames(10)
	var od := OverdriveController.for_vehicle(rival)
	_check(od.activate(race.track), "an AI car can fly too")
	await _frames(60)
	race._remove_vehicle(rival)
	_check(not rival.is_flying() and not od.is_active() and rival.collision_layer == 0,
			"elimination ends the flight; the car is out")
	_check(not rival.status.has(&"overdrive"), "and drops the buff")


# --- AI ----------------------------------------------------------------------------

func _test_ai_use(race: RaceManager) -> void:
	var used := {}
	race.weapon_manager.weapon_used.connect(func(_car: VehicleController, w: WeaponData) -> void:
		used[w.id] = used.get(w.id, 0) + 1)
	var recoveries := [0]
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var keys := ["hunter_killer", "overdrive", "override"]
	for t in 1500:
		if t % 120 == 0:
			for i in race.racers.size():
				var racer := race.racers[i]
				if racer.is_player or racer.vehicle.inventory == null:
					continue
				if racer.vehicle.inventory.has_space():
					racer.vehicle.inventory.add(_weapon(keys[(i + t / 120) % 3]))
		await physics_frame
	_check(used.get(&"hunter_killer", 0) > 0 and used.get(&"overdrive_protocol", 0) > 0 and used.get(&"system_override", 0) > 0,
			"rivals use all three (%s)" % [used])
	_check(recoveries[0] <= 6, "no recovery storm (%d recoveries)" % recoveries[0])
