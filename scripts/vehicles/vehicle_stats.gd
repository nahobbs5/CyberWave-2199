class_name VehicleStats
extends Resource
## Shared, data-driven driving values for one vehicle (GDD 5.2, 14.3).
## Speeds are m/s, rates are rad/s, accelerations are m/s².
## All numbers are first-pass prototype values and need playtesting.

@export var display_name: String = "Placeholder GT"

@export_group("Top Speed and Acceleration")
@export var top_speed: float = 55.0
@export var acceleration: float = 17.0
@export var reverse_top_speed: float = 14.0
@export var reverse_acceleration: float = 10.0
@export var brake_deceleration: float = 34.0
@export var coast_deceleration: float = 3.5
## Deceleration applied when above the current speed cap (e.g. after a boost).
@export var overspeed_deceleration: float = 9.0

@export_group("Handling")
## Maximum yaw rate at low-to-mid speed.
@export var handling: float = 1.9
## Fraction of handling left at top speed.
@export var high_speed_steer_factor: float = 0.5
## Speed at which steering reaches full authority.
@export var steer_full_speed: float = 8.0
## How quickly yaw rate approaches its target (1/s).
@export var steer_response: float = 9.0
## How quickly sideways velocity is removed (1/s).
@export var grip: float = 9.0
## How much speed is kept when grip redirects velocity (0 = scrubbed, 1 = kept).
@export_range(0.0, 1.0) var grip_speed_retention: float = 0.35

@export_group("Drift")
## Base yaw rate into the drift.
@export var drift: float = 0.95
## Extra / reduced yaw rate from steering into / against the drift.
@export var drift_steer_influence: float = 0.55
@export var drift_grip: float = 2.4
@export_range(0.0, 1.0) var drift_speed_retention: float = 0.85
@export var drift_min_speed: float = 12.0
## Sideways speed required for a drift to count as valid and charge (GDD 4.1).
@export var drift_min_lateral_speed: float = 1.5

@export_group("Drift Boost (Cyan, Magenta, Gold)")
@export var boost_extra_speed: PackedFloat32Array = PackedFloat32Array([6.0, 10.0, 15.0])
@export var boost_duration: PackedFloat32Array = PackedFloat32Array([0.7, 1.2, 1.8])
## Instant forward velocity added when the boost fires.
@export var boost_kick: PackedFloat32Array = PackedFloat32Array([3.0, 5.0, 8.0])
@export var boost_acceleration: float = 26.0

@export_group("Suspension")
@export var suspension_rest_length: float = 0.45
@export var suspension_stiffness: float = 30000.0
@export var suspension_damping: float = 3500.0
@export var wheel_radius: float = 0.38

@export_group("Stability")
## Upright correction while all wheels are on the ground.
@export var ground_upright_strength: float = 1.5
## Upright correction while airborne.
@export var air_upright_strength: float = 2.5
## Forward speed lost in one physics step that counts as a major collision.
@export var major_impact_speed_loss: float = 10.0
