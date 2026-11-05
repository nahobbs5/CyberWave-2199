# CyberWave-2199

Single-player 3D arcade combat racing game for Godot 4 (GDScript, Jolt Physics).
The authoritative design is [`docs/Game Design Document.md`](docs/Game%20Design%20Document.md) (GDD v1.3).

**Current milestone: Phase 4, game modes** (GDD §16). On the graybox test circuit:
- **Versus:** one race against seven AI rivals,
- **Grand Prix:** two three-race championships with points, grids that follow the previous race, and saving between races,
- **Elimination:** the last two racers are knocked out at each lap's midpoint checkpoint,
- a pause menu (Esc / Start) and a new **Triple Nitro** weapon.

Phases 1–3 (driving, racing, combat) are unchanged. The real main menu, garage and cosmetics are Phase 5.

Open the project in Godot 4.7 and press **F5**. That opens a placeholder **mode select** screen
(`scenes/menu/mode_select.tscn`) with the modes and race settings: AI difficulty, laps (Versus) and weapons on/off.
Running `scenes/race/race.tscn` directly (**F6**) still starts a Versus race using the `Race` node's Inspector settings.
**Free drive** (`scenes/free_drive.tscn`, the Phase 1 sandbox) is on the mode screen too; Esc returns from it.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + A / D | LB / L1 (left), RB / R1 (right) |
| Cycle camera (Far ↔ Close) | C | View / Touchpad |
| Reset vehicle | R | Y / Triangle |
| Select weapon slot 1 / 2 | 1 / 2 | D-pad Left / Right |
| Use selected weapon | Space | A / Cross |
| Pause menu | Esc | Start / Options |
| Menu buttons (pause, results, mode select) | Enter, mouse, arrow keys | A / Cross, D-pad |

Arrow keys are an extra convenience on top of the GDD's bindings. Space doesn't press menu buttons, so firing
weapons as you cross the line can't skip the results screen. The results buttons also wait 1.5 s before they respond.

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
- **AI difficulty, laps and weapons** come from the mode select screen. When `race.tscn` is run directly, they come from the `Race` node in the Inspector instead (`difficulty`, `total_laps`, `weapons_enabled`).

### Game modes

All races use the test circuit for now. Grand Prix races carry the real track names, and each championship's
track list is data (`resources/grand_prix/*.tres`), so the Phase 6 tracks can be dropped in.

- **Versus** (GDD §2.1): one race, you start eighth. When you finish, the results fill in as the AI cross the line. **Race again** or **Quit to mode select**.
- **Grand Prix** (GDD §2.2): *American Circuit* or *World Circuit*, three races of three laps each.
  - Points are 15-12-10-8-6-4-2-1. Ties are broken by most wins, then most second places, then the order in the most recent race.
  - Race 1 starts the seven rivals in slots 1–7 with you last. Each later grid is the previous race's finishing order, not the points order. Rivals keep their names, colours and personalities all season.
  - **The race result is fixed when you cross the line:** anyone still racing is classified in their current order. That way you never have to wait for the field, and the points always match what the results screen shows.
  - The results screen shows your race points and the championship standings, then **Next race**. After race 3 it shows the final standings with the champion highlighted.
  - **Saving:** the championship is saved to `user://grand_prix_save.json` when it starts and after every race. If you quit midway, **Continue Grand Prix** appears on the mode screen. The save holds the championship, results, points, next grid, vehicle, rival identities, settings and a coins field (coins are Phase 5). It's deleted once the championship is complete. Starting a new Grand Prix replaces it.
  - **Restart race** (pause menu) replays the current race, but only until you finish it: once the result is saved it can't be rerolled.
- **Elimination** (GDD §2.3): always three laps.
  - A red **ELIMINATION** arch marks checkpoint 4 (the lap midpoint).
  - On each lap, racers qualify in the order they cross it: 6 on lap 1, 4 on lap 2, 2 on lap 3. The moment the last place is taken, everyone else still racing is out. There's no timer, and the start/finish line never eliminates anyone.
  - Eliminated cars stop colliding with active racers and stop fighting at once, then shrink away and disappear. Their positions are 7–8, 5–6 and 3–4, ordered by how far they'd got.
  - The first finalist across the line wins, and the other is classified second.
  - HUD: active racers, the next elimination, places left, your distance to the gate, a QUALIFIED banner when you get through, and an "X ELIMINATED" feed. If you're knocked out, the camera follows the leader and the results appear.
