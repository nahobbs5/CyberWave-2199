extends SceneTree
## Phase 4 headless checks: championship points and tiebreaks, save / load,
## elimination rules, Triple Nitro charges, the pause menu, the main menu and race setup
## screen, and complete Versus, Grand Prix (3 races, with save / continue)
## and Elimination events. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_phase4.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const RACE_SETUP := "res://scenes/menu/race_setup.tscn"
const GP1 := "res://resources/grand_prix/american_circuit.tres"
const ROSTER := "res://resources/racers/rival_roster.tres"
const TEST_SAVE := "user://test_phase4_gp.json"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	# Races open the results without the podium ceremony (see test_podium.gd).
	PodiumCeremony.instant = true
	# Never touch the real profile or settings: races now pay out coins.
	PlayerProfile.save_path = "user://test_phase4_profile.json"
	GameSettings.path = "user://test_phase4_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	Championship.save_path = TEST_SAVE
	Championship.clear_save()
	GameSession.scene_changes_enabled = false
	_test_points()
	_test_tiebreak()
	_test_save_load()
	_test_elimination_rules()
	_test_triple_nitro_inventory()
	_test_rival_plates()
	await _test_mode_select()
	await _run("pause menu", _test_pause, _config(RaceConfig.Mode.VERSUS))
	await _run("triple nitro in a race", _test_triple_nitro_race, _config(RaceConfig.Mode.VERSUS))
	await _run("elimination during a recovery", _test_eliminate_mid_recovery, _config(RaceConfig.Mode.ELIMINATION))
	var versus := _config(RaceConfig.Mode.VERSUS)
	versus.total_laps = 1
	await _run("versus race", _test_versus, versus, true)
	await _test_grand_prix()
	await _run("elimination race", _test_elimination_race, _config(RaceConfig.Mode.ELIMINATION), true)
	Championship.clear_save()
	GameSession.current = null
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _config(mode: RaceConfig.Mode) -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	return config


func _run(test_name: String, test: Callable, config: RaceConfig, autopilot: bool = false) -> void:
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


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _wait_player_done(race: RaceManager, limit_seconds: float) -> void:
	var frames := 0
	while not race.race_hud.is_results_visible() and frames < int(limit_seconds * 60.0):
		await physics_frame
		frames += 1


func _ids(order: Array) -> Array[int]:
	var out: Array[int] = []
	for id in order:
		out.append(int(id))
	return out


# --- pure logic ----------------------------------------------------------------

func _test_points() -> void:
	_current = "points"
	print("- championship points (no scene)")
	var table: Array[int] = []
	for p in range(1, 10):
		table.append(Championship.points_for(p))
	_check(table == [15, 12, 10, 8, 6, 4, 2, 1, 0], "points table 15-12-10-8-6-4-2-1 (%s)" % [table])
	var c := Championship.create(load(GP1), "normal", true, load(ROSTER))
	_check(c.next_grid == _ids([0, 1, 2, 3, 4, 5, 6, -1]), "race 1 grid: rivals 1-7, player eighth")
	_check(c.rival_names.size() == 7, "seven rival identities recorded")
	var order := _ids([-1, 3, 0, 1, 2, 4, 5, 6])
	c.record_race(order)
	_check(c.points[-1] == 15 and c.points[3] == 12 and c.points[6] == 1, "points awarded by finishing position")
	_check(c.next_grid == order, "next grid follows the previous finishing order")
	_check(c.race_index == 1 and not c.is_complete(), "race 2 is next")
	var config := c.make_race_config()
	_check(config.grid_order == order and config.is_grand_prix() and config.total_laps == 3
			and config.track_name == "Six Flags New Orleans", "next race config: grid, laps, track name")


