class_name VehicleTrick
extends Node
## Ramp tricks: going over a jump ramp opens a trick window; pressing Trick
## (E / gamepad X) in the air spins the car once, and landing after a trick
## gives a short boost. The spin is visual only (the body and wheels turn a
## full circle about the car's centre), so physics, heading and the camera
## are untouched. The AI trick by calling try_trick().

signal ramp_entered
signal trick_started
signal trick_landed

## The window stays open this long after the ramp (or until landing).
const WINDOW := 1.5
## A trick can start this long after the lip even if still touching down.
const LIP_GRACE := 0.25
const SPIN_TIME := 0.5
## The landing boost: a small one, weaker than a Cyan drift boost.
const BOOST_EXTRA := 6.0
const BOOST_TIME := 1.0
const BOOST_KICK := 3.0
const BOOST_COLOR := Color(0.0, 0.95, 1.0)

var vehicle: VehicleController
## Tricks finished with a landing boost (tests).
var tricks_landed: int = 0

var _window: float = 0.0
var _since_ramp: float = 0.0
var _left_ground: bool = false
var _spinning: bool = false
var _spin_time: float = 0.0
var _pending_boost: bool = false
var _body: Node3D
var _body_rest: Transform3D


func _ready() -> void:
	vehicle = get_parent() as VehicleController
	# Run after the vehicle each physics tick, so the spin composes with the
	# wheel transforms it resets every step.
	process_physics_priority = 10


func is_tricking() -> bool:
	return _spinning


## True while a trick can still be started.
func window_open() -> bool:
	return _window > 0.0 and not _spinning and not _pending_boost


## Called by a jump ramp as the car goes over its lip.
func on_ramp() -> void:
	_window = WINDOW
	_since_ramp = 0.0
	_left_ground = false
	ramp_entered.emit()


## Starts a trick if one is allowed now (in the air after a ramp, or just
## past the lip). Returns whether it started.
func try_trick() -> bool:
	if not window_open() or vehicle == null:
		return false
	var airborne := vehicle.grounded_wheels == 0
	if not airborne and _since_ramp > LIP_GRACE:
		return false
	# The car's model can be swapped after spawning, so take the rest pose now.
	_body = vehicle.get_node_or_null("Body") as Node3D
	if _body != null:
		_body_rest = _body.transform
	_spinning = true
	_spin_time = 0.0
	_pending_boost = true
	_window = 0.0
	trick_started.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if vehicle == null or not vehicle.player_controlled or not vehicle.can_control():
		return
	if event.is_action_pressed(vehicle.action(&"trick")) and try_trick():
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	var airborne := vehicle.grounded_wheels == 0
	if _window > 0.0:
		_window -= delta
		_since_ramp += delta
		if airborne:
			_left_ground = true
		elif _left_ground and not _spinning and not _pending_boost:
			_window = 0.0 # landed without tricking
	if _spinning:
		_spin_time += delta
		if not airborne and _left_ground and _spin_time > 0.1:
			_spin_time = SPIN_TIME # landed early: finish the spin now
		if _spin_time >= SPIN_TIME:
			_spinning = false
		_apply_spin(_spin_angle())
	if _pending_boost:
		if _window <= 0.0:
			_since_ramp += delta
		if airborne:
			_left_ground = true
		elif not _spinning and _left_ground and vehicle.grounded_wheels >= 2:
			_pending_boost = false
			tricks_landed += 1
			vehicle.start_external_boost(BOOST_EXTRA, BOOST_TIME, BOOST_KICK, "Trick", BOOST_COLOR)
			trick_landed.emit()
		elif _since_ramp > 3.0:
			_pending_boost = false # never left the ground: no boost


## 0 .. TAU over the spin, eased so it whips round and settles.
func _spin_angle() -> float:
	if not _spinning:
		return 0.0
	var t := clampf(_spin_time / SPIN_TIME, 0.0, 1.0)
	return TAU * (1.0 - pow(1.0 - t, 2.0))


## Turns the body and each wheel about the car's up axis through its centre.
func _apply_spin(angle: float) -> void:
	var turn := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
	if _body != null:
		_body.transform = turn * _body_rest
	for child in vehicle.get_children():
		var ray := child as RayCast3D
		if ray == null or not ray.name.begins_with("Wheel"):
			continue
		var pivot := ray.get_node_or_null("Pivot") as Node3D
		if pivot == null:
			continue
		var local := ray.transform
		pivot.transform = local.affine_inverse() * turn * local * pivot.transform


## The body's current spin angle about the car's up axis (tests).
func body_angle() -> float:
	if _body == null:
		return 0.0
	var fwd := _body.transform.basis * _body_rest.basis.inverse() * Vector3.FORWARD
	return atan2(-fwd.x, -fwd.z)
