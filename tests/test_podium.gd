extends SceneTree
## Podium ceremony checks (GDD 11.7a): when it shows, who stands on it, the
## stage (cars, plates, platforms, crown), skipping, continuing to the
## results, split-screen colours, and a real single Versus race ending on it.
## Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_podium.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const GP1 := "res://resources/grand_prix/american_circuit.tres"
const ROSTER := "res://resources/racers/rival_roster.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_podium_profile.json"
	GameSettings.path = "user://test_podium_settings.cfg"
	Championship.save_path = "user://test_podium_gp.json"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	GameSession.scene_changes_enabled = false
	await _test_when()
	_test_sequence()
	await _test_grand_prix_ceremony()
	await _test_split_screen()
	await _test_versus_race()
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


func _start(config: RaceConfig, autopilot: bool = false) -> RaceManager:
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	race.player_uses_autopilot = autopilot
	race.auto_start = autopilot
	root.add_child(race)
	race.camera.save_preference = false
	await process_frame
	await process_frame
	return race


func _end(race: RaceManager) -> void:
	race.queue_free()
	await process_frame
	await process_frame


## A cup championship for this race's field, every race recorded with
## `order` (ids, winner first).
func _finished_cup(order: Array[int], devices: PackedInt32Array = PackedInt32Array()) -> Championship:
	var c := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster,
			PlayerProfile.DEFAULT_VEHICLE, devices)
	while not c.is_complete():
		c.record_race(order)
	return c


func _ceremony(race: RaceManager) -> PodiumCeremony:
	for child in race.get_children():
		if child is PodiumCeremony:
			return child
	return null


func _press_accept() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ENTER
		event.keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


# --- tests -------------------------------------------------------------------

func _test_when() -> void:
	_current = "when it shows"
	print("- " + _current)
	var race := await _start(_config(RaceConfig.Mode.VERSUS))
	_check(PodiumCeremony.wants_podium(race), "a single Versus race ends on the podium")
	var ids := PodiumCeremony.podium_ids(race)
	var standings := race.get_standings()
	_check(ids.size() == 3 and ids[0] == standings[0].racer_id and ids[2] == standings[2].racer_id,
			"a single race uses its own order")
	var c := Championship.create(load(GP1) as GrandPrixData, "normal", true, load(ROSTER) as RivalRoster)
	race.championship = c
	_check(not PodiumCeremony.wants_podium(race), "no podium before the cup's last race")
	var order: Array[int] = [3, 1, RaceConfig.PLAYER_ID, 0, 2, 4, 5, 6]
	while not c.is_complete():
		c.record_race(order)
	_check(PodiumCeremony.wants_podium(race), "the cup's last race ends on the podium")
	ids = PodiumCeremony.podium_ids(race)
	_check(ids == [3, 1, RaceConfig.PLAYER_ID], "a cup uses the standings (%s)" % [ids])
	var template := _config(RaceConfig.Mode.ELIMINATION)
	var series := Championship.create_series(2, template, "normal", load(ROSTER) as RivalRoster)
	race.championship = series
	series.record_race(order)
	_check(not PodiumCeremony.wants_podium(race), "no podium mid-set")
	series.record_race([5, 3, 1, RaceConfig.PLAYER_ID, 0, 2, 4, 6] as Array[int])
	_check(PodiumCeremony.wants_podium(race), "the set's last race ends on the podium (Elimination set too)")
	_check(PodiumCeremony.podium_ids(race)[0] == 3, "a set uses its points, not the last race")
	await _end(race)
	race = await _start(_config(RaceConfig.Mode.ELIMINATION))
	_check(not PodiumCeremony.wants_podium(race), "no podium after a single Elimination race")
	PodiumCeremony.instant = true
	_check(PodiumCeremony.open_then(race, race.race_hud.results) == null and race.race_hud.is_results_visible(),
			"tests can skip straight to the results")
	PodiumCeremony.instant = false
	await _end(race)


