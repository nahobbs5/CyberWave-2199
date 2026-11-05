extends Node3D
## Free-drive sandbox (Phase 1 prototype): one car, no race rules.
## Wires the track, car, camera and HUD. Esc returns to mode select.

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


func _unhandled_input(event: InputEvent) -> void:
	# No pause menu in the sandbox: Esc / Start goes back to mode select.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameSession.to_mode_select(get_tree())
