class_name WeaponManager
extends Node3D
## Runs combat for one race (GDD 6, 14.2 WeaponManager / PickupManager).
##
## Places the question-mark crates, rolls weapons with position-based odds,
## deploys weapons when racers use them, and routes every hit through the
## target's StatusEffects so all weapons follow the same rules. Finished
## racers can't use weapons, collect crates or be targeted.

signal weapon_collected(vehicle: VehicleController, weapon: WeaponData)
signal weapon_used(vehicle: VehicleController, weapon: WeaponData)
## blocked_by is &"" on a successful hit, else &"shield" / &"protection".
signal hit_resolved(target: VehicleController, weapon: WeaponData, shooter: VehicleController, blocked_by: StringName)
## A landed hit knocked a weapon out of the target's inventory.
signal item_lost(target: VehicleController, lost: WeaponData, by_weapon: WeaponData, shooter: VehicleController)

@export var weapons: Array[WeaponData] = []
@export var crate_respawn_time: float = 3.0
@export var random_seed: int = 6199
## Where projectiles leave the car, relative to its origin.
@export var muzzle_offset: Vector3 = Vector3(0.0, 0.0, -2.6)

var race: RaceManager
var track: TrackCircuit
var crates: Array[WeaponCrate] = []
## Use counts by weapon id (telemetry / tests).
var uses: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _reticle: MeshInstance3D
var _reticle_material: StandardMaterial3D
## One lock-on ring per human (player 1's is _reticle).
var _reticles: Array[MeshInstance3D] = []
var _reticle_materials: Array[StandardMaterial3D] = []
var _last_block: StringName = &""


func setup(race_manager: RaceManager) -> void:
	race = race_manager
	track = race.track
	_rng.seed = random_seed
	_spawn_crates()
	var vehicles := race.get_vehicles()
	for racer in race.racers:
		var car := racer.vehicle
		if car.inventory != null:
			car.inventory.use_requested.connect(use_weapon.bind(car))
		if car.targeting != null:
			car.targeting.racers = vehicles
			car.targeting.is_eligible = is_targetable
			car.targeting.race_distance = _race_distance
		if car.status != null:
			car.status.attack_blocked.connect(func(_e: StringName, by: StringName) -> void: _last_block = by)
	_build_reticle()


# --- rules ---------------------------------------------------------------------

func is_active() -> bool:
	return race != null and (race.state == RaceManager.State.RACING or race.state == RaceManager.State.FINISHED)


func is_targetable(vehicle: VehicleController) -> bool:
	if race == null:
		return false
	var progress: RaceProgress = race.progress_of(vehicle)
	return progress != null and not progress.finished and is_active() and not vehicle.is_recovering_hidden()


func can_fight(vehicle: VehicleController) -> bool:
	if not is_targetable(vehicle) or vehicle.recovery_lock:
		return false
	return vehicle.status == null or vehicle.status.can_use_weapons()


## Crate roll from each weapon's per-position percent (GDD 6.5): leaders get
## fewer powerful offensive weapons. If some weapons are missing, the rest
## scale up to fill 100%.
func roll_weapon(position: int, racer_count: int = 8) -> WeaponData:
	var total := 0.0
	for w in weapons:
		total += maxf(0.0, w.chance_for(position, racer_count))
	if total <= 0.0:
		return null
	var roll := _rng.randf() * total
	var last: WeaponData = null
	for w in weapons:
		var chance := maxf(0.0, w.chance_for(position, racer_count))
		if chance <= 0.0:
			continue
		last = w
		roll -= chance
		if roll < 0.0:
			return w
	return last


func try_give_weapon(vehicle: VehicleController) -> bool:
	if not is_targetable(vehicle) or vehicle.inventory == null or not vehicle.inventory.has_space():
		return false
	var weapon := roll_weapon(race.progress_of(vehicle).position, race.racers.size())
	if weapon == null or not vehicle.inventory.add(weapon):
		return false
	weapon_collected.emit(vehicle, weapon)
	return true


## Fires the selected weapon. Returns false if the racer can't fight right now.
func use_weapon(vehicle: VehicleController) -> bool:
	if not can_fight(vehicle) or vehicle.inventory == null or vehicle.inventory.current() == null:
		return false
	var weapon := vehicle.inventory.take_selected()
	_deploy(vehicle, weapon)
	uses[weapon.id] = uses.get(weapon.id, 0) + 1
	weapon_used.emit(vehicle, weapon)
	if vehicle.targeting != null:
		vehicle.targeting.clear()
	return true


