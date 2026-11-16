extends SceneTree
## Small trick ramps (GDD 8.7): every race track has at least one jump ramp
## that covers only part of the road (about half), so you choose a side:
## jump or drive past. Every main-road ramp sits inside the road. Then one
## small ramp (The Stacks) is driven: it launches the car, a trick can start
## in the air, its two item boxes float over the lip, and the car lands on
## its wheels.
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_small_ramps.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const FEATURE_SCRIPT := "res://scripts/track/track_feature.gd"
const TRACK_SCRIPT := "res://scripts/track/track_circuit.gd"
## A small ramp covers at most this share of the road.
const SMALL_SHARE := 0.6
const SMALL_MAX_HEIGHT := 1.1

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_small_ramps_profile.json"
	GameSettings.path = "user://test_small_ramps_settings.cfg"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	_test_every_track()
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.total_laps = 1
	config.track_name = "The Stacks"
	config.track_scene = TrackCatalog.scene("The Stacks")
	await _run("drive the Stacks small ramp", _test_launch, config)
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


## Node properties from a scene file without building it.
func _props(state: SceneState, i: int) -> Dictionary:
	var out := {}
	for k in state.get_node_property_count(i):
		out[state.get_node_property_name(i, k)] = state.get_node_property_value(i, k)
	return out


func _script_path(props: Dictionary) -> String:
	var script := props.get("script") as Script
	return script.resource_path if script != null else ""


func _test_every_track() -> void:
	_current = "every race track"
	print("- " + _current)
	for track_name in TrackCatalog.names():
		if TrackCatalog.PRACTICE_TRACKS.has(track_name) or not TrackCatalog.is_built(track_name):
			continue
		var state := (load(TrackCatalog.scene_path(track_name)) as PackedScene).get_state()
		var road := 18.0
		var ramps: Array[Dictionary] = []
		for i in state.get_node_count():
			var props := _props(state, i)
			var path := _script_path(props)
			if path == TRACK_SCRIPT and state.get_node_path(i) == NodePath("."):
				road = props.get("road_width", 18.0)
			elif path == FEATURE_SCRIPT and props.get("kind", 0) == TrackFeature.Kind.JUMP_RAMP \
					and str(props.get("on_shortcut", "")) == "":
				props["name"] = str(state.get_node_name(i))
				ramps.append(props)
		var small: Array[String] = []
		var outside: Array[String] = []
		var tall: Array[String] = []
		for r in ramps:
			var width: float = r.get("width", 5.0)
			var lateral: float = r.get("lateral", 0.0)
			if absf(lateral) + width * 0.5 > road * 0.5 + 0.01:
				outside.append(r.name)
			if width <= road * SMALL_SHARE:
				small.append(r.name)
				if float(r.get("ramp_height", 1.6)) > SMALL_MAX_HEIGHT:
					tall.append(r.name)
		_check(not small.is_empty(), "%s has a small ramp (ramps: %d)" % [track_name, ramps.size()])
		_check(outside.is_empty(), "%s ramps inside the %.0f m road (outside: %s)" % [track_name, road, outside])
		_check(tall.is_empty(), "%s small ramps are low (too tall: %s)" % [track_name, tall])


func _run(test_name: String, test: Callable, config: RaceConfig) -> void:
	_current = test_name
	print("- " + test_name)
	var race := (load(RACE_SCENE) as PackedScene).instantiate() as RaceManager
	race.config = config
	root.add_child(race)
	race.camera.save_preference = false
	var frames := 0
	while race.state != RaceManager.State.RACING and frames < 600:
		await physics_frame
		frames += 1
	await test.call(race)
	race.queue_free()
	await process_frame


func _test_launch(race: RaceManager) -> void:
	var me := race.player.vehicle
	me.player_controlled = false
	var track := race.track
	var ramp := track.get_node_or_null("SmallRampLoadingDock") as TrackFeature
	_check(ramp != null, "The Stacks has its small ramp")
	if ramp == null:
		return
	var boxes := ramp.item_box_transforms()
	var lip_y := (ramp.global_transform * Vector3(0, ramp.ramp_height, -ramp.length * 0.5)).y
	_check(boxes.size() == 2 and boxes.all(func(xf: Transform3D) -> bool: return xf.origin.y > lip_y),
			"two item boxes float over the lip (%d)" % boxes.size())
	var xf: Transform3D = ramp.global_transform
	me.teleport(Transform3D(xf.basis, xf.origin + xf.basis.z * 60.0 + Vector3.UP * 0.9))
	await _frames(3)
	me.linear_velocity = -xf.basis.z * 34.0
	me.inventory.clear()
	var airborne := 0
	var tricked := false
	var before := ramp.triggered
	for i in 240:
		me.throttle_input = 1.0
		await physics_frame
		# Count air time only after the lip (the teleport drop doesn't count).
		if ramp.triggered > before and me.grounded_wheels == 0:
			airborne += 1
			if airborne == 6 and me.trick != null:
				tricked = me.trick.try_trick()
	print("    small ramp: %.2f s airborne" % (airborne / 60.0))
	_check(airborne > 18, "the small ramp launches the car (%.2f s)" % (airborne / 60.0))
	_check(tricked, "a trick starts in the air off it")
	_check(me.global_transform.basis.y.dot(Vector3.UP) > 0.9 and me.grounded_wheels >= 3, "and it lands on its wheels")
	_check(me.recovery.last_reason == "" and track.is_on_road(me.global_position), "on the road, no recovery")
	_check(not me.inventory.is_empty(), "the small ramp's item boxes gave the car a weapon")


func _frames(count: int) -> void:
	for i in count:
		await process_frame
