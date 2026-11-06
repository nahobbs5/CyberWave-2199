extends SceneTree
## UI / HUD headless checks: fonts and theme, the race info panel and
## position-change cue, the speed + drift panel states, item slots (active /
## stored / empty, pickup and use animations), the results screen (placement,
## stats, rewards adding up, coin count-up, skipping the animation), the
## controls (pause menu only, never on the HUD), the coin counter and that
## the HUD panels don't overlap at
## 1280x720 with HUD scale 1.0 and 1.5. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_ui.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const FIREWALL := "res://resources/weapons/firewall.tres"
const RAILGUN := "res://resources/weapons/railgun.tres"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_ui_profile.json"
	GameSettings.path = "user://test_ui_settings.cfg"
	Championship.save_path = "user://test_ui_gp.json"
	_run_all.call_deferred()


func _run_all() -> void:
	_fresh()
	GameSession.scene_changes_enabled = false
	_test_fonts()
	_test_ordinals()
	_test_rival_cars_rules()
	await _test_credits()
	await _test_cups()
	_test_stacks_rename()
	await _test_practice_minimap()
	await _run("HUD in a race", _test_hud, _config(3), false)
	await _run("layout at HUD scale 1.0 and 1.5", _test_layout, _config(3), false)
	var cars := _config(3)
	cars.rival_vehicles = PackedStringArray(["aurora_gt", "orbiter", "riviera_88", "valkyrie_r", "nexus_x", "cipher_evo", "empyrean_s"])
	await _run("rivals drive their own cars", _test_rival_cars, cars, false)
	var flags := _config(1)
	flags.track_name = "Six Flags New Orleans"
	flags.track_scene = load("res://scenes/tracks/six_flags_new_orleans.tscn")
	flags.difficulty = load("res://resources/ai/hard.tres") as AIDifficulty
	await _run("ramp tricks", _test_tricks, flags, false)
	await _run("results screen", _test_results, _config(1), true)
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
	Championship.clear_save()
	GameSession.current = null


func _config(laps: int) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = laps
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
		await process_frame


# --- no scene ------------------------------------------------------------------------

func _test_fonts() -> void:
	_current = "fonts"
	print("- fonts and theme")
	_check(ProjectSettings.get_setting("gui/theme/custom") == "res://resources/ui/cyberwave_theme.tres", "project theme set")
	var theme := load("res://resources/ui/cyberwave_theme.tres") as Theme
	_check(theme != null and theme.default_font != null and theme.default_font.get_font_name().begins_with("Rajdhani"),
			"Rajdhani is the default font")
	var heading := UIStyle.heading_font()
	_check(heading != null and heading.get_font_name().begins_with("Oxanium"), "Oxanium for headings")
	_check(UIStyle.bold_font() != null, "Rajdhani Bold for stats")
	for f in ["Oxanium-OFL.txt", "Rajdhani-OFL.txt"]:
		_check(FileAccess.file_exists("res://assets/fonts/" + f), "%s shipped" % f)


func _test_ordinals() -> void:
	_current = "ordinals"
	var got: PackedStringArray = []
	for n in [1, 2, 3, 4, 8, 11, 12, 13, 21, 22]:
		got.append(ResultsScreen.ordinal(n))
	_check(", ".join(got) == "1ST, 2ND, 3RD, 4TH, 8TH, 11TH, 12TH, 13TH, 21ST, 22ND", "placement ordinals (%s)" % ", ".join(got))


func _test_rival_cars_rules() -> void:
	_current = "rival cars"
	print("- rival cars (no scene)")
	var ids := RaceConfig.random_vehicles(7)
	var ok := ids.size() == 7
	for id in ids:
		ok = ok and VehicleCatalog.by_id(id).id == id
	_check(ok, "7 random cars from the catalogue (%s)" % [ids])
	var c := Championship.create(load("res://resources/grand_prix/american_circuit.tres"), "normal", true,
			load("res://resources/racers/rival_roster.tres"))
	var first := c.make_race_config().rival_vehicles
	c.record_race(_ids([0, 1, 2, 3, 4, 5, 6, -1]))
	_check(first.size() == 7 and c.make_race_config().rival_vehicles == first, "Grand Prix keeps the cars race to race")
	var data := c.to_dict()
	_check(Championship.from_dict(data).rival_vehicles == first, "cars survive save / load")
	data.erase("vehicles")
	_check(Championship.from_dict(data).rival_vehicles.size() == 7, "an older save gets cars on load")