## Applies a weapon's effect to a racer. Returns true if it landed.
## `duration` < 0 uses the weapon's own effect_duration.
func apply_hit(target: VehicleController, weapon: WeaponData, shooter: VehicleController,
		duration: float = -1.0) -> bool:
	if target == null or target.status == null:
		return false
	if target == shooter and not weapon.can_affect_owner:
		return false
	var progress := race.progress_of(target)
	if progress == null or progress.finished:
		return false
	_last_block = &""
	var landed := target.status.apply_attack(weapon.effect, duration if duration >= 0.0 else weapon.effect_duration,
			weapon.pierces_shield)
	hit_resolved.emit(target, weapon, shooter, &"" if landed else _last_block)
	if not landed:
		return false
	# Blocked hits cost nothing; landed ones may strip or jam weapons.
	if weapon.weapon_lock_duration > 0.0:
		target.status.apply_jam(weapon.weapon_lock_duration)
	if weapon.strips_item and target.inventory != null:
		var lost := target.inventory.lose_item()
		if lost != null:
			item_lost.emit(target, lost, weapon, shooter)
	return true


## True if an opponent has locked on to, or a drone is chasing, this racer.
func is_incoming(vehicle: VehicleController) -> bool:
	if is_locked_on(vehicle):
		return true
	for drone in get_tree().get_nodes_in_group(&"hunter_drones"):
		if drone is HunterKillerDrone and drone.target == vehicle and not drone.is_spent():
			return true
	return false


## True if an opponent has a weapon lock on this racer (a Firewall helps).
func is_locked_on(vehicle: VehicleController) -> bool:
	for racer in race.racers:
		var other := racer.vehicle
		if other != vehicle and other.targeting != null and other.targeting.get_target() == vehicle:
			return true
	return false


## True if a Hunter-Killer diving on this racer can be dodged with a Nitro right now.
func can_dodge_drone(vehicle: VehicleController) -> bool:
	for drone in get_tree().get_nodes_in_group(&"hunter_drones"):
		if drone is HunterKillerDrone and drone.target == vehicle and drone.in_dodge_window():
			return true
	return false


## Nearest targetable racer ahead of a point along the track (for drones).
func find_target_ahead(from: Vector3, exclude: VehicleController, max_ahead: float) -> VehicleController:
	var from_offset := track.get_offset_at(from)
	var best: VehicleController = null
	var best_gap := max_ahead
	for racer in race.racers:
		var car := racer.vehicle
		if car == exclude or not is_targetable(car):
			continue
		var gap := track.wrapped_delta(from_offset, track.get_offset_at(car.global_position))
		if gap > 0.0 and gap < best_gap:
			best_gap = gap
			best = car
	return best


func _race_distance(vehicle: VehicleController) -> float:
	var progress := race.progress_of(vehicle)
	return progress.race_distance if progress != null else 0.0


# --- deployment ------------------------------------------------------------------

func _deploy(user: VehicleController, weapon: WeaponData) -> void:
	var forward := -user.global_transform.basis.z
	match weapon.kind:
		WeaponData.Kind.PROJECTILE:
			var shot := RailgunShot.new()
			shot.manager = self
			shot.shooter = user
			shot.weapon = weapon
			shot.position = user.global_transform * muzzle_offset
			shot.direction = _aim(user, weapon, shot.position, forward)
			add_child(shot)
			CombatSfx.play_on(user, CombatSfx.RAILGUN, "Railgun")
		WeaponData.Kind.GUIDED:
			var drone := HunterDrone.new()
			drone.manager = self
			drone.shooter = user
			drone.weapon = weapon
			# Guided weapons pick their own target if there was no lock (GDD 6.2).
			var target: VehicleController = user.targeting.get_target() if user.targeting != null else null
			if target == null:
				target = find_target_ahead(user.global_position, user, 120.0)
			drone.target = target
			drone.position = user.global_transform * muzzle_offset + Vector3.UP * 1.5
			add_child(drone)
		WeaponData.Kind.AREA:
			for racer in race.racers:
				var other := racer.vehicle
				if other != user and other.global_position.distance_to(user.global_position) <= weapon.radius:
					apply_hit(other, weapon, user)
			var blast := EmpBlast.new()
			blast.radius = weapon.radius
			blast.color = weapon.color
			blast.position = user.global_position
			add_child(blast)
			CombatSfx.play_on(user, CombatSfx.EMP, "Emp")
		WeaponData.Kind.HAZARD:
			var spike := RoadSpike.new()
			spike.manager = self
			spike.shooter = user
			spike.weapon = weapon
			var flat := Vector3(forward.x, 0.0, forward.z).normalized()
			var drop := user.global_position - flat * 4.5
			drop.y = track.get_center_at(track.get_offset_at(drop)).y
			spike.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), drop)
			add_child(spike)
			CombatSfx.play_on(spike, CombatSfx.SPIKE_DROP, "SpikeDrop")
		WeaponData.Kind.SELF_BOOST:
			user.start_external_boost(weapon.boost_extra_speed, weapon.effect_duration,
					weapon.boost_kick, weapon.display_name, weapon.color)
		WeaponData.Kind.SHIELD:
			if user.status != null:
				user.status.apply_buff(weapon.effect, weapon.effect_duration)
		WeaponData.Kind.LEADER_DRONE:
			var hunter := HunterKillerDrone.new()
			hunter.manager = self
			hunter.shooter = user
			hunter.weapon = weapon
			hunter.target = HunterKillerDrone.pick_target(race, user)
			hunter.position = user.global_transform * muzzle_offset + Vector3.UP * 1.8
			if hunter.target != null:
				add_child(hunter)
			else:
				hunter.free()
		WeaponData.Kind.OVERDRIVE:
			OverdriveController.for_vehicle(user).activate(track)
		WeaponData.Kind.OVERRIDE:
			_system_override(user, weapon)


