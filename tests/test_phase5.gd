extends SceneTree
## Phase 5 headless checks: cosmetics catalogue, player profile (coins,
## shop, equip, plate, records, save / reload, corrupt saves), race rewards,
## the eight vehicles, settings and rebinding, HUD scale, cosmetics on the
## car, track coins, rewards paid once (also in a Grand Prix), and the main
## menu, race setup, garage and settings screens. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_phase5.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"
const ROSTER := "res://resources/racers/rival_roster.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_phase5_profile.json"
	GameSettings.path = "user://test_phase5_settings.cfg"
	Championship.save_path = "user://test_phase5_gp.json"
	_run_all.call_deferred()


func _run_all() -> void:
	_fresh()
	GameSession.scene_changes_enabled = false
	_test_catalog()
	_test_profile()
	_test_profile_files()
	_test_rewards()
	_test_vehicles()
	_test_settings()
	await _test_hud_scaler()
	await _test_cosmetics_on_car()
	await _test_menus()
	await _run("vehicle, plates and coins in a race", _test_race_coins, _config(), false)
	await _run("settings in a race", _test_race_settings, _config(), false)
	var versus := _config()
	versus.total_laps = 1
	await _run("rewards after a race", _test_race_rewards, versus, true)
	await _test_grand_prix_rewards()
	_fresh()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _fresh() -> void:
	PlayerProfile.delete_save()
	SaveUtil.remove(GameSettings.path)
	GameSettings.load_settings()
	GameSettings.reset_bindings()
	Championship.clear_save()
	GameSession.current = null


func _config() -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.rival_plates = RaceConfig.random_plates(7, PlayerProfile.DEFAULT_PLATE)
	return config


func _run(test_name: String, test: Callable, config: RaceConfig, autopilot: bool) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = autopilot
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 300:
		await physics_frame
		frames += 1
	await test.call(race)
	paused = false
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _item(id: String) -> CosmeticItem:
	return CosmeticCatalog.by_id(id)


# --- pure logic ----------------------------------------------------------------

func _test_catalog() -> void:
	_current = "catalogue"
	print("- cosmetics catalogue (no scene)")
	var ids := {}
	var unique := true
	for item in CosmeticCatalog.items():
		unique = unique and not ids.has(item.id)
		ids[item.id] = true
	_check(unique, "item ids are unique")
	for c in CosmeticItem.Category.values():
		var items := CosmeticCatalog.in_category(c)
		var free := items.filter(func(i: CosmeticItem) -> bool: return i.is_free()).size()
		_check(items.size() >= 3 and free == 1, "%s: %d items, one free starter" % [CosmeticItem.CATEGORY_NAMES[c], items.size()])
	_check(_item("paint_crimson").price == 100 and _item("frame_chrome").price == 250
			and _item("wheels_chrome").price == 500 and _item("finish_chrome").price == 1000, "GDD 9.4 target prices")


func _test_profile() -> void:
	_current = "profile"
	print("- profile, shop and records (no scene)")
	_fresh()
	var p := PlayerProfile.get_profile()
	_check(p.coins == 0 and p.owns("paint_factory") and p.owns("wheels_standard"), "new profile: no coins, free items owned")
	var crimson := _item("paint_crimson")
	_check(not p.buy(crimson) and not p.owns(crimson.id), "can't buy without enough coins")
	_check(not p.equip("v8_specter", crimson), "can't equip an item you don't own")
	p.add_coins(150)
	_check(p.buy(crimson) and p.coins == 50 and p.owns(crimson.id), "buying spends coins and keeps the item")
	_check(not p.buy(crimson) and p.coins == 50, "can't buy the same item twice")
	_check(p.equip("v8_specter", crimson) and p.equipped_item("v8_specter", CosmeticItem.Category.PAINT) == crimson,
			"equip on one vehicle")
	_check(p.equipped_item("aurora_gt", CosmeticItem.Category.PAINT).id == "paint_factory", "other vehicles keep their own look")
	_check(PlayerProfile.sanitize_plate("hello world!x") == "HELLO WO", "plate: upper case, allowed characters, 8 max")
	p.set_plate("neo-77")
	_check(p.plate_text == "NEO-77", "plate saved")
	var r1 := p.record_race_time("Test Circuit", 3, 200.0, 65.0)
	var r2 := p.record_race_time("Test Circuit", 3, 210.0, 64.0)
	_check(r1.race and r1.lap and not r2.race and r2.lap, "personal bests: race and lap tracked separately")
	p.add_coins(60) # 110 now
	var newly := p.newly_affordable(50)
	_check(newly.size() > 0 and newly.all(func(i: CosmeticItem) -> bool: return i.price > 50 and i.price <= 110),
			"newly affordable items (%d)" % newly.size())
	p.last_setup = {"laps": 4}
	p.set_selected_vehicle("orbiter")
	# "Restart the game": drop the in-memory profile and read the file again.
	var q := PlayerProfile.reload_from_disk()
	_check(q != p and q.coins == 110 and q.owns("paint_crimson"), "coins and purchases survive a restart")
	_check(q.equipped_item("v8_specter", CosmeticItem.Category.PAINT).id == "paint_crimson", "equipped items survive")
	_check(q.plate_text == "NEO-77" and q.selected_vehicle == "orbiter", "plate and selected vehicle survive")
	_check(float(q.best_for("Test Circuit", 3).race) == 200.0 and float(q.best_for("Test Circuit", 3).lap) == 64.0,
			"personal bests survive")
	_check(int(q.last_setup.laps) == 4, "race setup choices survive")


