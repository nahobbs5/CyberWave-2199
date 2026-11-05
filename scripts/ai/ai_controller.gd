class_name AIController
extends Node
## Drives a VehicleController by writing its inputs (GDD 7.4).
##
## Steering: pure pursuit toward a point ahead on the RacingLine.
## Speed: tracks the line's safe speed, scaled by difficulty and personality.
## Drifting: holds drift through suitable corners, releases at the exit
## for a boost. Traffic: pulls out around slower cars ahead and avoids
## driving into them. Unsticking: reverses away from walls; resets after
## longer failures are left to the car's VehicleRecovery.

## Cars ahead closer than this (plus speed-based lookahead) are considered.
const TRAFFIC_BASE_RANGE := 10.0
## Lateral distance under which a car ahead blocks our line.
const TRAFFIC_LANE_WIDTH := 2.7
const PASS_OFFSET := 3.6
## Seconds of failing to move forward before reversing out.
const UNSTICK_DELAY := 0.8
const UNSTICK_DURATION := 1.2
## Don't start drifting more than this far off the line (metres).
const DRIFT_MAX_LINE_ERROR := 2.5
## Release a drift when this close to the road edge (metres).
const DRIFT_EDGE_MARGIN := 2.0

var vehicle: VehicleController
var track: TrackCircuit
var line: RacingLine
var profile: RacerProfile
var difficulty: AIDifficulty
## Every racer in the event (this car included); set by RaceManager.
var racers: Array[VehicleController] = []
## Target-speed multiplier from rubber-banding, set by RaceManager each frame.
var speed_scale: float = 1.0
var enabled: bool = true

## Boosts earned from drifts (for tests/telemetry).
var drift_boosts: int = 0

var _steer: float = 0.0
var _avoid: float = 0.0
var _wander_phase: float = 0.0
var _time: float = 0.0
var _zone: int = -1
var _drift_this_zone: bool = false
var _rng := RandomNumberGenerator.new()
var _blocked_time: float = 0.0
var _reverse_time: float = 0.0


func setup(p_vehicle: VehicleController, p_track: TrackCircuit, p_line: RacingLine,
		p_profile: RacerProfile, p_difficulty: AIDifficulty, seed_value: int) -> void:
	vehicle = p_vehicle
	track = p_track
	line = p_line
	profile = p_profile if p_profile != null else RacerProfile.new()
	difficulty = p_difficulty if p_difficulty != null else AIDifficulty.new()
	_rng.seed = seed_value
	_wander_phase = _rng.randf() * TAU
	vehicle.player_controlled = false
	if not vehicle.boost_started.is_connected(_on_boost_started):
		vehicle.boost_started.connect(_on_boost_started)


func _physics_process(delta: float) -> void:
	if vehicle == null or track == null or line == null:
		return
	if not enabled or not vehicle.input_enabled:
		_clear_inputs()
		return
	_time += delta

	var pos := vehicle.global_position
	var forward := -vehicle.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var speed := maxf(vehicle.forward_speed, 0.0)
	var offset := track.get_offset_at(pos)
	var road_right := track.get_tangent_at(offset).cross(Vector3.UP).normalized()
	var my_lateral := (pos - track.get_center_at(offset)).dot(road_right)

	# --- traffic ---
	var traffic := _scan_traffic(pos, forward, right, speed, my_lateral)
	var desired_avoid: float = traffic["avoid"]
	_avoid = move_toward(_avoid, desired_avoid, 5.0 * delta)

	# --- steering ---
	var wander := sin(_time * 0.4 + _wander_phase) \
			* difficulty.line_wander * profile.precision_wander
	var lookahead := difficulty.lookahead_base + speed * difficulty.lookahead_time
	var target := line.point_at(offset + lookahead, profile.line_bias + wander + _avoid)
	var to_target := target - pos
	to_target.y = 0.0
	var angle := forward.signed_angle_to(to_target, Vector3.UP)
	var raw_steer := clampf(-angle * difficulty.steer_gain, -1.0, 1.0)
	_steer = move_toward(_steer, raw_steer, delta / maxf(difficulty.reaction_time, 0.01))
	vehicle.steer_input = _steer

	if _update_unstick(delta, raw_steer):
		return

	# --- speed ---
	var lead := 3.0 + speed * 0.3
	var target_speed := line.speed_at(offset + lead) * difficulty.speed_factor \
			* profile.corner_speed_bias * speed_scale
	target_speed = minf(target_speed, traffic["max_speed"])
	# Far off the line (after a bump or recovery): slow down to rejoin.
	if absf(angle) > 0.9:
		target_speed = minf(target_speed, 14.0)
	var error := target_speed - vehicle.forward_speed
	if error > 1.0:
		vehicle.throttle_input = 1.0
		vehicle.brake_input = 0.0
	elif error < -1.5:
		vehicle.throttle_input = 0.0
		vehicle.brake_input = clampf(-error / 3.0, 0.3, 1.0)
	else:
		vehicle.throttle_input = 0.35
		vehicle.brake_input = 0.0

	_update_drift(offset, speed, angle, my_lateral)


