extends SceneTree
## Mario Kart style drift checks: steering-aware charging, the post-drift
## grip recovery, the entry hop and body yaw (visual only), tyre smoke and
## the skid loop. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_drift.gd

const DT := 1.0 / 60.0
const CAR := "res://scenes/vehicles/placeholder_car.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_drift_profile.json"
	GameSettings.path = "user://test_drift_settings.cfg"
	_run_all.call_deferred()


func _run_all() -> void:
	_test_charge_rates()
	await _test_in_car()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


## Seconds of sliding (right drift) to reach each level with this steering.
func _level_times(steer: float) -> Dictionary:
	var drift := DriftController.new()
	var stats := VehicleStats.new()
	drift.update(DT, false, true, true, 30.0, 0.0, stats, steer)
	var at := {}
	var t := 0.0
	while t < 7.0 and not at.has(3):
		drift.update(DT, false, true, true, 30.0, 6.0, stats, steer)
		t += DT
		if drift.level > 0 and not at.has(drift.level):
			at[drift.level] = t
	drift.free()
	return at


func _test_charge_rates() -> void:
	_current = "charge"
	print("- charge rates")
	var neutral := _level_times(0.0)
	var inward := _level_times(1.0)
	var outward := _level_times(-1.0)
	_check(absf(neutral.get(3, -1.0) - 4.0) < DT * 1.5, "neutral steering: Gold at 4.0 s (%s)" % neutral.get(3))
	_check(absf(inward.get(3, -1.0) - 4.0 / 1.5) < DT * 1.5, "steering into the drift: Gold at ~2.67 s (%s)" % inward.get(3))
	_check(absf(outward.get(3, -1.0) - 4.0 / 0.75) < DT * 1.5, "steering out: Gold at ~5.33 s (%s)" % outward.get(3))
	_check(inward.get(1, 9.0) < neutral.get(1, 0.0) and neutral.get(1, 0.0) < outward.get(1, 9.0), "Cyan comes sooner the more you steer in")


func _test_in_car() -> void:
	_current = "car"
	print("- drift feel on a car")
	# A big flat floor, so a long drift never meets a barrier.
	var track := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 1.0, 4000.0)
	floor_shape.shape = box
	track.add_child(floor_shape)
	track.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(track)
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.player_controlled = false
	car.is_player = true
	root.add_child(car)
	car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	car.set_visual_scale(VehicleController.TRACK_VISUAL_SCALE)
	var fb := car.get_node("Feedback") as VehicleFeedback
	var body := car.get_node("Body") as Node3D
	var rest_y := car.body_base_y()
	for i in 30:
		await physics_frame
	# Get up to speed, then drift right while steering into it.
	car.throttle_input = 1.0
	for i in 150:
		await physics_frame
	car.drift_right_held = true
	car.steer_input = 1.0
	var max_hop := 0.0
	for i in 12:
		await process_frame
		max_hop = maxf(max_hop, body.position.y - rest_y)
	_check(car.drift.is_drifting(), "the drift started")
	_check(max_hop > 0.1, "a hop when the drift starts (%.2f m)" % max_hop)
	for i in 60:
		await physics_frame
	_check(body.rotation.y < -0.2, "the body angles into a right drift (%.2f rad)" % body.rotation.y)
	_check(fb.smoke.size() == 2 and fb.smoke[0].emitting, "tyre smoke while sliding")
	_check(fb.skid_player.playing, "skid sound for a human player's car")
	_check(car.drift.level >= 1, "charge built up (level %d)" % car.drift.level)
	# Release: grip blends back rather than snapping.
	car.drift_right_held = false
	car.steer_input = 0.0
	await physics_frame
	_check(not car.drift.is_drifting() and car._recover_left > 0.0, "release starts the grip recovery")
	for i in 60:
		await physics_frame
	_check(is_zero_approx(car._recover_left), "recovery finishes")
	_check(absf(body.rotation.y) < 0.02 and absf(body.position.y - rest_y) < 0.01, "body back at rest within 1 s")
	_check(not fb.smoke[0].emitting, "smoke stops")
	# A stun spin owns the body: the drift visuals leave it alone.
	car.status.apply_attack(&"stun", 1.0)
	await process_frame
	await process_frame
	var spun := body.rotation.y
	_check(car.status.body_spin_active() and absf(spun) > 0.01, "a stun spins the body (%.2f)" % spun)
	car.queue_free()
	track.queue_free()
	await process_frame
