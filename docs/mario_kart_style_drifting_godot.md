# Mario Kart-Style Drifting: Technical Breakdown and Godot Implementation

Mario Kart drifting is **not a realistic tire-traction simulation**. It is an arcade movement system that combines steering, sideways sliding, momentum, and a chargeable speed boost.

For **Cyberwave 2199**, a Mario Kart 8 Deluxe-inspired approach can make drifting responsive and rewarding while retaining control over the kart.

## 1. The Five Stages of Drifting

1. **Initiation:** The player holds the drift button while steering. The kart performs a small hop and enters a drift state, establishing its initial drift direction.
2. **Controlled slide:** The kart rotates into the corner, but its movement direction does not perfectly match where its nose points. Steering into the drift tightens the corner; countersteering widens it.
3. **Boost charging:** Drifting builds a hidden charge meter. Sparks change color when thresholds are reached.
4. **Drift release:** Releasing the drift button ends the slide and grants a mini-turbo based on charge.
5. **Recovery:** The kart smoothly realigns its facing and movement directions while the mini-turbo temporarily increases speed.

**Key principle:** During a drift, the kart's **facing direction** and **velocity direction** can differ.

## 2. Steering Mechanics

### Normal driving

- Steering rotates the kart toward the requested direction.
- Movement closely follows the kart's forward direction.
- Sideways motion is limited.

### Drifting

- The drift direction is established when the drift begins.
- Steering **into** the corner tightens the turning radius.
- Steering **away** from the corner widens the turning radius.
- The kart retains a sideways visual angle.
- The kart follows a controlled curved path rather than an uncontrolled traction loss.

This is what distinguishes Mario Kart-style drifting from realistic vehicle simulations: the player is controlling a dedicated cornering state rather than recovering from a loss of grip.

## 3. Mini-Turbo Charging

Mario Kart 8 Deluxe uses a hidden charge system. It is not simply a timer: steering toward the inside of a drift can build charge faster than steering outward. Charge thresholds also depend on vehicle statistics.

| Level | Visual effect | Reward |
|---|---|---|
| 0 | No charged sparks | No boost |
| 1 | Blue sparks | Short mini-turbo |
| 2 | Orange sparks | Medium mini-turbo |
| 3 | Purple sparks | Long mini-turbo |

Ultra Mini-Turbo (purple) is unavailable when Smart Steering is enabled in Mario Kart 8 Deluxe.

The design tradeoff is important: turning more sharply can charge the boost faster, but may cause the player to take a less efficient racing line.

## 4. Godot Implementation Strategy

For Cyberwave 2199, use a **custom arcade controller with a drift state machine** rather than relying entirely on `VehicleBody3D` tire physics.

```text
NORMAL DRIVING
    |
    | Drift button + steering + sufficient speed
    v
DRIFTING
    | Adjustable turning radius
    | Sideways slip
    | Charge buildup
    |
    | Release drift button
    v
MINI-TURBO
    | Temporary speed increase
    v
NORMAL DRIVING
```

### Example GDScript

The following is **illustrative prototype code**, not Nintendo's source code or a complete production kart controller. It assumes a `CharacterBody3D` with input actions named `steer_left`, `steer_right`, and `drift`.

