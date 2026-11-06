extends SceneTree
## Split-screen multiplayer headless checks: the title menu, per-player
## input actions tied to one device each, the lobby (join / leave / cars /
## ready / settings), 2-4 player split views, the shared minimap, humans-only
## grids, a 4-player race to the shared results with no coins paid, and a
## 2-player Grand Prix that never touches the single-player save.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_multiplayer.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const TITLE := "res://scenes/menu/title_menu.tscn"
const CONNECT := "res://scenes/menu/multiplayer_connect.tscn"
const CARS := "res://scenes/menu/multiplayer_cars.tscn"
const SETUP := "res://scenes/menu/multiplayer_setup.tscn"
const TRACKS := "res://scenes/menu/track_select.tscn"
const GP1 := "res://resources/grand_prix/american_circuit.tres"
const ROSTER := "res://resources/racers/rival_roster.tres"
const TEST_SAVE := "user://test_mp_gp.json"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_mp_profile.json"
	GameSettings.path = "user://test_mp_settings.cfg"
	PlayerProfile.delete_save()
	Championship.save_path = TEST_SAVE
	_run_all.call_deferred()


func _run_all() -> void:
	Championship.clear_save()
	GameSession.scene_changes_enabled = false
	await _test_title()
	_test_player_actions()
	_test_layouts()
	await _test_lobby()
	await _test_views(2)
	await _test_views(3)
	await _test_views(4)
	await _test_humans_only()
	await _test_full_race()
	await _test_grand_prix()
	await _test_series()
	Championship.clear_save()
	GameSession.current = null
	GameSession.split_screen = false
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _mp_config(players: int, ai: bool = true, mode := RaceConfig.Mode.VERSUS) -> RaceConfig:
	var config := RaceConfig.new()
	config.mode = mode
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.ai_rivals = ai
	var devices := PackedInt32Array([-1, 0, 1, 2])
	var cars := PackedStringArray()
	for i in players:
		cars.append(VehicleCatalog.all()[i % VehicleCatalog.all().size()].id)
	config.player_devices = devices.slice(0, players)
	config.player_vehicle_ids = cars
	config.player_plates = PackedStringArray(["", "PL-2", "PL-3", "PL-4"]).slice(0, players)
	return config


func _start(config: RaceConfig, autopilot: bool = false) -> RaceManager:
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = autopilot
	root.add_child(race)
	await process_frame
	await process_frame
	return race


func _end(race: RaceManager) -> void:
	paused = false
	race.queue_free()
	await process_frame
	await process_frame


