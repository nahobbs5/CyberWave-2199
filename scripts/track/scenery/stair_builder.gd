class_name StairBuilder
extends RefCounted
## Stone stair flights drawn over a smooth driving surface (GDD 8.6i). The
## track hides its road surface over these stretches (hidden_surface) but
## keeps the collider, so cars drive a continuous ramp while the steps are
## what you see: irregular treads (depth, width and a slight twist vary),
## each tread's top meeting the ramp at its middle (so wheels sit within a
## few centimetres of the stone), with a painted riser between treads.

var scenery: TrackScenery
## Material keys: the treads and the painted risers.
var tread_key: String = "step_tread"
var riser_key: String = "step_riser"
var steps: int = 0


func _init(p_scenery: TrackScenery) -> void:
	scenery = p_scenery


## One flight from distance `from_d` to `to_d` along a route. `point` is
## func(d) -> Vector3 (track-local road centre) and `forward` is
## func(d) -> Vector3 (flat direction of travel); `width` is the road width.
func flight(point: Callable, forward: Callable, from_d: float, to_d: float, width: float) -> void:
	var rng := scenery.rng
	var d := from_d
	var prev_top := NAN
	while d < to_d - 0.4:
		var depth := minf(rng.randf_range(1.05, 1.65), to_d - d)
		var d1 := d + depth
		var a: Vector3 = point.call(d)
		var b: Vector3 = point.call(d1)
		var mid: Vector3 = point.call((d + d1) * 0.5)
		var fwd: Vector3 = forward.call((d + d1) * 0.5)
		var right := fwd.cross(Vector3.UP).normalized()
		var top := (a.y + b.y) * 0.5
		var twist := rng.randf_range(-0.035, 0.035)
		var basis := Basis(right, Vector3.UP, -fwd).rotated(Vector3.UP, twist)
		var w := width + rng.randf_range(0.0, 0.5)
		var shift := right * rng.randf_range(-0.15, 0.15)
		var centre := Vector3(mid.x, top - 0.4, mid.z) + shift
		scenery.add_box(tread_key, Vector3(w, 0.8, depth + 0.04), Transform3D(basis, centre))
		# The painted riser where this tread meets the one before.
		if not is_nan(prev_top):
			var rise := absf(top - prev_top)
			if rise > 0.03:
				var at := Vector3(a.x, minf(top, prev_top) + rise * 0.5, a.z)
				scenery.add_box(riser_key, Vector3(w + 0.02, rise + 0.02, 0.06), Transform3D(basis, at))
		prev_top = top
		steps += 1
		d = d1
