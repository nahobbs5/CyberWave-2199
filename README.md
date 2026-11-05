# CyberWave-2199

Single-player 3D arcade combat racing game for Godot 4 (GDScript, Jolt Physics).
The authoritative design is [`docs/Game Design Document.md`](docs/Game%20Design%20Document.md) (GDD v1.1).

**Current milestone: Phase 2, the racing prototype** (GDD §16). Race seven AI rivals over three laps
on the graybox test circuit: starting grid (you start 8th), READY / SET / GO countdown, checkpoints and
lap validation, live positions, and a results screen. Phase 1 driving (Shift drifting, boosts, cameras,
recovery) is unchanged. Weapons, menus and cosmetics are deliberately not implemented yet.

Open the project in Godot 4.7 and press **F5** to start a race (`scenes/race/race.tscn`).
`scenes/free_drive.tscn` is the Phase 1 sandbox: one car, no rules (open it and press **F6**).

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + A / D | LB / L1 (left), RB / R1 (right) |
| Cycle camera (Far ↔ Close) | C | View / Touchpad |
| Reset vehicle | R | Y / Triangle |
| Race again (results screen) | Enter | A / Cross |

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
  - stuck (pressing throttle or brake while barely moving forward or back; sliding sideways along a wall counts as stuck) for 3 s,
  - below the world, or
  - outside the circuit (more than 3 m past the road edge, i.e. beyond the barrier) for 1 s.
- The respawn spot is checked for other vehicles and shifts sideways or back if it is occupied.

### The test circuit

The test circuit is a 2.6 km graybox loop driven clockwise:
- a 600 m main straight into a tight right hairpin (T1),
- a left-right pair (T2–T3), where T3 is a long 133° right-hander made for drifting,
- flowing esses (T4–T6) into a 95° drift corner (T7),
- a fast kink (T8) onto a 500 m back straight,
- a double-right hairpin (T9–T10), then a left (T11) onto the main straight.

The two long straights ending in hard braking are the main overtaking spots.

The layout is the `control_points` list on `scenes/tracks/test_circuit.tscn`, sampled from straights and arcs. Barriers have a 4 m invisible collider above the 1.4 m visible wall, so cars can't be launched out of the circuit.

### Racing

- **Grid:** seven AI rivals fill slots 1–7 and you start last (GDD §2.1). Controls are locked during READY / SET / GO; there are no false-start penalties.
- **Checkpoints:** 8 evenly spaced gates, with gate 0 at the start/finish line. A gate only counts if it is the next one in order. Skipping ahead, reversing through gates, or a recovery teleport never adds progress. Crossing the line after every gate completes a lap.
- **Positions** are live: finishers in finishing order, everyone else by distance raced since their last valid gate.
- **When you finish,** the results screen shows the standings and fills in as the AI cross the line. Your car switches to autopilot.
- **HUD:** position, lap, race time, live standings, lap/finish banners and a WRONG WAY warning. Speed and drift charge are as before.
- **AI difficulty** is set on the `Race` node in the Inspector (`difficulty`: `resources/ai/easy|normal|hard.tres`; default Normal). Lap count is `total_laps` (default 3). Menus come in Phase 5.

## Project layout

```
scenes/
  race/race.tscn             Main scene: 8-car race (RaceManager + track + camera + HUDs)
  free_drive.tscn            Phase 1 sandbox (one car, no race rules)
  tracks/test_circuit.tscn   Graybox circuit, environment and moonlight
  vehicles/placeholder_car.tscn  Primitive-mesh car: body, 4 raycast wheels, drift/recovery/feedback
  ui/prototype_hud.tscn      Speed / drift / camera HUD
scripts/
  free_drive.gd              Wires the sandbox scene together
  race/
    race_manager.gd          RaceManager: grid, countdown, checkpoints, positions, finish
    race_progress.gd         RaceProgress: one racer's laps, gates, times
    racer_profile.gd         RacerProfile resource: rival name, colour, personality
    rival_roster.gd          RivalRoster resource: the seven rivals
  ai/
    ai_controller.gd         AIController: steering, speed, drifting, traffic
    racing_line.gd           RacingLine: precomputed line, safe speeds, drift corners
    ai_difficulty.gd         AIDifficulty resource (Easy / Normal / Hard)
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
  ui/                        PrototypeHUD, DriftMeter, RaceHUD
resources/
  vehicles/placeholder_gt_stats.tres
  cameras/far_chase.tres, close_chase.tres
  ai/easy.tres, normal.tres, hard.tres
  racers/rival_roster.tres   Seven placeholder rivals (edit in the Inspector)
tests/
  test_phase1.gd             Driving checks (free-drive scene)
  test_phase2.gd             Race checks, including full simulated races
docs/                        GDD
```

### Architecture notes

- **Vehicle physics** (`VehicleController`, a RigidBody3D) are shared and configured with a `VehicleStats` resource (GDD §14.3).
  - Four `RayCast3D` wheels apply spring/damper forces.
  - Drive, lateral grip and yaw shape the body's velocity directly in `_integrate_forces`. This gives arcade handling and keeps the car from rolling over in corners.
  - A low centre of mass and a gentle upright assist (on the ground and while truly airborne) resist flipping.
  - AI drive the same car: `AIController` sets `player_controlled = false` and writes `throttle_input`, `steer_input` and the drift buttons. Difficulty never changes car stats (GDD §7.2).
