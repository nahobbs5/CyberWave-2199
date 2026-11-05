class_name VehicleData
extends Resource
## One selectable vehicle (GDD 5.1): identity, driving stats and its model.
## Every car uses the shared car scene (physics, wheels, effects); the
## visible body comes from model_scene or the procedural CarDesigns entry.

@export var id: String = "vehicle"
@export var display_name: String = "Vehicle"
@export var vehicle_type: String = ""
@export_multiline var character: String = ""
@export var stats: VehicleStats
## Optional imported model (.glb scene) replacing the procedural one. See the
## README section "Vehicle models" for the naming conventions.
@export var model_scene: PackedScene
## Factory paint (the free "Factory" colour).
@export var factory_color: Color = Color(0.1, 0.12, 0.22)
## Proportions of the Phase 1 box car, used only when the vehicle has
## neither a model_scene nor a procedural design.
@export var body_scale: Vector3 = Vector3.ONE
@export var cabin_scale: Vector3 = Vector3.ONE
@export var spoiler_scale: Vector3 = Vector3.ONE
