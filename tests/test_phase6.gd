extends SceneTree
## Phase 6 headless checks (vehicle models and Vegas Overdrive): every car
## builds its model with all cosmetic anchors, .glb-style model scenes plug
## in, the Vegas layout and its Luxor shortcut (queries, barrier openings,
## mirrored checkpoints), track features, recovery on the shortcut, AI taking
## the shortcut, and full races on Vegas. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_phase6.gd

const RACE_SCENE := "res://scenes/race/race.tscn"
const CAR_SCENE := "res://scenes/vehicles/placeholder_car.tscn"
const VEGAS := "res://scenes/tracks/vegas_overdrive.tscn"
const SIX_FLAGS := "res://scenes/tracks/six_flags_new_orleans.tscn"
const STACKS := "res://scenes/tracks/the_stacks.tscn"
const HOIA := "res://scenes/tracks/hoia_baciu.tscn"
const CATACOMBS := "res://scenes/tracks/catacombs_descent.tscn"
const ARASHIYAMA := "res://scenes/tracks/arashiyama_circuit.tscn"
const GLACIER := "res://scenes/tracks/vatnajokull_glacier.tscn"
const CRAZY := "res://scenes/tracks/crazy_house.tscn"
const GARDENS := "res://scenes/tracks/gardens_by_the_bay.tscn"
const VALE := "res://scenes/tracks/vale_da_lua.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_phase6_profile.json"
	GameSettings.path = "user://test_phase6_settings.cfg"
	Championship.save_path = "user://test_phase6_gp.json"
	PlayerProfile.delete_save()
	_run_all.call_deferred()


func _run_all() -> void:
	GameSession.scene_changes_enabled = false
	await _test_models()
	await _test_glb_model()
	_test_wet_status()
	await _test_layout(VEGAS, "Vegas Overdrive", 3000.0, 3400.0, 9, 90.0)
	await _test_layout(SIX_FLAGS, "Six Flags New Orleans", 2900.0, 3300.0, 10, 80.0)
	await _test_layout(STACKS, "The Stacks", 2700.0, 2950.0, 5, 80.0)
	await _test_layout(HOIA, "Hoia Baciu Run", 3100.0, 3300.0, 6, 80.0)
	await _test_layout(CATACOMBS, "Catacombs Descent", 2700.0, 2950.0, 7, 150.0)
	await _test_layout(ARASHIYAMA, "Arashiyama Circuit", 3000.0, 3250.0, 7, 120.0)
	await _test_layout(GLACIER, "Vatnajökull Glacier", 2950.0, 3200.0, 7, 100.0)
	await _test_layout(CRAZY, "Crazy House", 2750.0, 3050.0, 7, 100.0)
	await _test_layout(GARDENS, "Gardens by the Bay", 3200.0, 3500.0, 7, 100.0)
	_test_forest()
	_test_catacombs()
	_test_arashiyama()
	_test_glacier()
	_test_crazy_house()
	await _test_gardens()
	await _test_build_times()
	await _run("features on Vegas", _test_features, _vegas_config(), false)
	await _run("item boxes on ramps and boosters (The Stacks)", _test_item_boxes, _config(STACKS, "The Stacks"), false)
	await _run("jump ramps and water (Six Flags)", _test_ramps_and_water, _config(SIX_FLAGS, "Six Flags New Orleans"), false)
	await _run("shortcut: recovery and positions", _test_shortcut_recovery, _vegas_config(), false)
	await _run("deep water recovers (Arashiyama)", _test_deep_water, _config(ARASHIYAMA, "Arashiyama Circuit"), false)
	await _run("deep water recovers (Six Flags)", _test_deep_water, _config(SIX_FLAGS, "Six Flags New Orleans"), false)
	await _run("deep water recovers (Vale da Lua)", _test_deep_water, _config(VALE, "Vale da Lua"), false)
	await _run("falling off the skyway recovers (Gardens)", _test_skyway_fall, _config(GARDENS, "Gardens by the Bay"), false)
	_test_menus_and_gp()
	for track in [[VEGAS, "Vegas Overdrive"], [SIX_FLAGS, "Six Flags New Orleans"], [STACKS, "The Stacks"], [HOIA, "Hoia Baciu Run"],
			[CATACOMBS, "Catacombs Descent"], [ARASHIYAMA, "Arashiyama Circuit"], [GLACIER, "Vatnajökull Glacier"], [CRAZY, "Crazy House"],
			[GARDENS, "Gardens by the Bay"]]:
		var forced := _config(track[0], track[1])
		forced.total_laps = 1
		await _run("%s: everyone takes the shortcut (1 lap)" % track[1], _test_forced_shortcut, forced, true)
		await _run("%s: full race (3 laps, weapons)" % track[1], _test_full_race, _config(track[0], track[1]), true)
	PlayerProfile.delete_save()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _config(path: String, track_name: String) -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.track_name = track_name
	config.track_scene = load(path) as PackedScene
	return config


func _vegas_config() -> RaceConfig:
	var config := RaceConfig.new()
	config.difficulty = load("res://resources/ai/normal.tres") as AIDifficulty
	config.track_name = "Vegas Overdrive"
	config.track_scene = load(VEGAS) as PackedScene
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
	race.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _car() -> VehicleController:
	var car := (load(CAR_SCENE) as PackedScene).instantiate() as VehicleController
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(car)
	return car


func _mesh_aabb(car: Node3D, part: String) -> AABB:
	var mi := car.get_node_or_null("Body/Model/" + part) as MeshInstance3D
	return mi.mesh.get_aabb() if mi != null and mi.mesh != null else AABB()


# --- models ------------------------------------------------------------------------

