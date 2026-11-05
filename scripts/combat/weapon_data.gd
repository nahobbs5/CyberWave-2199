class_name WeaponData
extends Resource
## Data-driven weapon definition (GDD 6.3, 14.3). WeaponManager reads these;
## behaviour is chosen by kind, numbers come from the fields.

enum Kind { PROJECTILE, GUIDED, AREA, HAZARD, SELF_BOOST, SHIELD }

@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var kind: Kind = Kind.PROJECTILE
@export var color: Color = Color.WHITE
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
## Relative chance from a crate for the race leader...
@export var weight_front: float = 1.0
## ...and for the last-placed racer (interpolated in between).
@export var weight_back: float = 1.0