func _test_profile_files() -> void:
	_current = "save files"
	print("- save file safety (no scene)")
	_fresh()
	var file := FileAccess.open(PlayerProfile.save_path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var p := PlayerProfile.reload_from_disk()
	_check(p.coins == 0 and p.owns("paint_factory"), "a corrupt save falls back to a fresh profile")
	file = FileAccess.open(PlayerProfile.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "coins": 5000}))
	file.close()
	_check(PlayerProfile.reload_from_disk().coins == 0, "an unknown save version isn't misread")
	PlayerProfile.delete_save()
	var p2 := PlayerProfile.get_profile()
	p2.add_coins(42)
	p2.save()
	_check(FileAccess.file_exists(PlayerProfile.save_path) and not FileAccess.file_exists(PlayerProfile.save_path + ".tmp"),
			"atomic save leaves no temporary file")
	# A swap interrupted after writing the temp file: the temp file is used.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PlayerProfile.save_path),
			ProjectSettings.globalize_path(PlayerProfile.save_path + ".tmp"))
	_check(PlayerProfile.reload_from_disk().coins == 42, "an interrupted save is recovered from the temporary file")
	_fresh()


func _test_rewards() -> void:
	_current = "rewards"
	print("- race rewards (no scene)")
	_check(RaceRewards.compute(1, true, 7).total == 25 + 40 + 7, "win: 25 + 40 + track coins")
	_check(RaceRewards.compute(2, true, 0).total == 50, "second: 25 + 25")
	_check(RaceRewards.compute(3, true, 0).total == 40, "third: 25 + 15")
	_check(RaceRewards.compute(4, true, 0).total == 25, "fourth: completion only")
	_check(RaceRewards.compute(7, false, 5).total == 5, "eliminated: track coins only")
	_check(RaceRewards.compute(1, true, 0, true).total == 165, "Grand Prix winner: +100 on top")


func _test_vehicles() -> void:
	_current = "vehicles"
	print("- vehicles (no scene)")
	var all := VehicleCatalog.all()
	var names: Array[String] = []
	for v in all:
		names.append(v.display_name)
	_check(names == ["V8 Specter", "Aurora GT", "Empyrean S", "Nexus X", "Riviera 88", "Orbiter", "Valkyrie R", "Cipher EVO"],
			"the eight GDD vehicles (%s)" % [names])
	var base := VehicleCatalog.primary_stats(all[0].stats)
	var band_ok := true
	for v in all:
		var s := VehicleCatalog.primary_stats(v.stats)
		for i in 4:
			band_ok = band_ok and absf(s[i] / base[i] - 1.0) <= 0.15
	_check(band_ok, "every stat within 15% of the V8 Specter")
	var dominated: Array[String] = []
	for a in all:
		for b in all:
			if a == b:
				continue
			var sa := VehicleCatalog.primary_stats(a.stats)
			var sb := VehicleCatalog.primary_stats(b.stats)
			var all_ge := true
			var any_gt := false
			for i in 4:
				all_ge = all_ge and sa[i] >= sb[i]
				any_gt = any_gt or sa[i] > sb[i]
			if all_ge and any_gt:
				dominated.append("%s > %s" % [a.display_name, b.display_name])
	_check(dominated.is_empty(), "no vehicle is better in every stat (%s)" % [dominated])
	var top := all.duplicate()
	top.sort_custom(func(a: VehicleData, b: VehicleData) -> bool: return a.stats.top_speed > b.stats.top_speed)
	var accel := all.duplicate()
	accel.sort_custom(func(a: VehicleData, b: VehicleData) -> bool: return a.stats.acceleration > b.stats.acceleration)
	_check((top[0] as VehicleData).id == "empyrean_s" and (accel[0] as VehicleData).id == "nexus_x",
			"Empyrean fastest, Nexus quickest off the line (GDD 5.1 characters)")