func _ids(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


func _test_credits() -> void:
	_current = "credits"
	print("- credits")
	var credits := (load("res://scenes/menu/credits.tscn") as PackedScene).instantiate() as Credits
	root.add_child(credits)
	await _frames(2)
	var text := credits.get_text()
	for wanted in ["Nathan Hobbs", "ikoliks_aj", "Wings of Hope", "freesound_community", "Oxanium", "Rajdhani", "Poly Haven", "Godot"]:
		_check(text.contains(wanted), "credits mention %s" % wanted)
	_check(credits.back_button != null and credits.back_button.has_focus(), "Back is focused")
	var labels := credits.find_children("*", "Label", true, false).filter(func(n: Node) -> bool: return (n as Label).text.contains("Poly Haven"))
	_check(not labels.is_empty(), "the credits are on screen")
	credits.queue_free()
	await process_frame


func _test_cups() -> void:
	_current = "cups"
	print("- cup and track screens")
	var poly := TrophyIcon.usa_polygon(Rect2(0, 0, 100, 60))
	_check(poly.size() >= 60 and not Geometry2D.triangulate_polygon(poly).is_empty(), "USA map is a valid shape (%d points)" % poly.size())
	var american := GrandPrixData.cup_by_path(GrandPrixData.CUPS[0])
	_check(american.display_name == "American Cup" and american.emblem == "usa", "American Cup with the USA trophy")
	_check(GrandPrixData.cup_by_path(GrandPrixData.CUPS[1]).display_name == "World Cup", "World Cup")
	# Versus: cup, then track.
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	GameSession.cup_path = ""
	GameSession.track_name = ""
	var cups := (load("res://scenes/menu/cup_select.tscn") as PackedScene).instantiate() as CupSelect
	root.add_child(cups)
	await _frames(2)
	var trophy := cups.cards[0].find_child("Trophy", true, false) as TrophyIcon
	_check(trophy != null and trophy.emblem == "usa" and not trophy.locked, "the American card shows its trophy")
	_check(cups.cards[0].has_focus(), "first cup focused")
	cups.pick(0)
	_check(GameSession.cup_path == GrandPrixData.CUPS[0], "Versus: cup picked")
	cups.queue_free()
	var tracks := (load("res://scenes/menu/track_select.tscn") as PackedScene).instantiate() as TrackSelect
	root.add_child(tracks)
	await _frames(2)
	_check(tracks.cards.size() == 3, "three track cards")
	var outlines_ok := true
	for card in tracks.cards:
		var thumb := card.find_child("Thumbnail", true, false) as TrackThumbnail
		outlines_ok = outlines_ok and thumb != null and thumb.outline.size() >= 3
	_check(outlines_ok, "every track card has its outline")
	tracks.pick(0)
	_check(GameSession.track_name == "Vegas Overdrive", "picking a track: Vegas is first (%s)" % GameSession.track_name)
	tracks.queue_free()
	var setup := (load("res://scenes/menu/race_setup.tscn") as PackedScene).instantiate() as RaceSetup
	root.add_child(setup)
	await _frames(2)
	var config := setup.make_config()
	_check(config.track_name == "Vegas Overdrive" and config.track_scene.resource_path.ends_with("vegas_overdrive.tscn"),
			"race setup races the picked track")
	_check(setup.summary_text() == "AMERICAN CUP  ·  VEGAS OVERDRIVE", "setup shows the cup and track (%s)" % setup.summary_text())
	setup.queue_free()
	GameSession.cup_path = ""
	GameSession.track_name = ""
	await process_frame


func _test_practice_minimap() -> void:
	_current = "practice minimap"
	print("- practice minimap")
	var practice := (load("res://scenes/free_drive.tscn") as PackedScene).instantiate()
	root.add_child(practice)
	await _frames(3)
	var map := practice.get("minimap") as Minimap
	_check(map != null and map.is_visible_in_tree() and map.track != null, "Practice has a minimap")
	if map != null:
		var view := map.get_viewport().get_visible_rect().size
		var rect := map.get_global_rect()
		_check(rect.position.x > view.x * 0.5 and rect.position.y > view.y * 0.5, "bottom right (%s)" % rect)
		var car := practice.get("car") as VehicleController
		_check(Rect2(Vector2.ZERO, map.size).has_point(map.world_to_map(car.global_position)), "your car is on it")
		_check(map.visible_racers().is_empty(), "no rivals in Practice")
	practice.queue_free()
	await process_frame


func _test_stacks_rename() -> void:
	_current = "rename"
	_check(TrackCatalog.names().has("The Stacks") and not TrackCatalog.names().has("The Stacks Grand Prix"), "the track is just The Stacks")
	var p := PlayerProfile.get_profile()
	p.personal_bests = {"The Stacks Grand Prix|3": {"race": 200.0, "lap": 65.0}}
	p.save()
	PlayerProfile._instance = null
	var loaded := PlayerProfile.get_profile()
	_check(loaded.best_for("The Stacks", 3).get("race", 0.0) == 200.0 and not loaded.personal_bests.has("The Stacks Grand Prix|3"),
			"old Stacks best times carry over")
	_fresh()


# --- races ---------------------------------------------------------------------------

func _test_tricks(race: RaceManager) -> void:
	var keys := InputMap.action_get_events(&"trick")
	var has_e := keys.any(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_E or e is InputEventKey and (e as InputEventKey).keycode == KEY_E)
	var has_x := keys.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_X)
	_check(has_e and has_x, "Trick is E / gamepad X")
	var car := race.player.vehicle
	var trick := car.trick
	_check(trick != null and not trick.try_trick(), "no trick without a ramp")
	# Without a trick: ramp, jump, land -> no boost.
	var landed := trick.tricks_landed
	trick.on_ramp()
	car.teleport(car.global_transform.translated(Vector3.UP * 3.0))
	await _physics(90)
	_check(trick.tricks_landed == landed and car.boost_label != "Trick", "no trick, no boost")
	# With a trick.
	trick.on_ramp()
	car.teleport(car.global_transform.translated(Vector3.UP * 4.0))
	await _physics(3)
	_check(car.grounded_wheels == 0 and trick.try_trick() and car.is_tricking(), "a trick starts in the air after a ramp")
	await _physics(12)
	var mid := absf(trick.body_angle())
	_check(mid > 0.3, "the car spins (%.2f rad)" % mid)
	var got_boost := false
	for i in 120:
		await physics_frame
		if car.is_boosting() and car.boost_label == "Trick":
			got_boost = true
			break
	_check(got_boost and trick.tricks_landed == landed + 1, "landing gives the Trick boost")
	_check(absf(trick.body_angle()) < 0.01 and not car.is_tricking(), "spin finished, body back to normal")
	# AI on Hard trick off the ramps during a lap.
	var ai_tricks := 0
	var frames := 0
	while frames < 60 * 120 and ai_tricks == 0:
		await physics_frame
		frames += 1
		if frames % 60 == 0:
			ai_tricks = 0
			for racer in race.racers:
				if not racer.is_player:
					ai_tricks += racer.vehicle.trick.tricks_landed
	_check(ai_tricks > 0, "AI land tricks off the ramps (%d after %.0f s)" % [ai_tricks, frames / 60.0])


