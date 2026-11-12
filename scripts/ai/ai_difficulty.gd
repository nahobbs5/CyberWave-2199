class_name AIDifficulty
extends Resource
## Overall AI competence for one difficulty level (GDD 7.2).
## Difficulty changes how well AI drives, never the car's stats.

@export var display_name: String = "Normal"
## Fraction of the racing line's safe corner speed the AI aims for.
@export_range(0.5, 1.1) var speed_factor: float = 0.93
## Steering lookahead: base metres plus seconds of travel.
@export var lookahead_base: float = 7.0
@export var lookahead_time: float = 0.45
@export var steer_gain: float = 2.6
## Seconds for steering input to swing fully (slower = less precise).
@export var reaction_time: float = 0.12
## How far off the ideal line the AI wanders (metres).
@export var line_wander: float = 1.0
## Chance (0-1) of drifting through a suitable corner.
@export_range(0.0, 1.0) var drift_chance: float = 0.65
## Chance of doing a trick off a jump ramp.
@export_range(0.0, 1.0) var trick_chance: float = 0.6
## Multiplies each shortcut's own AI chance (GDD 7.4, 14.3 shortcuts).
@export_range(0.0, 2.0) var shortcut_chance: float = 1.0
## Target-speed adjustment per 200 m gap to the player (0 = no rubber-banding).
@export_range(0.0, 0.3) var rubber_band: float = 0.03

## Rocket start (StartLaunch): chance of nailing the window, and of jumping
## the start into a burnout. Otherwise a normal start.
@export_range(0.0, 1.0) var rocket_start_chance: float = 0.4
@export_range(0.0, 1.0) var burnout_chance: float = 0.08

@export_group("Weapons")
## Seconds between weapon decisions.
@export var weapon_reaction: float = 0.4
## Chance (0-1) of acting on each decision.
@export_range(0.0, 1.0) var weapon_skill: float = 0.8