func _joy_button(device: int, button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	return e


func _key(key: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = pressed
	return e


# --- menus ---------------------------------------------------------------------

func _test_title() -> void:
	_current = "title menu"
	print("- title menu")
	var title := (load(TITLE) as PackedScene).instantiate() as TitleMenu
	root.add_child(title)
	await process_frame
	var order := ", ".join(title.button_texts())
	_check(order == "Single Player, Multiplayer, Settings, Credits, Exit", "title buttons (%s)" % order)
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITLE, "the title is the main scene")
	title.queue_free()
	await process_frame


func _test_player_actions() -> void:
	_current = "per-player input"
	print("- per-player input actions")
	InputSetup.build_player_actions(0, -1)
	InputSetup.build_player_actions(1, 0)
	InputSetup.build_player_actions(2, 1)
	_check(InputMap.has_action(&"p1_accelerate") and InputMap.has_action(&"p3_use_weapon"), "prefixed actions exist")
	var keys_only := true
	for e in InputMap.action_get_events(&"p1_accelerate"):
		keys_only = keys_only and e is InputEventKey
	_check(keys_only and not InputMap.action_get_events(&"p1_accelerate").is_empty(), "keyboard player gets key events only")
	var pad_a := _joy_button(0, JOY_BUTTON_LEFT_SHOULDER)
	_check(InputMap.event_is_action(pad_a, &"p2_use_weapon"), "pad 0's LB fires P2's weapon")
	_check(not InputMap.event_is_action(pad_a, &"p3_use_weapon"), "but not P3's (pad 1)")
	_check(not InputMap.event_is_action(pad_a, &"p1_use_weapon"), "nor the keyboard player's")
	_check(InputMap.event_is_action(_joy_button(1, JOY_BUTTON_LEFT_SHOULDER), &"p3_use_weapon"), "pad 1's LB fires P3's weapon")
	var space := _key(KEY_SPACE)
	_check(InputMap.event_is_action(space, &"p1_use_weapon") and not InputMap.event_is_action(space, &"p2_use_weapon"),
			"Space is only the keyboard player's")
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_TRIGGER_RIGHT
	stick.axis_value = 1.0
	_check(InputMap.event_is_action(stick, &"p2_accelerate") and not InputMap.event_is_action(stick, &"p3_accelerate"),
			"pad 0's trigger accelerates P2 only")
	_check(InputSetup.action(&"", &"brake") == &"brake" and InputSetup.action(&"p2_", &"brake") == &"p2_brake",
			"action() keeps single player unprefixed")
	# Gamepad layout: LT reverse, RB drift (hold + steer), LB weapon, Y trick, D-pad down camera, D-pad up reset.
	var lt := InputEventJoypadMotion.new()
	lt.device = 0
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	_check(InputMap.event_is_action(lt, &"brake") and InputMap.event_is_action(lt, &"p2_brake"), "LT brakes / reverses")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_RIGHT_SHOULDER), &"drift")
			and InputMap.event_is_action(_joy_button(0, JOY_BUTTON_RIGHT_SHOULDER), &"p2_drift"), "RB drifts")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_LEFT_SHOULDER), &"use_weapon")
			and InputMap.event_is_action(_joy_button(0, JOY_BUTTON_LEFT_SHOULDER), &"p2_use_weapon"), "LB fires weapon")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_Y), &"trick"), "Y tricks")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_DPAD_DOWN), &"cycle_camera"), "D-pad down: camera")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_DPAD_UP), &"reset_vehicle"), "D-pad up: reset")
	_check(InputMap.event_is_action(_joy_button(0, JOY_BUTTON_RIGHT_STICK), &"p2_look_back")
			and not InputMap.event_is_action(_joy_button(0, JOY_BUTTON_RIGHT_STICK), &"p3_look_back"), "RS: P2 looks back")


func _test_layouts() -> void:
	_current = "layouts"
	print("- view layouts")
	var size := Vector2(1280, 720)
	var two := SplitScreen.view_rects(2, size)
	_check(two.size() == 2 and two[0] == Rect2(0, 0, 1280, 360) and two[1] == Rect2(0, 360, 1280, 360), "2P: top and bottom halves")
	var four := SplitScreen.view_rects(4, size)
	_check(four.size() == 4 and four[0] == Rect2(0, 0, 640, 360) and four[3] == Rect2(640, 360, 640, 360), "4P: corners")
	_check(SplitScreen.view_rects(3, size).size() == 4, "3P: four views (the last for the spectator)")
	var mask := SplitScreen.camera_mask(1)
	_check(mask & SplitScreen.private_layer(1) != 0 and mask & SplitScreen.private_layer(0) == 0, "P2 sees their private layer, not P1's")
	_check(mask & SplitScreen.tag_layer(1) == 0 and mask & SplitScreen.tag_layer(0) != 0, "P2 sees P1's tag but not their own")
	var tv := SplitScreen.camera_mask(-1)
	_check(tv & SplitScreen.private_layer(0) == 0 and tv & SplitScreen.tag_layer(2) != 0, "the spectator sees tags, no private layers")
	var grid := RaceConfig.default_grid(RaceConfig.rivals_for(3, true), 3)
	_check(grid.size() == 8 and grid.slice(5) == [-3, -2, -1], "5 AI, then the humans at the back, P1 last (%s)" % [grid])
	_check(RaceConfig.rivals_for(1, false) == 7 and RaceConfig.rivals_for(4, false) == 0, "single player always gets 7 rivals")