func _physics(count: int) -> void:
	for i in count:
		await physics_frame


func _test_rival_cars(race: RaceManager) -> void:
	var wrong: PackedStringArray = []
	for racer in race.racers:
		if racer.is_player:
			continue
		var want := VehicleCatalog.by_id(race.config.rival_vehicles[racer.racer_id])
		if racer.vehicle.stats != want.stats:
			wrong.append("%s stats" % racer.display_name)
		var ai := race.get_ai(racer)
		if ai == null or ai.line != race.line_for(want.stats):
			wrong.append("%s line" % racer.display_name)
	_check(wrong.is_empty(), "each rival drives its series car with a line for it (%s)" % ", ".join(wrong))
	var fast := VehicleCatalog.by_id("valkyrie_r").stats
	var slow := VehicleCatalog.by_id("riviera_88").stats
	var a := race.line_for(fast)
	var b := race.line_for(slow)
	_check(a.points == race.line.points and b.points == race.line.points, "per-car lines share the base path")
	_check(a.speeds != b.speeds, "but have their own speeds")
	_check(race.line_for(fast) == a, "lines are cached per car")
	# A few seconds of racing: everyone moves.
	var start := {}
	for racer in race.racers:
		start[racer] = racer.vehicle.global_position
	for i in 240:
		await physics_frame
	var stuck: PackedStringArray = []
	for racer in race.racers:
		if not racer.is_player and racer.vehicle.global_position.distance_to(start[racer]) < 20.0:
			stuck.append(racer.display_name)
	_check(stuck.is_empty(), "every rival gets going (%s)" % ", ".join(stuck))