func _test_models() -> void:
	_current = "vehicle models"
	print("- vehicle models")
	var sizes := {}
	for vehicle in VehicleCatalog.all():
		var car := _car()
		var loadout := PlayerProfile.get_profile().loadout_for(vehicle.id)
		for c in CosmeticItem.Category.values():
			var items := CosmeticCatalog.in_category(c)
			loadout[c] = items[1]
		VehicleCosmetics.apply(car, vehicle, loadout, "TEST-1")
		var model := car.get_node_or_null("Body/Model")
		var ok := model != null
		for part in ["Paint", "Glass", "Trim", "Lights", "Tail", "NeonL", "NeonR",
				"PlateAnchor", "DecalL", "DecalR", "ExhaustL", "ExhaustR"]:
			ok = ok and model.get_node_or_null(part) != null
		_check(ok, "%s: model with paint, glass, lights and every cosmetic anchor" % vehicle.display_name)
		_check(not (car.get_node("Body/Chassis") as Node3D).visible, "%s: box car hidden" % vehicle.display_name)
		var box := _mesh_aabb(car, "Paint")
		_check(box.position.x > -1.15 and box.end.x < 1.15 and box.position.z > -2.65 and box.end.z < 2.65
				and box.position.y > -0.5 and box.end.y < 1.1, "%s: fits the car footprint (%s)" % [vehicle.display_name, box])
		sizes[vehicle.id] = box
		var plate := car.find_child("Plate", true, false)
		_check(plate != null and plate.get_parent().name == "PlateAnchor" and VehicleCosmetics.get_plate_text(car) == "TEST-1",
				"%s: plate on its anchor" % vehicle.display_name)
		var stripes := car.get_node_or_null("Body/Cosmetics/Stripes") as MeshInstance3D
		_check(stripes != null and stripes.mesh.get_surface_count() == 1, "%s: stripes follow the body" % vehicle.display_name)
		var decals := car.get_node("Body/Cosmetics").get_children().filter(func(n: Node) -> bool: return n is Label3D)
		_check(decals.size() == 2 and (decals[1] as Label3D).position.is_equal_approx((model.get_node("DecalR") as Node3D).position),
				"%s: decals on the door anchors" % vehicle.display_name)
		var neon := model.get_node("NeonL") as MeshInstance3D
		_check(neon.visible and (neon.material_override as StandardMaterial3D).emission.is_equal_approx(loadout[CosmeticItem.Category.UNDERGLOW].color),
				"%s: underglow recolours the sill strips" % vehicle.display_name)
		car.queue_free()
	var distinct := {}
	for id in sizes:
		distinct[str(sizes[id].size.snapped(Vector3.ONE * 0.01))] = true
	_check(distinct.size() == 8, "eight distinct body shapes (%d)" % distinct.size())
	# Meshes are cached: two cars of the same design share geometry.
	var a := _car()
	var b := _car()
	CarModelBuilder.build(a, "nexus_x")
	CarModelBuilder.build(b, "nexus_x")
	_check((a.get_node("Body/Model/Paint") as MeshInstance3D).mesh == (b.get_node("Body/Model/Paint") as MeshInstance3D).mesh,
			"model meshes are shared between cars")
	a.queue_free()
	b.queue_free()
	await process_frame


func _test_glb_model() -> void:
	_current = "imported models"
	print("- imported (.glb-style) models")
	# Stand-in for an imported .glb: a scene with a Paint mesh and anchors.
	var root_node := Node3D.new()
	root_node.name = "ImportedCar"
	var body := MeshInstance3D.new()
	body.name = "PaintBody"
	body.mesh = BoxMesh.new()
	root_node.add_child(body)
	body.owner = root_node
	var anchor := Marker3D.new()
	anchor.name = "PlateAnchor"
	anchor.position = Vector3(0, 0, 2.2)
	root_node.add_child(anchor)
	anchor.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	root_node.free()
	var vehicle := VehicleCatalog.by_id("orbiter").duplicate() as VehicleData
	vehicle.model_scene = packed
	var car := _car()
	var loadout := PlayerProfile.get_profile().loadout_for("orbiter")
	loadout[CosmeticItem.Category.PAINT] = CosmeticCatalog.by_id("paint_acid")
	VehicleCosmetics.apply(car, vehicle, loadout, "GLB-1")
	var mesh := car.get_node_or_null("Body/Model/PaintBody") as MeshInstance3D
	_check(mesh != null, "the imported scene is used as the model")
	_check(mesh != null and (mesh.material_override as StandardMaterial3D).albedo_color.is_equal_approx(CosmeticCatalog.by_id("paint_acid").color),
			"meshes named Paint* take the paint")
	var plate := car.find_child("Plate", true, false)
	_check(plate != null and plate.get_parent().name == "PlateAnchor", "the plate goes on its PlateAnchor")
	_check(car.get_node_or_null("Body/Cosmetics/Stripes") == null, "no stripes on imported models")
	car.queue_free()
	await process_frame


# --- Vegas layout ----------------------------------------------------------------------

