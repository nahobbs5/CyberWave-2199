extends SceneTree
## Engine classes (GDD 2.1a): 50 / 100 / 150 / 200cc scale every car's top
## speed, acceleration, braking and boosts (100cc = the base tuning). Records
## are kept per class. Grand Prix: car, CC and Mirror on the setup screen
## first, then the cup screen's START GRAND PRIX starts it. Split screen has
## CC under Race Type and a Grand Prix Mirror toggle. Then short races on the
## Test Circuit at 100cc and 200cc.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_cc.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const RACE_SETUP := "res://scenes/menu/race_setup.tscn"
const CUP_SELECT := "res://scenes/menu/cup_select.tscn"
const MP_SETUP := "res://scenes/menu/multiplayer_setup.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
## Seconds of racing in each speed race.
const RACE_SECONDS := 14.0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_cc_profile.json"
	# Every car unlocked: these checks pick any car (unlocks: test_time_trial).
	PlayerProfile.unlock_all_for_tests()
	GameSettings.path = "user://test_cc_settings.cfg"
	Championship.save_path = "user://test_cc_gp.json"
	PlayerProfile.delete_save()
	Championship.clear_save()
	GameSession.scene_changes_enabled = false
	PodiumCeremony.instant = true
	CarUnlockScreen.instant = true
	_run_all.call_deferred()


func _run_all() -> void:
	_test_data()
	_test_championship()
	await _test_gp_flow()
	await _test_versus_setup()
	await _test_multiplayer_setup()
	var top := {}
	for cc in [100, 200]:
		top[cc] = await _run_race(cc)
	_current = "speed"
	_check(top[200] > top[100] * 1.15, "200cc is clearly faster on track (%.1f vs %.1f m/s)" % [top[200], top[100]])
	PlayerProfile.delete_save()
	Championship.clear_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _test_data() -> void:
	_current = "data"
	print("- data")
	_check(RaceConfig.CC_CLASSES == [50, 100, 150, 200] and RaceConfig.CC_CLASSES[RaceConfig.DEFAULT_CC_INDEX] == 100,
			"classes 50 / 100 / 150 / 200, 100cc by default")
	_check(RaceConfig.new().cc == 100, "a new race is 100cc")
	_check(is_equal_approx(RaceConfig.cc_scale(100), 1.0) and RaceConfig.cc_scale(50) < 1.0
			and RaceConfig.cc_scale(150) > 1.0 and RaceConfig.cc_scale(200) > RaceConfig.cc_scale(150),
			"100cc is the base, 50 slower, 150 and 200 faster")
	var base := VehicleCatalog.by_id(PlayerProfile.DEFAULT_VEHICLE).stats
	_check(base.for_cc(100) == base, "100cc uses the car's own stats")
	var fast := base.for_cc(200)
	var k := RaceConfig.cc_scale(200)
	_check(fast != base and fast == base.for_cc(200), "200cc stats are one shared copy per car")
	_check(is_equal_approx(fast.top_speed, base.top_speed * k) and is_equal_approx(fast.acceleration, base.acceleration * k)
			and is_equal_approx(fast.brake_deceleration, base.brake_deceleration * k),
			"top speed, acceleration and brakes scale (%.1f -> %.1f m/s)" % [base.top_speed, fast.top_speed])
	_check(is_equal_approx(fast.grip, base.grip) and is_equal_approx(fast.handling, base.handling),
			"grip and handling stay the same")
	_check(is_equal_approx(base.top_speed, VehicleCatalog.by_id(PlayerProfile.DEFAULT_VEHICLE).stats.top_speed),
			"the catalogue's stats are untouched")
	var config := RaceConfig.new()
	config.track_name = "Marble Canyon"
	_check(config.record_name() == "Marble Canyon", "100cc records keep the track name")
	config.mirrored = true
	_check(config.record_name() == "Marble Canyon (Mirror)", "100cc Mirror keeps the old Mirror name")
	config.cc = 200
	_check(config.record_name() == "Marble Canyon (Mirror, 200cc)", "Mirror 200cc has its own record")
	config.mirrored = false
	_check(config.record_name() == "Marble Canyon (200cc)", "200cc has its own record")
	_check(RaceConfig.gp_record_id("american_circuit", 100, false) == "american_circuit"
			and RaceConfig.gp_record_id("american_circuit", 150, true) == "american_circuit_mirror_150cc",
			"Grand Prix bests per class and Mirror (100cc forward = the cup id)")
	_check(not RaceSetup.describe(RaceConfig.Mode.VERSUS, 1, true, false).contains("cc:")
			and RaceSetup.describe(RaceConfig.Mode.GRAND_PRIX).begins_with("GRAND PRIX: Race a Complete Cup"),
			"no CC line in the info box; Grand Prix line is the short one")


