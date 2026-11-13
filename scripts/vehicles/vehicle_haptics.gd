class_name VehicleHaptics
extends Node
## Controller rumble for a human racer (GDD 11.9): short pulses on speed
## boosts (pads, rings, rocket start, slipstream, Nitro), tricks, drift
## boosts, weapon hits and hard crashes. Made by VehicleController._ready.
##
## Only pulses while GameSettings.vibration is on and the car is a human
## player still driving (not AI, menu cars or the post-finish autopilot).
## Single player rumbles every connected pad; split screen sets `device` to
## that player's pad (keyboard players get nothing).

## `device` value: rumble every connected pad.
const ALL_PADS := -2

## Pulses as [weak motor, strong motor, seconds].
const DRIFT_BOOST: Array = [
	[0.35, 0.15, 0.15],
	[0.5, 0.35, 0.22],
	[0.75, 0.6, 0.32],
]
const BOOST_PAD: Array = [0.6, 0.3, 0.25]
const BOOST_RING: Array = [0.85, 0.55, 0.35]
const TRICK_LANDED: Array = [0.7, 0.7, 0.3]
const TRICK_STARTED: Array = [0.3, 0.0, 0.08]
## Rocket start, slipstream, Nitro and any other boost.
const OTHER_BOOST: Array = [0.55, 0.3, 0.25]
const HIT_STUN: Array = [1.0, 1.0, 0.45]
const HIT_EMP: Array = [0.5, 0.9, 0.4]
const HIT_LIGHT: Array = [0.6, 0.6, 0.3]
const SHIELD_BLOCK: Array = [0.4, 0.2, 0.15]
## Crash: strong motor goes from CRASH_MIN to 1 as speed lost goes from the
## car's major-impact threshold to CRASH_FULL_LOSS m/s.
const CRASH_MIN := 0.35
const CRASH_FULL_LOSS := 30.0
const CRASH_TIME := 0.2

var vehicle: VehicleController
var device: int = ALL_PADS
## Headless tests read these (no real pad needed).
var pulse_count: int = 0
var last_pulse: Vector3 = Vector3.ZERO # weak, strong, duration
## The pulse now playing: strength and when it ends (msec ticks).
var _strength: float = 0.0
var _until_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # hear the pause notification
	vehicle = get_parent() as VehicleController
	if vehicle == null:
		return
	vehicle.boost_started.connect(_on_drift_boost)
	vehicle.external_boost_started.connect(_on_external_boost)
	vehicle.heavy_impact.connect(_on_heavy_impact)
	if vehicle.trick != null:
		vehicle.trick.trick_started.connect(func() -> void: _pulse(TRICK_STARTED))
	var status := vehicle.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		status.effect_started.connect(_on_effect_started)
		status.attack_blocked.connect(_on_attack_blocked)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		stop()


func _process(_delta: float) -> void:
	# Pausing mid-pulse would leave the pad buzzing under the pause menu.
	if _until_ms > 0 and get_tree().paused:
		stop()


## Whether pulses would be sent now (setting on, human driving).
func is_active() -> bool:
	return GameSettings.vibration and vehicle != null and vehicle.is_player \
			and vehicle.player_controlled and device != -1


## Sends a pulse unless a stronger one is still playing.
func pulse(weak: float, strong: float, duration: float) -> void:
	if not is_active():
		return
	var now := Time.get_ticks_msec()
	var strength := maxf(weak, strong)
	if now < _until_ms and strength < _strength:
		return
	_strength = strength
	_until_ms = now + int(duration * 1000.0)
	pulse_count += 1
	last_pulse = Vector3(weak, strong, duration)
	for pad in target_pads():
		Input.start_joy_vibration(pad, weak, strong, duration)


func stop() -> void:
	_strength = 0.0
	_until_ms = 0
	for pad in target_pads():
		Input.stop_joy_vibration(pad)


## The pads this car rumbles.
func target_pads() -> Array[int]:
	if device == ALL_PADS:
		var pads: Array[int] = []
		pads.assign(Input.get_connected_joypads())
		return pads
	if device >= 0:
		return [device]
	return []


## A short test buzz on every pad (Settings, when vibration is switched on).
static func preview() -> void:
	if not GameSettings.vibration:
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, 0.5, 0.5, 0.25)


func _pulse(spec: Array) -> void:
	pulse(spec[0], spec[1], spec[2])


func _on_drift_boost(level: int) -> void:
	_pulse(DRIFT_BOOST[clampi(level, 1, DRIFT_BOOST.size()) - 1])


func _on_external_boost(label: String) -> void:
	match label:
		"Boost pad":
			_pulse(BOOST_PAD)
		"Boost ring":
			_pulse(BOOST_RING)
		"Trick":
			_pulse(TRICK_LANDED)
		_:
			_pulse(OTHER_BOOST)


func _on_effect_started(effect: StringName, _duration: float) -> void:
	match effect:
		&"stun", &"stagger":
			_pulse(HIT_STUN)
		&"emp":
			_pulse(HIT_EMP)
		&"traction", &"override":
			_pulse(HIT_LIGHT)


func _on_attack_blocked(_effect: StringName, by: StringName) -> void:
	if by == &"shield":
		_pulse(SHIELD_BLOCK)


func _on_heavy_impact(speed_lost: float) -> void:
	var low := vehicle.stats.major_impact_speed_loss if vehicle.stats != null else 10.0
	var t := clampf((speed_lost - low) / maxf(CRASH_FULL_LOSS - low, 0.01), 0.0, 1.0)
	var strong := lerpf(CRASH_MIN, 1.0, t)
	pulse(strong * 0.6, strong, CRASH_TIME)