func _test_layout(path: String, track_name: String, min_length: float, max_length: float,
		feature_count: int, min_saving: float) -> void:
	_current = "%s layout" % track_name
	print("- %s layout" % track_name)
	var track := (load(path) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	await physics_frame
	await physics_frame
	_check(track.length > min_length and track.length < max_length, "length %.0f m" % track.length)
	_check(track.shortcuts.size() == 1, "one shortcut")
	if track.shortcuts.is_empty():
		track.queue_free()
		return
	var sc := track.shortcuts[0]
	_check(sc.length < sc.span - min_saving, "the shortcut is shorter (%.0f m vs %.0f m)" % [sc.length, sc.span])
	var gates := track.find_children("Checkpoint*", "Area3D", true, false)
	var bypassed := 0
	for i in track.checkpoint_count:
		if sc.contains_main_offset(track, track.get_checkpoint_offset(i)):
			bypassed += 1
	_check(bypassed > 0 and gates.size() == track.checkpoint_count + bypassed,
			"bypassed gates are mirrored on the shortcut (%d gates, %d mirrored)" % [gates.size(), bypassed])
	# Queries on the shortcut map onto the main loop.
	var mid := track.to_global(sc.point_at(sc.length * 0.5))
	var off := track.get_offset_at(mid)
	_check(track.get_shortcut_at(mid) == sc and sc.contains_main_offset(track, off), "a point on the shortcut maps inside its span")
	_check(track.is_on_road(mid), "the shortcut counts as road")
	_check(track.get_direction_at(mid).dot(track.global_transform.basis * sc.tangent_at(sc.length * 0.5)) > 0.99,
			"direction follows the shortcut")
	_check(not track.is_on_road(track.to_global(Vector3(3000, 0, 3000))), "off-road far from both routes")
	# No barrier across either route (cast along the centre lines at car height).
	var space := track.get_world_3d().direct_space_state
	var blocked := []
	for route in ["main", "shortcut"]:
		var total := track.length if route == "main" else sc.length
		var d := 0.0
		while d < total:
			var a: Vector3
			var b: Vector3
			if route == "main":
				a = track.get_center_at(d) + Vector3.UP
				b = track.get_center_at(d + 8.0) + Vector3.UP
			else:
				a = track.to_global(sc.point_at(d)) + Vector3.UP
				b = track.to_global(sc.point_at(minf(d + 8.0, sc.length))) + Vector3.UP
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
			if not hit.is_empty() and hit.collider.name.begins_with("_GenBarriers"):
				blocked.append("%s@%.0f" % [route, d])
			d += 8.0
	_check(blocked.is_empty(), "no barrier blocks the main road or the shortcut (%s)" % [blocked])
	_check(track.find_children("_GenCornerSigns", "Node3D", false, false).size() == 1
			and track.get_node("_GenCornerSigns").get_child_count() >= 18,
			"chevron signs on the sharp corners (%d)" % track.get_node("_GenCornerSigns").get_child_count())
	var scenery := track.get_node("Scenery/Generated")
	_check(scenery != null and scenery.get_child_count() > 20, "the city is built (%d nodes)" % scenery.get_child_count())
	var features := track.find_children("*", "TrackFeature", false, false)
	_check(features.size() == feature_count, "%d track features placed (%d)" % [feature_count, features.size()])
	track.queue_free()
	await process_frame


func _test_features(race: RaceManager) -> void:
	var me := race.player.vehicle
	var track := race.track
	var feature := func(feature_name: String) -> TrackFeature: return track.get_node(feature_name) as TrackFeature
	var drive_into := func(f: TrackFeature, speed: float) -> void:
		var xf: Transform3D = f.global_transform
		me.teleport(Transform3D(xf.basis, xf.origin + xf.basis.z * 8.0 + Vector3.UP * 0.9))
		await _frames(2)
		me.linear_velocity = -xf.basis.z * speed
		for i in 40:
			await physics_frame
			me.linear_velocity = -xf.basis.z * maxf(me.linear_velocity.length(), speed * 0.7)
	await drive_into.call(feature.call("BoostPadStrip1"), 25.0)
	_check((feature.call("BoostPadStrip1") as TrackFeature).triggered >= 1 and me.boost_label == "Boost pad", "a boost pad boosts")
	me.clear_boost()
	await drive_into.call(feature.call("BoostRingTunnel"), 25.0)
	_check((feature.call("BoostRingTunnel") as TrackFeature).triggered >= 1 and me.boost_label == "Boost ring", "the tunnel ring boosts")
	await drive_into.call(feature.call("EmpCasino1"), 15.0)
	_check(me.status.has(&"emp") or (feature.call("EmpCasino1") as TrackFeature).triggered >= 1, "the EMP puddle zaps")
	await _frames(120)
	var gate := feature.call("LuxorGate") as TrackFeature
	await drive_into.call(gate, 25.0)
	_check(gate.is_broken(), "the shortcut barrier smashes")
	gate.rebuild_time = 0.5
	gate._broken_time = 0.3
	await _frames(40)
	_check(not gate.is_broken(), "and rebuilds")


func _test_item_boxes(race: RaceManager) -> void:
	var track := race.track
	var wm := race.weapon_manager
	var rows := track.crate_row_offsets.size() * track.crate_lateral_positions.size()
	var ramp := track.get_node("JumpCourtyard") as TrackFeature
	var ramp_boxes := ramp.item_box_transforms()
	var expected := rows + ramp_boxes.size()
	for n in ["BoostRingRotunda", "BoostPadGallery"]:
		var booster := track.get_node(n) as TrackFeature
		_check(booster.item_boxes and booster.item_box_transforms().size() == 2, "%s has 2 item boxes" % n)
		expected += 2
	var plain := track.get_node("BoostPadCorridor") as TrackFeature
	_check(not plain.item_boxes and plain.item_box_transforms().is_empty(), "a booster without item_boxes has none")
	_check(wm.crates.size() == expected, "%d crates placed (rows %d + features %d)" % [wm.crates.size(), rows, expected - rows])
	_check(ramp_boxes.size() >= 2, "the ramp has a row of %d item boxes" % ramp_boxes.size())
	var lip_y := (ramp.global_transform * Vector3(0, ramp.ramp_height, -ramp.length * 0.5)).y
	var above := true
	for xf in ramp_boxes:
		above = above and xf.origin.y > lip_y + 0.5 and absf(xf.origin.y - lip_y) < 2.0
	_check(above, "the ramp's boxes float just above the lip")


func _test_wet_status() -> void:
	_current = "wet surface"
	print("- wet surface effect (no scene)")
	var s := StatusEffects.new()
	s.apply_buff(&"shield", 10.0)
	s.apply_surface(&"wet", 0.3)
	_check(s.has(&"wet") and s.has(&"shield"), "a Firewall doesn't keep you dry")
	_check(is_equal_approx(s.speed_multiplier(), s.wet_speed_multiplier)
			and is_equal_approx(s.grip_multiplier(), s.wet_grip_multiplier), "wet: slower and less grip")
	s.apply_attack(&"emp", 1.5) # used up the shield
	s.apply_attack(&"emp", 1.5)
	s.apply_attack(&"traction", 1.0)
	_check(is_equal_approx(s.speed_multiplier(), s.wet_speed_multiplier * s.emp_speed_multiplier)
			and is_equal_approx(s.grip_multiplier(), s.wet_grip_multiplier * s.traction_grip_multiplier), "stacks with EMP and traction")
	for i in 30:
		s._physics_process(1.0 / 60.0)
	_check(not s.has(&"wet"), "dries off 0.3 s after leaving the water")
	s.free()


func _test_ramps_and_water(race: RaceManager) -> void:
	var me := race.player.vehicle
	me.player_controlled = false
	var track := race.track
	var ramp := track.get_node("JumpCoaster") as TrackFeature
	var xf: Transform3D = ramp.global_transform
	# Start 60 m before the ramp, at speed, aimed straight at it.
	me.teleport(Transform3D(xf.basis, xf.origin + xf.basis.z * 60.0 + Vector3.UP * 0.9))
	await _frames(3)
	me.linear_velocity = -xf.basis.z * 36.0
	me.inventory.slots = [null, null]
	me.inventory.charges = [0, 0]
	var airborne := 0
	var max_height := 0.0
	for i in 240:
		me.throttle_input = 1.0
		await physics_frame
		if me.grounded_wheels == 0:
			airborne += 1
		max_height = maxf(max_height, me.global_position.y - xf.origin.y)
	print("    jump: %.2f s airborne, %.1f m up" % [airborne / 60.0, max_height])
	_check(airborne > 30 and max_height > 2.0, "the ramp launches the car (%.2f s, %.1f m)" % [airborne / 60.0, max_height])
	_check(me.global_transform.basis.y.dot(Vector3.UP) > 0.9 and me.grounded_wheels >= 3, "and it lands on its wheels")
	_check(me.recovery.last_reason == "" and track.is_on_road(me.global_position), "on the road, no recovery")
	_check(not me.inventory.is_empty(), "the ramp's item boxes gave the car a weapon")
	# Water.
	var water := track.get_node("WaterBayou1") as TrackFeature
	var cap_dry := me.get_speed_cap()
	var wxf: Transform3D = water.global_transform
	me.teleport(Transform3D(wxf.basis, wxf.origin + Vector3.UP * 0.9))
	await _frames(10)
	_check(me.status.has(&"wet") and me.get_speed_cap() < cap_dry and me.status.grip_multiplier() < 1.0,
			"in the water: wet, slower top speed, less grip")
	me.teleport(Transform3D(wxf.basis, wxf.origin + wxf.basis.z * 60.0 + Vector3.UP * 0.9))
	await _frames(30)
	_check(not me.status.has(&"wet"), "dry again after leaving it")


func _test_shortcut_recovery(race: RaceManager) -> void:
	var me := race.player.vehicle
	var sc := race.track.shortcuts[0]
	var d := sc.length * 0.4
	var xf := Transform3D(Basis.looking_at(sc.tangent_at(d), Vector3.UP), race.track.to_global(sc.point_at(d)) + Vector3.UP * 0.9)
	me.teleport(xf)
	await _frames(120)
	_check(me.recovery.last_reason == "", "parked on the shortcut: no off-track recovery")
	_check(sc.contains_main_offset(race.track, race.track.get_offset_at(me.global_position)), "its offset maps inside the shortcut's span")
	# Recovering from the shortcut puts the car back on the road, not behind the start.
	me.recovery.request_recovery("test")
	await _frames(75)
	_check(race.track.is_on_road(me.global_position), "a reset from the shortcut lands on the road")


## Deep water is a hazard, but never on or right beside a road (bridges).
func _test_deep_water(race: RaceManager) -> void:
	var track := race.track
	var zones := track.find_children("*", "RecoveryZone", true, false)
	_check(zones.size() == 1 and zones[0].get_child_count() > 5, "a deep-water zone is built (%d boxes)"
			% (zones[0].get_child_count() if not zones.is_empty() else 0))
	if zones.is_empty():
		return
	var zone := zones[0] as RecoveryZone
	var inside := 0
	var d := 0.0
	while d < track.length:
		for lat in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if zone.has_point(track.get_safe_transform(d, lat, 0.6).origin):
				inside += 1
		d += 2.0
	for sc in track.shortcuts:
		var e := 0.0
		while e < sc.length:
			if zone.has_point(track.to_global(sc.point_at(e)) + Vector3.UP * 0.6):
				inside += 1
			e += 2.0
	_check(inside == 0, "no road (or shortcut) point is in the water zone (%d)" % inside)
	# Drop the player's car over the water.
	var me := race.player.vehicle
	await _frames(30)
	var box := zone.get_child(zone.get_child_count() / 2) as CollisionShape3D
	var over := zone.to_global(box.position) + Vector3(0.0, -0.4, 0.0)
	me.teleport(Transform3D(Basis.IDENTITY, over))
	await _frames(10)
	_check(me.recovery.last_reason == "water", "driving into deep water recovers (%s)" % me.recovery.last_reason)
	await _frames(80)
	_check(track.is_on_road(me.global_position), "and comes back on the road")


func _test_menus_and_gp() -> void:
	_current = "menus and Grand Prix"
	print("- race setup and Grand Prix use Vegas")
	_check(TrackCatalog.names().has("Vegas Overdrive") and TrackCatalog.scene_path("Vegas Overdrive") == VEGAS, "Vegas is in the track list")
	var gp := load("res://resources/grand_prix/american_circuit.tres") as GrandPrixData
	var c := Championship.create(gp, "normal", true, load("res://resources/racers/rival_roster.tres"))
	c.race_index = 0
	var config := c.make_race_config()
	_check(config.track_name == "Vegas Overdrive" and config.track_scene.resource_path == VEGAS,
			"American Cup race 1 runs on Vegas Overdrive")
	c.race_index = 1
	config = c.make_race_config()
	_check(config.track_name == "Six Flags New Orleans" and config.track_scene.resource_path == SIX_FLAGS,
			"American Cup race 2 runs on Six Flags New Orleans")
	_check(TrackCatalog.scene_path("Six Flags New Orleans") == SIX_FLAGS, "Six Flags is in the track list")
	_check(TrackCatalog.scene_path("The Stacks") == STACKS, "The Stacks is in the track list")
	c.race_index = 2
	config = c.make_race_config()
	_check(config.track_name == "The Stacks" and config.track_scene.resource_path == STACKS,
			"American Cup race 3 runs on The Stacks")
	var europe := load("res://resources/grand_prix/world_circuit.tres") as GrandPrixData
	var asia := load("res://resources/grand_prix/asia_circuit.tres") as GrandPrixData
	_check(not europe.locked and not asia.locked and not gp.locked, "all three cups are playable")
	_check(GrandPrixData.CUPS.size() == 5 and europe.display_name == "Europe Cup" and asia.display_name == "Asia Cup",
			"American, Europe, Asia, South America and Africa cups")


## Each track's scenery builds quickly (headless, no rendering).
func _test_build_times() -> void:
	_current = "scenery build times"
	print("- scenery build times")
	for path in [VEGAS, SIX_FLAGS, STACKS, HOIA, CATACOMBS, ARASHIYAMA, GLACIER, CRAZY, GARDENS, VALE]:
		var t0 := Time.get_ticks_msec()
		var track := (load(path) as PackedScene).instantiate() as TrackCircuit
		root.add_child(track)
		var ms := Time.get_ticks_msec() - t0
		# Headless: about half of this is loading the PBR textures (see README).
		_check(ms < 8000, "%s builds in under 8 s headless (%d ms)" % [path.get_file(), ms])
		track.queue_free()
		await process_frame


## Hoia Baciu: in the catalogue, Europe Cup race 1, and a
## forest of instanced trees that keeps off the roads and out of the clearing.
func _test_forest() -> void:
	_current = "Hoia Baciu forest"
	print("- Hoia Baciu forest")
	_check(TrackCatalog.scene_path("Hoia Baciu Run") == HOIA and TrackCatalog.music("Hoia Baciu Run") != "", "Hoia is in the track list with music")
	var world := load("res://resources/grand_prix/world_circuit.tres") as GrandPrixData
	_check(world.track_scenes[0] == HOIA, "Europe Cup race 1 is Hoia")
	_check(world.is_open(true) and world.is_open(false), "Europe Cup: open for Grand Prix and Versus")
	_check(world.is_track_built(0) and world.is_track_built(1) and world.is_track_built(2), "all three Europe Cup tracks are built")
	GameSession.setup_mode = RaceConfig.Mode.VERSUS
	var select := (load("res://scenes/menu/track_select.tscn") as PackedScene).instantiate() as TrackSelect
	root.add_child(select)
	var world_open := true
	for t in world.track_names:
		var i := select.track_names.find(t)
		world_open = world_open and i >= 0 and not select.cards[i].disabled
	_check(world_open, "Versus track select: all three Europe Cup tracks raceable")
	select.free()
	var track := (load(HOIA) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var chunks := track.find_children("Trees_*", "MultiMeshInstance3D", true, false)
	var total := 0
	var on_road := 0
	var in_clearing := 0
	for node in chunks:
		var mm := (node as MultiMeshInstance3D).multimesh
		total += mm.instance_count
		for i in mm.instance_count:
			var p := (node as Node3D).position + mm.get_instance_transform(i).origin
			if track.get_lateral_distance(p) < track.road_width * 0.5 + track.barrier_thickness:
				on_road += 1
			if Vector2(p.x - HoiaScenery.CLEARING.x, p.z - HoiaScenery.CLEARING.z).length() < HoiaScenery.CLEARING_RADIUS:
				in_clearing += 1
	_check(total > 3000 and chunks.size() < 400, "a forest of instanced trees (%d trees in %d chunks)" % [total, chunks.size()])
	_check(on_road == 0, "no tree stands on the main road (%d)" % on_road)
	_check(in_clearing == 0, "the Round Clearing stays treeless (%d)" % in_clearing)
	track.free()


## Catacombs Descent: Europe Cup race 2, roofed over every metre (main road
## and shortcut), torch-lit, with skull walls that keep off the roads and
## standing water on both routes.
func _test_catacombs() -> void:
	_current = "Catacombs Descent"
	print("- Catacombs Descent")
	_check(TrackCatalog.scene_path("Catacombs Descent") == CATACOMBS and TrackCatalog.music("Catacombs Descent") != "",
			"the Catacombs are in the track list with music")
	var world := load("res://resources/grand_prix/world_circuit.tres") as GrandPrixData
	_check(world.track_scenes[1] == CATACOMBS and world.track_names[1] == "Catacombs Descent", "Europe Cup race 2 is the Catacombs")
	var track := (load(CATACOMBS) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var scenery := track.get_node("Scenery") as CatacombsScenery
	var gaps: Array[String] = []
	var d := 0.0
	while d < track.length:
		for lateral: float in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if not scenery.is_roofed(track.to_local(track.get_safe_transform(d, lateral, 0.0).origin)):
				gaps.append("main@%d" % d)
		d += 3.0
	var sc := track.shortcuts[0]
	d = 0.0
	while d < sc.length:
		if not scenery.is_roofed(sc.point_at(d)):
			gaps.append("shortcut@%d" % d)
		d += 3.0
	_check(gaps.is_empty(), "a ceiling over every metre of both routes (gaps: %s)" % [gaps.slice(0, 8)])
	var torches := track.find_children("*", "FlickerLight", true, false).filter(func(l: Node) -> bool: return (l as FlickerLight).flame)
	_check(torches.size() > 120, "torch-lit (%d flames)" % torches.size())
	_check(track.find_children("*", "SpotLight3D", true, false).size() >= 5, "light shafts through street grates")
	# Positions come from the scenery: headless runs don't keep MultiMesh transforms.
	var total := scenery.skull_origins.size()
	var on_road := 0
	for p in scenery.skull_origins:
		if track.get_lateral_distance(track.to_global(p)) < track.road_width * 0.5 + track.barrier_thickness:
			on_road += 1
	var chunks := track.find_children("Skulls_*", "MultiMeshInstance3D", true, false)
	_check(total > 5000 and chunks.size() > 10, "skull-lined walls (%d skulls in %d chunks)" % [total, chunks.size()])
	_check(on_road == 0, "no skull sits on a road (%d)" % on_road)
	var water := track.find_children("*", "TrackFeature", false, false).filter(
			func(f: Node) -> bool: return (f as TrackFeature).kind == TrackFeature.Kind.WATER)
	_check(water.size() == 2 and water.any(func(f: Node) -> bool: return (f as TrackFeature).on_shortcut == "")
			and water.any(func(f: Node) -> bool: return (f as TrackFeature).on_shortcut == sc.name),
			"standing water in the cistern and the flooded crypt")
	track.free()


func _test_forced_shortcut(race: RaceManager) -> void:
	# Overdrive flies the main road, so leave the rare items out of this
	# routing test (they're covered in test_weapons_advanced.gd).
	var wm := race.weapon_manager
	if wm != null:
		wm.weapons = wm.weapons.filter(func(w: WeaponData) -> bool: return not w.is_special())
	var sc := race.track.shortcuts[0]
	sc.ai_chance = 1.0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			ai.difficulty = ai.difficulty.duplicate()
			ai.difficulty.shortcut_chance = 2.0
	var frames := 0
	while frames < 60 * 220 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var taken := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			taken += ai.shortcuts_taken
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "everyone finishes via the shortcut")
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.checkpoints_passed == race.track.checkpoint_count + 1),
			"every gate counted on the shortcut")
	_check(taken >= 8, "all eight took it (%d)" % taken)
	print("    1 lap via the shortcut: %.1f s simulated" % (frames / 60.0))


func _test_full_race(race: RaceManager) -> void:
	var recoveries := [0]
	for racer in race.racers:
		racer.vehicle.recovery.recovered.connect(func(_r: String) -> void: recoveries[0] += 1)
	var frames := 0
	while frames < 60 * 400 and not race.racers.all(func(r: RaceProgress) -> bool: return r.finished):
		await physics_frame
		frames += 1
	var taken := 0
	for racer in race.racers:
		var ai := race.get_ai(racer)
		if ai != null:
			taken += ai.shortcuts_taken
	var times: Array[String] = []
	for racer in race.get_standings():
		times.append(RaceProgress.format_time(racer.finish_time))
	print("    race %.1f s simulated; times %s; shortcuts taken %d; recoveries %d" % [frames / 60.0, times, taken, recoveries[0]])
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.finished), "all 8 finish 3 laps")
	_check(race.racers.all(func(r: RaceProgress) -> bool: return r.checkpoints_passed == 3 * race.track.checkpoint_count + 1),
			"every gate counted")
	_check(taken > 0, "the AI used the shortcut (%d times)" % taken)
	_check(recoveries[0] <= 4, "few recoveries (%d)" % recoveries[0])
	var winner := race.get_standings()[0]
	_check(winner.finish_time > 180.0 and winner.finish_time < 285.0, "a 3-4 minute race: %s" % RaceProgress.format_time(winner.finish_time))
	var map := race.race_hud.minimap
	_check(map.shortcut_count() == 1, "the minimap draws the shortcut")


