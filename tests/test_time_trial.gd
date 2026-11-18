extends SceneTree
## Time Trial, ghosts and car unlocks (GDD 2.5, 9.1a). Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_time_trial.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const RACE_SETUP := "res://scenes/menu/race_setup.tscn"
const TRACK_SELECT := "res://scenes/menu/track_select.tscn"
const GARAGE := "res://scenes/menu/garage.tscn"
const TEST_GHOSTS := "user://test_tt_ghosts/"
## A Time Trial track whose race is run on the (fast) test circuit.
## Its rival (Revenant) is a Time Trial unlock, not a cup / race-route car.
const TRACK := "Fires of Nyiragongo"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_tt_profile.json"
	GameSettings.path = "user://test_tt_settings.cfg"
	Championship.save_path = "user://test_tt_gp.json"
	TimeTrialCatalog.ghost_dir = TEST_GHOSTS
	TimeTrialCatalog.player_ghost_dir = "user://test_tt_best/"
	GameSession.scene_changes_enabled = false
	PodiumCeremony.instant = true
	CarUnlockScreen.instant = true
	_run_all.call_deferred()


func _run_all() -> void:
	# Start without ghosts left over from an earlier run.
	for dir in [TEST_GHOSTS, TimeTrialCatalog.player_ghost_dir]:
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	_fresh_profile()
	_test_catalogs()
	_test_profile_unlocks()
	_test_old_save()
	_test_signature_items()
	_test_ghost_data()
	await _test_menus()
	await _test_garage()
	await _test_race()
	await _test_unlock_routes()
	await _test_practice_lap()
	_test_baked_ghosts()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _fresh_profile() -> PlayerProfile:
	PlayerProfile.unlock_all_for_tests(false)
	PlayerProfile.delete_save()
	return PlayerProfile.get_profile()


## A straight-line ghost: `seconds` long, 30 Hz, gate times every 10 s.
func _fake_ghost(vehicle_id: String, seconds: float, target: float) -> GhostData:
	var g := GhostData.new()
	g.track_name = TRACK
	g.vehicle_id = vehicle_id
	var n := int(seconds * g.sample_hz) + 1
	for i in n:
		var t := i / g.sample_hz
		g.add_frame(Transform3D(Basis(), Vector3(0, 0, -t * 10.0)), 10.0, 0.0, 0.0, t >= 20.0 and t < 23.0)
	for k in int(seconds / 10.0):
		g.checkpoint_times.append((k + 1) * 10.0)
	g.recorded_time = seconds
	g.target_time = target
	return g


func _save_fake_ghosts(rival_t: float, expert_t: float) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_GHOSTS))
	var rival_id := TimeTrialCatalog.rival_vehicle(TRACK)
	ResourceSaver.save(_fake_ghost(rival_id, 100.0, rival_t), TimeTrialCatalog.ghost_path(TRACK, TimeTrialCatalog.Ghost.RIVAL))
	ResourceSaver.save(_fake_ghost(rival_id, 100.0, expert_t), TimeTrialCatalog.ghost_path(TRACK, TimeTrialCatalog.Ghost.EXPERT))


# --- data -------------------------------------------------------------------------

