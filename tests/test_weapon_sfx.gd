extends SceneTree
## Weapon sounds: Firewall up / down, Railgun shot, EMP Pulse zap and
## System Override crackle. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_weapon_sfx.gd

const RACE_SCENE := "res://scenes/race/race.tscn"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_weapon_sfx_profile.json"
	GameSettings.path = "user://test_weapon_sfx_settings.cfg"
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


## Sound players currently on `car` whose name starts with Sfx<sfx_name>.
func _sfx(car: Node, sfx_name: String) -> int:
	var count := 0
	for child in car.get_children():
		if child is AudioStreamPlayer3D and String(child.name).begins_with("Sfx" + sfx_name):
			count += 1
	return count


func _weapon(id: String) -> WeaponData:
	return load("res://resources/weapons/%s.tres" % id) as WeaponData


func _run_all() -> void:
	for stream in [CombatSfx.SHIELD_UP, CombatSfx.SHIELD_DOWN, CombatSfx.OVERRIDE, CombatSfx.RAILGUN, CombatSfx.EMP,
			CombatSfx.HK_LAUNCH, CombatSfx.HK_WARNING, CombatSfx.HK_EXPLOSION,
			CombatSfx.SPIKE_DROP, CombatSfx.BARRIER_SMASH]:
		var s := stream as AudioStream
		_check(s != null and s.get_length() > 0.1 and s.get_length() < 8.0,
				"clip loads and is short (%.2f s)" % (s.get_length() if s != null else 0.0))
		_check(s is AudioStreamMP3 and not (s as AudioStreamMP3).loop, "clip doesn't loop")

	# Levels: louder clips can't be capped by max_db, and Master has a limiter.
	var boosted := CombatSfx.play_on(null, CombatSfx.HK_WARNING, "X")
	_check(boosted == null, "no player without a node")
	_check(CombatSfx.level_db(CombatSfx.HK_WARNING) > CombatSfx.level_db(CombatSfx.RAILGUN),
			"quiet clips are lifted more than hot ones")
	var master_limited := false
	for i in AudioServer.get_bus_effect_count(0):
		master_limited = master_limited or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	_check(master_limited, "Master bus has a limiter")

	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.weapons_enabled = true
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	var wm := race.weapon_manager
	var me: VehicleController = race.player.vehicle

	# Firewall: activation sound once, not again on a refresh.
	wm._deploy(me, _weapon("firewall"))
	_check(_sfx(me, "ShieldUp") == 1, "Firewall activation plays the shield-up sound")
	_check(_sfx(me, "ShieldDown") == 0, "no shield-down sound while it's up")
	wm._deploy(me, _weapon("firewall"))
	_check(_sfx(me, "ShieldUp") == 1, "re-using Firewall while shielded doesn't replay it")
	# Expiry.
	me.status._timers[&"shield"] = 0.05
	await _frames(10)
	_check(not me.status.has(&"shield"), "shield ran out")
	_check(_sfx(me, "ShieldDown") == 1, "shield expiry plays the shield-drop sound")

	# Railgun and EMP play on the user.
	wm._deploy(me, _weapon("railgun"))
	_check(_sfx(me, "Railgun") == 1, "Railgun fire plays its sound")
	var rail := me.get_node_or_null("SfxRailgun") as AudioStreamPlayer3D
	_check(rail != null and rail.max_db >= rail.volume_db, "max_db leaves room for the clip's level")
	wm._deploy(me, _weapon("emp_pulse"))
	_check(_sfx(me, "Emp") == 1, "EMP Pulse plays the zap")

	# Road Spike: the drop sound sits on the strip behind the car.
	wm._deploy(me, _weapon("road_spike"))
	var spike: RoadSpike = null
	for child in wm.get_children():
		if child is RoadSpike:
			spike = child
	_check(spike != null and _sfx(spike, "SpikeDrop") == 1, "dropping a Road Spike plays the crowbar drop")

	# Breakable barrier: planks clatter at the barrier when smashed.
	var barrier: TrackFeature = null
	for node in race.track.find_children("*", "TrackFeature", true, false):
		if (node as TrackFeature).kind == TrackFeature.Kind.BREAKABLE:
			barrier = node
			break
	if barrier == null:
		barrier = TrackFeature.new()
		barrier.kind = TrackFeature.Kind.BREAKABLE
		race.add_child(barrier)
		await process_frame
	barrier._smash()
	_check(barrier.is_broken() and _sfx(barrier, "Smash") == 1, "smashing a breakable barrier plays the planks clatter")

	# System Override from last place: user plus every hacked car.
	var standings := race.get_standings()
	var last: VehicleController = standings[standings.size() - 1].vehicle
	for racer in race.racers:
		racer.vehicle.status.clear_all()
	await _frames(2)
	var hit: Array[VehicleController] = wm._system_override(last, _weapon("system_override"))
	_check(hit.size() > 0, "override hacked someone")
	_check(_sfx(last, "Override") == 1, "override sound plays at the user")
	var humans_ok := true
	var ai_quiet := true
	for car in hit:
		if car.is_player:
			humans_ok = humans_ok and _sfx(car, "Override") == 1
		else:
			ai_quiet = ai_quiet and _sfx(car, "Override") == 0
	_check(humans_ok, "override sound plays on hacked human cars")
	_check(ai_quiet, "no override sound on hacked AI cars (no stacking)")

	# Hunter-Killer: launch at the user, lock beeps then explosion on the leader.
	for racer in race.racers:
		racer.vehicle.status.clear_all()
	await _frames(2)
	wm._deploy(last, _weapon("hunter_killer"))
	var drone: HunterKillerDrone = null
	for child in wm.get_children():
		if child is HunterKillerDrone:
			drone = child
	_check(drone != null, "Hunter-Killer launched")
	_check(_sfx(last, "HkLaunch") == 1, "Hunter-Killer launch plays the rocket sound")
	if drone != null:
		var prey := drone.target
		var t := 0
		while is_instance_valid(drone) and not drone.is_warning() and t < 60 * 10:
			await physics_frame
			t += 1
		_check(is_instance_valid(drone) and drone.is_warning(), "Hunter-Killer reaches its warning")
		_check(_sfx(prey, "HkWarning") == 1, "warning plays the lock beeps on the target")
		t = 0
		while is_instance_valid(drone) and t < 60 * 10:
			await physics_frame
			t += 1
		await process_frame
		_check(not is_instance_valid(drone), "Hunter-Killer hit")
		_check(_sfx(prey, "HkExplosion") == 1, "hit plays the explosion on the target")
		_check(_sfx(prey, "HkWarning") == 0, "lock beeps stop when it hits")

	# Players free themselves when the clip ends (dummy driver plays in real time).
	var waited := 0.0
	while _sfx(me, "Railgun") > 0 and waited < 10.0:
		await create_timer(0.25).timeout
		waited += 0.25
	_check(_sfx(me, "Railgun") == 0, "sound player removes itself after the clip")

	race.queue_free()
	await process_frame
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
