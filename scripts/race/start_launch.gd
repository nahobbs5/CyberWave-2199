class_name StartLaunch
extends RefCounted
## Rocket start (Mario Kart style), one per human racer. Times are in
## countdown steps: "3" at 0, "2" at 1, "1" at 2, START at 3.
## What counts is when the accelerate hold still down at START began
## (letting go resets it):
##   began while the "2" fades (WINDOW_START..WINDOW_END)  ROCKET START
##   began earlier                                         burnout (smoke, a spin, a slow start)
##   began later, or not holding at START                  normal start

const ROCKET := &"rocket"
const BURNOUT := &"burnout"
## The "2" shows from 1.0 to 2.0 and fades over its last 0.3 (HudAnnouncer
## FADE_OUT); the window is that fade plus a little grace after it.
const WINDOW_START := 1.55
const WINDOW_END := 2.2
## Seconds of steady revving to reach full rev() (visuals only).
const REV_RISE := 0.6

## When the current hold began (-1 = not holding).
var pressed_at: float = -1.0
var _rev: float = 0.0
var _last_t: float = 0.0


## `t` = countdown time in steps; `held` = accelerate is down right now.
func update(t: float, held: bool) -> void:
	var dt := maxf(0.0, t - _last_t)
	_last_t = t
	if not held:
		pressed_at = -1.0
		_rev = maxf(0.0, _rev - dt * 3.0)
		return
	if pressed_at < 0.0:
		pressed_at = t
	_rev = minf(1.0, _rev + dt / REV_RISE)


## 0..1: how hard the engine is revving (exhaust pops, rear squat).
func rev() -> float:
	return _rev


func is_holding() -> bool:
	return pressed_at >= 0.0


## The start this hold earns at START: ROCKET, BURNOUT or &"" (normal).
func result() -> StringName:
	if pressed_at < 0.0:
		return &""
	if pressed_at < WINDOW_START:
		return BURNOUT
	if pressed_at < WINDOW_END:
		return ROCKET
	return &""