## System Override: every racer ahead of the user right now is hacked
## (slowed); nobody behind is touched (Advanced Weapons §3). The leader is
## hacked longest: each victim's time comes from their position right now.
## Already-hacked cars are skipped (no stacking, no extending).
func _system_override(user: VehicleController, weapon: WeaponData) -> Array[VehicleController]:
	var hit: Array[VehicleController] = []
	var me := race.progress_of(user)
	if me == null:
		return hit
	# Snapshot first, so hits can't reshuffle who counts as "ahead".
	var ahead: Array[VehicleController] = []
	var places: Array[int] = []
	for racer in race.get_standings():
		if racer.vehicle != user and racer.position < me.position and not racer.finished and not racer.eliminated:
			ahead.append(racer.vehicle)
			places.append(racer.position)
	for i in ahead.size():
		var car := ahead[i]
		if car.status != null and car.status.has(weapon.effect):
			continue
		var seconds := weapon.duration_for(places[i])
		if is_targetable(car) and apply_hit(car, weapon, user, seconds):
			hit.append(car)
			_attach_override_sparks(car, seconds, weapon.color)
	var pulse := EmpBlast.new()
	pulse.radius = 14.0
	pulse.color = weapon.color
	pulse.position = user.global_position
	add_child(pulse)
	# Heard at the user, and on hacked human cars (they may be far ahead).
	# Not on hacked AI cars: a pack of them stacked up far too loud.
	CombatSfx.play_on(user, CombatSfx.OVERRIDE, "Override")
	for car in hit:
		if car.is_player:
			CombatSfx.play_on(car, CombatSfx.OVERRIDE, "Override")
	return hit


## Red arcs crawling over a hacked car for `seconds`.
func _attach_override_sparks(car: VehicleController, seconds: float, color: Color) -> void:
	var old := car.get_node_or_null("OverrideSparks")
	if old != null:
		old.free()
	var sparks := CPUParticles3D.new()
	sparks.name = "OverrideSparks"
	sparks.amount = 30
	sparks.lifetime = 0.18
	sparks.explosiveness = 0.3
	var bolt := BoxMesh.new()
	bolt.size = Vector3(0.04, 0.5, 0.04)
	bolt.material = glow_material(color, 1.6)
	sparks.mesh = bolt
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.9, 0.5, 1.8) * car.visual_scale
	sparks.position = Vector3(0.0, 0.6 * car.visual_scale, 0.0)
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 0.5
	sparks.initial_velocity_max = 2.0
	sparks.angle_min = -180.0
	sparks.angle_max = 180.0
	sparks.particle_flag_align_y = true
	car.add_child(sparks)
	# A tween on the sparks themselves, so it dies with them (race ending early).
	var tween := sparks.create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(func() -> void: sparks.emitting = false)
	tween.tween_interval(0.3)
	tween.tween_callback(sparks.queue_free)


