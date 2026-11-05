class_name FlickerLight
extends OmniLight3D
## A dying lamp: mostly on, with random stutters and dropouts. Optionally
## drives a material's glow too (half-dead neon signs, bulbs). With the
## reduced-flashing setting it stays on, steady and a little dimmer.

## 0 = steady, 1 = constantly failing.
@export_range(0.0, 1.0) var failing: float = 0.35
@export var base_energy: float = 2.0
## Emissive material that dims along with the light (optional).
var material: StandardMaterial3D
var base_emission: float = 2.0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _level: float = 1.0


func _ready() -> void:
	_rng.randomize()
	light_energy = base_energy
	if material != null:
		base_emission = material.emission_energy_multiplier


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if GameSettings.reduced_flashing:
		_apply(0.75)
		return
	_timer -= delta
	if _timer <= 0.0:
		var roll := _rng.randf()
		if roll < failing * 0.5:
			_level = 0.0 # drop out
			_timer = _rng.randf_range(0.05, 0.6)
		elif roll < failing:
			_level = _rng.randf_range(0.2, 0.6) # brown-out
			_timer = _rng.randf_range(0.03, 0.15)
		else:
			_level = _rng.randf_range(0.85, 1.0)
			_timer = _rng.randf_range(0.2, 2.5)
	_apply(_level)


func _apply(level: float) -> void:
	light_energy = base_energy * level
	if material != null:
		material.emission_energy_multiplier = base_emission * level
