# Cyberwave 2199 — Holographic Kart Recovery System

## Overview

Cyberwave 2199 will use a **holographic reconstruction system** to recover karts that fall off the track, enter hazardous areas, or become permanently stuck.

The system is inspired by Mario Kart's out-of-bounds recovery mechanics but uses a futuristic teleportation effect instead of a physical rescue character.

### Design Goals

- Fast recovery that keeps races moving.
- Visually appealing holographic reconstruction.
- Consistent behavior across all tracks.
- Fair respawn positioning that prevents shortcuts and exploits.
- Support for AI-controlled and human-controlled karts.
- Compatibility with multiplayer racing.
- Reusable implementation across different environments.

---

## 1. Recovery Sequence

The recovery process consists of five stages.

### Stage 1 — Out-of-Bounds Detection

Recovery begins when a kart:

- Falls below a predefined height.
- Enters a designated hazard volume.
- Falls into deep water.
- Becomes stuck or overturned for an extended period.
- Activates a manual recovery command, if supported.

### Stage 2 — Holographic Disintegration

The kart begins dissolving into digital particles.

Suggested effects:

- Blue or cyan holographic flickering.
- Horizontal scanning lines moving across the kart.
- Wireframe outlines briefly replacing solid surfaces.
- Digital fragments separating from the kart.
- Short electronic distortion sound.
- A bright flash when the kart disappears.

**Suggested duration:** 0.3 seconds.

### Stage 3 — Teleportation

The kart disappears from its original location.

During this stage:

- Disable player steering and acceleration.
- Disable collision interactions with other karts.
- Clear velocity and angular momentum.
- Cancel any active drift.
- Remove accumulated mini-turbo charge.
- Cancel temporary speed boosts.
- Select the appropriate recovery location.

**Suggested duration:** 0.4 seconds.

### Stage 4 — Holographic Reconstruction

The kart materializes at its recovery location.

Suggested effects:

1. A glowing holographic outline appears.
2. A wireframe version of the kart forms.
3. Digital particles converge on the wireframe.
4. Solid textures gradually replace the hologram.
5. The kart briefly glows before returning to normal.

**Suggested duration:** 0.5 seconds.

### Stage 5 — Resume Racing

After reconstruction:

- Restore kart controls.
- Align the kart with the track.
- Restore a small amount of forward speed.
- Apply temporary collision protection.
- Return the kart to normal racing behavior.

**Suggested duration:** 0.4 seconds.

### Recommended Timing

| Stage | Duration |
|---|---:|
| Disintegration | 0.3 seconds |
| Teleportation | 0.4 seconds |
| Reconstruction | 0.5 seconds |
| Control restoration | 0.4 seconds |
| **Total** | **1.6 seconds** |

These values should be configurable.

---

## 2. Recovery State Machine

The kart controller should recognize the following states:

```text
NORMAL
  |
  | Out-of-bounds detected
  v
DISINTEGRATING
  |
  v
TELEPORTING
  |
  v
RECONSTRUCTING
  |
  v
RECOVERY_PROTECTION
  |
  v
NORMAL
```

During the first three recovery states, player controls should be disabled.

During `RECOVERY_PROTECTION`, the player can drive normally but is temporarily protected from collisions with other karts.

Recovery should be triggered only once per incident.

---

## 3. Godot Scene Architecture

Recommended scene organization:

```text
RaceTrack (Node3D)
├── TrackGeometry
├── TrackCollision
├── RecoveryPoints
│   ├── Recovery_001 (Marker3D)
│   ├── Recovery_002 (Marker3D)
│   ├── Recovery_003 (Marker3D)
│   └── Recovery_004 (Marker3D)
├── HazardZones
│   ├── FallZone_01 (Area3D)
│   ├── WaterZone_01 (Area3D)
│   └── FallZone_02 (Area3D)
├── Checkpoints
├── RecoveryManager
└── FinishLine
```

The recovery system should be separate from the main kart controller.

### RecoveryManager Responsibilities

The `RecoveryManager` should:

- Track each kart's last valid recovery point.
- Determine when recovery is necessary.
- Coordinate holographic effects.
- Handle teleportation.
- Restore kart movement.
- Prevent repeated recovery triggers.
- Validate recovery positions.
- Maintain legitimate race progress.

---

## 4. Recovery Checkpoints

Recovery points should be placed at safe locations along the track.

Recommended locations include:

- Before dangerous corners.
- Before large jumps.
- After completed jumps.
- Near bridges and elevated roads.
- Along narrow track sections.
- Near water hazards.
- Before complicated shortcuts.

Each recovery point should store:

```text
RecoveryPoint
├── Position
├── Rotation
├── TrackProgress
├── CheckpointIndex
└── SafeSpawnRadius
```

### Important Rules

1. Recovery points must face the correct racing direction.
2. Recovery points should not be placed too close to hazards.
3. Respawning must not allow players to skip checkpoints.
4. The system must account for overlapping roads and track sections.
5. A recovery point should not be activated until the player legitimately reaches its associated section.

**Do not simply use the geographically nearest recovery point.**

A geographically nearby recovery point may belong to a different part of the course.

---

## 5. Track Progress and Anti-Exploit Logic

Each kart should maintain a legitimate track-progress value.

Example:

| Recovery Point | Track Progress |
|---|---:|
| Recovery_001 | 10% |
| Recovery_002 | 25% |
| Recovery_003 | 40% |
| Recovery_004 | 55% |
| Recovery_005 | 70% |
| Recovery_006 | 85% |

If a kart falls at 43% progress, it should return to `Recovery_003`, not `Recovery_004`.

The game should track checkpoint order separately from physical position.

### Recommended Progress Variables

```gdscript
var current_lap: int = 1
var last_valid_checkpoint: int = 0
var track_progress: float = 0.0
var last_safe_transform: Transform3D
```

For tracks containing shortcuts, use checkpoint validation to ensure the player has followed a legitimate route.

A shortcut should only advance progress when its required entry and exit checkpoints are satisfied.

### Additional Safeguards

- Never award lap completion based solely on physical proximity to the finish line.
- Do not advance checkpoint progress during recovery.
- Do not award item pickups or boost pads during teleportation.
- Do not allow a player to trigger recovery repeatedly to move forward.
- Validate the recovery position before restoring controls.

---

## 6. Example Godot Recovery Controller

The following is a simplified Godot 4 GDScript implementation using `CharacterBody3D`.

It assumes the kart already has its own movement controller.

```gdscript
extends CharacterBody3D

enum RecoveryState {
    NORMAL,
    DISINTEGRATING,
    TELEPORTING,
    RECONSTRUCTING,
    PROTECTED
}

@export var disintegration_time := 0.3
@export var teleport_time := 0.4
@export var reconstruction_time := 0.5
@export var protection_time := 1.0
@export var respawn_speed := 5.0

var recovery_state := RecoveryState.NORMAL
var last_safe_transform: Transform3D
var recovering := false

func _ready() -> void:
    last_safe_transform = global_transform


func set_recovery_point(point: Marker3D) -> void:
    if recovering:
        return

    last_safe_transform = point.global_transform


func recover() -> void:
    if recovering:
        return

    recovering = true
    recovery_state = RecoveryState.DISINTEGRATING

    # Disable normal kart controls.
    # Reset drifting, boosts, and temporary movement effects.
    velocity = Vector3.ZERO

    # Trigger holographic disintegration VFX here.
    await get_tree().create_timer(
        disintegration_time
    ).timeout

    recovery_state = RecoveryState.TELEPORTING

    # Hide kart visuals and disable kart-to-kart collision.
    await get_tree().create_timer(
        teleport_time
    ).timeout

    # Move to the last valid recovery position.
    global_transform = last_safe_transform
    velocity = Vector3.ZERO

    recovery_state = RecoveryState.RECONSTRUCTING

    # Show kart visuals and play reconstruction VFX.
    await get_tree().create_timer(
        reconstruction_time
    ).timeout

    recovery_state = RecoveryState.PROTECTED

    # Restore controls and limited forward speed.
    velocity = -global_transform.basis.z * respawn_speed

    recovering = false

    # Kart-to-kart collision protection remains active.
    await get_tree().create_timer(
        protection_time
    ).timeout

    recovery_state = RecoveryState.NORMAL
```

