# CyberWave-2199

Single-player 3D arcade combat racing game for Godot 4 (GDScript, Jolt Physics).
The authoritative design is [`docs/Game Design Document.md`](docs/Game%20Design%20Document.md) (GDD v1.1).

**Current milestone: Phase 1, the driving prototype** (GDD §16). Drive one placeholder car around a
graybox test circuit, with Shift drifting, three boost levels, two chase cameras and vehicle recovery.
Weapons, AI, menus and cosmetics are deliberately not implemented yet.

Open the project in Godot 4.7 and press **F5**. The main scene is `scenes/main.tscn`.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + A / D | LB / L1 (left), RB / R1 (right) |
| Cycle camera (Far ↔ Close) | C | View / Touchpad |
| Reset vehicle | R | Y / Triangle |

Arrow keys are an extra convenience on top of the GDD's bindings. Space, 1/2 and Esc (weapons and pause) come in later phases.

Actions are registered at startup by `scripts/core/input_setup.gd`. Any action you define in
**Project Settings → Input Map** with the same name takes priority over the defaults.

### Drifting

- At speed (over 12 m/s, about 43 km/h), hold **Shift** and steer with **A** or **D**. The steering direction when the drift starts picks left or right; after that, keep Shift held and steer to shape it (into the drift tightens it, against it widens it). Shift while driving straight does nothing.
- Shift drifting replaced the original Q/E binding in GDD v1.1 (see its Revision History).
- Charge only builds while the car is grounded and sliding sideways.
- **Cyan** at 1 s, **Magenta** at 2.5 s, **Gold** at 4 s of valid drifting.
- **Releasing** Shift (or the bumper) fires the boost. Higher levels give more speed for longer.
- Leaving the ground pauses charging. Staying airborne for more than 1.5 s, hitting something hard, or slowing well below drift speed cancels the drift with no boost.
- Feedback: rear-wheel sparks and an undercarriage glow in the current level's colour, a tone for each level, exhaust flames and a FOV kick while boosting, and the HUD charge bar.

### Recovery

- **R** (or gamepad Y) resets you to the last point on the track you legitimately drove through, about 6 m behind it, upright and stopped. Resets can never move you forward, so they can't be used as shortcuts.
- Automatic recovery happens when the car is:
  - upside down or on its side for 1.5 s,
  - stuck (pressing throttle or brake while barely moving) for 3 s,
  - below the world, or
  - more than 25 m off the road edge for 2 s.
- The respawn spot is checked for other vehicles and shifts sideways or back if it is occupied.

## Project layout

```
scenes/
  main.tscn                  Phase 1 entry scene (track + car + camera + HUD)
  tracks/test_circuit.tscn   Graybox circuit, environment and moonlight
  vehicles/placeholder_car.tscn  Primitive-mesh car: body, 4 raycast wheels, drift/recovery/feedback
  ui/prototype_hud.tscn      Debug HUD
scripts/
  prototype_main.gd          Wires the scene together at startup
  core/input_setup.gd        Default keyboard and gamepad bindings
  vehicles/
    vehicle_controller.gd    VehicleController: suspension, drive, grip, steering, boost
    drift_controller.gd      DriftController: drift state, charge levels, boost on release
    vehicle_recovery.gd      VehicleRecovery: manual/auto reset, safe-point tracking
    vehicle_feedback.gd      Placeholder drift/boost visuals and generated audio cues
    vehicle_stats.gd         VehicleStats resource (Top Speed, Acceleration, Handling, Drift, ...)
  camera/
    chase_camera.gd          ChaseCamera: shared controller, collision avoidance, saved choice
    camera_profile.gd        CameraProfile resource (distance, height, FOV, smoothing, ...)
  track/track_circuit.gd     TrackCircuit: builds the circuit and answers track-space queries
  ui/                        PrototypeHUD and DriftMeter
resources/
  vehicles/placeholder_gt_stats.tres
  cameras/far_chase.tres, close_chase.tres
tests/test_phase1.gd         Headless logic and physics checks
docs/                        GDD
```

### Architecture notes

- **Vehicle physics** (`VehicleController`, a RigidBody3D) are shared and configured with a `VehicleStats` resource (GDD §14.3).
  - Four `RayCast3D` wheels apply spring/damper forces.
  - Drive, lateral grip and yaw shape the body's velocity directly in `_integrate_forces`. This gives arcade handling and keeps the car from rolling over in corners.
  - A low centre of mass and a gentle upright assist (on the ground and while truly airborne) resist flipping.
  - AI in Phase 2 can drive the same car by setting `player_controlled = false` and writing `throttle_input`, `steer_input`, etc.
- **Drifting** (`DriftController`) is pure logic, fed by the vehicle each physics step, so it is unit-testable. Its signals drive the HUD and effects.
- **Recovery** (`VehicleRecovery`) keeps `last_safe_offset` (distance along the track) and only accepts forward steps under 25 m. `total_progress` also feeds the HUD lap counter until real checkpoints arrive in Phase 2.
- **The track** (`TrackCircuit`, `@tool`) generates everything from a closed loop of control points (a Catmull-Rom curve). It runs in the editor too, so the layout is visible there.
  - Generated nodes are prefixed `_Gen` and are not saved, so edit the exported values instead.
  - It exposes `get_offset_at`, `get_safe_transform`, `wrapped_delta` and related helpers for later checkpoint and AI work.
- **Collision layers:** 1 = environment, 2 = vehicles. Wheel rays only hit the environment, so cars never "drive" on each other.
- **Camera choice** is stored in `user://settings.cfg` (`[camera] profile_index`). A Phase 5 SettingsManager should take over this file.

## Running the headless checks

```
godot --headless --import                     # first run / after adding scripts (builds class cache)
godot --headless -s res://tests/test_phase1.gd
```

These cover:
- drift thresholds and rules (pure logic),
- input bindings,
- track queries,
- spawning and settling,
- acceleration, braking and reverse,
- steering direction,
- a simulated drift reaching Gold and boosting,
- camera cycling and placement,
- manual reset and the anti-shortcut rule,
- overturned, stuck and out-of-bounds recovery.

The exit code is non-zero if anything fails. These checks do **not** judge how the game looks or feels.

## Status and known issues

**Verified (2026-11-05):** 83 headless checks pass on Godot 4.7.2 (Linux build), including a scripted driver completing a full lap (52.5 s at about 94 km/h) with no recoveries. The game has **not** yet been played or viewed on screen. Visuals, feel, camera motion, gamepad input and audio still need a hands-on check.

- **Tuning is first-pass.** Every number in `VehicleStats` and the camera profiles is a starting point (GDD §18 leaves these to playtesting): speeds, grip, drift yaw, boost strength, suspension and camera smoothing.
- **Camera jitter on high-refresh monitors.** The camera updates in `_physics_process` (60 Hz). Physics interpolation is not enabled yet.
- **Placeholder feedback only.** Sparks are emissive spheres, the audio cues are generated sine tones, and there are no tyre or engine sounds yet.
- **The lap counter is distance-based**, not checkpoint-based. Proper checkpoints and lap validation are Phase 2.
- **Safe-point tracking ignores jumps over 25 m.** A car flung far along the track keeps its old safe point until it resets. That is correct for anti-shortcut purposes, but may need softening once tracks have jumps.
- **The circuit is short for the GDD race-length target.** At 1.33 km, a three-lap race is roughly 2 to 3 minutes, against the GDD §15.2 target of 4 to 6. Adjust `control_points` once the speed feel is settled.
- **The track is flat.** No elevation, ramps or banking yet.
- **No pause** (Esc), weapons, AI, countdown or menus, by design for Phase 1.