func _test_championship() -> void:
	_current = "championship"
	print("- championship")
	var roster := load("res://resources/racers/rival_roster.tres") as RivalRoster
	var cup := GrandPrixData.cup_by_path(GrandPrixData.CUPS[0])
	var c := Championship.create(cup, "normal", true, roster, PlayerProfile.DEFAULT_VEHICLE,
			PackedInt32Array(), PackedStringArray(), true, 150, true)
	var rc := c.make_race_config()
	_check(rc.cc == 150 and rc.mirrored and rc.is_grand_prix(), "a 150cc Mirror Grand Prix races 150cc Mirror")
	var back := Championship.from_dict(c.to_dict())
	_check(back != null and back.cc == 150 and back.mirrored, "class and Mirror survive a save")
	var old := c.to_dict()
	old.erase("cc")
	old.erase("mirrored")
	var legacy := Championship.from_dict(old)
	_check(legacy != null and legacy.cc == 100 and not legacy.mirrored, "older saves load as 100cc forward")
	var template := RaceConfig.new()
	template.cc = 50
	template.mirrored = true
	var series := Championship.create_series(3, template, "normal", roster)
	series.add_track("Marble Canyon")
	_check(series.make_race_config().cc == 50 and series.make_race_config().mirrored, "a Versus series keeps its class")