```gdscript
extends CharacterBody3D

@export var speed := 25.0
@export var turn_rate := 2.0
@export var drift_turn_rate := 2.7
@export var drift_slip := 0.35

var drifting := false
var drift_direction := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var travel_direction := Vector3.FORWARD

func _physics_process(delta):
    var steer := Input.get_axis("steer_left", "steer_right")
    var drift_pressed := Input.is_action_pressed("drift")

    if drift_pressed and not drifting and abs(steer) > 0.2:
        drifting = true
        drift_direction = sign(steer)
        drift_charge = 0.0

    if drifting:
        var inward := steer * drift_direction
        var turn_strength := clamp(0.7 + inward * 0.3, 0.25, 1.0)

        rotate_y(-drift_direction * drift_turn_rate * turn_strength * delta)

        # Charge faster when steering into the drift.
        drift_charge += delta * (2.5 if inward > 0.5 else 1.0)

        if not drift_pressed:
            drifting = false
            if drift_charge >= 3.0:
                boost_time = 1.5
            elif drift_charge >= 1.5:
                boost_time = 0.8
            elif drift_charge >= 0.6:
                boost_time = 0.4
    else:
        rotate_y(-steer * turn_rate * delta)

    var forward := -global_transform.basis.z

    # Retain more sideways momentum while drifting.
    var grip := 3.0 if drifting else 12.0
    travel_direction = travel_direction.lerp(
        forward, clamp(grip * delta, 0.0, 1.0)
    ).normalized()

    boost_time = maxf(0.0, boost_time - delta)
    var current_speed := speed * (1.3 if boost_time > 0.0 else 1.0)

    velocity.x = travel_direction.x * current_speed
    velocity.z = travel_direction.z * current_speed
    move_and_slide()
```

**Prototype caveats:** The `drift_slip` export is not yet wired into the calculation; slip is currently controlled by the `grip` value. The code also uses fixed forward speed and omits acceleration, gravity, collision recovery, speed-dependent steering, drift hops, animation, and polished transitions. In a production controller, drift eligibility should check speed and ground contact, and release should be processed separately from the drift-steering update.

## 5. Suggested Initial Tuning for Cyberwave 2199

These are **starting values to test**, not measured Mario Kart parameters.

| Parameter | Initial value | Purpose |
|---|---:|---|
| Normal turn rate | 2.0 rad/s | Standard steering responsiveness |
| Drift turn rate | 2.7 rad/s | Cornering authority during drift |
| Conceptual drift slip | 35% | Visible sideways movement |
| Drift grip interpolation | 3.0 | Slower velocity realignment during drift |
| Normal grip interpolation | 12.0 | Faster realignment outside drift |
| Level 1 charge threshold | 0.6 | Short mini-turbo |
| Level 2 charge threshold | 1.5 | Medium mini-turbo |
| Level 3 charge threshold | 3.0 | Long mini-turbo |
| Boost speed multiplier | 1.3x | Temporary speed increase |
| Boost durations | 0.4 / 0.8 / 1.5 s | Rewards for three charge levels |

### Tuning goals

- **Low slip:** Tight, grippy cornering.
- **Moderate slip:** Balanced arcade drifting.
- **High slip:** Loose, exaggerated sliding.
- **Higher drift turn rate:** Tighter and more responsive drift corners.
- **Faster charge multiplier:** More frequent mini-turbos.

## 6. Recommended Polish Features

1. **Separate visual and physical rotation.** Let the visible kart lean or yaw independently of its collision-body movement so sliding looks dramatic without destabilizing handling.
2. **Add a drift-entry hop.** A small hop communicates the transition and makes the action feel intentional.
3. **Smooth the transitions.** Blend into drift and back into regular driving instead of snapping between orientations.
4. **Scale steering with speed.** Prevent very sharp high-speed turns while keeping low-speed control responsive.
5. **Use visual and audio feedback.** Tire smoke, blue/orange/purple sparks, skid sounds, and boost effects should clearly communicate charge levels.
6. **Preserve meaningful countersteering.** Players should be able to widen or tighten a corner without instantly canceling the drift.
7. **Tune racing lines and rewards together.** Boost charging should reward skilled cornering without making every turn trivially optimal.

## 7. Main Takeaway

The difference between drifting that merely **works** and drifting that **feels like Mario Kart** is largely in three areas:

- How smoothly the kart enters a drift.
- How much steering authority the player retains while sliding.
- How cleanly the kart straightens and accelerates when the drift ends.

For Cyberwave 2199, prioritize **predictable arcade handling, satisfying visual feedback, and a skill-based mini-turbo system** over realistic tire simulation.
