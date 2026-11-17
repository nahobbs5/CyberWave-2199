class_name SwarmBots
extends HunterDrone
## Swarm Bots (GDD 6.3): a cloud of small bots that chases the locked target
## like a Hunter Drone and latches on. A landed hit leashes the car (much
## lower top speed and acceleration, StatusEffects "leash") for the weapon's
## effect_duration, with the bots clinging on (SwarmLeash). A Firewall blocks
## it; a Holo Decoy draws it off. Not a hard stun, so no item is lost.

const BOT_COUNT := 14
const CLOUD_RADIUS := 0.9

var _bots: Array[MeshInstance3D] = []
var _phases: PackedFloat32Array = PackedFloat32Array()
var _fx_rng := RandomNumberGenerator.new()


func _build_visuals() -> void:
	_fx_rng.randomize()
	var mesh := SwarmBots.bot_mesh()
	var mat := WeaponManager.glow_material(weapon.color, 3.0)
	for i in BOT_COUNT:
		var bot := MeshInstance3D.new()
		bot.mesh = mesh
		bot.material_override = mat
		bot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bot)
		_bots.append(bot)
		_phases.append(_fx_rng.randf() * TAU)
	var light := OmniLight3D.new()
	light.light_color = weapon.color
	light.light_energy = 2.0
	light.omni_range = 6.0
	add_child(light)


## One small bot: a little glowing pyramid.
static func bot_mesh() -> Mesh:
	var prism := PrismMesh.new()
	prism.size = Vector3(0.22, 0.26, 0.22)
	return prism


func _strike(victim: VehicleController) -> void:
	if manager.apply_hit(victim, weapon, shooter):
		SwarmLeash.attach(victim, weapon.color)
	else:
		manager.spawn_arc_burst(global_position, weapon.color)


func _animate(_delta: float) -> void:
	var t := _age
	for i in _bots.size():
		var p := _phases[i]
		var bot := _bots[i]
		bot.position = Vector3(
				sin(t * 7.0 + p) * CLOUD_RADIUS,
				sin(t * 9.0 + p * 2.0) * CLOUD_RADIUS * 0.6,
				cos(t * 5.0 + p * 1.5) * CLOUD_RADIUS)
		bot.rotation = Vector3(t * 6.0 + p, t * 8.0 + p, 0.0)