func _test_tiebreak() -> void:
	_current = "tiebreak"
	print("- tiebreaker (no scene)")
	var gp := load(GP1) as GrandPrixData
	# A (0) and B (1) both finish on 16: A won a race, B didn't.
	var c := Championship.create(gp, "normal", true, load(ROSTER))
	c.record_race(_ids([0, 2, 1, 3, 4, 5, 6, -1])) # A 15, B 10
	c.record_race(_ids([2, 3, 4, 5, 1, 6, -1, 0])) # A 1, B 6
	_check(c.points[0] == 16 and c.points[1] == 16, "A and B tie on points")
	var s := c.standings()
	_check(s.find(0) < s.find(1), "more wins breaks the tie")
	# Same points, wins and seconds: the most recent race's order decides.
	var d := Championship.create(gp, "normal", true, load(ROSTER))
	d.record_race(_ids([0, 1, 2, 3, 4, 5, 6, -1]))
	d.record_race(_ids([1, 0, 2, 3, 4, 5, 6, -1]))
	_check(d.points[0] == d.points[1], "equal on points, wins and seconds")
	var t := d.standings()
	_check(t.find(1) < t.find(0), "then the final race's finishing order")
	_check(t[0] == 1 or t[0] == 0, "leaders on top")


func _test_save_load() -> void:
	_current = "save / load"
	print("- championship save / load (no scene)")
	Championship.clear_save()
	_check(not Championship.has_save(), "no save to begin with")
	var c := Championship.create(load(GP1), "hard", false, load(ROSTER))
	c.record_race(_ids([2, -1, 0, 1, 3, 4, 5, 6]))
	_check(c.save(), "saved")
	var loaded := Championship.load_saved()
	_check(loaded != null, "loads back")
	if loaded == null:
		return
	_check(loaded.gp.id == "american_circuit" and loaded.race_index == 1, "championship id and next race")
	_check(loaded.points == c.points, "cumulative points")
	_check(loaded.results.size() == 1 and _ids(loaded.results[0]) == _ids([2, -1, 0, 1, 3, 4, 5, 6]), "completed results")
	_check(loaded.next_grid == c.next_grid, "next starting grid")
	_check(loaded.rival_names == c.rival_names and loaded.vehicle_id == "v8_specter", "rival identities and vehicle")
	_check(loaded.difficulty_id == "hard" and not loaded.weapons_enabled and loaded.coins_awarded == 0, "settings and coins")
	loaded.record_race(_ids([0, 1, 2, 3, 4, 5, 6, -1]))
	loaded.record_race(_ids([0, 1, 2, 3, 4, 5, 6, -1]))
	loaded.save()
	_check(Championship.load_saved() == null, "a completed championship isn't offered to continue")
	Championship.clear_save()
	_check(not FileAccess.file_exists(TEST_SAVE), "save cleared")


func _test_elimination_rules() -> void:
	_current = "elimination rules"
	print("- elimination rules (no scene)")
	var racers: Array[RaceProgress] = []
	for i in 8:
		var r := RaceProgress.new(null, "R%d" % i, Color.WHITE, false, i, 8, 3)
		r.lap = 1
		racers.append(r)
	var t := EliminationTracker.new(racers, 4)
	_check(t.on_crossing(racers[0], 3).is_empty() and not t.just_qualified, "other gates don't count")
	for i in 5:
		_check(t.on_crossing(racers[i], 4).is_empty(), "qualifier %d of 6 crosses" % (i + 1))
	_check(t.spots_left() == 1, "one place left")
	_check(t.on_crossing(racers[0], 4).is_empty() and t.spots_left() == 1, "crossing twice doesn't count")
	var out := t.on_crossing(racers[7], 4)
	_check(out.size() == 2 and out.has(racers[5]) and out.has(racers[6]), "the 6th qualifier knocks out the two who haven't crossed")
	_check(t.event == 1 and t.next_event_lap() == 2, "next elimination is lap 2")
	for r in out:
		r.eliminated = true
		r.finished = true
	_check(RaceProgress.is_ahead(racers[0], out[0]) and not RaceProgress.is_ahead(out[0], racers[7]),
			"eliminated racers rank behind everyone still in")
	# Lap 2: four qualify. A racer still on lap 1 can't qualify for it.
	var survivors := t.active_racers()
	_check(survivors.size() == 6, "six remain")
	survivors[0].lap = 1
	_check(t.on_crossing(survivors[0], 4).is_empty() and not t.just_qualified, "a lap-1 crossing doesn't count for lap 2")
	for i in range(1, 5):
		survivors[i].lap = 2
		out = t.on_crossing(survivors[i], 4)
	_check(out.size() == 2 and out.has(survivors[0]) and out.has(survivors[5]), "lap 2: last two out")
	for r in out:
		r.eliminated = true
	var final := t.active_racers()
	for r in final:
		r.lap = 3
	t.on_crossing(final[0], 4)
	out = t.on_crossing(final[1], 4)
	_check(out.size() == 2 and t.is_done() and t.active_racers().size() == 4, "lap 3: two left after the last gate")