func _test_lobby() -> void:
	_current = "connect"
	print("- connect controllers, cars, setup")
	GameSession.mp_vehicles = PackedStringArray()
	GameSession.mp_devices = PackedInt32Array()
	GameSession.mp_plates = PackedStringArray()
	GameSession.mp_settings = {"ai": true, "difficulty": 1, "laps": 2, "weapons": true}
	var connect := (load(CONNECT) as PackedScene).instantiate() as MultiplayerConnect
	root.add_child(connect)
	await process_frame
	_check(GameSession.split_screen, "the connect screen turns split screen on")
	connect._input(_key(KEY_ENTER))
	_check(connect.devices == [-1] and not connect.is_ready(-1), "Enter joins the keyboard as P1 (not ready yet)")
	connect._input(_key(KEY_ENTER))
	_check(connect.is_ready(-1) and not connect.can_continue(), "the second press is READY; P1 alone can't go on")
	connect._input(_joy_button(0, JOY_BUTTON_A))
	connect._input(_joy_button(3, JOY_BUTTON_START))
	_check(connect.devices == [-1, 0, 3], "pads join as P2 and P3 in order")
	connect._input(_joy_button(0, JOY_BUTTON_A))
	_check(connect.is_ready(0) and GameSession.mp_devices.is_empty(), "P2 ready, but P3 isn't: nobody moves on")
	connect._input(_joy_button(0, JOY_BUTTON_B))
	_check(connect.devices.size() == 3 and not connect.is_ready(0), "B takes back READY first")
	connect._input(_joy_button(3, JOY_BUTTON_B))
	_check(connect.devices == [-1, 0], "B on a player who isn't ready leaves")
	connect._input(_joy_button(0, JOY_BUTTON_A))
	_check(connect.confirm_banner.visible and GameSession.mp_devices.is_empty(), "everyone ready: ALL READY banner, waiting for a final press")
	connect._input(_key(KEY_ESCAPE))
	_check(not connect.is_ready(-1) and not connect.confirm_banner.visible, "Esc on the banner takes P1's READY back")
	connect._input(_key(KEY_ENTER))
	_check(connect.confirm_banner.visible and GameSession.mp_devices.is_empty(), "ready again: banner back")
	connect._input(_joy_button(0, JOY_BUTTON_A))
	_check(GameSession.mp_devices == PackedInt32Array([-1, 0]), "final confirm: on to the cars with both players")
	connect.queue_free()
	await process_frame

	_current = "cars"
	var cars := (load(CARS) as PackedScene).instantiate() as MultiplayerCars
	root.add_child(cars)
	await process_frame
	_check(cars.slots.size() == 2 and cars.previews.size() == 2, "a car card per player")
	var stats_match := true
	for i in 2:
		var v := cars.vehicle_of(i)
		var wanted: Array[int] = []
		var names: Array = VehicleCatalog.STAT_RANGES.keys()
		var values := VehicleCatalog.primary_stats(v.stats)
		for k in names.size():
			wanted.append(VehicleCatalog.rating(names[k], values[k]))
		stats_match = stats_match and cars.shown_ratings(i) == wanted
	_check(stats_match, "each card shows its car's four stats")
	var before := int(cars.slots[1].vehicle)
	var right := InputEventJoypadMotion.new()
	right.device = 0
	right.axis = JOY_AXIS_LEFT_X
	right.axis_value = 0.9
	cars._input(right)
	cars._input(right) # still held: no second step
	_check(int(cars.slots[1].vehicle) == posmod(before + 1, VehicleCatalog.all().size()), "a stick push steps P2's car once")
	_check(int(cars.slots[0].vehicle) == VehicleCatalog.index_of(PlayerProfile.get_profile().selected_vehicle), "P1's car didn't move")
	var v1 := cars.vehicle_of(1)
	var ratings_now := cars.shown_ratings(1)
	_check(ratings_now[0] == VehicleCatalog.rating("Top speed", v1.stats.top_speed)
			and ratings_now[3] == VehicleCatalog.rating("Drift", v1.stats.drift), "stats follow the new car")
	cars._input(_joy_button(0, JOY_BUTTON_A))
	_check(bool(cars.slots[1].ready), "A readies P2")
	cars._input(_joy_button(0, JOY_BUTTON_DPAD_RIGHT))
	_check(cars.vehicle_of(1) == v1, "a ready player's car is locked")
	cars._input(_joy_button(0, JOY_BUTTON_B))
	_check(not bool(cars.slots[1].ready), "B: not ready again")
	# License plates: P2 (pad) uses the letter picker, P1 (keyboard) types.
	_check(cars.plate_of(0) == PlayerProfile.get_profile().plate_text and cars.plate_of(1) == "P2", "default plates")
	cars._input(_joy_button(0, JOY_BUTTON_Y))
	_check(cars.is_editing(0), "Y edits P2's plate")
	cars._input(_joy_button(0, JOY_BUTTON_DPAD_RIGHT)) # past the end: a new letter "A"
	cars._input(_joy_button(0, JOY_BUTTON_DPAD_UP)) # A -> B
	cars._input(_joy_button(0, JOY_BUTTON_DPAD_UP)) # B -> C
	_check(cars.plate_of(1) == "P2C", "picker adds and changes letters (%s)" % cars.plate_of(1))
	cars._input(_joy_button(0, JOY_BUTTON_DPAD_LEFT))
	cars._input(_joy_button(0, JOY_BUTTON_X))
	_check(cars.plate_of(1) == "PC", "X deletes the letter under the cursor (%s)" % cars.plate_of(1))
	cars.step_vehicle(0, 1)
	_check(cars.vehicle_of(1) == v1, "the car doesn't change while editing")
	cars._input(_joy_button(0, JOY_BUTTON_A))
	_check(not cars.is_editing(0) and not bool(cars.slots[1].ready), "A finishes the plate (not ready yet)")
	cars._input(_key(KEY_TAB))
	_check(cars.is_editing(-1), "Tab edits P1's plate")
	for i in 8:
		cars._input(_key(KEY_BACKSPACE))
	for ch in "zap 9!":
		var e := _key(KEY_NONE)
		e.unicode = ch.unicode_at(0)
		cars._input(e)
	cars._input(_key(KEY_ENTER))
	_check(cars.plate_of(0) == "ZAP 9" and PlayerProfile.get_profile().plate_text == "ZAP 9", "P1 types a plate, saved to the profile (%s)" % cars.plate_of(0))
	cars._input(_joy_button(0, JOY_BUTTON_A))
	cars._input(_key(KEY_ENTER))
	_check(cars.all_ready() and cars.confirm_banner.visible and GameSession.mp_plates.is_empty(), "everyone ready: ALL READY banner, not moving on yet")
	cars._input(_joy_button(0, JOY_BUTTON_START))
	_check(GameSession.mp_vehicles.size() == 2 and GameSession.mp_vehicles[1] == v1.id, "final confirm: cars stored, on to setup")
	_check(GameSession.mp_plates == PackedStringArray(["ZAP 9", "PC"]), "and the plates (%s)" % [GameSession.mp_plates])
	cars.queue_free()
	await process_frame

	_current = "setup"
	var setup := (load(SETUP) as PackedScene).instantiate() as MultiplayerSetup
	root.add_child(setup)
	await process_frame
	setup.set_mode(false)
	var labels: Array = setup.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text)
	_check(labels.has("NPCs") and labels.has("NPC difficulty") and not labels.has("AI rivals"), "rows say NPCs / NPC difficulty")
	_check(not labels.any(func(t: String) -> bool: return t.begins_with("No coins")), "no 'No coins or records' line")
	setup.set_ai_rivals(false)
	_check(not setup._difficulty_row.visible, "NPC difficulty hidden with NPCs off")
	_check(not setup.elimination_allowed(), "Elimination needs NPCs")
	setup.set_race_type(1)
	_check(setup.selected_mode() == RaceConfig.Mode.VERSUS, "so Elimination falls back to Standard without AI")
	setup.set_ai_rivals(true)
	setup.set_race_type(1)
	_check(setup.selected_mode() == RaceConfig.Mode.ELIMINATION and setup._difficulty_row.visible, "with NPCs it's allowed")
	_check(setup._note.text.contains("knocked out"), "and the screen explains Elimination")
	setup.set_race_type(0)
	setup.set_races(3)
	setup.next()
	var s := GameSession.series
	_check(s != null and s.is_series() and s.race_count() == 3 and s.is_multiplayer(), "Versus, 3 races: a 3-race split-screen series")
	_check(GameSession.versus_template != null and GameSession.versus_template.is_multiplayer()
			and GameSession.versus_template.player_vehicle_ids[1] == v1.id
			and GameSession.versus_template.player_plates[1] == "PC", "with both players, their cars and plates")
	setup.set_races(1)
	setup.next()
	_check(GameSession.series == null and GameSession.versus_template.is_multiplayer(), "1 race: no series")
	setup.set_mode(true)
	setup.next()
	_check(GameSession.setup_mode == RaceConfig.Mode.GRAND_PRIX, "Grand Prix goes to the cup screen")
	setup.queue_free()
	await process_frame
	var again := (load(CONNECT) as PackedScene).instantiate() as MultiplayerConnect
	root.add_child(again)
	await process_frame
	_check(again.devices == [-1, 0] and not again.is_ready(-1), "back to connecting: the same players, not ready")
	again.queue_free()
	await process_frame


