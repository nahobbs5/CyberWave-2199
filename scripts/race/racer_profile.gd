class_name RacerProfile
extends Resource
## Identity and driving personality of one AI rival (GDD 7.3).
## Personality shapes decisions; AIDifficulty sets overall competence.

@export var display_name: String = "Rival"
@export var archetype: String = "Technician"
@export var color: Color = Color(0.8, 0.8, 0.8)
## Preferred offset from the racing line in metres (+ = right).
@export var line_bias: float = 0.0
## Multiplies the difficulty's corner speed (risk taking).
@export_range(0.85, 1.1) var corner_speed_bias: float = 1.0
## Multiplies the difficulty's drift chance.
@export_range(0.0, 2.0) var drift_tendency: float = 1.0
## 0 = waits behind slower cars, 1 = pulls out to pass immediately.
@export_range(0.0, 1.0) var aggression: float = 0.5
## Multiplies the difficulty's line wander (lower = more precise).
@export_range(0.0, 2.0) var precision_wander: float = 1.0
