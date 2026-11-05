extends Node3D
## Phase 1 driving prototype: wires the track, player car, camera and HUD.

@onready var track: TrackCircuit = $TestCircuit
@onready var car: VehicleController = $PlayerCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: PrototypeHUD = $PrototypeHUD


func _ready() -> void:
	InputSetup.ensure_actions()
	var spawn := track.get_spawn_transform()
	car.global_transform = spawn
	car.recovery.set_track(track, track.get_spawn_offset())
	camera.set_target(car)
	hud.setup(car, camera, track)
