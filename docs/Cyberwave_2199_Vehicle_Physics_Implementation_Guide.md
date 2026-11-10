# Cyberwave 2199 — Vehicle Physics Improvement Guide

**Target:** Godot 4 / GDScript · **Vehicle root:** `RigidBody3D` · **Handling style:** fast, controlled arcade kart racer with believable suspension

**Scope for this iteration:** flat tracks. Do **not** implement slope-following alignment yet. Preserve existing driving feel, drift charging, boosts, AI input, weapons/status effects, recovery, tricks, cosmetics, and split-screen controls.

## 1. What the project already has

Based on the supplied scripts:

| File | Relevant implementation |
|---|---|
| `vehicle_controller.gd` | `RigidBody3D`; discovers child `Wheel*` `RayCast3D` nodes; raycast spring/damper impulses in `_apply_suspension()`; chassis velocity-based drive/grip/steering in `_integrate_forces()`; ground wheel count and `ground_normal`; airborne upright assist; wheel-pivot animation. |
| `vehicle_stats.gd` | Suspension rest length `0.45`, spring stiffness `30000`, damping `3500`, wheel radius `0.38`; handling/grip/drift and boost parameters. |
| `vehicle_trick.gd` | Uses `grounded_wheels == 0` for airborne and `>= 2` for landing boost; spins `Body` and wheel *visual pivots* without rotating physics. |
| `vehicle_recovery.gd` | Detects invalid orientation / low wheel contact and uses hold/teleport/release; restoring physics and recovery safety must not be disrupted. |
| `vehicle_cosmetics.gd` | Visual models/wheels independent of collider and wheel-ray physics positions. |
| `vehicle_catalog.gd`, `vehicle_data.gd` | Eight cars/resources; maintain identical mechanics with stats-driven tuning. |

**Important:** This is **physics raycasting** (wheel-ground detection), not GPU ray-traced lighting. **Do not** replace `RigidBody3D` with `VehicleBody3D` or create duplicate wheel rays.

### Critical existing behavior to preserve

- `_integrate_forces()` has early returns for recovery **hold**, scripted **flight/Overdrive**, and **teleport**. Suspension must not run in these modes.
- `_pending_launch`, `_pending_kick`, `_pending_speed_scale`, the drift controller, status effects, and the separate visual wheel animation must keep working.
- `_apply_drive()` and `_apply_grip()` intentionally steer velocity directly: **retain arcade handling** instead of rewriting the entire vehicle as a realistic tire simulator.
- The existing suspension uses a physics-state impulse, then reads the resulting velocity: keep the update order coherent.
- `vehicle_trick.gd` depends on `grounded_wheels` semantics; avoid casually changing that variable to count every ray hit.
- `_apply_upright_assist()` currently aligns to world up. That is acceptable on flat tracks; defer slope alignment.

## 2. First: establish a baseline and inspect the scene

Before writing physics code:

1. Commit current working state to Git; note which eight vehicle `.tres` resources differ.
2. In the Godot scene, inspect `RigidBody3D.mass`, `gravity_scale`, `center_of_mass_mode` / center-of-mass position, `linear_damp`, `angular_damp`, collision shape dimensions, physics tick rate, and whether continuous collision detection (CCD) is enabled.
3. Verify four **direct child** `RayCast3D` nodes are present and begin with `Wheel`; identify exact node names (e.g. `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR`) and their real left/right layout. `vehicle_controller.gd` discovers only direct children.
4. Confirm rays point along **local -Y**, do not collide with the vehicle itself, and their collision mask includes drivable surfaces.
5. Confirm the ray origins are positioned at wheel suspension mounts, *not* shifted when enlarged cosmetic meshes are applied. The project deliberately separates physics scale from visual scale.
6. Record baseline results at standstill, 20 m/s, 44 m/s, while drifting, off a jump ramp, and during a hard landing. Note bottoming out, wheel jitter, chassis roll, unintended launches, and drift responsiveness.
7. Verify the actual values on `.tres` resources and scene Inspector: exported/script defaults may be **overridden** by serialized resources or nodes.

**Missing information:** The provided scripts do not state the car's actual `RigidBody3D.mass` or scene-level physics settings. Do **not** hard-code suspension tuning as final until inspected.

## 3. Change order (small, testable increments)

| Phase | Change | Gate before moving on |
|---|---|---|
| A | Instrument and tune current suspension | Vehicle rests without oscillation, sinking or launching |
| B | Add independent front/rear anti-roll | Less excessive roll; no destabilizing impulses |
| C | Separate raw ray hit from loaded wheel / traction | Drift and landing behavior still work |
| D | Improve high-speed contact and landing stability | No jitter, belly-scraping, unfair lost landing boost |
| E | Tune 8 cars and run regression tests | Old driving features behave as before |
| Later | Road-normal slope alignment and surfaces | Deferred: tracks currently flat |

## 4. Phase A — Suspension calculations and tuning

**Existing code:** `VehicleController._apply_suspension(state, up)` iterates `Wheel*` rays, computes compression from hit position, subtracts damping based on wheel-point velocity, and calls `state.apply_impulse()` at an offset.

### Required changes

- Keep physics calculations in `_integrate_forces()`; do not add a second independent suspension force loop in `_physics_process()`.
- Cache per-wheel hit/compression/load data **for the current physics step** so suspension, anti-roll, and traction all use consistent contact definitions. Clear cache each step and before/after teleport/flight/hold transitions as needed.
- Clamp compression to a physically meaningful range: `0 ... suspension_rest_length`. Negative compression gives zero spring load. Clamp peak applied spring force/impulse with **configurable, mass-aware** limits only after observing high-speed landings.
- Ensure the direction and magnitude of spring force don't suddenly become enormous on a deep collision or high downward speed. Do not accidentally prevent necessary landing support with an overly low clamp.
- Check the raycast data age. The supplied controller explicitly notes ray collision positions can lag a physics step at speed. **Test** moving-road contact and sharp ramp lips first; consider a fresh `PhysicsDirectSpaceState3D.intersect_ray()` query inside the physics integration if stale `RayCast3D` results cause reproducible problems. Do not query *both* methods unconditionally in production.
- Keep damping based on **velocity at each wheel mount**, including angular contribution: `linear_velocity + angular_velocity.cross(offset)`.
- Preserve the ability for the car to become airborne; never fake wheel support once it passes ray reach.

### Mass-aware initial tuning

Use the **actual** rigid-body mass `m` (kg), number of load-bearing wheels `N` (usually 4), gravity magnitude `g`, and target static compression `x` (m):

```text
Per-wheel spring stiffness k ≈ (m * g) / (N * x)
Per-wheel effective mass ≈ m / N
Critical damping c_crit ≈ 2 * sqrt(k * m / N)
Initial damping c ≈ 0.7 to 0.9 * c_crit
```

These are **starting estimates** for a simplified four-spring system, not precise suspension design. Wheel placement, inertia, collider contact, and arcade stabilization also matter.

Example **only if mass = 1,000 kg**, `x = 0.10 m`, `g = 9.81 m/s²`:

```text
k ≈ 24,525 N/m per wheel
c_crit ≈ 4,952 N·s/m per wheel
70%–90% damping ≈ 3,467–4,457 N·s/m
```

At **1,000 kg**, the current `30000` stiffness / `3500` damping look plausible starting points. At **1 kg** the same stiffness is drastically too large. Confirm actual mass rather than assuming it.

**Suggested exports in `VehicleStats` (proposed, not present yet):** `anti_roll_stiffness`, optionally `max_suspension_force`, `landing_damping_multiplier`, `contact_grace_time`, and a debug flag on the controller. Keep all additions optional/default-safe; the `.tres` files must continue loading.

## 5. Phase B — Anti-roll bar simulation

Goal: reduce excessive chassis roll without locking the car completely upright.

1. Identify left/right wheel pairs by explicit node references or a validated mapping, **not** by assuming unseen node names match examples.
2. For front and rear axles **separately**, compute compression difference from the Phase A cache.
3. `anti_roll_force = (left_compression - right_compression) * anti_roll_stiffness`.
4. When the left suspension is more compressed, push **down** at the left mount and **up** at the right mount, and vice versa. Apply forces at proper mount offsets using the same physics state. When a side is off the ground, decide whether and how to apply the opposite side's bar load; start conservatively and test one-wheel curb contact.
5. Begin with `anti_roll_stiffness = 0` (feature off), then small test values such as `2000`, `4000`, `8000`. These are **tentative**, not guaranteed correct without mass/inertia.
6. Do **not** let the anti-roll bar generate net upward lift out of nowhere when both wheels are grounded. Monitor pitch/roll and clamp if needed.

Implementation sketch (conceptual; integrate with cached data and actual node names):

```gdscript
# In VehicleStats.gd
@export_group("Suspension")
@export var anti_roll_stiffness: float = 0.0

# In VehicleController._integrate_forces(), after suspension:
_apply_suspension(state, up)
_apply_anti_roll(state, up) # new; runs only in normal driving branch
```

Within `_apply_anti_roll`, compare left/right spring compression, calculate opposing axle forces, and use `state.apply_force(force, wheel_mount_offset)`. `apply_force()` is integrated over the step; **do not multiply by `dt` again**. If using `apply_impulse` instead, multiply force by `state.step` exactly once.

> Do not blindly copy old example code using `get_node_or_null("WheelFL")`: scene node names must be verified first.

## 6. Phase C — Ground contact vs suspension load

There are three distinct states:

- **Ray hit:** a ray intersects a drivable surface within its configured reach.
- **Loaded wheel:** ray hit **and** positive suspension compression / normal load.
- **Traction weight:** proportional/scaled contribution of wheel load to steering and grip (0–1), optionally smoothed for brief glitches.

Currently `grounded_wheels` counts *compressed* springs, not all rays that hit. Preserve that meaning initially because `vehicle_trick.gd` checks `grounded_wheels == 0` for airborne and `>= 2` for successful landing. Consider adding `ray_hit_wheels` and `traction_fraction` **without** silently changing `grounded_wheels`.

Suggested staged approach:

1. Cache `ray_hit_wheels`, `grounded_wheels`, and per-wheel compression/load.
2. Keep existing `grounded_wheels`-based trick behavior in phase C; record discrepancies between hits, load, and actual visuals.
3. Derive traction from load-bearing wheels first, not raw hits. Add load normalization later only if it improves feel.
4. Apply a short (e.g., ~1–2 physics-tick) **grip/contact smoothing** only for transient glitches, **not** for trick airborne state. A long grace period could suppress jumping and landing events.
5. Keep `DriftController.update(...)` behavior and its `grounded_wheels >= 2` requirement intact until explicitly validated.

Do **not** turn every ray contact into full grip: a fully extended wheel barely touching the road should not steer as firmly as a loaded tire.

## 7. Phase D — High speed and landing

### Problems to measure

- Brief wheel-ground misses at high forward speed.
- Car collider contacts the road before suspension can support it (“belly scraping”).
- Spring launches car upward after landing.
- Car spins or oscillates after one-wheel / nose-first impact.
- A trick fails to award a landing boost due to a one-frame grounded-wheel glitch.

### Changes to trial, in order