func _test_catalogs() -> void:
	var first: Array[String] = []
	for v in VehicleCatalog.all().slice(0, UnlockCatalog.STARTERS.size()):
		first.append(v.id)
	_check(first == UnlockCatalog.STARTERS, "the starter cars come first in the list (%s)" % ", ".join(first))
	_current = "catalogs"
	print("- unlock and Time Trial catalogs")
	var tracks := TimeTrialCatalog.tracks()
	_check(tracks.size() == 16, "16 Time Trial tracks (%d)" % tracks.size())
	_check(tracks.has("Vegas Overdrive") and not tracks.has("Test Circuit"), "Vegas in, Test Circuit out")
	var every_cup_track := true
	for cup in GrandPrixData.all_cups():
		for t in cup.track_names:
			every_cup_track = every_cup_track and tracks.has(t)
	_check(every_cup_track, "every cup track has a Time Trial")
	var rivals_locked := true
	var per_car := {}
	for t in tracks:
		var id := TimeTrialCatalog.rival_vehicle(t)
		rivals_locked = rivals_locked and not UnlockCatalog.is_starter(id) and VehicleCatalog.by_id(id).id == id
		per_car[id] = int(per_car.get(id, 0)) + 1
	_check(rivals_locked, "every rival is a real, locked car")
	var locked_ids := VehicleCatalog.all().map(func(v: VehicleData) -> String: return v.id).filter(
			func(id: String) -> bool: return not UnlockCatalog.is_starter(id))
	_check(locked_ids.all(func(id: String) -> bool: return int(per_car.get(id, 0)) >= 1),
			"each locked car is the rival somewhere (%s)" % str(per_car))
	_check(UnlockCatalog.CUP_UNLOCKS.values().all(func(id: String) -> bool: return int(per_car.get(id, 0)) >= 2),
			"each cup car is the rival on 2+ tracks (paint + glow) (%s)" % str(per_car))
	_check(TimeTrialCatalog.rival_vehicle("Arashiyama Circuit") == "switchback", "Switchback is the Arashiyama rival")
	_check(UnlockCatalog.STARTERS.size() == 3 and VehicleCatalog.all().size() - locked_ids.size() == 3, "three starters")
	var rewards := {}
	var rewards_ok := true
	for t in tracks:
		var r := TimeTrialCatalog.expert_reward(t)
		if r == "":
			continue
		var item := CosmeticCatalog.by_id(r)
		rewards_ok = rewards_ok and item != null and item.unlock_only and item.vehicle_id == TimeTrialCatalog.rival_vehicle(t)
		rewards[r] = true
	_check(rewards_ok and rewards.size() == 15, "15 expert rewards, each the rival car's own (%d)" % rewards.size())
	# Every unlockable car has a signature paint and an animated underglow:
	# won in Time Trial, or (one-track cars' glows) bought for that car only.
	var sig_ok := true
	for id: String in locked_ids:
		var paint := CosmeticCatalog.by_id("sig_paint_" + id)
		var glow := CosmeticCatalog.by_id("sig_glow_" + id)
		sig_ok = sig_ok and paint != null and glow != null and paint.vehicle_id == id \
				and glow.vehicle_id == id and glow.is_animated()
	_check(sig_ok, "every unlockable car has a signature paint and glow")
	var shop_glow := CosmeticCatalog.by_id("sig_glow_switchback")
	_check(shop_glow != null and not shop_glow.unlock_only and shop_glow.price > 0
			and shop_glow.fits("switchback") and not shop_glow.fits("v8_specter"), "Switchback's glow is a shop item for it alone")
	var cups_ok := true
	for cup in GrandPrixData.all_cups():
		var id := UnlockCatalog.cup_unlock(cup.id)
		cups_ok = cups_ok and id != "" and not UnlockCatalog.is_starter(id)
	_check(cups_ok, "every cup unlocks a car")
	# The last five of the original eight cars, one per cup in menu order.
	var originals := VehicleCatalog.all().slice(3, 8).map(func(v: VehicleData) -> String: return v.id)
	var cup_cars := GrandPrixData.all_cups().map(func(c: GrandPrixData) -> String: return UnlockCatalog.cup_unlock(c.id))
	_check(cup_cars == originals, "cups give %s in order (%s)" % [str(originals), str(cup_cars)])
	_check(UnlockCatalog.ELIMINATION_UNLOCK == VehicleCatalog.all()[8].id, "Elimination gives the first new car")
	_check(UnlockCatalog.MIRROR_PODIUM_UNLOCK == "afterimage" and UnlockCatalog.TOP_CC_WIN_UNLOCK == "high_roller",
			"Mirror podium gives Afterimage, a 200cc win High Roller")
	_check(UnlockCatalog.PRACTICE_LAP_UNLOCK == "interceptor" and UnlockCatalog.PRACTICE_LAP_TRACK == "Vegas Overdrive"
			and not UnlockCatalog.time_trial_unlocks("interceptor"), "a Practice lap of Vegas gives Interceptor")
	var tt_cars := VehicleCatalog.all().slice(11, 12).map(func(v: VehicleData) -> String: return v.id)
	_check(tt_cars == ["revenant"] and tt_cars.all(func(id: String) -> bool: return UnlockCatalog.time_trial_unlocks(id)),
			"the rest are Time Trial unlocks (%s)" % str(tt_cars))
	_check(not UnlockCatalog.time_trial_unlocks("afterimage") and not UnlockCatalog.time_trial_unlocks("high_roller"),
			"Mirror / 200cc cars aren't")
	_check(not UnlockCatalog.time_trial_unlocks("empyrean_s") and not UnlockCatalog.time_trial_unlocks("switchback")
			and not UnlockCatalog.time_trial_unlocks("v8_specter"), "cup / Elimination / starter cars aren't")
	var ways := UnlockCatalog.how_to_unlock("empyrean_s")
	_check(ways.size() == 1 and "American Cup" in ways[0], "how to unlock Empyrean S (%s)" % str(ways))
	ways = UnlockCatalog.how_to_unlock(UnlockCatalog.ELIMINATION_UNLOCK)
	_check(ways.size() == 1 and "Elimination" in ways[0], "Elimination route listed (%s)" % str(ways))
	ways = UnlockCatalog.how_to_unlock("afterimage")
	_check(ways.size() == 1 and "Mirror" in ways[0], "how to unlock Afterimage (%s)" % str(ways))
	ways = UnlockCatalog.how_to_unlock("high_roller")
	_check(ways.size() == 1 and "200cc" in ways[0], "how to unlock High Roller (%s)" % str(ways))
	ways = UnlockCatalog.how_to_unlock("interceptor")
	_check(ways.size() == 1 and "rough draft" in ways[0], "how to unlock Interceptor (%s)" % str(ways))
	ways = UnlockCatalog.how_to_unlock("revenant")
	_check(ways.size() == 1 and "Fires of Nyiragongo" in ways[0], "how to unlock Revenant (%s)" % str(ways))
	_check(UnlockCatalog.how_to_unlock("v8_specter").is_empty(), "starters need no unlock")
	_check(UnlockCatalog.join_or(PackedStringArray(["A", "B", "C"])) == "A, B or C", "join_or")