# --- races ---------------------------------------------------------------------

func _test_views(players: int) -> void:
	_current = "%dP views" % players
	print("- %d player split screen" % players)
	var race := await _start(_mp_config(players))
	var split := race.split
	_check(split != null, "a split screen is built")
	if split == null:
		await _end(race)
		return
	_check(race.players.size() == players and race.racers.size() == 8, "%d humans + AI make 8 cars" % players)
	_check(split.views.size() == players and split.cameras.size() == players and split.huds.size() == players,
			"one view, camera and HUD per player")
	_check(split.view_count() == (4 if players == 3 else players), "view count (%d)" % split.view_count())
	_check((split.spectator != null) == (players == 3), "spectator view only for 3 players")
	var size := race.get_viewport().get_visible_rect().size
	var rects := SplitScreen.view_rects(players, size)
	var placed := true
	for i in split.view_count():
		placed = placed and split.view_rect(i).is_equal_approx(rects[i])
	_check(placed, "views cover their rects")
	var distinct := true
	for i in players:
		distinct = distinct and split.cameras[i].target == race.players[i].vehicle
		distinct = distinct and split.cameras[i].cull_mask == SplitScreen.camera_mask(i)
		distinct = distinct and race.players[i].vehicle.input_prefix == StringName("p%d_" % (i + 1))
		distinct = distinct and split.huds[i].racer == race.players[i]
	_check(distinct, "each view follows, masks and reads its own player")
	_check(race.camera == split.cameras[0] and race.race_hud == split.huds[0], "race.camera / race_hud are P1's")
	var cams_ok := true
	for cam in split.cameras:
		cams_ok = cams_ok and cam.profiles.size() == 3 and cam.rear_view != null and cam.allow_look_back
	_check(cams_ok, "every player camera has Far, Close and Rear views")
	if split.spectator != null:
		_check(not split.spectator.allow_look_back, "the spectator never looks back")
	_check(VehicleCosmetics.get_plate_text(race.players[1].vehicle) == "PL-2"
			and VehicleCosmetics.get_plate_text(race.player.vehicle) == PlayerProfile.get_profile().plate_text,
			"cars carry the plates from the car screen (P1: their own)")
	var map := split.minimap
	var map_center := map.get_global_rect().get_center()
	if players >= 3:
		_check(map_center.distance_to(size * 0.5) < 2.0, "3-4P: minimap in the centre (%s)" % map_center)
	else:
		_check(absf(map_center.y - size.y * 0.5) < 2.0 and map_center.x > size.x * 0.7, "2P: minimap at the right end of the divider (%s)" % map_center)
	_check(map.arrow_count() == players, "one minimap arrow per player")
	var hidden := true
	for hud in split.huds:
		hidden = hidden and not hud.minimap.is_visible_in_tree()
	_check(hidden, "the per-view minimaps are hidden")
	_check(race.wrong_way_signs.size() == players and race.weapon_manager._reticles.size() == players,
			"a wrong-way sign and lock-on ring per player")
	var sign_layer := true
	for i in players:
		for mesh in race.wrong_way_signs[i].find_children("*", "VisualInstance3D", true, false):
			sign_layer = sign_layer and (mesh as VisualInstance3D).layers == SplitScreen.private_layer(i)
	_check(sign_layer, "signs are on their owner's private layer")
	var tags_ok := true
	for i in players:
		var tag := race.players[i].vehicle.find_children("*", "Label3D", false, false)
		tags_ok = tags_ok and tag.size() == 1 and (tag[0] as Label3D).text == "P%d" % (i + 1) \
				and (tag[0] as Label3D).layers == SplitScreen.tag_layer(i)
	_check(tags_ok, "every player has a P-tag hidden from themselves")
	if players == 3:
		var tv := split.spectator
		_check(tv.shown != null and tv.caption != null and tv.caption.text.begins_with("LIVE"), "the spectator shows someone (%s)" % (tv.caption.text if tv.caption else ""))
		var first := tv.shown
		for i in int(SpectatorCamera.SHOT_TIME * 60.0) + 10:
			await physics_frame
		_check(tv._cuts >= 2, "and cuts to another shot after a while")
	await _end(race)