1. **Geometry:** ray reach, origin height, wheel positions, body collider clearance, and `Body` visual scale. A numerical fix cannot compensate for wrong ray geometry.
2. **Physics interpolation / tick:** test at the project's current physics tick and compare 60 vs 120 physics TPS *only if performance allows*; never make gameplay logic frame-rate dependent.
3. **Fresh contact queries:** if necessary, move to current-step physics space ray tests as described in Phase A; validate physics collision masks and self-exclusion.
4. **Landing force limit:** introduce a mass-aware cap only after recording peak forces on real landings; verify it doesn't cause clipping through the ground.
5. **Landing stabilizer:** when transitioning from airborne to two or more loaded wheels, add a *short*, limited pitch/roll angular damping effect, leaving yaw mostly unchanged. Avoid snap-to-world-up and avoid killing drift yaw or trick visuals.
6. **CCD:** investigate continuous collision detection for the moving `RigidBody3D` if thin barriers/track geometry are being tunneled through; CCD is **not** a substitute for wheel-ground rays.
7. **No automatic downforce by default:** only consider mild speed-dependent downforce after jumps and ramp behavior are verified. Extra downforce can damage intentional airtime and tricks.

### Existing upright assist

`_apply_upright_assist()` biases toward `Vector3.UP`, is active on ground and in the air, and has an intentional exception for a car resting on its side/roof. Keep this for flat tracks. Anti-roll must complement it, not compound into violent overcorrection. Preserve `VehicleRecovery` as the authority for true rollover recovery.

## 8. Interaction / regression constraints

**Drift:** `drift.update()` checks whether at least two wheels are grounded; `_apply_grip()` has drift-specific `grip`, `drift_grip`, retention, and recovery blend. New contact or lateral-force logic must not stop charge accumulation or produce a snap after drift release.

**Boosts:** regular boost, external boost and slipstream modify speed caps, acceleration, or pending velocity kicks. Suspension must not clamp forward speed, consume kicks, or turn boosts into artificial jumps.

**Tricks:** `VehicleTrick` spins the mesh/pivots **visually only** and awards its boost after airborne → grounded transition. Do not rotate wheel-ray mount transforms to perform tricks; do not suppress airborne state with contact smoothing.

**Recovery:** `VehicleRecovery` examines wheel count and orientation and invokes `hold_at()`, `teleport()`, `release()`. No suspension/anti-roll must run during held, flight or teleport branches; reset any cached contact state when states change. Check hidden/ghost cases and overlap with other cars.

**Overdrive flight:** existing `fly_to()` drives a scripted transform; suspension stays off until `end_flight()`. Avoid a large first-frame spring impulse upon return to driving.

**AI and multiplayer:** AI writes throttle/brake/steer; player reads input. Do not attach physics fixes to input source. Apply same physics to all eight racers, including split-screen cars.

**Cosmetics:** vehicle art can be scaled separately (`TRACK_VISUAL_SCALE = 1.3`); do not scale collision/raycast physics with cosmetic meshes. Confirm wheel visuals still align after replacing/upscaling meshes.

**Stats/resources:** use exports/defaults in `VehicleStats` for parameters. Check existing per-car `.tres` overrides; avoid editing the eight vehicle resources unless necessary and intended.

## 9. Debug instrumentation

Add an optional developer debug overlay / logging toggle showing, per vehicle:

```text
Speed (m/s), forward speed, lateral speed
Actual RigidBody3D mass, gravity_scale, physics TPS
Raw ray hits / compressed wheels (0–4)
Per-wheel ray distance, compression, vertical point velocity, spring load
Front/rear anti-roll force and roll/pitch angular rates
Airborne flag, transition time since takeoff/landing
Drifting / boost / trick / recovery / flying flags
```

Use `DebugDraw3D` only if already installed, otherwise Godot `ImmediateMesh`, debug gizmos, or simple print/labels. Keep any visual debug geometry separate from physics.

## 10. Test plan and acceptance criteria

