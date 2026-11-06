class_name SlipstreamLines
extends Control
## Faint white wind streaks at the screen edges, rushing toward the centre,
## while you're in someone's slipstream; they get stronger as the meter
## fills. Off with Reduced flashing. Drawn lines only (no particles).

const STREAKS := 26

var vehicle: VehicleController
## Current strength 0..1 (eased toward the meter; tests).
var strength: float = 0.0

var _seeds: Array[Vector3] = []


func _init() -> void:
	name = "SlipstreamLines"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2199
	for i in STREAKS:
		# x: angle around the centre, y: phase, z: length factor.
		_seeds.append(Vector3(rng.randf() * TAU, rng.randf(), rng.randf_range(0.6, 1.0)))


func _process(delta: float) -> void:
	var want := 0.0
	if is_instance_valid(vehicle) and vehicle.in_slipstream and not GameSettings.reduced_flashing:
		want = 0.35 + 0.65 * vehicle.slipstream_charge
	strength = move_toward(strength, want, delta * 3.0)
	if strength > 0.0 or want > 0.0:
		queue_redraw()


func _draw() -> void:
	if strength <= 0.01:
		return
	var c := size * 0.5
	var reach := c.length()
	var t := Time.get_ticks_msec() / 1000.0
	for s in _seeds:
		var dir := Vector2(cos(s.x), sin(s.x))
		# Streaks travel inward from the edge over 0.4 s, then repeat.
		var phase := fposmod(t * 2.5 + s.y, 1.0)
		var outer := reach * lerpf(1.0, 0.62, phase)
		var inner := outer - reach * 0.16 * s.z
		var alpha := strength * 0.35 * sin(phase * PI)
		draw_line(c + dir * outer, c + dir * inner, Color(1, 1, 1, alpha), 2.0, true)
