class_name StatusEffects
extends Node
## Consistent status-effect rules for every racer (GDD 5.3, 6.5, 14.3
## StatusEffectManager). Weapons never change a car directly; they ask this
## node to apply an effect, and the vehicle reads the results.
##
## Effects:
##   stun / stagger  hard stuns: no control, speed scrubbed (Hunter Drone / Railgun)
##   emp             no weapon use, no drift charging, lower top speed (EMP Pulse)
##   traction        greatly reduced grip (Road Spike)
##   jammed          weapons offline; outlasts the EMP itself (EMP Pulse)
##   shield          blocks the next incoming attack (Firewall)
## After any hard stun ends, the racer is protected from hard stuns for
## stun_protection_time, so stuns can't be chained (GDD 6.5).

signal effect_started(effect: StringName, duration: float)
signal effect_ended(effect: StringName)
## by = &"shield" or &"protection".
signal attack_blocked(effect: StringName, by: StringName)

const HARD_STUNS: Array[StringName] = [&"stun", &"stagger"]

@export var stun_protection_time: float = 1.5
## Fraction of speed kept when hit by each hard stun.
@export var stun_speed_kept: float = 0.5
@export var stagger_speed_kept: float = 0.7
@export var emp_speed_multiplier: float = 0.85
@export var traction_grip_multiplier: float = 0.2

var _timers: Dictionary = {}
var _protection: float = 0.0
var _vehicle: VehicleController
var _shield_mesh: MeshInstance3D
var _status_light: OmniLight3D
var _spin: float = 0.0


func _ready() -> void:
	_vehicle = get_parent() as VehicleController
	_build_visuals()


## Applies a harmful effect. Returns false if a shield or stun protection
## blocked it.
func apply_attack(effect: StringName, duration: float) -> bool:
	if has(&"shield"):
		_end(&"shield")
		attack_blocked.emit(effect, &"shield")
		return false
	if HARD_STUNS.has(effect) and (_protection > 0.0 or is_stunned()):
		attack_blocked.emit(effect, &"protection")
		return false
	_start(effect, duration)
	if HARD_STUNS.has(effect) and _vehicle != null:
		_vehicle.scrub_speed(stun_speed_kept if effect == &"stun" else stagger_speed_kept)
		_vehicle.drift.cancel("stunned")
	elif effect == &"emp" and _vehicle != null:
		_vehicle.drift.cancel("EMP")
	return true


## Applies a beneficial effect (e.g. the Firewall shield); never blocked.
func apply_buff(effect: StringName, duration: float) -> void:
	_start(effect, duration)


## Takes weapons offline. Only called after an attack has landed, so it is
## never blocked itself.
func apply_jam(duration: float) -> void:
	_start(&"jammed", duration)


func has(effect: StringName) -> bool:
	return _timers.has(effect)


func time_left(effect: StringName) -> float:
	return _timers.get(effect, 0.0)


func active_effects() -> Array:
	return _timers.keys()


func is_stunned() -> bool:
	return has(&"stun") or has(&"stagger")


func is_protected() -> bool:
	return _protection > 0.0


func can_drive() -> bool:
	return not is_stunned()


func can_use_weapons() -> bool:
	return not is_stunned() and not has(&"emp") and not has(&"jammed")


func can_charge_drift() -> bool:
	return not is_stunned() and not has(&"emp")


func speed_multiplier() -> float:
	return emp_speed_multiplier if has(&"emp") else 1.0


func grip_multiplier() -> float:
	return traction_grip_multiplier if has(&"traction") else 1.0


func clear_all() -> void:
	for effect in _timers.keys():
		_end(effect)
	_protection = 0.0


func _start(effect: StringName, duration: float) -> void:
	_timers[effect] = maxf(time_left(effect), duration)
	effect_started.emit(effect, duration)


func _end(effect: StringName) -> void:
	if not _timers.has(effect):
		return
	_timers.erase(effect)
	if HARD_STUNS.has(effect) and not is_stunned():
		_protection = stun_protection_time
	effect_ended.emit(effect)


func _physics_process(delta: float) -> void:
	_protection = maxf(0.0, _protection - delta)
	for effect in _timers.keys():
		_timers[effect] -= delta
		if _timers[effect] <= 0.0:
			_end(effect)


# --- readable placeholder visuals (GDD 6.5) ---------------------------------------

func _build_visuals() -> void:
	if _vehicle == null:
		return
	_shield_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.8
	sphere.height = 3.4
	_shield_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mesh.material_override = mat
	_shield_mesh.visible = false
	_shield_mesh.position = Vector3(0.0, 0.3, 0.0)
	_vehicle.add_child.call_deferred(_shield_mesh)
	_status_light = OmniLight3D.new()
	_status_light.omni_range = 5.0
	_status_light.light_energy = 0.0
	_status_light.position = Vector3(0.0, 1.2, 0.0)
	_vehicle.add_child.call_deferred(_status_light)


func _process(delta: float) -> void:
	if _vehicle == null or _shield_mesh == null:
		return
	_shield_mesh.visible = has(&"shield")
	var body := _vehicle.get_node_or_null("Body") as Node3D
	if body != null:
		# Hard stuns spin the bodywork (visual only; physics keeps going straight).
		if is_stunned():
			_spin += delta * TAU * 2.0
		else:
			_spin = move_toward(_spin, roundf(_spin / TAU) * TAU, delta * 12.0)
		body.rotation.y = _spin
	var flicker := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
	if has(&"emp"):
		_status_light.light_color = Color(0.3, 0.6, 1.0)
		_status_light.light_energy = 3.0 * flicker
	elif has(&"traction"):
		_status_light.light_color = Color(1.0, 0.9, 0.2)
		_status_light.light_energy = 3.0 * flicker
	elif is_stunned():
		_status_light.light_color = Color(1.0, 0.2, 0.2)
		_status_light.light_energy = 3.0
	elif has(&"jammed"):
		_status_light.light_color = Color(0.3, 0.6, 1.0)
		_status_light.light_energy = 1.0 * flicker
	else:
		_status_light.light_energy = 0.0