func _test_rival_plates() -> void:
	_current = "rival plates"
	print("- rival plates (no scene)")
	var plates := RaceConfig.random_plates(7, "CW-2199")
	var valid := RegEx.create_from_string("^[A-Z]{3}-[0-9]{3}$")
	var ok := plates.size() == 7 and not plates.has("CW-2199")
	for i in plates.size():
		ok = ok and valid.search(plates[i]) != null and PlayerProfile.sanitize_plate(plates[i]) == plates[i]
		ok = ok and plates.find(plates[i]) == i
	_check(ok, "7 distinct valid plates, never the player's (%s)" % [plates])
	_check(RaceConfig.random_plates(7) != RaceConfig.random_plates(7), "each series rolls new plates")
	var c := Championship.create(load(GP1), "normal", true, load(ROSTER))
	var first := c.make_race_config().rival_plates
	c.record_race(_ids([0, 1, 2, 3, 4, 5, 6, -1]))
	_check(first.size() == 7 and c.make_race_config().rival_plates == first, "Grand Prix keeps its plates race to race")
	var data := c.to_dict()
	_check(Championship.from_dict(data).rival_plates == first, "plates survive save / load")
	data.erase("plates")
	var old := Championship.from_dict(data)
	_check(old != null and old.rival_plates.size() == 7, "an older save without plates gets new ones")


func _test_triple_nitro_inventory() -> void:
	_current = "triple nitro inventory"
	print("- triple nitro inventory (no scene)")
	var inv := ItemInventory.new()
	var triple := load("res://resources/weapons/triple_nitro.tres") as WeaponData
	var spike := load("res://resources/weapons/road_spike.tres") as WeaponData
	inv.add(triple)
	inv.add(spike)
	_check(inv.charges[0] == 3, "Triple Nitro has three charges")
	_check(inv.take_selected() == triple and inv.charges[0] == 2 and inv.current() == triple, "first use keeps it selected")
	inv.take_selected()
	_check(inv.take_selected() == triple and inv.slots[0] == null and inv.current() == spike,
			"third use empties the slot and selects the other")
	inv.clear()
	inv.add(triple)
	inv.take_selected()
	_check(inv.lose_item() == triple and inv.is_empty() and inv.charges[0] == 0, "a stripping hit takes every remaining charge")
	var tspike := load("res://resources/weapons/triple_spike.tres") as WeaponData
	_check(tspike.kind == WeaponData.Kind.HAZARD and tspike.charges == 3 and tspike.chance_for(1, 8) > tspike.chance_for(8, 8),
			"Triple Spike: a 3-charge hazard, mostly for leaders")
	inv.add(tspike)
	inv.take_selected()
	_check(inv.lose_item() == tspike and inv.is_empty(), "a hit knocks out the remaining spikes")
	inv.free()


# --- scenes ----------------------------------------------------------------------