func _test_grand_prix_ceremony() -> void:
	_current = "grand prix ceremony"
	print("- " + _current)
	var race := await _start(_config(RaceConfig.Mode.GRAND_PRIX))
	var c := _finished_cup([RaceConfig.PLAYER_ID, 4, 2, 0, 1, 3, 5, 6] as Array[int])
	race.championship = c
	var ceremony := PodiumCeremony.open_then(race, race.race_hud.results, 0.5)
	_check(ceremony != null and ceremony.grand, "a Grand Prix gets the big ceremony")
	await process_frame
	_check(not ceremony.root.visible, "waits for FINISH! first")
	_check(ceremony.title_text == "CONGRATULATIONS!" and ceremony.mode_text.begins_with("GRAND PRIX"),
			"banner (%s / %s)" % [ceremony.mode_text, ceremony.title_text])
	_check(ceremony.trophy != null and ceremony.trophy.emblem == c.gp.emblem, "the cup's trophy")
	var stage := ceremony.stage
	_check(stage.cars.size() == 3 and stage.platforms.size() == 3, "three cars on three platforms")
	var plates_ok := true
	for i in 3:
		var look: Dictionary = ceremony.entries[i].look
		plates_ok = plates_ok and VehicleCosmetics.get_plate_text(stage.cars[i]) == str(look.plate)
	_check(plates_ok, "each car wears its racer's plate")
	_check(str(ceremony.entries[1].name) == _name_of(race, 4), "2nd is the cup's runner-up")
	_check(ceremony.entries[0].color == UIStyle.MAGENTA and ceremony.entries[1].color == Color.WHITE,
			"the player's name in magenta, rivals in white")
	# Halfway: cars parked, platforms rising, no crown yet.
	for i in 90:
		await process_frame
	_check(not stage.crown.visible and not ceremony.is_prompt_shown(), "no crown or prompt early on")
	_check(not race.race_hud.is_results_visible(), "results wait for the ceremony")
	# Just after 3rd's name is up: 3rd shown, 2nd's platform not yet moving.
	ceremony.time = PodiumStage.name_time(2, true) + PodiumStage.NAME_FADE + 0.01
	ceremony._advance(0.0)
	_check(ceremony.tags[2].modulate.a > 0.99 and ceremony.tags[1].modulate.a == 0.0 and ceremony.tags[0].modulate.a == 0.0,
			"3rd's name shows before 2nd's")
	_check(is_equal_approx(stage.platforms[1].position.y, PodiumStage.LOW) and is_equal_approx(stage.platforms[0].position.y, PodiumStage.LOW),
			"2nd and 1st haven't started rising yet")
	ceremony.time = PodiumStage.name_time(1, true) + PodiumStage.NAME_FADE + 0.01
	ceremony._advance(0.0)
	_check(ceremony.tags[1].modulate.a > 0.99 and ceremony.tags[0].modulate.a == 0.0 and is_equal_approx(stage.platforms[0].position.y, PodiumStage.LOW),
			"then 2nd's name, before 1st rises")
	ceremony.skip()
	await process_frame
	_check(ceremony.is_prompt_shown(), "skipping shows the Continue prompt")
	_check(stage.crown.visible and Vector2(stage.crown.position.x, stage.crown.position.z).distance_to(
			Vector2(PodiumStage.SPOTS[0].x, PodiumStage.SPOTS[0].z)) < 0.01, "the crown floats over the winner")
	var tops: Array[float] = []
	for p in stage.platforms:
		tops.append(p.position.y)
	_check(tops[0] > tops[1] and tops[1] > tops[2], "1st stands highest, then 2nd, then 3rd (%s)" % [tops])
	_check(stage.cars[0].position.y > stage.cars[1].position.y and absf(stage.cars[0].position.z - PodiumStage.SPOTS[0].z) < 0.01,
			"the winner's car is up on its platform")
	_check(ceremony._played_fanfare and ceremony.confetti.size() == 3 and ceremony.confetti[0].emitting,
			"confetti and fanfare")
	var tags_ok := true
	for tag in ceremony.tags:
		tags_ok = tags_ok and tag.modulate.a > 0.9
	_check(tags_ok and (ceremony.tags[0].find_child("Ribbon", true, false) as Label).text == "CUP CHAMPION", "tags and the champion ribbon")
	await _press_accept()
	_check(race.race_hud.is_results_visible(), "Continue opens the results")
	_check(ceremony.is_finished(), "and the ceremony closes")
	for i in 40:
		await process_frame
	_check(not is_instance_valid(ceremony), "then frees itself")
	await _end(race)