## Arashiyama Circuit: the Asia Cup. A bamboo grove whose canopy closes
## over most of the lap (open at the start plaza, the bridge and the temple
## garden), thousands of culms that keep off both roads, the bridge and
## garden open to the sky, and its features on the right routes.
func _test_arashiyama() -> void:
	_current = "Arashiyama Circuit"
	print("- Arashiyama Circuit")
	_check(TrackCatalog.scene_path("Arashiyama Circuit") == ARASHIYAMA and TrackCatalog.music("Arashiyama Circuit") != "",
			"Arashiyama is in the track list with music")
	var asia := load("res://resources/grand_prix/asia_circuit.tres") as GrandPrixData
	_check(asia.track_scenes[0] == ARASHIYAMA and asia.track_names[0] == "Arashiyama Circuit", "Asia Cup race 1 is Arashiyama")
	var track := (load(ARASHIYAMA) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var scenery := track.get_node("Scenery") as ArashiyamaScenery
	var covered := 0
	var samples := 0
	var d := 0.0
	while d < track.length:
		samples += 1
		if scenery.is_covered(track.to_local(track.get_safe_transform(d, 0.0, 0.0).origin)):
			covered += 1
		d += 3.0
	var fraction := float(covered) / samples
	_check(fraction > 0.68 and fraction < 0.9, "the canopy closes over most of the lap (%d%%)" % roundi(fraction * 100.0))
	var bridge := track.curve.get_closest_point(Vector3(563, 0, 172))
	_check(not scenery.is_covered(bridge), "open sky over the bridge")
	var garden := track.curve.get_closest_point(Vector3(-130, 0, 390))
	_check(not scenery.is_covered(garden) and ArashiyamaScenery.GARDEN.has_point(Vector2(garden.x, garden.z)),
			"open sky over the temple garden")
	var sc := track.shortcuts[0]
	var sc_covered := 0
	d = 0.0
	while d < sc.length:
		if scenery.is_covered(sc.point_at(d)):
			sc_covered += 1
		d += 3.0
	_check(sc_covered > int(sc.length / 3.0 * 0.6), "the shrine path runs under bamboo too")
	var chunks := track.find_children("Bamboo_*", "MultiMeshInstance3D", true, false)
	var total := 0
	for node in chunks:
		total += (node as MultiMeshInstance3D).multimesh.instance_count
	_check(total > 12000 and total == scenery.bamboo.culm_count() and chunks.size() < 400,
			"a grove of instanced bamboo (%d culms in %d chunks)" % [total, chunks.size()])
	# Positions come from the builder: headless MultiMesh transforms read back as identity.
	var off_road := func(kind: String, margin: float) -> int:
		var hits := 0
		for p in scenery.bamboo.positions(kind):
			if track.get_lateral_distance(track.to_global(p)) < track.road_width * 0.5 + margin:
				hits += 1
		return hits
	_check(off_road.call("culm", track.barrier_thickness) == 0, "no culm stands on a road (%d)" % off_road.call("culm", track.barrier_thickness))
	var undergrowth := scenery.bamboo.item_count("fern") + scenery.bamboo.item_count("sasa")
	var growth_on_road: int = off_road.call("fern", track.barrier_thickness) + off_road.call("sasa", track.barrier_thickness)
	_check(undergrowth > 1000 and growth_on_road == 0,
			"ferns and sasa underfoot, none on a road (%d, %d on road)" % [undergrowth, growth_on_road])
	var crest := scenery.bamboo.item_count("brush")
	_check(crest > 1500 and off_road.call("brush", 0.0) == 0 and scenery.bamboo.item_count("pole") > 3000,
			"brushwood fences: crest along the walls, off the road, with bamboo rails (%d bays)" % crest)
	var features := track.find_children("*", "TrackFeature", false, false)
	var on_route := func(kind: TrackFeature.Kind, shortcut: String) -> bool:
		return features.any(func(f: Node) -> bool: return (f as TrackFeature).kind == kind and (f as TrackFeature).on_shortcut == shortcut)
	_check(on_route.call(TrackFeature.Kind.WATER, "") and on_route.call(TrackFeature.Kind.BREAKABLE, sc.name),
			"standing water on the main road; fallen bamboo blocks the shrine path")
	track.free()


## Vatnajökull Glacier: Europe Cup race 3. An ice cave roofed over every
## metre of both routes, tall enough at the start for the gantry, with
## thousands of icicles that never hang low over a road, sky-light shafts in
## Moulin Hall and a meltwater ford on the main road.
func _test_glacier() -> void:
	_current = "Vatnajökull Glacier"
	print("- Vatnajökull Glacier")
	_check(TrackCatalog.scene_path("Vatnajökull Glacier") == GLACIER and TrackCatalog.location("Vatnajökull Glacier").contains("Iceland"),
			"the glacier is in the track list (Iceland)")
	var europe := load("res://resources/grand_prix/world_circuit.tres") as GrandPrixData
	_check(europe.track_scenes[2] == GLACIER and europe.track_names[2] == "Vatnajökull Glacier", "Europe Cup race 3 is the glacier")
	var track := (load(GLACIER) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var scenery := track.get_node("Scenery") as GlacierScenery
	var gaps: Array[String] = []
	var d := 0.0
	while d < track.length:
		for lateral: float in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if not scenery.is_roofed(track.to_local(track.get_safe_transform(d, lateral, 0.0).origin)):
				gaps.append("main@%d" % d)
		d += 3.0
	var sc := track.shortcuts[0]
	d = 0.0
	while d < sc.length:
		if not scenery.is_roofed(sc.point_at(d)):
			gaps.append("tube@%d" % d)
		d += 3.0
	_check(gaps.is_empty(), "ice over every metre of both routes (gaps: %s)" % [gaps.slice(0, 8)])
	_check(scenery.start_roof_height >= 20.0, "a roomy start hall: roof %.1f m over the grid" % scenery.start_roof_height)
	var low := 0
	for p in scenery.icicle_tips:
		if track.get_lateral_distance(track.to_global(p)) < track.road_width * 0.5 + 1.0 and p.y < 7.0:
			low += 1
	var chunks := track.find_children("Icicles_*", "MultiMeshInstance3D", true, false)
	_check(scenery.icicle_count() > 5000 and chunks.size() > 10, "icicles everywhere (%d in %d chunks)" % [scenery.icicle_count(), chunks.size()])
	_check(low == 0, "no icicle hangs below 7 m over the road (%d)" % low)
	_check(scenery.skylights >= 4 and track.find_children("Skylight*", "SpotLight3D", true, false).size() >= 4,
			"sky-light shafts in Moulin Hall")
	var water := track.find_children("*", "TrackFeature", false, false).filter(
			func(f: Node) -> bool: return (f as TrackFeature).kind == TrackFeature.Kind.WATER and (f as TrackFeature).on_shortcut == "")
	_check(water.size() == 1, "a meltwater ford on the main road")
	track.queue_free()


## Crazy House: Asia Cup race 2. Inside one giant hollow tree, roofed over
## every metre of both routes, with staircases everywhere, bone arches that
## never come below 7.5 m over a road, and daylight through roof windows.
func _test_crazy_house() -> void:
	_current = "Crazy House"
	print("- Crazy House")
	_check(TrackCatalog.scene_path("Crazy House") == CRAZY and TrackCatalog.location("Crazy House").contains("Vietnam"),
			"the Crazy House is in the track list (Vietnam)")
	var asia := load("res://resources/grand_prix/asia_circuit.tres") as GrandPrixData
	_check(asia.race_count() >= 2 and asia.track_scenes[1] == CRAZY and asia.track_names[1] == "Crazy House", "Asia Cup race 2 is the Crazy House")
	var track := (load(CRAZY) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	var scenery := track.get_node("Scenery") as CrazyHouseScenery
	var gaps: Array[String] = []
	var d := 0.0
	while d < track.length:
		for lateral: float in [-track.road_width * 0.5, 0.0, track.road_width * 0.5]:
			if not scenery.is_roofed(track.to_local(track.get_safe_transform(d, lateral, 0.0).origin)):
				gaps.append("main@%d" % d)
		d += 3.0
	var sc := track.shortcuts[0]
	d = 0.0
	while d < sc.length:
		if not scenery.is_roofed(sc.point_at(d)):
			gaps.append("tunnel@%d" % d)
		d += 3.0
	_check(gaps.is_empty(), "inside the tree over every metre of both routes (gaps: %s)" % [gaps.slice(0, 8)])
	_check(scenery.start_roof_height >= 20.0, "a tall Root Hall: roof %.1f m over the grid" % scenery.start_roof_height)
	_check(scenery.stair_flights >= 6 and scenery.step_count > 300, "staircases everywhere (%d flights, %d steps)" % [scenery.stair_flights, scenery.step_count])
	_check(scenery.bone_arches >= 10 and scenery.bone_arch_clearance >= 7.5,
			"bone arches (%d) never lower than 7.5 m over a road (%.1f m)" % [scenery.bone_arches, scenery.bone_arch_clearance])
	_check(scenery.window_shafts >= 4 and track.find_children("WindowShaft*", "SpotLight3D", true, false).size() >= 4,
			"daylight through roof windows")
	track.queue_free()


## Gardens by the Bay: Asia Cup race 3. A glass skyway 24 m above the
## jungle: the deck has its own collider, the barriers are left out on the
## open edges (main loop and shortcut) so cars can fall, and the Supertree
## canopies never hang at road level over a road.
func _test_gardens() -> void:
	_current = "Gardens by the Bay"
	print("- Gardens by the Bay")
	_check(TrackCatalog.scene_path("Gardens by the Bay") == GARDENS and TrackCatalog.location("Gardens by the Bay").contains("Singapore"),
			"Gardens by the Bay is in the track list (Singapore)")
	var asia := load("res://resources/grand_prix/asia_circuit.tres") as GrandPrixData
	_check(asia.race_count() == 3 and asia.track_scenes[2] == GARDENS and asia.track_names[2] == "Gardens by the Bay",
			"Asia Cup race 3 is Gardens by the Bay")
	var track := (load(GARDENS) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	await physics_frame
	await physics_frame
	_check(track.elevated and track.find_child("*Deck", false, false) is StaticBody3D, "an elevated deck with its own collider")
	var ground := track.find_child("*Ground", false, false)
	var slab := ground.get_child(0) as CollisionShape3D if ground != null else null
	_check(slab != null and is_equal_approx(slab.position.y, -track.ground_depth - 1.0), "the ground is 24 m below the deck")
	_check(track.road_material != null and (track.road_material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
			"the road is glass")
	_check(track.open_edges.size() >= 2, "open edges on the main loop (%d)" % track.open_edges.size())
	var space := track.get_world_3d().direct_space_state
	var drop := func(pos: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 40.0))
		return (hit.position as Vector3).y if hit else -INF
	var edge := track.road_width * 0.5 + track.barrier_thickness * 0.5
	var open_ok := true
	for e in track.open_edges:
		var mid := (e.x + e.y) * 0.5
		var side := signf(e.z)
		open_ok = open_ok and absf(drop.call(track.get_safe_transform(mid, side * edge, 0.0).origin)) < 0.1 \
				and drop.call(track.get_safe_transform(mid, side * (edge + 2.5), 0.0).origin) < -20.0 \
				and drop.call(track.get_safe_transform(mid, -side * edge, 0.0).origin) > 3.0
	_check(open_ok, "open edges: no wall (only the deck under the edge, a drop beyond), the far side still walled")
	var walled := drop.call(track.get_safe_transform(track.start_line_offset, edge, 0.0).origin) as float
	_check(walled > 3.0, "elsewhere the barrier is there (%.1f m)" % walled)
	_check(drop.call(track.get_safe_transform(500.0, 0.0, 0.0).origin) > -0.1, "the deck holds the road up")
	_check(not track.is_open_edge(track.start_line_offset, -1.0) and track.is_open_edge(track.open_edges[0].x + 1.0, track.open_edges[0].z),
			"is_open_edge answers")
	var sc := track.shortcuts[0]
	_check(sc.open_edges.size() >= 2, "the Cloud Forest walk has open edges too")
	var e0 := sc.open_edges[0]
	var mid_d := (e0.x + e0.y) * 0.5
	var t := sc.tangent_at(mid_d)
	var right := t.cross(Vector3.UP).normalized()
	var sc_edge := sc.road_width * 0.5 + track.barrier_thickness * 0.5
	var p := track.to_global(sc.point_at(mid_d) + right * signf(e0.z) * sc_edge)
	_check(absf(drop.call(p)) < 0.1, "no wall on the shortcut's open edge")
	var glass := track.find_children("*", "TrackFeature", true, false).filter(func(f: TrackFeature) -> bool:
		return f.kind == TrackFeature.Kind.BREAKABLE and f.on_shortcut == sc.name)
	_check(glass.size() == 1, "a smashable glass panel at the Cloud Forest entrance")
	var scenery := track.get_node("Scenery") as GardensScenery
	_check(scenery.supertrees.placed.size() >= 12, "a grove of Supertrees (%d)" % scenery.supertrees.placed.size())
	var wrap := scenery.supertrees.placed.filter(func(t2: Array) -> bool:
		return Vector2((t2[0] as Vector3).x, (t2[0] as Vector3).z).distance_to(Vector2(GardensScenery.WRAP_TREE.x, GardensScenery.WRAP_TREE.z)) < 1.0)
	_check(wrap.size() == 1 and wrap[0][1] >= 50.0, "the tallest Supertree stands inside the Great Wrap")
	var low: Array[String] = []
	for t2 in scenery.supertrees.placed:
		var base := t2[0] as Vector3
		var span := SupertreeBuilder.canopy_span(base.y, t2[1])
		var at_road_level := span.y > -1.0 and span.x < GardensScenery.ROAD_CLEARANCE
		var top := Vector3(base.x, 0, base.z)
		if scenery.edge_distance(top) < 2.0 or (at_road_level and scenery.edge_distance(top) < t2[2]):
			low.append("(%d, %d)" % [base.x, base.z])
	_check(low.is_empty(), "no Supertree trunk on a road or canopy at road level over one (%s)" % [low])
	track.queue_free()
	await process_frame


## Drive off an open edge: the car falls into the jungle and comes back on the deck.
func _test_skyway_fall(race: RaceManager) -> void:
	var track := race.track
	var me := race.player.vehicle
	await _frames(30)
	var e := track.open_edges[0]
	var mid := (e.x + e.y) * 0.5
	var out := track.get_safe_transform(mid, signf(e.z) * (track.road_width * 0.5 + 4.0), 1.0)
	me.teleport(out)
	var fell := false
	var frames := 0
	while frames < 240 and me.recovery.last_reason == "":
		fell = fell or me.global_position.y < -3.0
		await physics_frame
		frames += 1
	_check(fell, "the car drops off the edge")
	_check(me.recovery.last_reason in ["out of bounds", "off track"], "and is recovered (%s)" % me.recovery.last_reason)
	await _frames(150)
	_check(track.is_on_road(me.global_position) and me.global_position.y > -0.5 and me.global_position.y < 3.0,
			"back on the deck (y %.1f)" % me.global_position.y)
