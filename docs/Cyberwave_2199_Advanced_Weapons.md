# Cyberwave 2199 — Advanced Weapon Systems

**Design specification · Godot 4 · 8-player kart racing**

![Cyberwave 2199 racing concept](concept_art/cyberwave_banner.png)

## Overview

Three high-impact items provide different comeback mechanics while preserving skill, counterplay, and race integrity.

| Item | Role | Effect | Eligible positions |
|---|---|---|---|
| **Hunter-Killer Drone** | Leader suppression | Pursues the leader and delivers a targeted electrical blast | 3rd–8th |
| **Overdrive Protocol** | Last-place comeback | Launches the kart into high-speed, automated **flight above the course** | 5th–8th |
| **System Override** | Position recovery | Hacks **every racer ahead of the user** at activation | 3rd–8th |

All values below are **initial playtesting targets**, not final balance values.

## 1. Hunter-Killer Drone

![Hunter-Killer Drone concept](concept_art/hunter_killer_drone.png)

### Player experience

1. Activate the item; a matte-black, angular drone deploys with red sensor lights.
2. Target the first-place racer at the moment of launch (the user cannot obtain it in first).
3. Fly rapidly along the track route, avoiding geometry and passing non-target racers.
4. On approach, show the leader a red reticle and play a distinctive warning tone.
5. After the warning, dive and discharge a blue-white electrical blast, spinning out the target.
6. Despawn after impact, interception, or timeout.

### Proposed parameters

| Parameter | Starting value |
|---|---|
| Spawn positions | 4th–8th |
| Travel speed | 1.8× normal kart top speed |
| Target | Leader at activation, locked thereafter |
| Target warning | 1.2 seconds |
| Main target disruption | 1.5 seconds |
| Splash radius | 4 meters (optional nearby racers) |
| Lifetime | 12 seconds |
| Counterplay | A Nitro (Nitro Overload / Triple Nitro) fired in the last 0.4 s of the warning or during the dive makes it miss. A Firewall does **not** block it (shield kept). Active Overdrive: it waits. |

**Targeting and fairness:** Lock a racer ID, not a position number. If that racer drops to second after launch, the drone still pursues them. Prevent back-to-back unavoidable hits with brief post-hit immunity or diminishing effects. For the first implementation, consider disabling splash damage to make behavior predictable.

### Visual/audio direction

Matte-black triangular body, articulated stabilizers, red tracking eye, thin targeting beam, rising turbine whine, and a bright electrical detonation. The attack must be readable even when the camera is crowded.

### Godot scene

```text
HunterKillerDrone (Node3D)
├── DroneMesh (MeshInstance3D)
├── HitArea (Area3D)
├── ThrusterVFX (GPUParticles3D)
├── TargetingLaser (MeshInstance3D)
├── WarningAudio (AudioStreamPlayer3D)
├── ExplosionVFX (GPUParticles3D)
└── AnimationPlayer
```

**Implementation:** Track an authoritative target kart ID. Follow a `Path3D`/`Curve3D` route with an offset above the track; blend into local homing near the target. Use swept collision detection or segment raycasts for fast travel so it cannot tunnel through obstacles. Validate target availability and cancel safely when the target finishes, disconnects, or enters a protected state.

## 2. Overdrive Protocol — Flying Mode

![Overdrive Protocol concept](concept_art/overdrive_protocol.png)

### Player experience

1. Activate Overdrive; cyan energy flows across the kart, and auxiliary thrusters deploy.
2. The kart rises **3–5 meters above the roadway**.
3. Driving switches to assisted, automated flight; the player follows the course at extreme speed.
4. A protective energy field pushes aside nearby opponents while the kart remains immune to ordinary attacks.
5. At expiration, choose a safe landing segment, descend, and restore steering and normal kart physics.

The kart stays recognizably the player's kart; it is **not** replaced by a missile or airplane. It can fly over corners and low obstacles, but it must never skip mandatory race progress.

### Proposed parameters

| Parameter | Starting value |
|---|---|
| Spawn positions | 4th–8th (mostly 7th–8th) |
| Nominal active duration | 5–7 seconds |
| Flight speed | 2.0× normal top speed |
| Height above track | 3–5 meters, track dependent |
| Steering | Fully automated along flight route |
| Other-kart contact | Push aside, no permanent damage |
| Item resistance | Invulnerable during flight |
| Drift/mini-turbo | Cancel and reset on activation |
| End behavior | Controlled descent at validated landing point |