### Implementation Notes

This is a conceptual prototype, not a complete drop-in controller.

A production implementation should additionally:

- Use an explicit `controls_enabled` flag.
- Integrate with the existing kart state machine.
- Reset steering, drift charge, boost timers, and airborne state.
- Disable and restore collision layers selectively.
- Use a recovery token or generation ID to prevent outdated asynchronous callbacks from changing the kart state.
- Cancel active recovery timers when the kart is destroyed or the race ends.
- Ensure the kart is not overlapping another kart or solid geometry when reconstructed.
- Handle AI and multiplayer recovery through the same central system.

The kart should remain protected against new recovery triggers until the current recovery process is fully completed.

---

## 7. Out-of-Bounds Detection

Use a combination of detection methods rather than relying on a single global height limit.

### Method A — Fall Height

Suitable for tracks with large drops.

```gdscript
@export var minimum_track_height := -25.0

func _physics_process(delta: float) -> void:
    if global_position.y < minimum_track_height:
        recover()
```

This is simple but may not work well for tracks with multiple elevations.

### Method B — Hazard Volumes

Use `Area3D` nodes with collision shapes to define hazardous regions.

Example:

```gdscript
extends Area3D

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("karts"):
        body.recover()
```

Hazard volumes are particularly useful for:

- Water.
- Bottomless pits.
- Dangerous industrial areas.
- Off-track regions.
- Unreachable terrain.

### Method C — Stuck Detection

A kart may become trapped without leaving the track.

Track the kart's movement over time.

Suggested rules:

- If the player is attempting to accelerate but barely moves for 3–5 seconds, consider recovery.
- If the kart remains upside down for 2–3 seconds, initiate recovery.
- Allow a short opportunity for the player to correct the situation.
- Avoid triggering recovery when the player is intentionally stopped.

Stuck detection should consider player input, actual displacement, orientation, and nearby collisions rather than speed alone.

---

## 8. Holographic Visual Effects

The holographic reconstruction should be visually distinctive but not overly distracting.

### Color Palette

| Element | Suggested Color |
|---|---|
| Main hologram | Cyan |
| Secondary glow | Electric blue |
| Particle highlights | White |
| Warning distortion | Magenta |
| Recovery platform | Blue-white |

### Shader Effects

Possible Godot shader features:

- Transparency controlled by a dissolve parameter.
- Scrolling horizontal scan lines.
- Fresnel-based edge glow.
- Animated digital noise.
- Brief wireframe appearance.
- Particle emission synchronized with material dissolution.

### Disintegration

The kart should dissolve from bottom to top or front to back.

Suggested animation:

```text
0.00s — Kart flickers
0.10s — Scan lines appear
0.20s — Body begins dissolving
0.30s — Kart disappears
```

### Reconstruction

```text
0.00s — Holographic outline appears
0.15s — Wireframe becomes visible
0.30s — Solid body starts forming
0.45s — Glow fades
0.50s — Kart is fully reconstructed
```

### Performance Considerations

For multiple karts:

- Reuse particle materials.
- Pool reusable VFX objects where practical.
- Limit particle counts.
- Avoid expensive full-screen distortion.
- Use lightweight shaders for distant opponents.
- Keep effects synchronized with the recovery state machine.

---

## 9. Audio Design

The recovery sequence should have a recognizable futuristic sound.

Suggested audio layers:

| Event | Sound |
|---|---|
| Recovery triggered | Short electronic warning |
| Disintegration | Digital breakup or static |
| Teleportation | Low synthetic pulse |
| Reconstruction | Rising electronic shimmer |
| Recovery complete | Short confirmation tone |

Audio should be brief enough that repeated recoveries do not become annoying.

Avoid long voice announcements or excessively loud effects.

---

## 10. Recovery Edge Cases