func _test_settings() -> void:
	_current = "settings"
	print("- settings and rebinding (no scene)")
	_fresh()
	InputSetup.ensure_actions()
	GameSettings.hud_scale = 1.25
	GameSettings.reduced_flashing = true
	GameSettings.camera_shake = 0.0
	GameSettings.sfx_volume = 0.5
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	GameSettings.set_binding(&"use_weapon", key)
	_check(InputSetup.describe(&"use_weapon", true) == "J", "rebind replaces the keyboard key (%s)" % InputSetup.describe(&"use_weapon", true))
	_check(InputSetup.describe(&"use_weapon", false) == "A", "gamepad binding untouched")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	GameSettings.set_binding(&"use_weapon", pad)
	_check(GameSettings.save_settings(), "settings saved")
	# Restart: defaults come back, then the saved settings are applied.
	GameSettings.reset_values()
	for action in InputSetup.DEFAULTS:
		InputSetup.reset_action(action)
	GameSettings.load_settings()
	InputSetup.ensure_actions()
	_check(is_equal_approx(GameSettings.hud_scale, 1.25) and GameSettings.reduced_flashing
			and GameSettings.camera_shake == 0.0 and is_equal_approx(GameSettings.sfx_volume, 0.5), "display and audio settings survive a restart")
	_check(InputSetup.describe(&"use_weapon", true) == "J" and InputSetup.describe(&"use_weapon", false) == "X",
			"rebinds survive a restart")
	var sfx := AudioServer.get_bus_index("SFX")
	_check(sfx >= 0 and AudioServer.get_bus_index("Music") >= 0, "Music and SFX buses exist")
	_check(sfx >= 0 and absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "SFX volume applied")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = -1.0
	_check(InputSetup.event_to_string(InputSetup.event_from_string("a:2:-1")) == "a:2:-1"
			and InputSetup.event_to_string(motion) == "a:2:-1", "stick directions round-trip")
	GameSettings.reset_bindings()
	_check(InputSetup.describe(&"use_weapon", true) == "Space" and InputSetup.describe(&"use_weapon", false) == "A",
			"reset restores the defaults")
	_fresh()


func _test_hud_scaler() -> void:
	_current = "hud scale"
	print("- HUD scale")
	var layer := CanvasLayer.new()
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(full)
	root.add_child(layer)
	await process_frame
	HudScaler.apply(layer, 1.25)
	await process_frame
	var view := root.get_visible_rect().size
	_check(is_equal_approx(layer.scale.x, 1.25), "layer scaled")
	_check(full.get_parent().name == "HudScaleRoot" and (full.size * 1.25).distance_to(view) < 2.0,
			"full-screen controls still fill the screen (%s x 1.25 vs %s)" % [full.size, view])
	layer.queue_free()
	await process_frame