### Flight route design

Maintain a dedicated **flight spline** or a validated elevated path generated from the racing line. Include per-segment clearance and landing metadata. Do not blindly add a vertical offset to a road spline: tunnels, overpasses, buildings, and cliff ceilings can make that unsafe.

```text
NORMAL_DRIVING
  -> ACTIVATING
  -> ASCENDING
  -> AUTOMATED_FLIGHT
  -> DESCENDING
  -> NORMAL_DRIVING
```

- Flight progress advances along the legitimate course, with mandatory checkpoints still validated.
- Do not let a fixed timer force a landing into water, voids, walls, or another kart.
- When time expires in an unsafe segment, continue until the next authorized landing zone, with a strict fallback to safe recovery.
- Maintain camera continuity and readable speed effects during takeoff and landing.
- AI and human racers use the same flight controller.

### Godot architecture

```text
OverdriveController (Node3D)
├── FlightPathFollower (PathFollow3D)
├── ThrusterVFX (GPUParticles3D)
├── EnergyShield (Node3D)
├── FlightAudio (AudioStreamPlayer3D)
└── AnimationPlayer
```

Sample the desired world-space transform from `PathFollow3D`, then move the kart through a controlled flight-motion state rather than applying ordinary ground steering. Blend orientation smoothly, and restore the ground controller only after a confirmed safe touchdown. Keep checkpoint progression under the race manager's authority.

## 3. System Override

![System Override concept](concept_art/system_override.png)

### Player experience

1. The user activates a red digital hacking pulse.
2. Take a **snapshot of race standings at activation**.
3. Select **all racers with a better position than the user**; do not affect the user or anyone behind.
4. Targets display red warnings, flickering electronics, and brief electrical arcs.
5. Temporarily reduce top speed and acceleration while leaving steering control intact.
6. Restore normal performance automatically when the debuff expires.

**Eight-player example:** A player in **5th** affects racers in **1st–4th**. Racers in 6th–8th are unaffected. A player in 8th can affect all seven opponents; a player in 1st cannot receive this item.

### Proposed parameters

| Parameter | Starting value |
|---|---|
| Spawn positions | 3rd–8th (mostly 7th–8th) |
| Targets | All racers ahead at activation |
| Debuff duration | By victim's position at activation (table below) |
| Top speed | −25% |
| Acceleration | −30% |
| Drift steering | Unchanged |
| Existing mini-turbo | Canceled; can't build drift charge while hacked |
| Weapons | Still usable |
| Stacking | None: a repeat hit neither extends nor restarts it |
| Counter | Firewall (blocks it, shield used up) / active Overdrive (immune; starting one clears it) |

| Victim position | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th* |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Hacked for | 12.0 s | 10.5 s | 9.0 s | 7.5 s | 6.0 s | 4.5 s | 3.0 s | 1.5 s |

*8th is reference only: nobody is behind the user. Durations live in `resources/weapons/system_override.tres` (`duration_by_position`).

Use a status-effect modifier system rather than permanently editing a kart's base stats. Clamp overlapping slowdowns and make restoration deterministic.

### Godot targeting pseudocode

```gdscript
func activate_system_override(user_kart: Node) -> void:
    var user_position: int = user_kart.race_position
    var targets: Array = []

    for kart in race_manager.get_all_karts():
        if kart == user_kart:
            continue
        if kart.race_position < user_position:
            targets.append(kart)

    # In multiplayer, only the authoritative server applies effects.
    for kart in targets:
        if not kart.has_override_immunity():
            kart.apply_system_override(duration_for(kart.race_position))
```

In multiplayer, use a single authoritative snapshot to avoid position changes during target selection. Replicate target IDs, start time, and expiration time to clients.

## 4. Item Distribution — Eight Racers

These are the in-game odds (GDD §6.5, v7.4): the percent chance of each item when a racer in that position opens a crate. Every weapon has a chance for each position, and each position adds up to 100%. Triple Nitro, the third comeback item, is shown alongside.

