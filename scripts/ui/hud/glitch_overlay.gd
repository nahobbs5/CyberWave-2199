class_name GlitchOverlay
extends ColorRect
## System Glitch on a racer's view (GDD 6.3): scrambles the middle of the
## screen while their car has the "glitch" status. Sits at the back of the
## RaceHUD, so every HUD panel (position, laps, items, minimap) draws over it
## and stays readable; its shader leaves the corners alone. One per view, so
## split screen works. Reduced flashing (GDD 11.9) keeps it slow and smooth
## without strobing, but it still covers the centre.

const SHADER := preload("res://assets/shaders/screen_glitch.gdshader")
const RAMP_IN := 0.25
const FADE_OUT := 0.8

## The car whose status drives this overlay (set by RaceHUD.setup).
var vehicle: VehicleController

var _material: ShaderMaterial
var _intensity: float = 0.0
var _burst: float = 0.0
var _next_burst: float = 0.0
var _glitched_for: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "GlitchOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 1)
	_rng.randomize()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	visible = false


## 0..1 strength right now (tests).
func intensity() -> float:
	return _intensity


func _process(delta: float) -> void:
	var left := 0.0
	if vehicle != null and is_instance_valid(vehicle) and vehicle.status != null:
		left = vehicle.status.time_left(&"glitch")
	if left <= 0.0:
		_glitched_for = 0.0
		_intensity = move_toward(_intensity, 0.0, delta / 0.15)
		_burst = 0.0
	else:
		_glitched_for += delta
		var ramp := minf(_glitched_for / RAMP_IN, 1.0)
		var fade := clampf(left / FADE_OUT, 0.0, 1.0)
		_intensity = 0.75 * ramp * fade
		var calm := GameSettings.reduced_flashing
		# Heavy splat moments every so often (gentle swells when calm).
		_next_burst -= delta
		if _next_burst <= 0.0:
			_next_burst = _rng.randf_range(0.4, 0.9) * (2.0 if calm else 1.0)
			_burst = _rng.randf_range(0.6, 1.0) * (0.5 if calm else 1.0)
		_burst = move_toward(_burst, 0.0, delta / (0.6 if calm else 0.25))
		_intensity = minf(1.0, _intensity + 0.25 * _burst * fade)
	visible = _intensity > 0.001
	if visible:
		_material.set_shader_parameter("intensity", _intensity)
		_material.set_shader_parameter("burst", _burst)
		_material.set_shader_parameter("calm", 1.0 if GameSettings.reduced_flashing else 0.0)
		_material.set_shader_parameter("seed", float(get_instance_id() % 997))
