class_name GhostData
extends Resource
## One recorded run for Time Trial (GDD 2.5): the car's pose sampled at a
## fixed rate from GO to the finish, plus its gate times. Baked rival /
## expert ghosts (tests/tools/bake_ghosts.gd) and your own best run use it.
##
## Playback is time-scaled so the ghost crosses the line at exactly
## `target_time`: race time t shows the recording at t * time_scale().

## Floats per frame: position xyz, rotation quaternion xyzw, forward speed,
## steer (-1..1), drawn drift yaw, boosting (0 / 1: Nitro or any boost).
const STRIDE := 11

@export var track_name: String = ""
@export var vehicle_id: String = ""
## Paint colour for the ghost's tint (your own ghost: your car's colour).
@export var color: Color = Color(0.2, 0.9, 1.0)
@export var sample_hz: float = 30.0
@export var frames: PackedFloat32Array = PackedFloat32Array()
## Recorded race time at each gate crossed after GO, in order (lap gates
## included; the last one is the finish).
@export var checkpoint_times: PackedFloat32Array = PackedFloat32Array()
@export var lap_times: PackedFloat32Array = PackedFloat32Array()
## The recording's own finish time.
@export var recorded_time: float = 0.0
## The time playback finishes in (0 = as recorded).
@export var target_time: float = 0.0


func frame_count() -> int:
	return frames.size() / STRIDE


## The time to beat: the target if set, else the recording's.
func finish_time() -> float:
	return target_time if target_time > 0.0 else recorded_time


## Recording seconds per race second (>1 = played faster than recorded).
func time_scale() -> float:
	var f := finish_time()
	return recorded_time / f if f > 0.0 and recorded_time > 0.0 else 1.0


## Race time at which the played-back ghost crosses gate number `n` (0 =
## the first gate after GO), or -1.
func gate_time(n: int) -> float:
	if n < 0 or n >= checkpoint_times.size():
		return -1.0
	return checkpoint_times[n] / time_scale()


func add_frame(xf: Transform3D, speed: float, steer: float, yaw: float, boosting: bool = false) -> void:
	var q := xf.basis.get_rotation_quaternion()
	frames.append_array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w, speed, steer, yaw,
			1.0 if boosting else 0.0])


## The pose at race time `t` (scaled): {transform, speed, steer, yaw,
## boosting, done}.
## Past the end it holds the last frame with done = true.
func sample(t: float) -> Dictionary:
	var n := frame_count()
	if n == 0:
		return {"transform": Transform3D.IDENTITY, "speed": 0.0, "steer": 0.0, "yaw": 0.0, "boosting": false, "done": true}
	var rec := maxf(t, 0.0) * time_scale()
	var f := rec * sample_hz
	var i := clampi(int(floor(f)), 0, n - 1)
	var j := mini(i + 1, n - 1)
	var w := clampf(f - float(i), 0.0, 1.0) if j != i else 0.0
	var a := i * STRIDE
	var b := j * STRIDE
	var pos := Vector3(frames[a], frames[a + 1], frames[a + 2]).lerp(Vector3(frames[b], frames[b + 1], frames[b + 2]), w)
	var qa := Quaternion(frames[a + 3], frames[a + 4], frames[a + 5], frames[a + 6]).normalized()
	var qb := Quaternion(frames[b + 3], frames[b + 4], frames[b + 5], frames[b + 6]).normalized()
	return {
		"transform": Transform3D(Basis(qa.slerp(qb, w)), pos),
		"speed": lerpf(frames[a + 7], frames[b + 7], w) * time_scale(),
		"steer": lerpf(frames[a + 8], frames[b + 8], w),
		"yaw": lerpf(frames[a + 9], frames[b + 9], w),
		"boosting": frames[a + 10] > 0.5,
		"done": rec >= recorded_time and recorded_time > 0.0,
	}