| Test | Expected behavior |
|---|---|
| Stationary spawn on flat road | Rest height stable; no persistent bounce, sinking or launch |
| Accelerate 0 → top speed (44 m/s baseline car) | Straight line stable, no wheel jitter, no unexpected lateral snap |
| Aggressive left and right turns | Some lean; reduced roll with anti-roll enabled; no spontaneous overturn |
| Drift left/right at speed | Drift engages and charges normally; recovery after release is smooth |
| Cyan / Magenta / Gold boost | Correct speed/kick; car stays planted on flat road |
| Ride a small bump / one-wheel curb | Independent wheel motion; no violent roll correction |
| Ramp takeoff | Grounded count transitions to 0; car gets genuine airtime |
| Trick while airborne → land | Visual spin only; landing gives correct trick boost |
| Hard and asymmetric landings | Compression damped; no launch, indefinite wobble or clipped collision |
| Out-of-bounds / manual reset | Held and teleported car doesn't experience leftover suspension forces |
| Overdrive fly → land/drive | No abrupt physics impulse or broken velocity state |
| AI 8-racer race + split-screen | No widespread slowdowns, odd bounce or input-specific behavior |
| Alternate vehicle skins and eight stats resources | No visual wheel clipping from physics changes; handling distinctions retained |

Run baseline and after-each-phase tests at the current physics tick rate. Also validate at a higher tick rate or lower graphics FPS to detect time-step sensitivity. Record before/after speed, maximum roll, max spring force and landed-trick count where possible.

## 11. Tasks for Claude Code / Codex

```text
Implement the physics improvements described in Cyberwave_2199_Vehicle_Physics_Implementation_Guide.md.

Inspect the actual Godot scene files and eight VehicleStats resources before editing.
Do not replace RigidBody3D or the existing arcade velocity driving system.
Do not add duplicate RayCast3D wheels.
Keep all gameplay integration: drifting, speed boosts, status effects, AI, trick visuals/landing boosts,
recovery/teleports, Overdrive flight, split-screen, and independent cosmetic scaling.

Work in small, reviewable commits/phases:
A. Instrument and validate suspension, mass and wheel-ray geometry.
B. Add tunable anti-roll forces by axle, defaulting off until tuned.
C. Separate ray hits, loaded contacts and traction contribution without changing trick behavior.
D. Resolve observed high-speed and landing issues, not speculative ones.
E. Test all eight cars and perform regressions.

Do not implement slope alignment yet; tracks are currently flat.
Use Godot 4 GDScript and run available automated/editor tests.
Report scene mass/physics values, exact edits, tunable settings and test results.
If assets/scenes/resources needed are absent, identify the missing information rather than inventing it.
```

## 12. Definition of done

- [ ] All four wheel rays confirmed and correctly placed in the actual scene
- [ ] Mass, collision dimensions and physics settings inspected
- [ ] Spring/damper tuned for the actual vehicle mass
- [ ] Anti-roll implemented and adjustable without upsetting steering
- [ ] Raw hits, loaded contacts and traction meaning made explicit
- [ ] High-speed contact and landings stable in repeatable tests
- [ ] Drift levels, boost behavior and trick landing bonuses unchanged
- [ ] Recovery, scripted flight and teleports remain safe
- [ ] Cosmetic vehicle scaling and wheel meshes remain aligned
- [ ] All eight AI/player cars pass regression tests
- [ ] Changes documented with before/after test observations

**Future phase (not now):** banked roads and hills using road-normal-aware chassis stabilization, terrain-specific tire grip, and more elaborate per-wheel tire forces.

---

## 13. Results (implemented 2026-11-10)

### Inspected scene and physics values

All eight cars share `scenes/vehicles/placeholder_car.tscn`; the `.tres` stats don't override any suspension values.

| Setting | Value |
|---|---|
| `RigidBody3D.mass` | 1200 kg |
| `center_of_mass` | custom, (0, -0.35, 0) |
| `gravity_scale` | 1 (default gravity 9.8 m/s²) |
| `continuous_cd` | on |
| `can_sleep` | off |
| Physics engine / tick | Jolt, 60 ticks/s |
| Collider | box 1.9 × 0.55 × 4.2 m, friction 0.2 |
| Wheel rays | `WheelFL` (-0.85, 0, -1.35), `WheelFR` (0.85, 0, -1.35), `WheelRL` (-0.85, 0, 1.35), `WheelRR` (0.85, 0, 1.35); mask 1 (environment only), length = rest + radius = 0.83 m |
| Springs | k 30000, c 3500, rest 0.45 m, wheel radius 0.38 m |

