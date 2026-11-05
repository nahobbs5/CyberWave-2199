extends SceneTree
## UI / HUD headless checks: fonts and theme, the race info panel and
## position-change cue, the speed + drift panel states, item slots (active /
## stored / empty, pickup and use animations), the results screen (placement,
## stats, rewards adding up, coin count-up, skipping the animation), the
## controls card (first race only) and that the HUD panels don't overlap at
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
	await _run("HUD in a race", _test_hud, _config(3), false)
	await _run("second race: no controls card", _test_controls_seen, _config(3), false)
	await _run("layout at HUD scale 1.0 and 1.5", _test_layout, _config(3), false)
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


# --- races ---------------------------------------------------------------------------

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
	_check(proto.controls_card.visible and PlayerProfile.get_profile().seen_controls, "controls card on the first race, then remembered")

	# Position change: pretend we were a place behind.
	await _settle(race)
	var gains := hud.info.gains
	hud._last_position = p.position + 1
	await _frames(1)
	_check(hud.info.gains == gains + 1 and hud.info.pos_cue.text == "POSITION UP!", "gaining a place pulses and says POSITION UP!")
	var losses := hud.info.losses
	hud._last_position = maxi(p.position - 1, 1) if p.position > 1 else 0
	if p.position > 1:
		await _frames(1)
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


func _test_controls_seen(race: RaceManager) -> void:
	await _frames(2)
	_check(not race.prototype_hud.controls_card.visible, "not shown again once seen")


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
		var view := hud.get_viewport().get_visible_rect().size / hud_scale
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
