class_name WeaponData
extends Resource
## Data-driven weapon definition (GDD 6.3, 14.3). WeaponManager reads these;
## behaviour is chosen by kind, numbers come from the fields.

## New kinds go at the end: .tres files store the number.
## LEADER_DRONE: Hunter-Killer Drone (hunts the leader). OVERDRIVE: automated
## flight. OVERRIDE: System Override (slows everyone ahead).
enum Kind { PROJECTILE, GUIDED, AREA, HAZARD, SELF_BOOST, SHIELD, LEADER_DRONE, OVERDRIVE, OVERRIDE }

@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var kind: Kind = Kind.PROJECTILE
@export var color: Color = Color.WHITE
## HUD slot picture (from the Weapon Arsenal concept art).
@export var icon: Texture2D
## Uses lock-on targeting while selected (GDD 6.2).
@export var targeted: bool = false
## Uses per pickup; the slot empties after the last one (e.g. Triple Nitro).
@export_range(1, 9) var charges: int = 1

@export_group("Effect")
## Status applied to the victim (stun, stagger, emp, traction) or to the
## user for buffs (shield).
@export var effect: StringName = &""
@export var effect_duration: float = 1.0
## A landed hit knocks out the victim's selected weapon.
@export var strips_item: bool = false
## A landed hit takes the victim's weapons offline this long ("jammed").
@export var weapon_lock_duration: float = 0.0

@export_group("Behaviour")
## Projectile / drone speed (m/s).
@export var speed: float = 0.0
## Seconds a drone, hazard or shield lasts.
@export var lifetime: float = 0.0
## Area weapons: effect radius (m). Projectiles: max range (m).
@export var radius: float = 0.0
## Self boost: extra top speed (m/s) and instant kick (m/s).
@export var boost_extra_speed: float = 0.0
@export var boost_kick: float = 0.0

@export_group("Self-effects (GDD 6.4)")
@export var can_affect_owner: bool = false
## Seconds after deployment before it can affect its owner.
@export var owner_grace: float = 0.0

@export_group("Crate odds (GDD 6.5)")
## Percent chance from a crate for each position, 1st to 8th (fewer racers
## are spread over the same rows). All weapons add up to 100 per position.
@export var position_chance: PackedFloat32Array = PackedFloat32Array()
## Rare comeback item (Advanced Weapons doc): Hunter-Killer, Overdrive,
## System Override.
@export var rare: bool = false


## True for the rare comeback items.
func is_special() -> bool:
	return rare


## Percent chance (0-100) for a racer in `position` of `racer_count`.
func chance_for(position: int, racer_count: int) -> float:
	if position_chance.is_empty():
		return 0.0
	var rows := position_chance.size()
	var t := clampf(float(position - 1) / float(maxi(racer_count - 1, 1)), 0.0, 1.0)
	return position_chance[clampi(roundi(t * (rows - 1)), 0, rows - 1)]
