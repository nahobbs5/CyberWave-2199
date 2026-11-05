class_name VehicleData
extends Resource
## One selectable vehicle (GDD 5.1): identity, driving stats and placeholder
## body proportions until the Phase 6 models arrive. Every car uses the
## shared placeholder car scene; only stats and proportions differ.

@export var id: String = "vehicle"
@export var display_name: String = "Vehicle"
@export var vehicle_type: String = ""
@export_multiline var character: String = ""
@export var stats: VehicleStats
## Factory paint (the free "Factory" colour).
@export var factory_color: Color = Color(0.1, 0.12, 0.22)
## Placeholder proportions: scale of the whole body, the cabin and the spoiler.
@export var body_scale: Vector3 = Vector3.ONE
@export var cabin_scale: Vector3 = Vector3.ONE
@export var spoiler_scale: Vector3 = Vector3.ONE