## A one-shot burst of electric streaks (the Hunter-Killer's discharge).
func spawn_arc_burst(at: Vector3, color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 36
	burst.lifetime = 0.35
	var streak := BoxMesh.new()
	streak.size = Vector3(0.05, 0.9, 0.05)
	streak.material = glow_material(color, 6.0)
	burst.mesh = streak
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.gravity = Vector3.ZERO
	burst.initial_velocity_min = 8.0
	burst.initial_velocity_max = 16.0
	burst.particle_flag_align_y = true
	burst.position = at
	add_child(burst)
	burst.emitting = true
	var tween := burst.create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(burst.queue_free)


## Aims at the locked target's predicted position, else straight ahead.
func _aim(user: VehicleController, weapon: WeaponData, from: Vector3, forward: Vector3) -> Vector3:
	var target: VehicleController = user.targeting.get_target() if user.targeting != null else null
	if target == null or weapon.speed <= 0.0:
		return forward
	var lead_time := from.distance_to(target.global_position) / weapon.speed
	var predicted := target.global_position + target.linear_velocity * lead_time
	return (predicted - from).normalized()


func _spawn_crates() -> void:
	for row in track.crate_row_offsets:
		for lateral in track.crate_lateral_positions:
			_add_crate(track.get_safe_transform(row, lateral, 1.1))
	# Rows on branch routes (an alternate route's own item row).
	for sc in track.shortcuts:
		for d in sc.crate_distances:
			for lateral in sc.crate_laterals:
				_add_crate(track.global_transform * sc.safe_transform(d, lateral, 1.1))
	# Item boxes on ramps and on boosters that ask for them.
	for child in track.get_children():
		if child is TrackFeature:
			for xf in (child as TrackFeature).item_box_transforms():
				_add_crate(xf)


func _add_crate(xf: Transform3D) -> void:
	var crate := WeaponCrate.new()
	crate.manager = self
	crate.respawn_time = crate_respawn_time
	crate.transform = xf
	add_child(crate)
	crates.append(crate)


func spawn_flash(at: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	# Reduced flashing (GDD 11.9): a dimmer, slower fade.
	light.light_energy = 2.0 if GameSettings.reduced_flashing else 6.0
	light.omni_range = 8.0
	light.position = at
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.6 if GameSettings.reduced_flashing else 0.3)
	tween.tween_callback(light.queue_free)


# --- player lock indicator (GDD 6.2) ------------------------------------------------

func _build_reticle() -> void:
	_reticles.clear()
	_reticle_materials.clear()
	var count := maxi(1, race.players.size())
	for i in count:
		var reticle := MeshInstance3D.new()
		reticle.name = "Reticle%d" % (i + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = 1.6
		torus.outer_radius = 1.85
		reticle.mesh = torus
		var mat := glow_material(Color(1.0, 0.2, 0.85), 4.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		reticle.material_override = mat
		reticle.visible = false
		add_child(reticle)
		# Split screen: each player sees only their own lock-on ring.
		if race.is_multiplayer():
			SplitScreen.set_render_layer(reticle, SplitScreen.private_layer(i))
		_reticles.append(reticle)
		_reticle_materials.append(mat)
	_reticle = _reticles[0]
	_reticle_material = _reticle_materials[0]


func _physics_process(delta: float) -> void:
	if race == null:
		return
	for racer in race.racers:
		var car := racer.vehicle
		if car.targeting == null or car.inventory == null:
			continue
		var weapon := car.inventory.current()
		car.targeting.update(delta, weapon != null and weapon.targeted and can_fight(car))


func _process(_delta: float) -> void:
	if _reticles.is_empty() or race.player == null:
		return
	for i in _reticles.size():
		var human := race.players[i] if i < race.players.size() else race.player
		_update_reticle(_reticles[i], _reticle_materials[i], human.vehicle.targeting)


func _update_reticle(reticle: MeshInstance3D, mat: StandardMaterial3D, targeting: TargetingSystem) -> void:
	var shown: VehicleController = targeting.candidate if targeting != null else null
	reticle.visible = shown != null
	if shown == null:
		return
	reticle.global_position = shown.global_position + Vector3.UP * 1.0
	var pulse := 1.0 if GameSettings.reduced_flashing else 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.015)
	if targeting.locked:
		reticle.scale = Vector3.ONE * pulse
		mat.albedo_color = Color(1.0, 0.2, 0.85, 0.95)
	else:
		# Shrinks onto the target while the lock is being acquired.
		reticle.scale = Vector3.ONE * lerpf(2.0, 1.0, targeting.acquire_progress)
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.5)


static func glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat
