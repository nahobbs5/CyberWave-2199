class_name CameraProfile
extends Resource
## Settings for one chase camera view (GDD 10.3).

@export var display_name: String = "Far Chase"
@export var distance: float = 9.0
@export var height: float = 3.6
## Height above the car's origin that the camera looks at.
@export var look_height: float = 1.2
## Metres ahead of the car that the camera looks toward.
@export var look_ahead: float = 6.0
@export_range(30.0, 120.0) var fov: float = 72.0
## Rear View: the camera sits ahead of the car and looks back past it.
@export var look_back: bool = false

@export_group("Speed Responsiveness")
## Extra FOV at top speed.
@export var speed_fov_gain: float = 8.0
## Extra distance at top speed.
@export var speed_distance_gain: float = 1.5
## Extra FOV while a drift boost is active.
@export var boost_fov_kick: float = 7.0

@export_group("Smoothing")
@export var position_smoothing: float = 10.0
@export var rotation_smoothing: float = 5.0
@export var fov_smoothing: float = 4.0
## 0 = follow the car's nose, 1 = follow its direction of travel.
@export_range(0.0, 1.0) var velocity_blend: float = 0.45

@export_group("Collision Avoidance")
@export var collision_margin: float = 0.4