## Pinned against something (e.g. sideways on a wall): steering needs forward
## speed to turn the car, so back out with the nose swinging toward the
## target. Returns true while reversing (inputs already written).
func _update_unstick(delta: float, raw_steer: float) -> bool:
	if _reverse_time > 0.0:
		_reverse_time -= delta
		vehicle.throttle_input = 0.0
		vehicle.brake_input = 1.0
		# Reversing flips which way steering yaws the car.
		vehicle.steer_input = -signf(raw_steer) if absf(raw_steer) > 0.05 else 0.0
		vehicle.drift_left_held = false
		vehicle.drift_right_held = false
		return true
	var trying := vehicle.throttle_input > 0.5
	_blocked_time = _blocked_time + delta if trying and vehicle.forward_speed < 2.0 else 0.0
	if _blocked_time > UNSTICK_DELAY:
		_blocked_time = 0.0
		_reverse_time = UNSTICK_DURATION
	return false


func _update_drift(offset: float, speed: float, angle: float, my_lateral: float) -> void:
	var zone := line.drift_zone_at(offset)
	if zone != _zone:
		_zone = zone
		_drift_this_zone = zone >= 0 and _rng.randf() < difficulty.drift_chance * profile.drift_tendency
	var want_drift := _drift_this_zone and zone >= 0 and absf(angle) < 0.7
	# Let go before the wall (keeps any charge earned as a boost).
	if absf(my_lateral) > track.road_width * 0.5 - DRIFT_EDGE_MARGIN:
		want_drift = false
	if not vehicle.drift.is_drifting():
		var line_error := absf(my_lateral - line.lateral_at(offset) - profile.line_bias)
		want_drift = want_drift and speed > vehicle.stats.drift_min_speed + 4.0 \
				and line_error < DRIFT_MAX_LINE_ERROR and absf(angle) < 0.35
	var direction := int(line.drift_zones[zone].z) if zone >= 0 else 0
	vehicle.drift_left_held = want_drift and direction < 0
	vehicle.drift_right_held = want_drift and direction > 0


## Returns {avoid: lateral metres, max_speed: m/s cap from the car ahead}.
func _scan_traffic(pos: Vector3, forward: Vector3, right: Vector3, speed: float, my_lateral: float) -> Dictionary:
	var result := {"avoid": 0.0, "max_speed": INF}
	var range_ahead := TRAFFIC_BASE_RANGE + speed * 0.6
	var nearest := INF
	for other in racers:
		if other == vehicle or not is_instance_valid(other):
			continue
		var rel := other.global_position - pos
		var ahead := rel.dot(forward)
		var side := rel.dot(right)
		# Side-by-side: ease away to avoid trading paint.
		if absf(ahead) < 4.5 and absf(side) < 3.2:
			result["avoid"] += -signf(side if absf(side) > 0.1 else 1.0) * 1.2
		if ahead <= 0.0 or ahead > range_ahead or absf(side) > TRAFFIC_LANE_WIDTH:
			continue
		if ahead >= nearest:
			continue
		nearest = ahead
		var other_speed := other.linear_velocity.dot(forward)
		var closing := speed - other_speed
		if closing < -0.5:
			continue # pulling away from us
		# Pass on the side with more room relative to where the line puts us.
		var pass_dir := -signf(side) if absf(side) > 0.6 else (-1.0 if my_lateral > 0.0 else 1.0)
		result["avoid"] = pass_dir * PASS_OFFSET * lerpf(0.6, 1.0, profile.aggression)
		# Don't ram: close to the car ahead, match its speed unless we're aggressive.
		if ahead < 7.0 + speed * 0.2 and profile.aggression < 0.9:
			result["max_speed"] = maxf(other_speed - 1.0, 5.0)
	return result


func _clear_inputs() -> void:
	vehicle.throttle_input = 0.0
	vehicle.brake_input = 0.0
	vehicle.steer_input = 0.0
	vehicle.drift_left_held = false
	vehicle.drift_right_held = false
	_steer = 0.0


func _on_boost_started(_level: int) -> void:
	drift_boosts += 1