- **Drifting** (`DriftController`) is pure logic, fed by the vehicle each physics step, so it is unit-testable. Its signals drive the HUD and effects.
- **Recovery** (`VehicleRecovery`) keeps `last_safe_offset` (distance along the track). It only accepts a forward move if the car actually travelled about that far (+15 m slack), so teleports and shortcuts never count, but missed updates (airborne, scraping a wall) do. It works the same for AI cars. `total_progress` feeds the free-drive lap timer; races use checkpoints.
- **The racing line** (`RacingLine`) is built once per race and shared by every AI driver:
  - A shortest-path pass cuts the corners, then a minimum-curvature pass rounds off the apexes.
  - A safe speed is computed for every point from the car's handling, with a braking pass so the AI slows before corners.
  - Drift corners are stretches whose turn rate suits a drift (at least 0.6 rad/s) and that last long enough to earn at least Cyan.
- **AI drivers** (`AIController`):
  - steer toward a point ahead on the line, and track the line's speed scaled by difficulty and personality,
  - pull out to pass slower cars and ease away from cars alongside,
  - roll per corner whether to drift, using the difficulty's drift chance times the rival's drift tendency.
  - Rubber-banding only adjusts the AI's target speed (Easy mild, Normal minimal, Hard none).
- **The track** (`TrackCircuit`, `@tool`) generates everything from a closed loop of control points (a Catmull-Rom curve). It runs in the editor too, so the layout is visible there.
  - Generated nodes are prefixed `_Gen` and are not saved, so edit the exported values instead.
  - It also builds the checkpoint gates (Area3D, emitting `checkpoint_crossed`), defines the grid slots, and exposes `get_offset_at`, `get_safe_transform`, `wrapped_delta` and related helpers.
- **Collision layers:** 1 = environment, 2 = vehicles. Wheel rays only hit the environment, so cars never "drive" on each other.
- **Camera choice** is stored in `user://settings.cfg` (`[camera] profile_index`). A Phase 5 SettingsManager should take over this file.

## Running the headless checks

```
godot --headless --import                                   # first run / after adding scripts
godot --headless --fixed-fps 60 -s res://tests/test_phase1.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase2.gd
```

`--fixed-fps 60` runs the physics as fast as the machine allows (about 2.5× faster than real time here), which matters for the simulated races. Phase 1 takes about 45 s and Phase 2 about 60 s.

Phase 1 covers:
- drift thresholds and rules (pure logic),
- input bindings,
- track queries,
- spawning and settling,
- acceleration, braking and reverse,
- steering direction,
- a simulated drift reaching Gold and boosting,
- camera cycling and placement,
- manual reset and the anti-shortcut rule,
- overturned, stuck and out-of-bounds recovery,
- a scripted lap and Shift + A/D drifting with real key events.

Phase 2 covers:
- checkpoint order and lap logic (pure logic),
- standings order,
- grid layout (8 cars, you last, nobody overlapping, all behind the line),
- countdown lock and GO,
- teleporting past gates not counting,
- the wrong-way warning,
- a full 3-lap race with 8 AI drivers, checking that every gate is counted, finish order matches standings, live positions agree with an independent distance measure, and the results screen appears,
- AI earning drift boosts on a test oval.

The exit code is non-zero if anything fails. These checks do **not** judge how the game looks or feels.

## Status and known issues

**Verified (2026-11-05):** 91 Phase 1 and 159 Phase 2 headless checks pass on Godot 4.7.2 (Linux build). On the redesigned 2.6 km circuit, simulated races run with no recoveries at any difficulty. AI earn roughly 2–18 drift boosts each per race.

| AI difficulty | Typical lap | 3-lap race (all 8 AI) |
|---|---|---|
| Easy | about 71 s | 3:33–3:42 |
| Normal | about 64 s | 3:12–3:27 |
| Hard | about 61 s | 3:01–3:25 |

The racing has **not** been played on screen yet.

- **AI pace is untested against a human.** Normal laps at about 64 s may be quick or slow for you. Tune `speed_factor` in `resources/ai/*.tres`.
- **Enter and gamepad A** restart from the results screen through Godot's default `ui_accept` action, which also includes Space. Space becomes the weapon key in Phase 3, so restart should get its own action then.

- **Tuning is first-pass.** Every number in `VehicleStats` and the camera profiles is a starting point (GDD §18 leaves these to playtesting): speeds, grip, drift yaw, boost strength, suspension and camera smoothing.
- **Camera jitter on high-refresh monitors.** The camera updates in `_physics_process` (60 Hz). Physics interpolation is not enabled yet.
- **Placeholder feedback only.** Sparks are emissive spheres, the audio cues are generated sine tones, and there are no tyre or engine sounds yet.
- **The free-drive lap timer is distance-based.** Races use real checkpoints.
- **Race length:** AI finish a Normal race in about 3:15. A human finishing mid-pack will likely take about 3:30–4:00, near the low end of the GDD §15.2 target of 4–6 minutes. Lengthen the layout or raise the lap count if races feel short.
- **Scene load takes about 1.2 s** of generation (track meshes and colliders about 0.8 s, racing line about 0.4 s) before the countdown. That's acceptable for now, but could later be cached or baked.
- **The Aggressor wins most simulated races.** Its personality never backs off behind slower cars, which pays off in AI-only races. Balancing rivals is Phase 6 work.
- **The track is flat.** No elevation, ramps or banking yet. The road is visual only; the ground slab provides collision, so elevation will need road colliders.
- **No pause** (Esc), weapons, menus, cosmetics or pre-race camera sweep yet. These come in later phases.
- **Rival names are placeholders** ("The Technician", etc.), following GDD §7.3. AI cars show a floating name tag.