| Situation | Recommended Behavior |
|---|---|
| Kart falls off a cliff | Trigger recovery after crossing a fall boundary |
| Kart enters deep water | Play a brief splash, then reconstruct |
| Kart gets stuck | Recover after validated immobility |
| Kart flips upside down | Allow self-righting, then recover |
| Kart misses a jump | Return to a safe point before the jump |
| Kart falls from a shortcut | Return to the last valid recovery point |
| Kart falls near the finish | Preserve legitimate lap progress without allowing a shortcut |
| Two karts respawn together | Temporarily disable kart-to-kart collision |
| Kart falls during a boost | Cancel the boost |
| Kart falls while drifting | Cancel drift and accumulated charge |
| Kart falls while holding an item | Preserve the item by default, subject to balancing |
| AI kart falls | Use the same recovery logic as human players |

---

## 11. Multiplayer Considerations

Recovery should be synchronized between players.

For authoritative multiplayer:

- The server validates recovery triggers.
- The server selects the respawn point.
- The server controls the final respawn transform.
- Clients display the holographic effects.
- Race progress remains server-authoritative.

Clients should not be allowed to select arbitrary recovery positions.

Recovery animations can be client-side, but gameplay state must remain consistent.

### Collision Protection

After reconstruction, apply approximately one second of protection against other karts.

During protection:

- Kart-to-kart collisions should be disabled.
- Track collision should remain active.
- Driving controls should work normally.
- The kart may use a subtle transparent or holographic appearance.

Protection should expire automatically.

---

## 12. Recommended Default Settings

| Parameter | Starting Value |
|---|---:|
| Total control-lock recovery time | 1.2 seconds |
| Full visual sequence | 1.6 seconds |
| Disintegration duration | 0.3 seconds |
| Teleportation duration | 0.4 seconds |
| Reconstruction duration | 0.5 seconds |
| Control restoration transition | 0.4 seconds |
| Respawn speed | 25% of normal top speed |
| Collision protection | 1.0 second |
| Stuck detection | 4.0 seconds |
| Overturned detection | 2.5 seconds |

These are initial tuning targets and should be adjusted through playtesting.

---

## 13. Implementation Priorities

### Phase 1 — Functional Recovery

- [ ] Create a reusable `RecoveryManager`.
- [ ] Add recovery markers to the track.
- [ ] Add out-of-bounds hazard volumes.
- [ ] Detect falling and trigger recovery.
- [ ] Disable controls during recovery.
- [ ] Respawn at the last valid recovery point.
- [ ] Restore movement after recovery.

### Phase 2 — Race Integration

- [ ] Integrate checkpoint and lap validation.
- [ ] Prevent shortcut exploits.
- [ ] Reset drift and boost states.
- [ ] Add stuck and overturned detection.
- [ ] Add temporary kart-to-kart collision immunity.
- [ ] Support AI kart recovery.

### Phase 3 — Visual Polish

- [ ] Add holographic disintegration shader.
- [ ] Add reconstruction shader.
- [ ] Add particle effects.
- [ ] Add scanning lines and digital distortion.
- [ ] Add recovery sound effects.
- [ ] Add subtle camera effects.
- [ ] Smoothly transition controls back to the player.

### Phase 4 — Testing and Optimization

- [ ] Test recovery on every track.
- [ ] Test overlapping track sections.
- [ ] Test falls during jumps.
- [ ] Test falls during boosts and drifts.
- [ ] Test simultaneous recovery of multiple karts.
- [ ] Test recovery near the finish line.
- [ ] Test AI recovery.
- [ ] Test multiplayer synchronization, if applicable.
- [ ] Profile shader and particle performance.

---

## Final Design Recommendation

Cyberwave 2199 should use a **fast holographic teleportation and reconstruction system** that preserves the arcade racing experience.

The system should prioritize reliable gameplay over elaborate animations.

The most important technical decisions are:

1. Use a centralized recovery system rather than separate recovery logic for every track.
2. Base respawn positions on legitimate track progress, not geographic proximity.
3. Separate visual reconstruction from gameplay collision and movement states.
4. Prevent recovery from becoming an exploitable shortcut.
5. Make all recovery timings and effects configurable.
6. Ensure recovery behaves consistently for both player-controlled and AI-controlled karts.

The result should feel like a natural part of Cyberwave 2199's futuristic world while maintaining the quick, accessible racing flow associated with Mario Kart.