func _test_profile_unlocks() -> void:
	_current = "profile"
	print("- profile unlocks")
	var p := _fresh_profile()
	_check(p.available_vehicles().size() == 3, "a new profile has the three starters")
	_check(not p.has_vehicle("cipher_evo"), "Cipher EVO starts locked")
	p.set_selected_vehicle("cipher_evo")
	_check(p.selected_vehicle == PlayerProfile.DEFAULT_VEHICLE, "a locked car can't be selected")
	_check(p.unlock_vehicle("cipher_evo"), "unlocking is new the first time")
	_check(not p.unlock_vehicle("cipher_evo"), "and not the second")
	_check(not p.unlock_vehicle("no_such_car") and not p.unlock_vehicle("v8_specter"), "unknown / starter cars aren't unlocked")
	p.set_selected_vehicle("cipher_evo")
	_check(p.selected_vehicle == "cipher_evo", "an unlocked car can be selected")
	var r := p.record_time_trial(TRACK, 100.0, true, false)
	_check(bool(r.best) and bool(p.time_trial(TRACK).rival), "Time Trial best and rival recorded")
	_check(not bool(p.record_time_trial(TRACK, 105.0, false, false).best), "a slower time isn't a best")
	_check(bool(p.time_trial(TRACK).rival), "rival stays beaten")
	p.save()
	var again := PlayerProfile.reload_from_disk()
	_check(again.has_vehicle("cipher_evo") and again.selected_vehicle == "cipher_evo", "unlocks survive a reload")
	_check(is_equal_approx(float(again.time_trial(TRACK).best), 100.0), "Time Trial best survives a reload")
	PlayerProfile.unlock_all_for_tests(true)
	_check(again.has_vehicle("orbiter"), "tests can unlock everything")
	PlayerProfile.unlock_all_for_tests(false)


func _test_old_save() -> void:
	_current = "old save"
	print("- older saves lose the locked cars")
	PlayerProfile.delete_save()
	var old := {"version": PlayerProfile.SAVE_VERSION, "coins": 50, "owned": [], "vehicle": "valkyrie_r"}
	SaveUtil.write_atomic(PlayerProfile.save_path, JSON.stringify(old))
	var p := PlayerProfile.reload_from_disk()
	_check(p.available_vehicles().size() == 3, "only the starters")
	_check(p.selected_vehicle == PlayerProfile.DEFAULT_VEHICLE, "a locked selection falls back to the default car")
	_check(p.coins == 50, "the rest of the save is kept")


func _test_signature_items() -> void:
	_current = "signature"
	print("- signature paint and animated underglow")
	var p := _fresh_profile()
	var paint := CosmeticCatalog.by_id("sig_paint_empyrean_s")
	var glow := CosmeticCatalog.by_id("sig_glow_empyrean_s")
	_check(paint != null and glow != null and paint.unlock_only and glow.is_animated(), "items exist")
	_check(not p.owns(paint.id) and not paint.is_free(), "not owned from the start")
	var q := _fresh_profile()
	var sb_glow := CosmeticCatalog.by_id("sig_glow_switchback")
	q.add_coins(5000)
	_check(not q.can_buy(sb_glow) and not q.newly_affordable(0).has(sb_glow), "a car's shop glow needs that car unlocked")
	q.unlock_vehicle("switchback")
	_check(q.can_buy(sb_glow) and q.newly_affordable(0).has(sb_glow), "and is for sale once it is")
	p = _fresh_profile()
	p.coins = 99999
	_check(not p.can_buy(paint) and not p.buy(paint), "can't be bought")
	_check(p.grant_item(paint.id) and not p.grant_item(paint.id), "granted once")
	_check(not p.equip("v8_specter", paint), "only its own car can wear it")
	p.unlock_vehicle("empyrean_s")
	_check(p.equip("empyrean_s", paint) and p.equipped_item("empyrean_s", CosmeticItem.Category.PAINT) == paint, "equipped on its car")
	_check(not p.newly_affordable(0).has(paint), "never 'newly affordable'")
	# Animated underglow on a car.
	p.grant_item(glow.id)
	p.equip("empyrean_s", glow)
	var car := (load("res://scenes/vehicles/placeholder_car.tscn") as PackedScene).instantiate() as VehicleController
	root.add_child(car)
	car.freeze = true
	VehicleCosmetics.apply(car, VehicleCatalog.by_id("empyrean_s"), p.loadout_for("empyrean_s"), "TEST")
	var pulse := car.find_child("UnderglowPulse", true, false) as UnderglowPulse
	_check(pulse != null, "animated underglow adds a pulse")
	if pulse != null:
		GameSettings.reduced_flashing = false
		var a := pulse.mix_at(0.0)
		var b := pulse.mix_at(UnderglowPulse.PERIOD * 0.5)
		_check(a < 0.05 and b > 0.95, "it moves between its two colours (%.2f, %.2f)" % [a, b])
		GameSettings.reduced_flashing = true
		_check(is_equal_approx(pulse.mix_at(0.0), pulse.mix_at(0.4)), "Reduced Flashing holds it steady")
		GameSettings.reduced_flashing = false
		pulse.apply_mix(1.0)
		_check(pulse.current_color().is_equal_approx(glow.color2), "colour 2 applied")
	# Signature paint keeps its own finish.
	var body_mats := car.find_children("*", "MeshInstance3D", true, false)
	_check(not body_mats.is_empty(), "car dressed")
	car.free()