- **Pause menu** (Esc / Start): the whole race stops (physics, timers, AI). It offers **Resume**, **Restart race** and **Quit to mode select**.

### Weapons

Drive through a "?" crate to collect a random weapon into your first free slot. With both slots full, crates stay in place for someone else. Crates respawn after 3 s, in 5 rows of 4 around the lap.

| Weapon | How it works | Effect on the victim |
|---|---|---|
| Railgun | Targeted. Fast shot aimed at your lock (with lead), else straight ahead | 0.7 s stagger (hard stun); knocks out the selected weapon |
| Hunter Drone | Targeted / guided. Follows the track, then homes in on your lock or the nearest racer ahead | 0.8 s stun (hard stun); knocks out the selected weapon |
| EMP Pulse | Instant 22 m pulse around you | 1.5 s: no drift charging, −15% top speed; weapons jammed (unusable, but kept) for 5 s |
| Road Spike | Strip dropped behind you; lasts 12 s; single use | 1 s traction loss |
| Nitro Overload | Self boost | 3 s, +10 m/s top speed |
| Triple Nitro | Three Nitro charges in one slot (HUD shows ×3, ×2, ×1). Each press is a separate boost; the slot empties after the third | Rare. Mostly for trailing racers. A Railgun or drone hit knocks out all remaining charges |
| Firewall | Shield | Blocks the next attack, up to 10 s |

- **Targeting** (GDD §6.2):
  - With a Railgun or Hunter Drone selected, the nearest eligible opponent in a 40° cone ahead is targeted, preferring racers ahead of you in the race.
  - A reticle shrinks onto them and locks after 0.4 s.
  - A lock survives 0.6 s without line of sight.
  - You never target yourself, and finished racers can't be targeted.
- **Status rules** (`StatusEffects`, GDD §6.5):
  - Hard stuns (stun / stagger) take away control, scrub speed, and spin the bodywork as a visual.
  - When a hard stun ends, the racer is protected from further hard stuns for 1.5 s.
  - A Firewall blocks the next attack, whatever kind it is.
  - A landed Railgun or Hunter Drone hit knocks out the victim's selected weapon (or the other one if that slot is empty). Hits blocked by a Firewall or stun protection cost nothing.
- **Self-effects** (GDD §6.4): only the Road Spike can hit its owner, and only after a 1 s grace period. Everything else ignores its owner.
- **Crate odds** depend on race position (GDD §6.5). Leaders mostly get Road Spikes and Firewalls, while trailing racers get more Hunter Drones and Nitros.
- **HUD:**
  - two weapon slots, top left; the selected one is outlined, and empty ones are dimmed
  - position, lap, time and standings below the slots (moved to the very top when weapons are off)
  - the bottom-right corner is left clear for the minimap (GDD §11.5)
  - beside the slots: lock status, your active effects (with timers, e.g. JAMMED), and hit / pickup / "LOST …" notices
  - a flashing INCOMING warning when someone has locked on to you or a drone is chasing you
  - short tones for pickup, hit, getting hit, blocked and incoming
- **AI** score each weapon for the moment: fire when locked, EMP when someone is close, drop spikes on a racer behind, Nitro on long straights (one burst at a time), and raise a Firewall when attacked. Difficulty sets reaction time and reliability; personality sets how long they hold weapons.
- **Weapons on/off** is the `weapons_enabled` setting on the `Race` node (GDD §2.1).

## Project layout