func _test_humans_only() -> void:
	_current = "humans only"
	print("- humans-only race")
	var race := await _start(_mp_config(2, false))
	_check(race.racers.size() == 2, "AI off: just the two players (%d cars)" % race.racers.size())
	_check(race.player != null and race.player.racer_id == RaceConfig.PLAYER_ID and race.players[1].racer_id == -2,
			"ids -1 and -2")
	await _end(race)


func _test_full_race() -> void:
	_current = "4P race"
	print("- 4 player race to the results (autopilot)")
	var profile := PlayerProfile.get_profile()
	var coins_before := profile.coins
	var config := _mp_config(4)
	config.track_name = "Test Circuit"
	var race := await _start(config, true)
	var finished_signals := [0]
	var all_done := [false]
	race.player_finished.connect(func(_r: RaceProgress) -> void: finished_signals[0] += 1)
	race.all_players_finished.connect(func() -> void: all_done[0] = true)
	var frames := 0
	while not all_done[0] and frames < 60 * 240:
		await physics_frame
		frames += 1
	_check(all_done[0], "every player finished (%.0f s)" % (frames / 60.0))
	_check(finished_signals[0] == 4, "player_finished once per player (%d)" % finished_signals[0])
	await process_frame
	await process_frame
	_check(race.split.results.visible, "the shared results open")
	_check(race.split.results.players_box.visible and race.split.results.players_box.get_child_count() == 4,
			"with a line per player")
	var any_open := false
	for hud in race.split.huds:
		any_open = any_open or hud.is_results_visible()
	_check(not any_open, "the per-view results stay closed")
	_check(race.reward_summary.is_empty() and PlayerProfile.get_profile().coins == coins_before, "no coins paid")
	_check(PlayerProfile.get_profile().best_for("Test Circuit", 1).is_empty(), "no personal bests recorded")
	_check(race.split.results.menu_button.text == "Car select", "the menu button goes back to car select")
	await _end(race)