At 1200 kg the springs are already well matched: static compression is 1200 · 9.8 / (4 · 30000) ≈ 0.098 m. Critical damping is 6000, so 3500 is about 0.58 of critical.

### What changed (`vehicle_controller.gd`, `vehicle_stats.gd`)

- **Per-step wheel cache:** `wheel_spring_length`, `wheel_compression` (0…rest), `wheel_load`, `ray_hit_wheels`, `traction_fraction`, `anti_roll_force`, `air_time`, `since_landing`. It is cleared on hold, flight and teleport, and `grounded_wheels` keeps its meaning.
- **Spring force past full travel is not clamped.** It acts as a bump-stop. Clamping it shortened ramp jumps (airtime 2.45 → 2.38 s), because the take-off off a ramp face relies on it. Only the recorded compression is clamped.
- **Traction:** each loaded wheel is weighted by `smoothstep(0, 0.25 · static compression, compression)`. Traction is held for `contact_grace_ticks` (2) steps over a contact glitch. This affects traction only, not the airborne or landing checks.
- **Anti-roll** (`anti_roll_stiffness`, default 0, off): axles are paired from the wheel positions (`find_axles`). The force is equal and opposite on each axle (no net lift), and an axle is skipped when either of its wheels is unloaded.
- **Landing** (on after more than 0.15 s of airtime): `landing_damping_multiplier` 1.5 from touchdown, plus `landing_stabilize_time` 0.3 s / `landing_stabilize_strength` 8, which damps pitch and roll rate only.
- `max_suspension_force` exists but is off (0). The probe showed a cap at 20 kN shortened jumps and made the landing wobble worse.
- **Debug readout:** `PhysicsDebugOverlay`, F3 in debug builds. It is added by `PrototypeHUD`, so there is one per split-screen view.

### Measurements

Measured with a headless probe on a flat floor, a 14° × 14 m ramp at 38 m/s, and a 6 cm curb at 25 m/s, at 60 ticks/s.

| Test | Before | After |
|---|---|---|
| Rest (all 8 cars) | stable, 0 mm drift | identical |
| Full-lock turn, 20 / 33 m/s | peak roll 0.07°, yaw 2.08 / 1.86 rad/s | identical |
| Drift to gold boost | reaches level 3, fires | identical |
| Curb, one side | peak roll 1.95°, 4 wheels loaded | identical |
| Ramp airtime / peak height (default car) | 2.45 s / 9.78 m | identical (all 8 cars identical) |
| Bounce back into the air after landing | 3 of 8 cars | 0 of 8 |
| Upward rebound after landing | 2.18–2.74 m/s | 1.99–2.12 m/s |
| Peak pitch/roll rate after landing | 1.03–3.20 rad/s | 0.34–1.98 rad/s |
| Pitch after landing | 1.3–2.0° | 0.7–1.6° |

### Settings tried and rejected

- **Damping 4500 / 5000** (0.75–0.83 of critical): cut jump height by 0.7–0.8 m, which would change every jump and shortcut gap.
- **Anti-roll 2000–16000:** turns already roll less than 0.1°, because grip steers the velocity directly. On a curb the bar made roll slightly worse (1.95° → 2.13°), as real anti-roll bars do on one-wheel bumps. Left off until banked or hilly tracks give it work to do.
- **Spring force cap 20 kN:** shorter jumps and more landing wobble.
- **Fresh `intersect_ray` contact queries:** not needed. No wheel lost contact in full-lock turns at up to 33 m/s or on the curb at 25 m/s.

Tests: `tests/test_vehicle_physics.gd` covers resting for all 8 cars, contact data, axles, anti-roll, the ramp and landing, hold / flight / teleport hand-offs, and the overlay.