| Position | Hunter-Killer Drone | Overdrive Protocol | System Override | Triple Nitro |
|---|---:|---:|---:|---:|
| 1st | 0% | 0% | 0% | 0% |
| 2nd | 0% | 0% | 0% | 0% |
| 3rd | 0% | 0% | 2% | 4% |
| 4th | 2% | 3% | 5% | 9% |
| 5th | 4% | 6% | 8% | 14% |
| 6th | 6% | 10% | 12% | 18% |
| 7th | 8% | 20% | 26% | 22% |
| 8th | 8% | 25% | 31% | 25% |

Leaders get weak and defensive items instead: Road Spikes only drop for 1st–3rd and Firewalls only for 1st–5th.

Consider limiting simultaneous global effects and tracking recent item awards to avoid repeated unavoidable disruptions. Measure average positions gained, lap-time impact, and hit frequency in eight-kart playtests.

## 5. Interactions and Counterplay

| Interaction | Rule |
|---|---|
| Drone vs. Overdrive | Flying kart is immune; drone may briefly wait, then expire |
| System Override vs. Overdrive | Active Overdrive ignores override; activating Overdrive clears an existing override |
| Drone vs. System Override | May coexist, but avoid stacking long hard-control loss |
| Drone vs. Sonic Burst | Well-timed burst destroys incoming drone |
| System Override vs. Invulnerability Matrix | Protected kart ignores the debuff |
| Overdrive vs. recovery | Terminate flight safely; RecoveryManager handles unrecoverable state |
| All items vs. finish line | Mandatory checkpoint and lap rules always apply |

## 6. Shared Technical Architecture

| System | Responsibility |
|---|---|
| `RaceManager` | Eight-racer standings, checkpoint and lap validation |
| `ItemManager` | Weighted distribution, activation, item cooldowns |
| `KartController` | Movement modes, drift, boost, flight handoff |
| `StatusEffectManager` | Timed modifiers, immunity, non-stacking rules |
| `TrackManager` | Road and flight splines, landing metadata |
| `RecoveryManager` | Safe out-of-bounds handling and respawns |
| `AIController` | Item decisions and reactions |
| `VFXManager` | Pooled effects, shaders, sounds |

### Implementation safety and correctness

- Centralize item activation in one authoritative service; do not duplicate item effects inside each kart script.
- Use stable racer IDs and state checks instead of assuming position numbers are permanent.
- Ensure effects clean up when a kart finishes, disconnects, recovers, or the race resets.
- For network play, server-authorize targets, movement state transitions, and hit results.
- Use time-based effects with explicit end times; do not leave modifiers active after interruptions.
- Protect flight transitions from invalid terrain, geometry, and checkpoint shortcuts.

## 7. Development Checklist

### Phase 1 — Shared foundations
- [ ] Build item activation/cooldown interface
- [ ] Add authoritative standings snapshot and racer IDs
- [ ] Add reusable timed status effects and immunity flags
- [ ] Add item VFX/audio hooks

### Phase 2 — System Override
- [ ] Select all racers ahead at activation
- [ ] Apply speed/acceleration modifiers
- [ ] Add warning HUD and red digital VFX
- [ ] Test positions 1–8 and overlapping effects

### Phase 3 — Hunter-Killer Drone
- [ ] Create drone scene and path-following motion
- [ ] Add leader target lock and warning
- [ ] Implement attack, hit reaction, and timeout
- [ ] Add Sonic Burst counter and invulnerability interaction

### Phase 4 — Overdrive Protocol
- [ ] Create safe flight paths for each track
- [ ] Implement ascent, autonomous flight, and descent
- [ ] Integrate collision immunity and push-aside effect
- [ ] Validate landing zones and mandatory checkpoints
- [ ] Handle early cancellation, recovery, and race finish

### Phase 5 — Polish and balance
- [ ] Implement AI use and defensive reactions
- [ ] Test eight-kart simultaneous item interactions
- [ ] Tune spawn odds, duration, and speed multipliers
- [ ] Profile particles, shaders, and fast-moving collision
- [ ] Test tunnels, bridges, shortcuts, water, and complex track geometry

## 8. Design Summary

**Hunter-Killer Drone** is a highly telegraphed threat to the leader. **Overdrive Protocol** gives trailing racers a spectacular automated **flying** comeback. **System Override** selectively disrupts **all racers ahead**, without punishing racers behind the user.

Together they should create dramatic reversals without making skillful driving irrelevant.

---

*Concept art is exploratory and not a final in-game asset specification. All numerical tuning values are provisional.*