func _test_grand_prix() -> void:
	_current = "2P grand prix"
	print("- 2 player Grand Prix (in memory only)")
	# A single-player save that must survive.
	var solo := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster)
	solo.save()
	var saved_text := FileAccess.get_file_as_string(TEST_SAVE)
	var c := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster,
			VehicleCatalog.all()[0].id, PackedInt32Array([-1, 0]), PackedStringArray([VehicleCatalog.all()[0].id, VehicleCatalog.all()[1].id]))
	_check(c.is_multiplayer() and c.next_grid.size() == 8 and c.next_grid.has(-2), "both humans on the grid (%s)" % [c.next_grid])
	_check(not c.save(), "a split-screen championship refuses to save")
	var config := c.make_race_config()
	_check(config.is_multiplayer() and config.player_vehicle_ids.size() == 2, "race configs carry the players")
	config.total_laps = 1
	var race := await _start(config, true)
	var frames := 0
	while race.state != RaceManager.State.FINISHED and frames < 60 * 240:
		await physics_frame
		frames += 1
	_check(c.race_index == 1 and c.results.size() == 1, "race 1 recorded")
	var order: Array = c.results[0]
	_check(order.has(-1) and order.has(-2) and order.size() == 8, "both players ranked (%s)" % [order])
	_check(int(c.points.get(-1, 0)) + int(c.points.get(-2, 0)) > 0, "players scored points")
	_check(FileAccess.get_file_as_string(TEST_SAVE) == saved_text, "the single-player save is untouched")
	await process_frame
	await process_frame
	_check(race.split.results.standings_box.visible, "championship standings on the results")
	await _end(race)
	var ai_off := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster,
			"", PackedInt32Array([-1, 0, 1]), PackedStringArray(), false)
	_check(ai_off.next_grid == [-3, -2, -1], "humans-only Grand Prix grid (%s)" % [ai_off.next_grid])