func _test_hud(race: RaceManager) -> void:
	var hud := race.race_hud
	var proto := race.prototype_hud
	await _frames(2)
	var p := race.player
	_check(hud.get_position_text() == "POS %d / 8" % p.position, "position panel (%s)" % hud.get_position_text())
	_check(hud.info.lap_value.text == "1 / 3", "lap (%s)" % hud.info.lap_value.text)
	_check(hud.info.time_value.text == RaceProgress.format_time(race.race_time)
			or hud.info.time_value.text.length() == 7, "race time shown (%s)" % hud.info.time_value.text)
	_check(hud.get_standings_text().split("\n").size() == 8, "standings list all eight")
	var cards := hud.find_children("*", "ControlsCard", true, false) + proto.find_children("*", "ControlsCard", true, false)
	_check(cards.is_empty(), "no controls on the HUD")
	var pause := race.get_node_or_null("PauseMenu")
	if pause == null:
		pause = race.find_children("*", "PauseMenu", true, false).front() if not race.find_children("*", "PauseMenu", true, false).is_empty() else null
	_check(pause != null and not pause.find_children("*", "ControlsCard", true, false).is_empty(), "controls are in the pause menu")
	_check(hud.info.coin_label.text == "0" and hud.info.coin_icon.is_visible_in_tree()
			and hud.info.coin_icon.get_global_rect().position.x > hud.info.coin_label.get_global_rect().end.x,
			"coins: the count with the coin symbol on its right (%s)" % hud.info.coin_label.text)

	# Position change: pretend we were a place behind.
	await _settle(race)
	var gains := hud.info.gains
	hud._last_position = p.position + 1
	await _frames(2)
	_check(hud.info.gains == gains + 1 and hud.info.pos_cue.text == "POSITION UP!", "gaining a place pulses and says POSITION UP!")
	var losses := hud.info.losses
	hud._last_position = maxi(p.position - 1, 1) if p.position > 1 else 0
	if p.position > 1:
		await _frames(2)
		_check(hud.info.losses == losses + 1, "losing a place pulses too")

	# Speed + drift panel states (driven directly; physics may change them next step).
	var panel := proto.speed_panel
	var car := p.vehicle
	car.drift.direction = 0
	car.boost_time_left = 0.0
	panel._process(0.016)
	_check(panel.get_state_text() == "" and panel.drift_percent.text == "", "idle: no drift state")
	car.drift.direction = 1
	car.drift.charge_time = 2.0
	car.drift.level = 0
	panel._process(0.016)
	_check(panel.get_state_text() == "CHARGING" and panel.drift_percent.text == "50%", "charging shows the percentage (%s)" % panel.drift_percent.text)
	car.drift.charge_time = 2.6
	car.drift.level = 2
	panel._process(0.016)
	_check(panel.get_state_text() == "BOOST READY  -  MAGENTA", "boost ready at a tier (%s)" % panel.get_state_text())
	car.drift.direction = 0
	car.drift.charge_time = 0.0
	car.drift.level = 0
	car.start_boost(2)
	panel._process(0.016)
	_check(panel.get_state_text() == "BOOST  MAGENTA", "boosting (%s)" % panel.get_state_text())
	car.clear_boost()

	# Item slots.
	var items := hud.items
	var inv := car.inventory
	inv.clear()
	await _frames(2)
	_check(items.captions[0].text == "ACTIVE" and items.captions[1].text == "STORED", "active and stored captions")
	_check(items.empties[0].visible and items.empties[1].visible, "empty slots say EMPTY")
	var picks := items.pickup_anims
	inv.add(load(FIREWALL))
	inv.add(load(RAILGUN))
	await _frames(2)
	_check(items.pickup_anims == picks + 2, "pickup animation per item")
	_check(not items.empties[0].visible and items.icons[0].texture != null, "slot shows the item")
	inv.select(1)
	await _frames(12)
	_check(items.panels[1].custom_minimum_size.x > items.panels[0].custom_minimum_size.x
			and items.captions[1].text == "ACTIVE", "the selected slot grows")
	var uses := items.use_anims
	inv.take_selected()
	await _frames(2)
	_check(items.use_anims == uses + 1 and items.empties[1].visible, "using an item puffs it out and empties the slot")
	inv.clear()