func _test_cosmetics_on_car() -> void:
	_current = "cosmetics on the car"
	print("- cosmetics on the car")
	var holder := Node3D.new()
	root.add_child(holder)
	var car := (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	holder.add_child(car)
	var loadout := {
		CosmeticItem.Category.PAINT: _item("paint_acid"),
		CosmeticItem.Category.FINISH: _item("finish_chrome"),
		CosmeticItem.Category.STRIPES: _item("stripes_twin_white"),
		CosmeticItem.Category.DECAL: _item("decal_2199"),
		CosmeticItem.Category.WHEELS: _item("wheels_neon"),
		CosmeticItem.Category.PLATE_FRAME: _item("frame_gold"),
		CosmeticItem.Category.UNDERGLOW: _item("glow_magenta"),
		CosmeticItem.Category.EXHAUST: _item("exhaust_plasma"),
	}
	var riviera := VehicleCatalog.by_id("riviera_88")
	VehicleCosmetics.apply(car, riviera, loadout, "ABC-123")
	var paint := (car.get_node("Body/Model/Paint") as MeshInstance3D).material_override as StandardMaterial3D
	_check(paint != null and paint.metallic == 1.0 and paint.roughness < 0.1, "chrome finish on the paint")
	_check(VehicleCosmetics.model_design(car) == "riviera_88", "the Riviera's own model")
	var stripes := car.get_node_or_null("Body/Cosmetics/Stripes") as MeshInstance3D
	_check(stripes != null and stripes.mesh.get_surface_count() == 1, "twin stripes along the body")
	var decals := car.get_node("Body/Cosmetics").get_children().filter(func(n: Node) -> bool: return n is Label3D)
	_check(decals.size() == 2 and (decals[0] as Label3D).text == "2199", "a decal on each side")
	var rims := 0
	for w in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		if car.get_node_or_null(w + "/Pivot/Mesh/Rim") != null:
			rims += 1
	_check(rims == 4, "rims on all four wheels")
	_check(VehicleCosmetics.get_plate_text(car) == "ABC-123", "license plate text")
	var frame := (car.find_child("Plate", true, false).get_node("Frame") as MeshInstance3D).material_override as StandardMaterial3D
	_check(frame.albedo_color.is_equal_approx(_item("frame_gold").color), "gold plate frame")
	var glow := car.get_node_or_null("Body/Cosmetics/Underglow") as OmniLight3D
	_check(glow != null and glow.light_color.is_equal_approx(_item("glow_magenta").color), "magenta underglow")
	_check(car.get_node("Body/Cosmetics").get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Exhaust")).size() == 2,
			"exhaust tips")
	# Applying again (garage try-on) rebuilds instead of stacking.
	loadout[CosmeticItem.Category.STRIPES] = _item("stripes_none")
	loadout[CosmeticItem.Category.UNDERGLOW] = _item("glow_none")
	VehicleCosmetics.apply(car, VehicleCatalog.by_id("v8_specter"), loadout, "ABC-123")
	_check(car.get_node_or_null("Body/Cosmetics/Stripes") == null and car.get_node_or_null("Body/Cosmetics/Underglow") == null
			and VehicleCosmetics.model_design(car) == "v8_specter", "re-applying replaces the old look")
	holder.queue_free()
	await process_frame


func _test_menus() -> void:
	_current = "menus"
	print("- main menu, race setup, garage, settings")
	_fresh()
	var menu := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var labels: Array[String] = []
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).visible:
			labels.append((b as Button).text)
	for wanted in ["Versus", "Grand Prix", "Elimination", "Garage", "Settings", "Exit"]:
		_check(labels.has(wanted), "main menu has %s" % wanted)
	menu.queue_free()

	# Garage: buy, equip, plate, vehicle.
	var p := PlayerProfile.get_profile()
	p.add_coins(600)
	var garage := (load("res://scenes/menu/garage.tscn") as PackedScene).instantiate() as Garage
	root.add_child(garage)
	await process_frame
	_check(not garage.buy(_item("finish_chrome")) and p.coins == 600, "garage refuses an unaffordable item")
	_check(garage.buy(_item("wheels_gold")) and p.coins == 100 and p.equipped_item("v8_specter", CosmeticItem.Category.WHEELS).id == "wheels_gold",
			"buying in the garage spends coins and equips it")
	garage.try_on(_item("glow_lime"))
	_check(not p.owns("glow_lime") and garage._preview.car.get_node_or_null("Body/Cosmetics/Underglow") != null,
			"try-on shows an unowned item without buying it")
	garage.set_plate("zap!9")
	_check(p.plate_text == "ZAP9" and VehicleCosmetics.get_plate_text(garage._preview.car) == "ZAP9", "plate editor updates the profile and preview")
	garage.select_vehicle(VehicleCatalog.index_of("nexus_x"))
	_check(p.selected_vehicle == "nexus_x", "choosing a car in the garage selects it")
	_check(p.equipped_item("nexus_x", CosmeticItem.Category.WHEELS).id == "wheels_standard",
			"each car has its own loadout")
	garage.queue_free()

	# Race setup remembers choices.
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	var setup := (load("res://scenes/menu/race_setup.tscn") as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await process_frame
	_check(setup.vehicle().id == "nexus_x", "race setup starts on the selected car")
	setup.select_vehicle(VehicleCatalog.index_of("cipher_evo"))
	setup._laps.selected = 1
	setup._difficulty.selected = 0
	setup._weapons.button_pressed = false
	setup.start()
	var c := GameSession.current
	_check(c.vehicle_id == "cipher_evo" and c.total_laps == 2 and not c.weapons_enabled
			and c.difficulty.resource_path.ends_with("easy.tres"), "race config from the setup screen")
	setup.queue_free()
	PlayerProfile.reload_from_disk()
	var again := (load("res://scenes/menu/race_setup.tscn") as PackedScene).instantiate() as RaceSetup
	root.add_child(again)
	await process_frame
	_check(again._laps.selected == 1 and again._difficulty.selected == 0 and not again._weapons.button_pressed
			and again.vehicle().id == "cipher_evo", "previous choices are remembered after a restart")
	again.queue_free()

	# Settings: rebinding through the screen.
	var settings := (load("res://scenes/menu/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	root.add_child(settings)
	await process_frame
	settings.start_capture(&"reset_vehicle", true)
	_check(settings.is_capturing(), "waiting for a key")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C # already the camera key
	key.pressed = true
	settings.accept_capture(key)
	_check(InputSetup.describe(&"reset_vehicle", true) == "C", "reset rebound to C")
	_check(settings._message.text.contains("also used by Cycle camera"), "conflict noted (%s)" % settings._message.text)
	GameSettings.load_settings()
	_check(GameSettings.bindings.has("reset_vehicle"), "rebind saved")
	settings.start_capture(&"brake", false)
	for i in 400:
		await process_frame
		if not settings.is_capturing():
			break
	_check(not settings.is_capturing(), "capture times out")
	settings.queue_free()
	await process_frame
	_fresh()


# --- races -------------------------------------------------------------------------

func _test_race_coins(race: RaceManager) -> void:
	var me := race.player.vehicle
	_check(me.stats.top_speed == VehicleCatalog.by_id("v8_specter").stats.top_speed, "default vehicle: V8 Specter")
	_check(VehicleCosmetics.get_plate_text(me) == PlayerProfile.get_profile().plate_text, "player plate shown")
	var tech := race.racers.filter(func(r: RaceProgress) -> bool: return r.display_name == "The Technician")[0] as RaceProgress
	var tech_plate := VehicleCosmetics.get_plate_text(tech.vehicle)
	_check(tech_plate == race.config.rival_plates[0] and RegEx.create_from_string("^[A-Z]{3}-[0-9]{3}$").search(tech_plate) != null,
			"AI show the series' random plates (%s)" % tech_plate)
	var coins := race.coins
	_check(coins.coins().size() == 10 and coins.available_count() == 10, "10 coins per lap")
	var rival := race.racers.filter(func(r: RaceProgress) -> bool: return not r.is_player)[0].vehicle as VehicleController
	rival.teleport(Transform3D(rival.global_transform.basis, coins.coins()[0].global_position + Vector3.UP * 0.3))
	await _frames(10)
	_check(coins.collected == 0 and coins.coins()[0].visible, "AI cars don't take coins")
	var got := [0]
	coins.coin_collected.connect(func(_t: int) -> void: got[0] += 1)
	for i in 3:
		me.teleport(Transform3D(me.global_transform.basis, coins.coins()[i + 1].global_position + Vector3.UP * 0.3))
		await _frames(10)
	_check(coins.collected == 3 and got[0] == 3 and coins.available_count() == 7, "driving through coins collects them")
	_check(race.race_hud._coin_label.text == "COINS  3", "HUD coin counter")
	_place_away(race, me)
	await _frames(5)
	coins.respawn()
	await _frames(2)
	_check(coins.available_count() == 10, "coins come back each lap")
	coins.collected = TrackCoins.MAX_PER_RACE - 1
	me.teleport(Transform3D(me.global_transform.basis, coins.coins()[5].global_position + Vector3.UP * 0.3))
	await _frames(10)
	_check(coins.collected == TrackCoins.MAX_PER_RACE and coins.available_count() == 0, "30-coin cap reached: coins vanish")
	coins.respawn()
	_check(coins.available_count() == 0, "and don't come back")


func _place_away(race: RaceManager, car: VehicleController) -> void:
	car.teleport(race.track.get_safe_transform(100.0, 0.0))


func _test_race_settings(race: RaceManager) -> void:
	_check(race.get_node_or_null("SpeedBlur") == null, "motion blur off by default")
	_check(race.race_hud.get_node_or_null("HudScaleRoot") != null and is_equal_approx(race.race_hud.scale.x, 1.0),
			"HUD scale applied (100%)")
	GameSettings.camera_shake = 0.0
	race.camera.add_shake(1.0)
	_check(race.camera.get_shake() == 0.0, "camera shake 0% turns shake off")
	GameSettings.camera_shake = 1.0
	race.camera.add_shake(0.8)
	_check(race.camera.get_shake() > 0.7, "camera shake works when enabled")
	GameSettings.reduced_flashing = true
	race.weapon_manager.spawn_flash(Vector3.ZERO, Color.WHITE)
	var lights := race.weapon_manager.get_children().filter(func(n: Node) -> bool: return n is OmniLight3D)
	_check(not lights.is_empty() and (lights[-1] as OmniLight3D).light_energy <= 2.0, "reduced flashing dims weapon flashes")
	GameSettings.reduced_flashing = false
	GameSettings.camera_shake = 0.6
	# Motion blur and a different car in a fresh race.
	GameSettings.motion_blur = true
	var config := _config()
	config.vehicle_id = "empyrean_s"
	var r2 := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	r2.config = config
	root.add_child(r2)
	await _frames(5)
	_check(r2.get_node_or_null("SpeedBlur") != null, "motion blur overlay when enabled")
	_check(is_equal_approx(r2.player.vehicle.stats.top_speed, 46.2), "chosen vehicle's stats used (Empyrean S)")
	r2.queue_free()
	GameSettings.motion_blur = false
	await process_frame


func _test_race_rewards(race: RaceManager) -> void:
	var profile := PlayerProfile.get_profile()
	var before := profile.coins
	var granted := [0]
	race.rewards_granted.connect(func(_s: Dictionary) -> void: granted[0] += 1)
	race.coins.collected = 4 # as if four coins had been picked up
	var frames := 0
	while not race.race_hud.is_results_visible() and frames < 60 * 150:
		await physics_frame
		frames += 1
	var s := race.reward_summary
	# The autopilot may pick up more coins on its lap.
	_check(int(s.track_coins) >= 4, "track coins counted (%d)" % int(s.track_coins))
	var expected: int = RaceRewards.compute(race.player.finish_position, true, int(s.track_coins)).total
	_check(granted[0] == 1 and int(s.total) == expected, "reward paid once (%d coins for P%d)" % [int(s.total), race.player.finish_position])
	_check(profile.coins == before + expected and int(s.coins_after) == profile.coins, "balance updated")
	_check(bool(s.best_race) and bool(s.best_lap), "first finish sets personal bests")
	_check(race.race_hud.get_rewards_text().contains("COINS  +%d" % expected), "results show coins earned (%s)" % race.race_hud.get_rewards_text())
	_check(race.race_hud.get_rewards_text().contains("NEW PERSONAL BEST"), "results show the personal best")
	_check(PlayerProfile.reload_from_disk().coins == before + expected, "coins saved to disk")
	await _frames(120)
	_check(granted[0] == 1 and PlayerProfile.get_profile().coins == before + expected, "nothing paid again while the AI finish")


## A two-race championship (1 lap each): race 1's coins are recorded in the
## championship save, paid once, and continuing doesn't pay them again.
func _test_grand_prix_rewards() -> void:
	var gp := GrandPrixData.new()
	gp.id = "test_gp"
	gp.display_name = "Test Cup"
	gp.track_names = PackedStringArray(["Race A", "Race B"])
	gp.track_scenes = PackedStringArray(["", ""])
	gp.laps = 1
	Championship.clear_save()
	var c := Championship.create(gp, "normal", true, load(ROSTER), "valkyrie_r")
	var before := PlayerProfile.get_profile().coins
	await _run("grand prix rewards", func(race: RaceManager) -> void:
		_check(race.player.vehicle.stats == VehicleCatalog.by_id("valkyrie_r").stats, "the championship's car is used")
		var frames := 0
		while not race.race_hud.is_results_visible() and frames < 60 * 150:
			await physics_frame
			frames += 1
		var total := int(race.reward_summary.total)
		_check(c.coins_awarded == total and total >= RaceRewards.COMPLETE, "reward recorded in the championship (%d)" % total)
		_check(PlayerProfile.get_profile().coins == before + total, "and paid to the profile")
		_check(not race.can_restart(), "the race can't be replayed for more coins"),
			c.make_race_config(), true)
	# The in-memory GrandPrixData isn't a file, so check the record directly.
	_check(c.race_index == 1 and c.results.size() == 1, "race 1 recorded")
	var paid := PlayerProfile.get_profile().coins
	var dict := c.to_dict()
	_check(int(dict.coins_awarded) == c.coins_awarded, "coins awarded are part of the save")
	_check(PlayerProfile.reload_from_disk().coins == paid, "profile balance persisted")
	Championship.clear_save()