func _test_ghost_data() -> void:
	_current = "ghost data"
	print("- ghost recording and playback")
	var g := _fake_ghost("orbiter", 100.0, 80.0)
	_check(g.frame_count() == 3001, "frames (%d)" % g.frame_count())
	_check(is_equal_approx(g.time_scale(), 1.25), "plays 1.25x faster to finish at the target")
	var s: Dictionary = g.sample(40.0) # = 50 s of recording
	_check(absf((s.transform as Transform3D).origin.z + 500.0) < 0.01, "sample is time-scaled (%s)" % str((s.transform as Transform3D).origin))
	var mid: Dictionary = g.sample(1.0 / 60.0 / 1.25)
	_check(absf((mid.transform as Transform3D).origin.z + 0.1667) < 0.01, "interpolates between frames")
	_check(bool(g.sample(80.0).done) and not bool(g.sample(79.0).done), "done at the target time")
	_check(is_equal_approx(g.gate_time(0), 8.0), "gate times are scaled too")
	_check(bool(g.sample(17.0).boosting) and not bool(g.sample(10.0).boosting), "records when it was boosting")
	_check(g.gate_time(99) < 0.0, "no such gate")
	_check(is_equal_approx(g.finish_time(), 80.0), "finish time = target")
	g.target_time = 0.0
	_check(is_equal_approx(g.finish_time(), 100.0) and is_equal_approx(g.time_scale(), 1.0), "no target: as recorded")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tt_tmp/"))
	var path := "user://test_tt_tmp/round.res"
	_check(ResourceSaver.save(g, path) == OK, "saves")
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GhostData
	_check(back != null and back.frames.size() == g.frames.size() and back.vehicle_id == "orbiter", "loads back")


# --- menus ------------------------------------------------------------------------