```
scenes/
  menu/mode_select.tscn      Main scene: placeholder mode select (Phase 5 replaces it)
  race/race.tscn             8-car race (RaceManager + track + camera + HUDs)
  free_drive.tscn            Phase 1 sandbox (one car, no race rules)
  tracks/test_circuit.tscn   Graybox circuit, environment and moonlight
  vehicles/placeholder_car.tscn  Primitive-mesh car: body, 4 raycast wheels, drift/recovery/feedback
  ui/prototype_hud.tscn      Speed / drift / camera HUD
scripts/
  free_drive.gd              Wires the sandbox scene together
  race/
    race_manager.gd          RaceManager: grid, countdown, checkpoints, positions, finish
    race_progress.gd         RaceProgress: one racer's laps, gates, times
    race_config.gd           RaceConfig: mode, difficulty, laps, weapons, track, grid order
    championship.gd          Championship: Grand Prix points, tiebreaks, grid, save / load
    grand_prix_data.gd       GrandPrixData resource: a championship's three races
    elimination_tracker.gd   EliminationTracker: lap-midpoint qualifying and eliminations
    racer_profile.gd         RacerProfile resource: rival name, colour, personality
    rival_roster.gd          RivalRoster resource: the seven rivals
  combat/
    weapon_manager.gd        WeaponManager: crates, odds, deployment, hits, incoming warnings, reticle
    weapon_data.gd           WeaponData resource (data-driven weapons)
    item_inventory.gd        ItemInventory: two slots, 1/2/Space input
    targeting_system.gd      TargetingSystem: lock-on
    status_effects.gd        StatusEffects: stun / EMP / traction / shield rules and visuals
    railgun_shot.gd, hunter_drone.gd, road_spike.gd, emp_blast.gd, weapon_crate.gd
  ai/
    ai_controller.gd         AIController: steering, speed, drifting, traffic
    ai_combat.gd             AICombat: weapon decisions
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
  ui/                        PrototypeHUD, DriftMeter, RaceHUD, PauseMenu, UIStyle
  menu/mode_select.gd        ModeSelect: placeholder launch screen
  core/game_session.gd       GameSession: carries the chosen RaceConfig between scenes
resources/
  vehicles/placeholder_gt_stats.tres
  cameras/far_chase.tres, close_chase.tres
  ai/easy.tres, normal.tres, hard.tres
  racers/rival_roster.tres   Seven placeholder rivals (edit in the Inspector)
  weapons/*.tres             The six weapons: durations, speeds, odds
tests/
  test_phase1.gd             Driving checks (free-drive scene)
  test_phase2.gd             Race checks, including full simulated races (weapons off)
  test_phase3.gd             Combat checks, including a full race with weapons
  test_phase4.gd             Mode checks: full Versus, 3-race Grand Prix and Elimination events
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
godot --headless --fixed-fps 60 -s res://tests/test_phase3.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase4.gd
```

`--fixed-fps 60` runs the physics as fast as the machine allows (about 2.5× faster than real time here), which matters for the simulated races. Phases 1–3 take 40–90 s each here. Phase 4 takes about 6 minutes: it runs a Versus race, three Grand Prix races (shortened to 1 lap each) and a full Elimination event. It writes a temporary save (`user://test_phase4_gp.json`), never your real one.

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

Phase 3 covers:
- inventory rules, status rules, stun protection, Firewall, crate odds by position, and targeting priority (pure logic),
- crates (collect, full inventory, respawn) and the 1/2/Space keys with auto-select,
- the Railgun lock timing and hit,
- the drone finding a target without a lock,
- the EMP's radius, that it never hits its owner, and that weapons stay jammed for 5 s without being lost,
- Railgun and drone hits knocking out the selected item, and blocked hits or Road Spikes costing nothing,
- the HUD layout: slots top left, race info below, bottom-right corner clear,
- the Road Spike's owner grace period, then hitting its owner and an opponent,
- the Nitro boost, Firewall blocking, a stunned car losing control, and the protection window,
- finished racers being out of combat, and weapons switching off,
- a full race with weapons: everyone finishes, every gate is counted, and every weapon type is used and lands hits.