func _test_mode_select() -> void:
	_current = "menus and race setup"
	print("- main menu and race setup")
	Championship.clear_save()
	GameSession.current = null
	var menu := (load(MAIN_MENU) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(not menu.has_continue(), "no Continue Grand Prix without a save")
	var order := ", ".join(menu.button_texts())
	_check(order == "Grand Prix, Versus, Practice, Garage, Settings, Credits, Back", "main menu order (%s)" % order)
	menu.queue_free()
	var setup := await _open_setup(RaceConfig.Mode.VERSUS)
	_start_versus(setup)
	_check(GameSession.current != null and GameSession.current.mode == RaceConfig.Mode.VERSUS
			and GameSession.current.total_laps == 3 and GameSession.current.weapons_enabled, "Versus: default settings")
	setup.queue_free()
	var versus_plates := GameSession.current.rival_plates
	_check(versus_plates.size() == 7, "Versus rolls 7 rival plates")
	var cars_ok := GameSession.current.rival_vehicles.size() == 7
	for id in GameSession.current.rival_vehicles:
		cars_ok = cars_ok and VehicleCatalog.by_id(id).id == id
	_check(cars_ok, "and 7 rival cars from the catalogue (%s)" % [GameSession.current.rival_vehicles])
	# Elimination is a Versus race type now.
	setup = await _open_setup(RaceConfig.Mode.VERSUS)
	_check(setup._race_type != null and setup._race_type.selected == 0, "Versus setup has a Race type, Standard first")
	setup.set_race_type(1)
	_check(not setup._laps_row.visible and setup._title.text.begins_with("ELIMINATION"), "picking Elimination hides laps and retitles")
	_start_versus(setup)
	_check(GameSession.current.is_elimination(), "Race type Elimination starts an Elimination race")
	_check(GameSession.last_versus_mode() == RaceConfig.Mode.ELIMINATION, "Versus reopens on the race type used last")
	setup.queue_free()
	setup = await _open_setup(RaceConfig.Mode.ELIMINATION)
	setup._laps.selected = 4
	setup._difficulty.selected = 2
	_start_versus(setup)
	_check(GameSession.current.is_elimination() and GameSession.current.total_laps == 5
			and GameSession.current.difficulty.resource_path.ends_with("hard.tres"), "Elimination with chosen settings")
	_check(GameSession.current.rival_plates.size() == 7 and GameSession.current.rival_plates != versus_plates,
			"a new set gets new plates")
	setup.queue_free()
	# Grand Prix: pick a cup first (Mario Kart style).
	GameSession.setup_mode = RaceConfig.Mode.GRAND_PRIX
	GameSession.cup_path = ""
	var cups := (load("res://scenes/menu/cup_select.tscn") as PackedScene).instantiate() as CupSelect
	root.add_child(cups)
	await process_frame
	var open_cups := 0
	for cup in cups.cups:
		open_cups += 1 if cup.is_open(true) else 0
	_check(cups.cards.size() == GrandPrixData.CUPS.size() and open_cups == 4, "a badge per cup, four open for Grand Prix (%d)" % open_cups)
	cups.pick(1)
	_check(GameSession.cup_path == GrandPrixData.CUPS[1], "picking the Europe Cup")
	GameSession.cup_path = ""
	cups.pick(0)
	_check(GameSession.cup_path == GrandPrixData.CUPS[0], "picking the American Cup")
	cups.queue_free()
	setup = await _open_setup(RaceConfig.Mode.GRAND_PRIX)
	_check(setup.cup.id == "american_circuit" and setup.summary_text() == "AMERICAN CUP", "setup shows the American Cup")
	setup.start()
	_check(GameSession.current.is_grand_prix() and Championship.has_save(), "starting a Grand Prix saves it")
	setup.queue_free()
	await process_frame
	var again := (load(MAIN_MENU) as PackedScene).instantiate() as MainMenu
	root.add_child(again)
	await process_frame
	_check(again.has_continue(), "Continue Grand Prix appears when a save exists")
	GameSession.current = null
	again.continue_grand_prix()
	_check(GameSession.current != null and GameSession.current.is_grand_prix()
			and GameSession.current.championship.race_index == 0, "Continue loads the saved championship")
	again.queue_free()
	await process_frame
	Championship.clear_save()
	GameSession.current = null
	GameSession.cup_path = ""
	GameSession.track_name = ""


## Versus setup: Next, then pick the first track on the track screen.
func _start_versus(setup: RaceSetup) -> void:
	setup.start()
	GameSession.start_versus_race(self, "Vegas Overdrive")


func _open_setup(mode: RaceConfig.Mode) -> RaceSetup:
	GameSession.setup_mode = mode
	var setup := (load(RACE_SETUP) as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await process_frame
	return setup


func _test_pause(race: RaceManager) -> void:
	var menu := race.get_node("PauseMenu") as PauseMenu
	await _frames(30)
	await _press(KEY_ESCAPE)
	_check(paused and menu.is_open(), "Esc pauses and opens the menu")
	var time_before := race.race_time
	var pos_before := race.racers[0].vehicle.global_position
	await _frames(30)
	_check(is_equal_approx(race.race_time, time_before), "the race timer stops")
	_check(race.racers[0].vehicle.global_position.distance_to(pos_before) < 0.01, "cars stop")
	_check(not menu._restart.disabled, "Restart available in Versus")
	await _press(KEY_ESCAPE)
	_check(not paused and not menu.is_open(), "Esc again resumes")
	await _frames(10)
	_check(race.race_time > time_before, "the race carries on")


func _test_triple_nitro_race(race: RaceManager) -> void:
	var me := race.player.vehicle
	var wm := race.weapon_manager
	me.inventory.add(load("res://resources/weapons/triple_nitro.tres"))
	await _frames(5)
	_check(race.race_hud.get_slot_text(0).contains("x3"), "HUD shows the charges (%s)" % race.race_hud.get_slot_text(0))
	var kicks := 0
	for i in 3:
		if wm.use_weapon(me) and me.is_boosting() and me.boost_label == "Triple Nitro":
			kicks += 1
		await _frames(20)
	_check(kicks == 3, "three separate boosts (%d)" % kicks)
	_check(me.inventory.is_empty(), "slot empty after the third")
	_check(not wm.use_weapon(me), "nothing left to fire")
	# Triple Spike: three charges, one Road Spike per press.
	# Count spikes as they're dropped (rivals behind may run over them at once).
	var dropped := [0]
	var on_child := func(n: Node) -> void:
		if n is RoadSpike and (n as RoadSpike).shooter == me:
			dropped[0] += 1
	wm.child_entered_tree.connect(on_child)
	me.inventory.add(load("res://resources/weapons/triple_spike.tres"))
	await _frames(5)
	_check(race.race_hud.get_slot_text(0).contains("Triple Spike  x3"), "HUD shows Triple Spike x3 (%s)" % race.race_hud.get_slot_text(0))
	var counts: Array[int] = []
	for i in 3:
		wm.use_weapon(me)
		counts.append(me.inventory.charges[0])
		await _frames(10)
	_check(counts == _ids([2, 1, 0]) and me.inventory.is_empty(), "x3 -> x2 -> x1 -> empty (%s)" % [counts])
	wm.child_entered_tree.disconnect(on_child)
	_check(dropped[0] == 3, "one spike per press (%d)" % dropped[0])
	_check(wm.weapons.any(func(w: WeaponData) -> bool: return w.id == &"triple_spike"), "Triple Spike is in the crate pool")


func _test_versus(race: RaceManager) -> void:
	_check(race.mode() == RaceConfig.Mode.VERSUS and race.total_laps == 1 and race.championship == null, "Versus from config")
	await _wait_player_done(race, 150.0)
	var hud := race.race_hud
	_check(hud.is_results_visible() and hud.get_results_title().begins_with("VERSUS / "), "results shown (%s)" % hud.get_results_title())
	_check(hud.get_continue_text() == "Race again" and hud._continue_button.disabled, "Race again, briefly disabled")
	await _frames(100)
	_check(not hud._continue_button.disabled, "then enabled")
	_check(race.can_restart(), "Versus can be restarted after finishing")


func _test_grand_prix() -> void:
	var gp := load(GP1) as GrandPrixData
	var saved_laps := gp.laps
	gp.laps = 1 # keep the headless run short
	Championship.clear_save()
	var c := Championship.create(gp, "normal", true, load(ROSTER))
	c.save()
	var roster := load(ROSTER) as RivalRoster
	for race_number in 3:
		# After race 1, continue from the save as if the game had been restarted.
		if race_number == 1:
			var loaded := Championship.load_saved()
			_current = "grand prix"
			_check(loaded != null and loaded.race_index == 1, "race 1 saved; continue from the save")
			if loaded != null:
				loaded.gp = gp
				c = loaded
		var config := c.make_race_config()
		var expected_grid := config.grid_order.duplicate()
		await _run("grand prix race %d" % (race_number + 1), func(race: RaceManager) -> void:
			var updates := [0]
			race.championship_updated.connect(func(_c: Championship) -> void: updates[0] += 1)
			# Grid and identities.
			var grid_ok := true
			var names_ok := true
			for racer in race.racers:
				grid_ok = grid_ok and expected_grid[racer.grid_slot] == racer.racer_id
				if racer.racer_id >= 0:
					names_ok = names_ok and racer.display_name == roster.rivals[racer.racer_id].display_name
			_check(grid_ok, "grid follows the previous race (%s)" % [expected_grid])
			_check(names_ok, "AI identities stay the same")
			_check(race.can_restart(), "restart allowed before the finish")
			await _wait_player_done(race, 150.0)
			_check(updates[0] == 1, "result recorded once")
			_check(not race.can_restart(), "no restart once the result is saved")
			var positions: Array[int] = []
			for racer in race.racers:
				positions.append(racer.finish_position)
			positions.sort()
			_check(positions == _ids([1, 2, 3, 4, 5, 6, 7, 8]), "everyone classified 1-8 (%s)" % [positions])
			var total := 0
			for id in c.points:
				total += c.points[id]
			_check(total == 58 * (race_number + 1), "58 points per race awarded (%d)" % total)
			var order: Array = c.results[race_number]
			var order_ok := true
			for racer in race.racers:
				order_ok = order_ok and order[racer.finish_position - 1] == racer.racer_id
			_check(order_ok, "recorded order matches the classification")
			var hud := race.race_hud
			# Mario Kart style: the race first (+points), then Continue shows the totals.
			var neon := hud.results as NeonResultsScreen
			_check(neon != null and not neon.standings_page and hud.get_continue_text() == "Standings",
					"race results first, Continue reads Standings (%s)" % hud.get_continue_text())
			var emitted := [0]
			hud.results.continue_pressed.connect(func() -> void: emitted[0] += 1, CONNECT_ONE_SHOT)
			hud.results.skip_animation()
			neon._on_continue()
			_check(neon.standings_page and emitted[0] == 0, "first Continue shows the standings, doesn't leave")
			neon.skip_animation()
			var rows_ok := true
			var ranking := c.standings()
			for i in ranking.size():
				rows_ok = rows_ok and (neon._rows[i] as NeonResultsScreen.ResultRow).racer_id == ranking[i] \
						and (neon._cells[i][2] as Label).text == str(c.points[ranking[i]])
			_check(rows_ok, "standings rows in points order with their totals")
			if race_number == 2:
				_check(neon._title_bar.label.text == "FINAL STANDINGS", "final standings page")
			if race_number < 2:
				_check(Championship.load_saved() != null and Championship.load_saved().race_index == race_number + 1,
						"saved after the race")
				_check(hud.get_continue_text() == "Next Race", "results offer the next race (%s)" % hud.get_continue_text())
			else:
				_check(c.is_complete() and Championship.load_saved() == null, "championship complete, save cleared")
				_check(hud.get_results_title().begins_with("CHAMPIONSHIP FINAL"), "final standings shown")
				_check(hud.get_continue_text() == "Back to main menu", "then back to the main menu")
				var s := c.standings()
				var sorted_ok := true
				for i in range(1, s.size()):
					sorted_ok = sorted_ok and c.points[s[i - 1]] >= c.points[s[i]]
				_check(sorted_ok, "standings sorted by points")
				print("    champion: %s with %d pts; player %d pts" % [s[0], c.points[s[0]], c.points[-1]]),
				config, true)
	gp.laps = saved_laps


func _test_elimination_race(race: RaceManager) -> void:
	var tracker := race.elimination
	_check(tracker != null and race.total_laps == 3, "Elimination: 3 laps with a tracker")
	_check(race.get_node_or_null("EliminationGate") != null, "elimination gate marker built")
	var batches: Array = []
	var bad := [0]
	race.racer_eliminated.connect(func(r: RaceProgress) -> void:
		var e := tracker.event - 1
		if (tracker.qualified[e] as Array).has(r):
			bad[0] += 1
		if batches.size() <= e:
			batches.append([])
		(batches[e] as Array).append(r)
		_check(r.vehicle.collision_layer == 0, "%s stops colliding with racers at once" % r.display_name))
	var saw_hud := false
	var frames := 0
	var last_active := -1
	var steady := 0
	var standings_checked: Array[int] = []
	var standings_bad: Array[String] = []
	while frames < 60 * 420 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
		if not saw_hud and race.race_hud.get_elimination_text().contains("ACTIVE"):
			saw_hud = true
		var active := race.racers.filter(func(r: RaceProgress) -> bool: return not r.eliminated)
		steady = steady + 1 if active.size() == last_active else 0
		last_active = active.size()
		# A few frames after each cut, the live list shows only those still in, ranked 1..N.
		if steady == 5 and not standings_checked.has(active.size()):
			standings_checked.append(active.size())
			var lines := race.race_hud.get_standings_text().split("\n")
			var ranks: Array[int] = []
			for r in active:
				ranks.append((r as RaceProgress).position)
			ranks.sort()
			var expected: Array[int] = []
			for i in active.size():
				expected.append(i + 1)
			if lines.size() != active.size() or ranks != expected:
				standings_bad.append("%d active: %d lines, ranks %s" % [active.size(), lines.size(), ranks])
	await _frames(60)
	_check(saw_hud, "elimination HUD shown")
	_check(standings_checked.size() == 4 and standings_bad.is_empty(),
			"live standings list only active racers, ranked 1..N (checked %s; bad %s)" % [standings_checked, standings_bad])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "every racer classified")
	var sizes: Array[int] = []
	for b in batches:
		sizes.append((b as Array).size())
	_check(sizes == _ids([2, 2, 2]), "two eliminated at each of three lap midpoints (%s)" % [sizes])
	_check(bad[0] == 0, "nobody who qualified was eliminated")
	for e in tracker.SCHEDULE.size():
		_check((tracker.qualified[e] as Array).size() == EliminationTracker.SCHEDULE[e], "event %d: %d qualified" % [e + 1, EliminationTracker.SCHEDULE[e]])
	var positions_ok := true
	for e in batches.size():
		for r in batches[e]:
			var p: int = (r as RaceProgress).finish_position
			positions_ok = positions_ok and p >= 7 - e * 2 and p <= 8 - e * 2
	_check(positions_ok, "eliminated in order: 7-8, then 5-6, then 3-4")
	var positions: Array[int] = []
	for r in race.racers:
		positions.append(r.finish_position)
	positions.sort()
	_check(positions == _ids([1, 2, 3, 4, 5, 6, 7, 8]), "final positions 1-8 (%s)" % [positions])
	var out := race.racers.filter(func(r: RaceProgress) -> bool: return r.eliminated)
	_check(out.size() == 6 and out.all(func(r: RaceProgress) -> bool: return not r.vehicle.visible),
			"six eliminated cars have disappeared")
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 0.0 and not winner.eliminated, "the winner crossed the line")
	_check(race.race_hud.is_results_visible() and race.race_hud.get_results_title().begins_with("ELIMINATION / "),
			"results shown to the player")
	print("    winner %s; player P%d%s; %.1f s simulated" % [winner.display_name, race.player.finish_position,
			" (eliminated)" if race.player.eliminated else "", frames / 60.0])


## Elimination wins over a recovery in progress: the car stays out of the race.
func _test_eliminate_mid_recovery(race: RaceManager) -> void:
	await _frames(30)
	var car := race.racers[1].vehicle
	_check(car.recovery.request_recovery("test"), "a rival starts recovering")
	await _frames(25)
	race._remove_vehicle(car)
	_check(car.recovery.state == VehicleRecovery.State.NORMAL and not car.recovery_lock and not car.is_held(),
			"the recovery is cancelled")
	_check(car.collision_layer == 0 and not car.is_ghost(), "eliminated: off the car layer at once")
	await _frames(120)
	_check(car.collision_layer == 0 and not car.visible, "and stays parked out of the race")