func _settle(race: RaceManager) -> void:
	while race.race_time < RaceHUD.POSITION_SETTLE + 0.2:
		await physics_frame


func _test_layout(race: RaceManager) -> void:
	for hud_scale in [1.0, 1.5]:
		HudScaler.apply(race.race_hud, hud_scale)
		HudScaler.apply(race.prototype_hud, hud_scale)
		await _frames(4)
		var hud := race.race_hud
		var panels := {
			"race info": hud.info,
			"standings": hud.standings,
			"items": hud.items,
			"minimap": hud.minimap,
			"speed / drift": race.prototype_hud.speed_panel,
		}
		var view: Vector2 = hud.get_viewport().get_visible_rect().size / float(hud_scale)
		var clashes: PackedStringArray = []
		var off_screen: PackedStringArray = []
		var keys := panels.keys()
		for i in keys.size():
			var a := panels[keys[i]] as Control
			if not a.is_visible_in_tree():
				continue
			var ra := a.get_global_rect()
			if not Rect2(Vector2.ZERO, view).grow(1.0).encloses(ra):
				off_screen.append("%s %s" % [keys[i], ra])
			for j in range(i + 1, keys.size()):
				var b := panels[keys[j]] as Control
				if b.is_visible_in_tree() and ra.intersects(b.get_global_rect()):
					clashes.append("%s / %s" % [keys[i], keys[j]])
		_check(clashes.is_empty(), "scale %.1f: HUD panels don't overlap (%s)" % [hud_scale, ", ".join(clashes)])
		_check(off_screen.is_empty(), "scale %.1f: all on screen (%s)" % [hud_scale, ", ".join(off_screen)])
		if hud_scale == 1.0:
			_check(hud.standings.visible, "standings fit at scale 1.0")
	HudScaler.apply(race.race_hud, 1.0)
	HudScaler.apply(race.prototype_hud, 1.0)


func _test_results(race: RaceManager) -> void:
	var hud := race.race_hud
	var frames := 0
	while not hud.is_results_visible() and frames < 60 * 150:
		await physics_frame
		frames += 1
	_check(hud.is_results_visible(), "results shown after one lap")
	if not hud.is_results_visible():
		return
	var results := hud.results
	var p := race.player
	_check(results.is_animating(), "results animate in")
	_check(hud.get_results_title() == "VERSUS / TEST CIRCUIT", "mode / track line (%s)" % hud.get_results_title())
	_check(results.placement.text == "%s PLACE" % ResultsScreen.ordinal(p.finish_position), "placement (%s)" % results.placement.text)
	var expected_sub := "VICTORY!" if p.finish_position == 1 else ("PODIUM!" if p.finish_position <= 3 else "RACE COMPLETE")
	_check(results.subtitle.text == expected_sub, "subtitle for P%d (%s)" % [p.finish_position, results.subtitle.text])
	_check(results.time_value.text == RaceProgress.format_time(p.finish_time), "race time tile")
	_check(results.best_value.text == RaceProgress.format_time(p.best_lap), "best lap tile")
	var r := race.reward_summary
	var sum := 0
	for line in r.lines:
		sum += int(line[1])
	_check(sum == r.total and r.total > 0, "rewards breakdown adds up (%d = %d)" % [sum, r.total])
	results.skip_animation()
	await _frames(1)
	_check(not results.is_animating(), "skipping ends the animation")
	_check(results.get_coins_shown() == "+%d" % r.total, "coins counted up to the total (%s)" % results.get_coins_shown())
	_check(results.best_banner.visible, "first race is a personal best")
	var player_rows := 0
	for i in results._rows.size():
		var style := results._rows[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style.border_color == UIStyle.MAGENTA:
			player_rows += 1
			_check((results._cells[i][1] as Label).text == "You", "your row is highlighted")
	_check(player_rows == 1, "exactly one highlighted row")
	# Other placements' wording.
	p.finish_position = 5
	_check(results.placement_subtitle() == "RACE COMPLETE", "P5: race complete")
	p.finish_position = 2
	_check(results.placement_subtitle() == "PODIUM!", "P2: podium")
	await _frames(100)
	_check(not hud._continue_button.disabled and results.continue_button.has_focus(), "Race again focused once enabled")