Phase 4 covers:
- the points table, both tiebreak rules, and the next grid following the previous result (pure logic),
- championship save / load of every saved field, a completed championship not being offered, and clearing the save,
- elimination rules: only the gate counts, double crossings and wrong-lap crossings don't, and the last two are out as each quota fills (pure logic),
- Triple Nitro charges in the inventory, and three separate boosts in a race,
- the mode select screen building the right race settings, saving a new Grand Prix, and offering Continue,
- the pause menu: Esc stops the timer and the cars, Esc again resumes,
- a full Versus race and its results buttons,
- a 3-race Grand Prix, continued from the save after race 1: grids, rival identities, 58 points per race, one save per race, no restart after a saved result, and final standings,
- a full Elimination event: 2 out at each of the three midpoints, nobody who qualified eliminated, positions 1–8, eliminated cars gone, and results shown.

The exit code is non-zero if anything fails. These checks do **not** judge how the game looks or feels.

## Status and known issues

**Verified (2026-11-05):** 91 Phase 1, 159 Phase 2, 97 Phase 3 and 115 Phase 4 headless checks pass on Godot 4.7.2 (Linux build). In a typical simulated weapons race, the AI use 30–50 weapons and land 13–19 hits, with no recoveries. On the redesigned 2.6 km circuit, simulated races run with no recoveries at any difficulty. AI earn roughly 2–18 drift boosts each per race.

| AI difficulty | Typical lap | 3-lap race (all 8 AI) |
|---|---|---|
| Easy | about 71 s | 3:33–3:42 |
| Normal | about 64 s | 3:12–3:27 |
| Hard | about 61 s | 3:01–3:25 |

The racing has **not** been played on screen yet.

- **AI pace is untested against a human.** Normal laps at about 64 s may be quick or slow for you. Tune `speed_factor` in `resources/ai/*.tres`.
- **Game modes haven't been played on screen.** The mode select screen, pause menu, results buttons, Grand Prix standings and Elimination HUD are built in code and only checked headless. They may need layout fixes.
- **Every race uses the test circuit**, and there's only one vehicle, until Phases 5–6.
- **Grand Prix classification at your finish** gives racers still on track their current position. The GDD doesn't specify this; it avoids waiting for the field.
- **Only 6 of the GDD's 11 weapons** exist so far, plus Triple Nitro. Holo Decoy, Gravity Mine, System Glitch, Cyber Leech and Swarm Bots are Phase 6 content; the data-driven setup should make adding them straightforward.
- **Combat balance is untested against a human:** crate odds, durations, the 22 m EMP radius and the Railgun's speed. The Railgun hits about half its shots in AI races. The AI often spend a held Firewall pre-emptively rather than saving it.
- **Weapon visuals and sounds are placeholders:** glowing primitives, coloured lights and generated tones.
- **The combat HUD hasn't been seen on screen.** Its layout is built in code and may need nudging.

- **Tuning is first-pass.** Every number in `VehicleStats` and the camera profiles is a starting point (GDD §18 leaves these to playtesting): speeds, grip, drift yaw, boost strength, suspension and camera smoothing.
- **Camera jitter on high-refresh monitors.** The camera updates in `_physics_process` (60 Hz). Physics interpolation is not enabled yet.
- **Placeholder feedback only.** Sparks are emissive spheres, the audio cues are generated sine tones, and there are no tyre or engine sounds yet.
- **The free-drive lap timer is distance-based.** Races use real checkpoints.
- **Race length:** AI finish a Normal race in about 3:15. A human finishing mid-pack will likely take about 3:30–4:00, near the low end of the GDD §15.2 target of 4–6 minutes. Lengthen the layout or raise the lap count if races feel short.
- **Scene load takes about 1.2 s** of generation (track meshes and colliders about 0.8 s, racing line about 0.4 s) before the countdown. That's acceptable for now, but could later be cached or baked.
- **The Aggressor wins most simulated races.** Its personality never backs off behind slower cars, which pays off in AI-only races. Balancing rivals is Phase 6 work.
- **The track is flat.** No elevation, ramps or banking yet. The road is visual only; the ground slab provides collision, so elevation will need road colliders.
- **No pause** (Esc), menus, cosmetics or pre-race camera sweep yet. These come in later phases.
- **Rival names are placeholders** ("The Technician", etc.), following GDD §7.3. AI cars show a floating name tag.