## Drive in, then 3rd rises, 3rd's name, 2nd rises, 2nd's name, 1st rises,
## 1st's name, then the crown; nothing overlaps.
func _test_sequence() -> void:
	_current = "sequence"
	print("- " + _current)
	for grand in [true, false]:
		var tl := PodiumStage.timeline(grand)
		var label := "GP" if grand else "Versus"
		var ok := PodiumStage.rise_start(2, grand) >= tl[0]
		for i in [2, 1, 0]:
			ok = ok and PodiumStage.rise_end(i, grand) <= PodiumStage.name_time(i, grand)
			if i > 0:
				ok = ok and PodiumStage.name_time(i, grand) + PodiumStage.NAME_FADE <= PodiumStage.rise_start(i - 1, grand)
		ok = ok and PodiumStage.name_time(0, grand) + PodiumStage.NAME_FADE <= tl[1]
		_check(ok, "%s: drive in, then each place rises and is named in turn" % label)


func _test_split_screen() -> void:
	_current = "split screen"
	print("- " + _current)
	var config := _config(RaceConfig.Mode.VERSUS)
	config.player_devices = PackedInt32Array([-1, 0])
	config.player_vehicle_ids = PackedStringArray(["", PlayerProfile.DEFAULT_VEHICLE])
	var race := await _start(config)
	var p2 := RaceConfig.human_id(1)
	var order: Array[int] = [p2, 0, RaceConfig.human_id(0)]
	for id in race.racers.map(func(r: RaceProgress) -> int: return r.racer_id):
		if not order.has(id):
			order.append(id)
	var series := Championship.create_series(2, config, "normal", load(ROSTER) as RivalRoster)
	series.record_race(order)
	series.record_race(order)
	race.championship = series
	var entries := PodiumCeremony.entries_for(race)
	_check(entries.size() == 3 and entries[0].id == p2, "P2 won the set")
	_check(entries[0].color == SplitScreen.PLAYER_COLORS[1] and entries[2].color == SplitScreen.PLAYER_COLORS[0],
			"players' names use their player colours")
	_check(str(entries[0].look.get("plate", "")) == "P2" and entries[0].look.has("paint"), "P2's car is dressed like on track")
	var ceremony := PodiumCeremony.open_then(race, race.split.results)
	_check(ceremony != null and not ceremony.grand and ceremony.mode_text.begins_with("VERSUS SET"),
			"a set gets the shorter Versus ceremony (%s)" % ceremony.mode_text)
	await process_frame
	ceremony.skip()
	await process_frame
	_check((ceremony.tags[0].find_child("Ribbon", true, false) as Label).text == "SET WINNER", "SET WINNER ribbon")
	await _press_accept()
	_check(race.split.results.visible, "Continue opens the shared results")
	await _end(race)


func _test_versus_race() -> void:
	_current = "versus race"
	print("- " + _current)
	var config := _config(RaceConfig.Mode.VERSUS)
	config.total_laps = 1
	var race := await _start(config, true)
	var frames := 0
	while _ceremony(race) == null and frames < 60 * 150:
		await physics_frame
		frames += 1
	var ceremony := _ceremony(race)
	_check(ceremony != null, "the podium follows the finish")
	if ceremony == null:
		await _end(race)
		return
	_check(not race.race_hud.is_results_visible(), "before the results")
	_check(ceremony.winner_text == "RACE WINNER" and ceremony.duration() < PodiumStage.timeline(true)[3], "shorter single-race ceremony")
	frames = 0
	while not ceremony.is_prompt_shown() and frames < 60 * 14:
		await process_frame
		frames += 1
	_check(ceremony.is_prompt_shown(), "it plays through to the prompt (%d frames)" % frames)
	await _press_accept()
	_check(race.race_hud.is_results_visible(), "then the results")
	await _end(race)


func _name_of(race: RaceManager, id: int) -> String:
	for r in race.racers:
		if r.racer_id == id:
			return r.display_name.to_upper()
	return ""