func _test_gp_flow() -> void:
	_current = "grand prix flow"
	print("- grand prix flow")
	GameSession.split_screen = false
	GameSession.race_settings = {}
	GameSession.gp_template = null
	var menu := (load(MAIN_MENU) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	for b in menu._buttons:
		if b.text == "Grand Prix":
			b.pressed.emit()
	_check(GameSession.setup_mode == RaceConfig.Mode.GRAND_PRIX, "Grand Prix opens the race setup first")
	menu.queue_free()
	await process_frame
	var setup := (load(RACE_SETUP) as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await _frames(2)
	_check(setup.is_grand_prix() and setup.cc() == 100 and not setup.mirrored, "starts on 100cc, Mirror off")
	_check(setup.showcase != null and setup.showcase.is_visible_in_tree(), "the car is picked here")
	setup.set_cc(200)
	setup.set_mirror(true)
	setup.select_vehicle(VehicleCatalog.index_of("cipher_evo"))
	_check(not setup._note.text.contains("200cc") and setup._note.text.contains("reverse")
			and setup._note.text.contains("Race a Complete Cup") and not setup._note.text.contains("Pick the cup next"),
			"the note explains Mirror, no CC line (%s)" % setup._note.text)
	GameSession.current = null
	setup.start()
	_check(GameSession.current == null and GameSession.gp_template != null and GameSession.gp_template.cc == 200
			and GameSession.gp_template.mirrored and GameSession.gp_template.vehicle_id == "cipher_evo",
			"Choose Cup keeps the car, class and Mirror and doesn't start a race yet")
	setup.queue_free()
	await process_frame
	PlayerProfile.get_profile().record_grand_prix(RaceConfig.gp_record_id("american_circuit", 200, true), 2, 40)
	var cups := (load(CUP_SELECT) as PackedScene).instantiate() as CupSelect
	root.add_child(cups)
	await _frames(2)
	cups.board.preview(0)
	_check(cups.board._cup_info.text.to_lower().contains("2nd") and cups.board._cup_info.text.contains("200cc"),
			"the cup shows its best for this class (%s)" % cups.board._cup_info.text)
	cups.pick(0)
	var current := GameSession.current
	_check(current != null and current.is_grand_prix() and current.cc == 200 and current.mirrored
			and current.championship.vehicle_id == "cipher_evo", "START GRAND PRIX starts race 1 at 200cc Mirror")
	_check(Championship.has_save() and Championship.load_saved().cc == 200, "and saves it")
	cups.queue_free()
	await process_frame
	# Back from the cup screen returns to the setup.
	cups = (load(CUP_SELECT) as PackedScene).instantiate() as CupSelect
	root.add_child(cups)
	await process_frame
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	cups.back()
	_check(GameSession.setup_mode == RaceConfig.Mode.GRAND_PRIX, "Back from the cups goes to the Grand Prix setup")
	cups.queue_free()
	await process_frame
	setup = (load(RACE_SETUP) as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await _frames(2)
	_check(setup.cc() == 200 and setup.mirrored and setup._mirror.button_pressed, "the setup reopens on the last choices")
	setup.set_cc(100)
	setup.set_mirror(false)
	setup._remember()
	setup.queue_free()
	await process_frame
	Championship.clear_save()
	GameSession.current = null
	GameSession.gp_template = null


func _test_versus_setup() -> void:
	_current = "versus setup"
	print("- versus setup")
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	var setup := (load(RACE_SETUP) as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await _frames(2)
	var rows := setup._cc.get_parent().get_parent().get_parent()
	var type_row := setup._race_type.get_parent().get_parent()
	var cc_row := setup._cc.get_parent().get_parent()
	_check(setup._mirror == null and cc_row.get_index() == type_row.get_index() + 1 and rows == type_row.get_parent(),
			"Versus: CC right under Race Type, no Mirror toggle")
	var base_kmh := roundi(setup.vehicle().stats.top_speed * 3.6)
	setup.set_cc(150)
	_check(setup.showcase.top_speed_text() == "%d km/h" % roundi(setup.vehicle().stats.top_speed * 1.15 * 3.6)
			and setup.showcase.top_speed_text() != "%d km/h" % base_kmh,
			"the car's top-speed card follows the CC (%s)" % setup.showcase.top_speed_text())
	setup._cc.selected = 0
	setup._cc.item_selected.emit(0)
	_check(setup.showcase.top_speed_text() == "%d km/h" % roundi(setup.vehicle().stats.top_speed * 0.8 * 3.6),
			"stepping the CC row updates the card (%s)" % setup.showcase.top_speed_text())
	setup.set_cc(150)
	setup.select_vehicle(setup.vehicle_index + 1)
	_check(setup.showcase.top_speed_text() == "%d km/h" % roundi(setup.vehicle().stats.top_speed * 1.15 * 3.6),
			"another car keeps the class's top speed (%s)" % setup.showcase.top_speed_text())
	setup.select_vehicle(setup.vehicle_index - 1)
	setup.set_race_type(RaceSetup.MIRROR)
	var config := setup.make_config()
	_check(config.cc == 150 and config.mirrored, "Versus config carries the class")
	GameSession.versus_template = config
	var tracks := (load("res://scenes/menu/track_select.tscn") as PackedScene).instantiate() as TrackSelect
	root.add_child(tracks)
	await _frames(2)
	_check(tracks.title_text() == "MIRROR 150CC", "the track screen title shows the class (%s)" % tracks.title_text())
	tracks.queue_free()
	GameSession.versus_template = null
	setup.set_race_type(0)
	setup.set_cc(100)
	setup._remember()
	setup.queue_free()
	await process_frame


func _test_multiplayer_setup() -> void:
	_current = "split screen setup"
	print("- split screen setup")
	GameSession.mp_devices = PackedInt32Array([-1, 0])
	GameSession.mp_vehicles = PackedStringArray([PlayerProfile.DEFAULT_VEHICLE, PlayerProfile.DEFAULT_VEHICLE])
	GameSession.mp_plates = PackedStringArray(["", ""])
	var setup := (load(MP_SETUP) as PackedScene).instantiate() as MultiplayerSetup
	root.add_child(setup)
	await _frames(2)
	setup.set_mode(false)
	var type_row := setup._race_type_row
	var cc_row := setup._cc.get_parent().get_parent()
	_check(cc_row.get_index() == type_row.get_index() + 1 and not setup._mirror_row.visible,
			"Versus: CC under Race Type, no Mirror toggle")
	setup.set_cc(50)
	setup.set_races(1)
	setup.next()
	_check(GameSession.versus_template != null and GameSession.versus_template.cc == 50, "split-screen Versus at 50cc")
	setup.set_mode(true)
	_check(setup._mirror_row.visible and cc_row.visible, "Grand Prix: CC and Mirror")
	setup.set_cc(150)
	setup.set_mirror(true)
	_check(not setup._note.text.contains("150cc") and setup._note.text.contains("reverse")
			and setup._note.text.contains("Race a Complete Cup"), "the note explains Mirror, no CC line")
	setup.next()
	_check(GameSession.mp_cc() == 150 and GameSession.pending_gp_mirrored(), "the lobby keeps 150cc Mirror")
	var cup := GrandPrixData.cup_by_path(GrandPrixData.CUPS[0])
	GameSession.start_multiplayer_grand_prix(self, cup)
	var current := GameSession.current
	_check(current != null and current.is_multiplayer() and current.cc == 150 and current.mirrored,
			"split-screen Grand Prix races 150cc Mirror")
	setup.queue_free()
	await process_frame
	GameSession.mp_settings["cc"] = RaceConfig.DEFAULT_CC_INDEX
	GameSession.mp_settings["gp_mirror"] = false
	GameSession.split_screen = false
	GameSession.current = null
	GameSession.versus_template = null


## A short race on the Test Circuit; returns the player's best forward speed.
func _run_race(cc: int) -> float:
	_current = "%dcc race" % cc
	print("- " + _current)
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.weapons_enabled = false
	config.cc = cc
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = true
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 900:
		await physics_frame
		frames += 1
	var car := race.player.vehicle
	var base := VehicleCatalog.by_id(race.player_vehicle.id).stats
	_check(is_equal_approx(car.stats.top_speed, base.top_speed * RaceConfig.cc_scale(cc))
			and is_equal_approx(car.cc_scale, RaceConfig.cc_scale(cc)), "the player's car runs %dcc stats" % cc)
	var rivals_ok := race.racers.all(func(r: RaceProgress) -> bool:
		return is_equal_approx(r.vehicle.cc_scale, RaceConfig.cc_scale(cc)))
	_check(rivals_ok, "every car runs the same class")
	var line := race.line_for(car.stats)
	if cc != 100:
		var base_line := race.line_for(base)
		_check(line != base_line, "the AI gets a racing line for the faster stats")
	var top := 0.0
	for i in int(RACE_SECONDS * 60.0):
		await physics_frame
		top = maxf(top, -car.linear_velocity.dot(car.global_transform.basis.z))
	var gates := race.racers.map(func(r: RaceProgress) -> int: return r.checkpoints_passed)
	print("    top %.1f m/s, gates %s" % [top, gates])
	_check(race.racers.filter(func(r: RaceProgress) -> bool: return r.checkpoints_passed >= 1).size()
			>= race.racers.size() - 1, "the field gets round (%s)" % [gates])
	# Boosts scale with the class too.
	car.clear_boost()
	car.start_external_boost(10.0, 1.0, 0.0, "Test", Color.WHITE)
	_check(is_equal_approx(car._boost_extra_speed, 10.0 * RaceConfig.cc_scale(cc)), "boosts scale with the class")
	race.queue_free()
	await process_frame
	return top