func _test_series() -> void:
	_current = "versus series"
	print("- Versus series of 2 races (track screen between races)")
	var solo := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster)
	solo.save()
	var saved_text := FileAccess.get_file_as_string(TEST_SAVE)
	GameSession.split_screen = false
	var template := RaceConfig.new()
	template.mode = RaceConfig.Mode.VERSUS
	template.total_laps = 1
	template.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	template.vehicle_id = VehicleCatalog.all()[0].id
	GameSession.begin_versus(self, template, 2, "normal")
	var s := GameSession.series
	_check(s != null and s.race_count() == 2 and s.series_mode == RaceConfig.Mode.VERSUS and not s.is_multiplayer(),
			"a single-player 2-race series")
	var tracks := (load(TRACKS) as PackedScene).instantiate() as TrackSelect
	root.add_child(tracks)
	await process_frame
	_check(tracks.title_text() == "VERSUS  -  RACE 1 OF 2", "the track screen says race 1 of 2 (%s)" % tracks.title_text())
	tracks.pick(0)
	tracks.queue_free()
	var config := GameSession.current
	_check(config != null and config.championship == s and config.mode == RaceConfig.Mode.VERSUS, "picking a track starts race 1 of the series")
	config.track_scene = null # the light test circuit
	var coins_before := PlayerProfile.get_profile().coins
	var race := await _start(config, true)
	var frames := 0
	while race.state != RaceManager.State.FINISHED and frames < 60 * 240:
		await physics_frame
		frames += 1
	_check(s.race_index == 1 and s.results.size() == 1 and int(s.points.get(-1, 0)) > 0, "race 1 recorded with points")
	_check(PlayerProfile.get_profile().coins > coins_before, "single player still earns the race's coins")
	await process_frame
	await process_frame
	_check(race.race_hud.get_continue_text() == "Next race: pick a track", "results offer the next track (%s)" % race.race_hud.get_continue_text())
	GameSession.series = null
	race.continue_after_results()
	_check(GameSession.series == s, "continue goes back to the track screen for the series")
	await _end(race)
	var next_tracks := (load(TRACKS) as PackedScene).instantiate() as TrackSelect
	root.add_child(next_tracks)
	await process_frame
	_check(next_tracks.title_text() == "VERSUS  -  RACE 2 OF 2", "now race 2 of 2")
	_check(next_tracks.random_card != null and not next_tracks.random_card.disabled, "there's a RANDOM card")
	var random_ok := true
	for i in 20:
		var t := next_tracks.random_track()
		var at := next_tracks.track_names.find(t)
		random_ok = random_ok and at != -1 and not next_tracks.cards[at].disabled and t != s.gp.track_names[0]
	_check(random_ok, "RANDOM picks built tracks not raced yet in the series")
	next_tracks.pick(1)
	next_tracks.queue_free()
	var config2 := GameSession.current
	_check(config2.track_name == s.gp.track_names[1] and s.gp.track_names.size() == 2, "race 2 on the newly picked track")
	_check(config2.grid_order == s.next_grid, "the grid follows race 1's result")
	config2.track_scene = null
	var race2 := await _start(config2, true)
	frames = 0
	while race2.state != RaceManager.State.FINISHED and frames < 60 * 240:
		await physics_frame
		frames += 1
	_check(s.is_complete(), "the series is complete after race 2")
	await process_frame
	await process_frame
	_check(race2.race_hud.get_results_placement().contains("SERIES"), "the results call the series (%s)" % race2.race_hud.get_results_placement())
	_check(FileAccess.get_file_as_string(TEST_SAVE) == saved_text, "the Grand Prix save is untouched")
	race2.continue_after_results()
	_check(GameSession.series == null, "finishing the series leaves the track screen behind")
	await _end(race2)
	Championship.clear_save()