func _test_menus() -> void:
	_current = "menus"
	print("- menus")
	_fresh_profile()
	var menu := (load(MAIN_MENU) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var texts := menu.button_texts()
	_check(not texts.has("Continue Grand Prix"), "no Continue Grand Prix")
	_check(texts.find("Time Trial") == texts.find("Versus") + 1, "Time Trial right below Versus (%s)" % ", ".join(texts))
	menu.queue_free()
	await process_frame

	GameSession.setup_mode = RaceConfig.Mode.TIME_TRIAL
	var setup := (load(RACE_SETUP) as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await process_frame
	await process_frame
	_check(setup.is_time_trial() and setup.layout.title_label.text.contains("TIME TRIAL"), "TIME TRIAL setup")
	_check(not setup._cc.is_visible_in_tree(), "no CC row")
	_check(not setup._weapons.is_visible_in_tree() and not setup._laps.is_visible_in_tree()
			and not setup._difficulty.is_visible_in_tree(), "no items / laps / difficulty rows")
	_check(setup.summary_text().contains("3 LAPS") and setup.summary_text().contains("150CC"), "summary: 3 laps, 150cc")
	_check(setup.cc() == 150 and setup.showcase.cc == 150, "the top-speed card is for 150cc")
	# Every car in list order; locked ones are a mystery and can't be raced.
	setup.select_vehicle(0)
	var picked: Array[String] = []
	for i in VehicleCatalog.all().size():
		picked.append(setup.vehicle().id)
		setup.showcase.step(1)
	var order: Array[String] = []
	for v in VehicleCatalog.all():
		order.append(v.id)
	_check(picked == order, "steps through all eight cars, starters first (%s)" % str(picked))
	setup.select_vehicle(VehicleCatalog.index_of("orbiter"))
	_check(setup.vehicle_locked() and setup.showcase.preview.is_mystery_shown() and setup.showcase.lock_banner.visible,
			"a locked car shows as ? with the LOCKED plate")
	_check(setup._start.disabled and PlayerProfile.get_profile().selected_vehicle != "orbiter", "and can't be started with")
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	setup.start()
	_check(GameSession.setup_mode == RaceConfig.Mode.VERSUS, "start does nothing on a locked car")
	setup.select_vehicle(VehicleCatalog.index_of("riviera_88"))
	_check(not setup._start.disabled and not setup.showcase.preview.is_mystery_shown(), "a starter can be started")
	setup.start()
	_check(GameSession.setup_mode == RaceConfig.Mode.TIME_TRIAL and GameSession.series == null, "on to the tracks")
	setup.queue_free()
	await process_frame

	_save_fake_ghosts(90.0, 70.0)
	var tracks := (load(TRACK_SELECT) as PackedScene).instantiate() as TrackSelect
	root.add_child(tracks)
	await process_frame
	_check(tracks.random_card == null, "no RANDOM card")
	_check(tracks.track_names.size() == 16 and tracks.track_names.has("Vegas Overdrive"), "every Time Trial track (%d)" % tracks.track_names.size())
	var card := tracks.cards[tracks.track_names.find(TRACK)] as TrackCard
	_check(card.rival_label != null and card.rival_label.text.contains("Revenant"), "the card names the rival")
	tracks.pick_track(TRACK)
	await process_frame
	var picker := tracks.ghost_picker
	_check(picker != null, "picking a track opens the ghost picker")
	if picker != null:
		_check(Array(picker.kinds) == [TimeTrialCatalog.Ghost.RIVAL, TimeTrialCatalog.Ghost.NONE],
				"rival and no ghost before the rival is beaten (%s)" % str(picker.kinds))
		_check(picker.buttons[0].text.contains("1:30.00"), "rival button shows its time (%s)" % picker.buttons[0].text)
		_check(picker.default_index() == 0, "opens on the rival")
		GameSession.current = null
		picker.choose(TimeTrialCatalog.Ghost.RIVAL)
		var c := GameSession.current
		_check(c != null and c.is_time_trial() and c.track_name == TRACK and c.ghost_kind == TimeTrialCatalog.Ghost.RIVAL
				and c.total_laps == 3 and not c.weapons_enabled and c.cc == 150 and not c.mirrored, "starts a 3-lap, no-item TT")
		picker.close()
	PlayerProfile.get_profile().record_time_trial(TRACK, 85.0, true, false)
	var p2 := GhostPicker.new(TRACK)
	tracks.add_child(p2)
	await process_frame
	_check(p2.kinds.has(TimeTrialCatalog.Ghost.EXPERT) and p2.default_index() == p2.kinds.find(TimeTrialCatalog.Ghost.EXPERT),
			"expert offered once the rival is beaten, and picked by default")
	p2.queue_free()
	tracks.queue_free()
	await process_frame
	_fresh_profile()


func _test_garage() -> void:
	_current = "garage"
	print("- garage")
	_fresh_profile()
	var garage := (load(GARAGE) as PackedScene).instantiate() as Garage
	root.add_child(garage)
	await process_frame
	garage.select_vehicle(VehicleCatalog.index_of("orbiter"))
	_check(garage.vehicle_locked() and garage.showcase.lock_banner.visible, "a locked car shows the lock banner")
	_check(garage.showcase.lock_label.text.contains("Asia Cup"), "with how to unlock it")
	_check(garage.showcase.preview.mystery and garage.showcase.preview.is_mystery_shown(), "shown as a silhouette with a ?")
	_check(garage.showcase._name.text == "???" and not garage.showcase._stats_row.visible, "name and stats hidden")
	var dark := true
	for mi: MeshInstance3D in garage.showcase.preview.car.find_children("*", "MeshInstance3D", true, false):
		if mi.visible and mi.material_override != VehiclePreview._silhouette_material():
			dark = false
	_check(dark, "every car mesh is the silhouette")
	_check(garage.showcase.dots[VehicleCatalog.index_of("orbiter")].tooltip_text == "???", "its dot doesn't give the name away")
	_check(PlayerProfile.get_profile().selected_vehicle != "orbiter", "and isn't selected")
	PlayerProfile.get_profile().coins = 5000
	_check(not garage.buy(CosmeticCatalog.by_id("paint_crimson")), "can't buy paint for it")
	garage.select_vehicle(VehicleCatalog.index_of("aurora_gt"))
	_check(not garage.showcase.lock_banner.visible and PlayerProfile.get_profile().selected_vehicle == "aurora_gt", "a starter is fine")
	_check(not garage.showcase.preview.is_mystery_shown() and garage.showcase._name.text == "AURORA GT", "and shown as itself")
	var restored := true
	for mi: MeshInstance3D in garage.showcase.preview.car.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == VehiclePreview._silhouette_material():
			restored = false
	_check(restored, "its paint is back")
	var strip := MultiplayerCars.ThumbStrip.new(Color.WHITE)
	_check(strip.is_mystery(VehicleCatalog.index_of("orbiter")) and not strip.is_mystery(VehicleCatalog.index_of("v8_specter")),
			"split-screen car strip draws locked cars as ?")
	strip.free()
	garage.queue_free()
	await process_frame


# --- races ------------------------------------------------------------------------

## A Time Trial of TRACK, raced on the test circuit (fast to build).
func _start_tt(ghost: int, vehicle_id: String = "v8_specter") -> RaceManager:
	var config := RaceConfig.time_trial(TRACK, ghost, vehicle_id)
	config.track_scene = load("res://scenes/tracks/test_circuit.tscn") as PackedScene
	config.total_laps = 9 # forced back to 3
	config.weapons_enabled = true # forced off
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	return race


func _finish(race: RaceManager, at: float) -> void:
	race.race_time = at
	var p := race.player
	p.lap = p.total_laps
	p.next_checkpoint = 0
	race._on_checkpoint_crossed(0, p.vehicle)


func _end(race: RaceManager) -> void:
	paused = false
	race.queue_free()
	await process_frame
	await process_frame


func _test_race() -> void:
	_current = "race"
	print("- a Time Trial race")
	_fresh_profile()
	_save_fake_ghosts(90.0, 70.0)
	var race := await _start_tt(TimeTrialCatalog.Ghost.RIVAL)
	_check(race.state == RaceManager.State.RACING, "the race starts")
	_check(race.racers.size() == 1 and race.player != null, "just you")
	_check(race.total_laps == 3 and not race.weapons_enabled and race.weapon_manager.crates.is_empty(), "3 laps, no items, no crates")
	_check(race.coins.collected == 0 and race.coins.get_child_count() == 0, "no coins")
	var inv := race.player.vehicle.inventory
	_check(inv.current() != null and inv.current().id == &"triple_nitro" and inv.charges[inv.selected] == 3,
			"you start with one Triple Nitro")
	_check(race.combat_enabled() and race.race_hud.items.visible, "the item slot shows")
	_check(race.player.vehicle.recovery.keep_items, "recoveries don't take it")
	var speed_before := race.player.vehicle.is_boosting()
	inv.request_use()
	await physics_frame
	_check(not speed_before and race.player.vehicle.is_boosting() and inv.charges[inv.selected] == 2, "a Nitro fires (2 left)")
	_check(race.ghost != null and race.ghost.car != null, "the ghost is on track")
	if race.ghost != null:
		var g := race.ghost
		_check(not g.car.is_in_group(VehicleController.GROUP) and g.car.collision_layer == 0 and g.car.freeze,
				"the ghost can't be hit or targeted")
		_check(g.label_text() == "RIVAL · REVENANT", "tag (%s)" % g.label_text())
		var ok_mats := g.car.find_children("*", "MeshInstance3D", true, false).all(
				func(m: Node) -> bool: return (m as MeshInstance3D).material_override == g.material or not (m as Node3D).is_visible_in_tree())
		_check(ok_mats, "drawn as a hologram")
		for i in 30:
			await physics_frame
		_check(absf(g.time - race.race_time) < 0.05, "follows race time")
	_check(race.ghost_recorder != null, "your run is recorded")
	for i in 40:
		await physics_frame
	_check(race.ghost_recorder.data.frame_count() > 0, "frames recorded (%d)" % race.ghost_recorder.data.frame_count())
	# The HUD: no standings or position, and no ghost time gap (the minimap
	# dot shows where it is).
	_check(not race.race_hud.info.visible and not race.race_hud.standings.visible, "no position / standings")
	_check(race.race_hud.find_child("GhostSplit", true, false) == null, "no ghost time-gap readout")
	# Beat the rival, not the expert.
	_finish(race, 80.0)
	await process_frame
	var p := PlayerProfile.get_profile()
	_check(race.time_trial_summary.get("beat_ghost", false), "rival beaten")
	_check(p.has_vehicle("revenant") and (race.unlocks.vehicles as Array).has("revenant"), "Revenant unlocked")
	_check(not p.owns("sig_paint_revenant"), "expert reward not yet")
	_check(bool(p.time_trial(TRACK).rival) and is_equal_approx(float(p.time_trial(TRACK).best), 80.0), "result recorded")
	var mine := TimeTrialCatalog.load_ghost(TRACK, TimeTrialCatalog.Ghost.BEST)
	_check(mine != null and is_equal_approx(mine.recorded_time, 80.0) and mine.frame_count() > 0, "a new best saves your ghost")
	_check(PlayerProfile.reload_from_disk().has_vehicle("revenant"), "and saved")
	var cards: Array = race.unlocks.get("cards", [])
	_check(cards.size() == 1 and str(cards[0].vehicle) == "revenant", "one CAR UNLOCKED card")
	if cards.size() == 1:
		_check(str(cards[0].line1) == TRACK, "card line 1 is the track (%s)" % cards[0].line1)
		_check(str(cards[0].line2).begins_with("Rival ghost beaten by ") and str(cards[0].line2).ends_with(" s"),
				"card line 2 is the margin (%s)" % cards[0].line2)
	await _test_unlock_screen(race)
	race.race_hud.results.open(race)
	var results := race.race_hud.results as NeonResultsScreen
	_check(results.tt_panel.visible and results.time_trial_text().contains("NEW CAR UNLOCKED"), "results show the unlock")
	_check(results.menu_button.text == "Change track", "Change track button")
	_check(results.mode_text() == "TIME TRIAL · RIVAL", "mode line (%s)" % results.mode_text())
	await _end(race)

	# Beat the expert: the signature paint.
	race = await _start_tt(TimeTrialCatalog.Ghost.EXPERT, "revenant")
	_check(race.ghost != null and race.ghost.kind == TimeTrialCatalog.Ghost.EXPERT, "expert ghost")
	_finish(race, 60.0)
	await process_frame
	p = PlayerProfile.get_profile()
	_check(p.owns("sig_paint_revenant") and (race.unlocks.items as Array).has("sig_paint_revenant"), "signature paint won")
	_check(bool(p.time_trial(TRACK).expert), "expert recorded")
	await _end(race)

	# A slow run: nothing new.
	race = await _start_tt(TimeTrialCatalog.Ghost.RIVAL)
	_finish(race, 200.0)
	await process_frame
	_check(not race.time_trial_summary.get("beat_ghost", true) and race.unlocks.is_empty(), "a slow run unlocks nothing")
	_check(float(race.time_trial_summary.delta) > 0.0, "positive gap")
	await _end(race)

	# Your best ghost from a real recorded run.
	var best := _fake_ghost("v8_specter", 50.0, 0.0)
	_check(RaceManager.save_player_ghost(best), "your best ghost saves")
	var loaded := TimeTrialCatalog.load_ghost(TRACK, TimeTrialCatalog.Ghost.BEST)
	_check(loaded != null and is_equal_approx(loaded.finish_time(), 50.0), "and loads as YOUR BEST")
	race = await _start_tt(TimeTrialCatalog.Ghost.NONE)
	_check(race.ghost == null, "No Ghost: no ghost")
	await _end(race)


func _test_unlock_routes() -> void:
	_current = "routes"
	print("- Grand Prix, Elimination, Mirror and 200cc unlocks")
	_fresh_profile()
	# Elimination win.
	var config := RaceConfig.new()
	config.mode = RaceConfig.Mode.ELIMINATION
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	var p := race.player
	p.lap = p.total_laps
	p.next_checkpoint = 0
	race._on_checkpoint_crossed(0, p.vehicle)
	await process_frame
	_check(p.finish_position == 1, "player won")
	_check(PlayerProfile.get_profile().has_vehicle(UnlockCatalog.ELIMINATION_UNLOCK), "Elimination win unlocks %s" % UnlockCatalog.ELIMINATION_UNLOCK)
	_check(race.reward_summary.has("unlocks") and not (race.reward_summary.unlocks.lines as Array).is_empty(), "and says so")
	race.race_hud.results.open(race)
	_check((race.race_hud.results as NeonResultsScreen).unlock_label.visible, "unlock line on the results")
	await _end(race)
	# Grand Prix win (one-race cup made up for the test).
	_fresh_profile()
	var cup := (GrandPrixData.all_cups()[2] as GrandPrixData).duplicate() as GrandPrixData
	cup.track_names = PackedStringArray(["Test Circuit"])
	cup.track_scenes = PackedStringArray(["res://scenes/tracks/test_circuit.tscn"])
	var c := Championship.create(cup, "normal", false, load("res://resources/racers/rival_roster.tres") as RivalRoster, "v8_specter")
	race = (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = c.make_race_config()
	root.add_child(race)
	race.camera.save_preference = false
	frames = 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	p = race.player
	p.lap = p.total_laps
	p.next_checkpoint = 0
	race._on_checkpoint_crossed(0, p.vehicle)
	await process_frame
	var want := UnlockCatalog.cup_unlock(cup.id)
	_check(c.is_complete() and PlayerProfile.get_profile().has_vehicle(want), "%s win unlocks %s" % [cup.display_name, want])
	_check(not PlayerProfile.get_profile().has_vehicle(UnlockCatalog.TOP_CC_WIN_UNLOCK)
			and not PlayerProfile.get_profile().has_vehicle(UnlockCatalog.MIRROR_PODIUM_UNLOCK), "a 100cc forward win gives no race-route car")
	await _end(race)
	Championship.clear_save()

	# Mirror at 200cc, won: the Mirror podium car and the 200cc car.
	_fresh_profile()
	config = RaceConfig.new()
	config.mode = RaceConfig.Mode.VERSUS
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.mirrored = true
	config.cc = 200
	race = await _race_to_finish(config, [0])
	var prof := PlayerProfile.get_profile()
	_check(prof.has_vehicle(UnlockCatalog.MIRROR_PODIUM_UNLOCK) and prof.has_vehicle(UnlockCatalog.TOP_CC_WIN_UNLOCK),
			"a Mirror 200cc win unlocks both (%s)" % str(race.unlocks.get("vehicles", [])))
	var cards: Array = race.unlocks.get("cards", [])
	_check(cards.size() == 2 and str(cards[0].line2) == "Finished P1" and str(cards[1].line2) == "Won at 200cc",
			"one card each (%s)" % str(cards))
	_check(PlayerProfile.reload_from_disk().has_vehicle(UnlockCatalog.TOP_CC_WIN_UNLOCK), "and saved")
	await _end(race)

	# Split screen: player 2 wins a one-race cup at 200cc Mirror; every route counts.
	_fresh_profile()
	c = Championship.create(cup, "normal", false, load("res://resources/racers/rival_roster.tres") as RivalRoster, "v8_specter",
			PackedInt32Array([-1, 0]), PackedStringArray(["v8_specter", "aurora_gt"]), true, 200, true)
	race = await _race_to_finish(c.make_race_config(), [1, 0])
	prof = PlayerProfile.reload_from_disk()
	_check(race.is_multiplayer() and race.best_human_finish() == 1, "split screen, player 2 first")
	_check(prof.has_vehicle(want), "a split-screen cup win unlocks %s" % want)
	_check(prof.has_vehicle(UnlockCatalog.MIRROR_PODIUM_UNLOCK) and prof.has_vehicle(UnlockCatalog.TOP_CC_WIN_UNLOCK),
			"and the Mirror / 200cc cars, saved")
	await _end(race)
	Championship.clear_save()

	# Split-screen Elimination win.
	_fresh_profile()
	config = RaceConfig.new()
	config.mode = RaceConfig.Mode.ELIMINATION
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.player_devices = PackedInt32Array([-1, 0])
	config.player_vehicle_ids = PackedStringArray(["v8_specter", "aurora_gt"])
	config.player_plates = PackedStringArray(["", "PL-2"])
	race = await _race_to_finish(config, [1, 0])
	_check(PlayerProfile.reload_from_disk().has_vehicle(UnlockCatalog.ELIMINATION_UNLOCK), "a split-screen Elimination win unlocks it")
	await _end(race)
	_fresh_profile()


## A full free-drive lap of Vegas Overdrive unlocks Interceptor; the Test
## Circuit doesn't.
func _test_practice_lap() -> void:
	_current = "practice lap"
	print("- Practice lap unlock")
	var before := GameSession.practice_track
	for track_name in ["Test Circuit", UnlockCatalog.PRACTICE_LAP_TRACK]:
		_fresh_profile()
		CarUnlockScreen.instant = false
		GameSession.practice_track = track_name
		var drive := (load("res://scenes/free_drive.tscn") as PackedScene).instantiate()
		root.add_child(drive)
		await process_frame
		var track := drive.get("track") as TrackCircuit
		var car := drive.get("car") as VehicleController
		car.recovery.total_progress = track.spawn_distance_behind_line + track.length + 1.0
		await process_frame
		var hud := drive.get("hud") as PrototypeHUD
		var screens := drive.get_children().filter(func(n: Node) -> bool: return n is CarUnlockScreen)
		var owned := PlayerProfile.reload_from_disk().has_vehicle(UnlockCatalog.PRACTICE_LAP_UNLOCK)
		_check(hud.get_lap_count() == 1, "%s: a lap counted" % track_name)
		if track_name == UnlockCatalog.PRACTICE_LAP_TRACK:
			_check(owned, "a Vegas lap unlocks Interceptor, saved")
			_check(screens.size() == 1 and paused, "the game pauses on the CAR UNLOCKED screen")
			if screens.size() == 1:
				var screen := screens[0] as CarUnlockScreen
				await process_frame
				_check(screen.line1_label.text == "Vegas Overdrive · Practice"
						and screen.line2_label.text.begins_with("Lap completed in "), "with where and how (%s / %s)"
						% [screen.line1_label.text, screen.line2_label.text])
				screen.continue_button.pressed.emit()
				await process_frame
				_check(not paused, "Continue drives on")
		else:
			_check(not owned and screens.is_empty(), "a Test Circuit lap unlocks nothing")
		paused = false
		CarUnlockScreen.instant = true
		drive.queue_free()
		await process_frame
		await process_frame
	GameSession.practice_track = before
	_fresh_profile()


## Starts a race and finishes the humans (RaceManager.players indexes) in
## `order`, first place first.
func _race_to_finish(config: RaceConfig, order: Array) -> RaceManager:
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	if race.camera != null:
		race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	for i: int in order:
		var h: RaceProgress = race.players[i]
		h.lap = h.total_laps
		h.next_checkpoint = 0
		race._on_checkpoint_crossed(0, h.vehicle)
	await process_frame
	return race


## Real baked ghosts (skipped with a note until tests/tools/bake_ghosts.gd has run).
func _test_baked_ghosts() -> void:
	_current = "baked"
	print("- baked ghosts")
	TimeTrialCatalog.ghost_dir = TimeTrialCatalog.GHOST_DIR
	var missing: PackedStringArray = []
	var bad: PackedStringArray = []
	for t in TimeTrialCatalog.tracks():
		var rival := TimeTrialCatalog.load_ghost(t, TimeTrialCatalog.Ghost.RIVAL)
		var expert := TimeTrialCatalog.load_ghost(t, TimeTrialCatalog.Ghost.EXPERT)
		if rival == null or expert == null:
			missing.append(t)
			continue
		if rival.vehicle_id != TimeTrialCatalog.rival_vehicle(t) or expert.vehicle_id != rival.vehicle_id:
			bad.append(t + " (car)")
		elif not (expert.finish_time() < rival.finish_time()):
			bad.append(t + " (expert not faster)")
		elif rival.checkpoint_times.is_empty() or rival.frame_count() < 100:
			bad.append(t + " (empty)")
	_check(missing.is_empty(), "every track has both ghosts baked (missing: %s)" % ", ".join(missing))
	_check(bad.is_empty(), "baked ghosts look right (%s)" % ", ".join(bad))
	TimeTrialCatalog.ghost_dir = TEST_GHOSTS


## The CAR UNLOCKED screen for this race's card: name and lines shown,
## Continue opens the results, View in Garage selects the car.
func _unlock_screens(race: RaceManager) -> Array:
	return race.get_children().filter(func(n: Node) -> bool: return n is CarUnlockScreen)


func _test_unlock_screen(race: RaceManager) -> void:
	CarUnlockScreen.instant = false
	var results := race.race_hud.results
	results.open(race)
	await process_frame
	_check(results.visible and _unlock_screens(race).is_empty(),
			"the results come first, with no CAR UNLOCKED screen yet")
	# A results button opens the CAR UNLOCKED screen; its Continue then does
	# what the button does.
	var done := [0]
	results.leave(func() -> void: done[0] += 1)
	var found := _unlock_screens(race)
	var screen: CarUnlockScreen = found[0] if not found.is_empty() else null
	_check(screen != null and done[0] == 0, "leaving the results opens the CAR UNLOCKED screen first")
	if screen == null:
		CarUnlockScreen.instant = true
		return
	await process_frame
	await process_frame
	_check(screen.name_label.text == "REVENANT" or screen.name_label.text == VehicleCatalog.by_id("revenant").display_name.to_upper(),
			"it names the car (%s)" % screen.name_label.text)
	_check(screen.line1_label.text == TRACK and screen.line2_label.text.begins_with("Rival ghost beaten"), "with where and how")
	_check(screen.continue_button.has_focus(), "Continue has focus")
	screen.continue_button.pressed.emit()
	await process_frame
	_check(done[0] == 1, "Continue carries out the results button")
	_check(not is_instance_valid(screen) or screen.is_queued_for_deletion(), "and closes the screen")
	results.leave(func() -> void: done[0] += 1)
	_check(done[0] == 2 and _unlock_screens(race).all(
			func(n: Node) -> bool: return n.is_queued_for_deletion()), "shown once per race")
	# View in Garage.
	race.remove_meta(&"unlocks_shown")
	PlayerProfile.get_profile().set_selected_vehicle("v8_specter")
	var again := CarUnlockScreen.show_then(race, func() -> void: pass)
	await process_frame
	CarUnlockScreen.last_scene = ""
	again.garage_button.pressed.emit()
	_check(CarUnlockScreen.last_scene == GameSession.GARAGE_SCENE, "View in Garage goes to the garage")
	_check(PlayerProfile.get_profile().selected_vehicle == "revenant", "with the new car selected")
	_check(GameSession.garage_return == GameSession.MAIN_MENU_SCENE, "and Back from there goes to the main menu")
	again.queue_free()
	await process_frame
	CarUnlockScreen.instant = true
