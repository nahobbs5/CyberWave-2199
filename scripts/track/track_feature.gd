@tool
class_name TrackFeature
extends Node3D
## A shared track feature (GDD 8.7), placed by distance along the track.
## Add as a child of a TrackCircuit (or give it a shortcut name to sit on a
## shortcut). Kinds:
##   BOOST_PAD      flat strip: short speed burst for anyone driving over it
##   BOOST_RING     drive-through ring: a bigger burst
##   EMP_PUDDLE     electrified hazard: a 1 s EMP (a Firewall blocks it)
##   BREAKABLE      destructible barrier row: smashes on contact, costs some
##                  speed, rebuilds after a while (often guards a shortcut)
##   JUMP_RAMP      a solid ramp the wheels drive up; launches cars into the
##                  air (place on straights, full road width)
##   WATER          standing water: cars in it are "wet" (a little slower,
##                  less grip) and throw spray
## Every kind is clearly marked and lit so it reads at speed (GDD 15.3).

enum Kind { BOOST_PAD, BOOST_RING, EMP_PUDDLE, BREAKABLE, JUMP_RAMP, WATER }

const PAD_COLOR := Color(0.0, 0.95, 1.0)
const RING_COLOR := Color(1.0, 0.2, 0.85)
## Harsh violet-white: deliberately unlike the cyan boost pads.
const EMP_COLOR := Color(0.75, 0.5, 1.0)
const BARRIER_COLOR := Color(1.0, 0.75, 0.1)
const RAMP_COLOR := Color(1.0, 0.55, 0.1)
const WATER_COLOR := Color(0.2, 0.55, 0.75)
const WATER_SHADER := preload("res://assets/shaders/standing_water.gdshader")
const EMP_SHADER := preload("res://assets/shaders/emp_puddle.gdshader")
const SIGN_SHADER := preload("res://assets/shaders/hazard_sign.gdshader")
## How long a car stays wet after leaving the water.
const WET_LINGER := 0.3

@export var kind: Kind = Kind.BOOST_PAD:
	set(value):
		kind = value
		_rebuild_visuals()
## Distance along the main loop (or along the shortcut when on_shortcut is set).
@export var offset: float = 0.0
## If set (main road only), offset is measured from the road point nearest
## this layout position instead of from the start.
@export var anchor_point: Vector3 = Vector3.ZERO
## Metres right of the centre line.
@export var lateral: float = 0.0
## Name of a TrackShortcut sibling to place this on; empty = main road.
@export var on_shortcut: String = ""
## Width across the road (pads, puddles, barrier rows, ramps, water).
@export var width: float = 5.0
## Along the road (ramps and water).
@export var length: float = 14.0
## Water only: tint of the water (deep colour derived from it).
@export var water_tint: Color = WATER_COLOR:
	set(value):
		water_tint = value
		_rebuild_visuals()
## Height of a jump ramp's lip.
@export var ramp_height: float = 1.6
## Boost strength (pads and rings): extra top speed, duration, instant kick.
@export var boost_extra: float = 7.0
@export var boost_duration: float = 1.0
@export var boost_kick: float = 4.0
## Boosters only: put item boxes on this pad or ring. Ramps always carry a
## row of item boxes along the lip.
@export var item_boxes: bool = false
## Breakable barriers rebuild after this long.
@export var rebuild_time: float = 8.0
## Fraction of speed kept when smashing through a breakable barrier.
@export var smash_speed_kept: float = 0.85

## Times anything triggered it (tests / telemetry).
var triggered: int = 0
## Main-road boost pads become a pattern (BoostPattern): this node is the
## first pad; the others are generated copies (pattern_copy).
var pattern_copy: bool = false
## The pattern this pad was given: &"single", &"diagonal" or &"triangle".
var pattern: StringName = &"single"

var _cooldowns: Dictionary = {}
var _broken_time: float = 0.0
var _visual: Node3D
var _light: OmniLight3D
var _time: float = 0.0
var _area: Area3D
var _emp_mat: ShaderMaterial
var _sparks: CPUParticles3D
var _flash: float = 0.0
## Own RNG for the flicker so visuals never shift the global random sequence.
var _fx_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rebuild_visuals()


const PATTERNS: Array[StringName] = [&"single", &"diagonal", &"triangle"]
## Boost-pad patterns: metres between rows along the road, and sideways.
const PATTERN_ROW_GAP := 14.0
const DIAGONAL_STEP := 4.5
const TRIANGLE_HALF := 3.0


## Called by the TrackCircuit once its curve (and shortcuts) are built.
func place_on_track(track: TrackCircuit) -> void:
	if kind == Kind.BOOST_PAD and on_shortcut == "" and not pattern_copy:
		_place_pattern(track)
		return
	_place_at(track, 0.0, lateral)


## Main-road boost pad: a single pad, three in a diagonal, or two side by
## side then one (a triangle). Picked from a seed of the track and this
## node's name, so a track always has the same layout.
func _place_pattern(track: TrackCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s" % [track.scene_file_path, name])
	pattern = PATTERNS[rng.randi_range(0, PATTERNS.size() - 1)]
	var room := maxf(0.0, track.road_width * 0.5 - width * 0.5 - 1.0)
	var spots: Array[Vector2] = [] # (along, lateral offset from centre)
	match pattern:
		&"diagonal":
			var step := minf(DIAGONAL_STEP, room)
			var dir := 1.0 if rng.randf() < 0.5 else -1.0
			for i in 3:
				spots.append(Vector2(i * PATTERN_ROW_GAP, (i - 1) * step * dir))
		&"triangle":
			var half := minf(TRIANGLE_HALF, room)
			spots.append_array([Vector2(0.0, -half), Vector2(0.0, half), Vector2(PATTERN_ROW_GAP, 0.0)])
		_:
			spots.append(Vector2.ZERO)
	# Keep the whole pattern on the road.
	var reach := 0.0
	for spot in spots:
		reach = maxf(reach, absf(spot.y))
	var centre := clampf(lateral, -room + reach, room - reach) if room >= reach else 0.0
	_place_at(track, spots[0].x, centre + spots[0].y)
	var parent := get_parent()
	for i in range(1, spots.size()):
		var copy := TrackFeature.new()
		copy.name = "%s%s_%d" % [TrackCircuit.GENERATED_PREFIX, name, i]
		copy.pattern_copy = true
		copy.pattern = pattern
		copy.kind = kind
		# Its own spot, so placing it again on its own lands in the same place.
		copy.offset = offset + spots[i].x
		copy.lateral = centre + spots[i].y
		copy.anchor_point = anchor_point
		copy.width = width
		copy.length = length
		copy.boost_extra = boost_extra
		copy.boost_duration = boost_duration
		copy.boost_kick = boost_kick
		parent.add_child(copy)
		copy.place_on_track(track)
		# A pad under a road column (Kilwa) is dropped.
		if track.column_near(track.to_local(copy.global_position), width * 0.5) >= 0:
			parent.remove_child(copy)
			copy.queue_free()


func _place_at(track: TrackCircuit, along: float, p_lateral: float) -> void:
	var xf: Transform3D
	var sc := track.get_node_or_null(on_shortcut) as TrackShortcut if on_shortcut != "" else null
	if sc != null and sc.is_valid():
		var tangent := sc.tangent_at(offset)
		var right := tangent.cross(Vector3.UP).normalized()
		xf = Transform3D(Basis.looking_at(tangent, Vector3.UP), sc.point_at(offset) + right * p_lateral)
	else:
		var d := offset + along
		if anchor_point != Vector3.ZERO:
			d += track.curve.get_closest_offset(anchor_point)
		xf = track.global_transform.affine_inverse() * track.get_safe_transform(track.wrap_offset(d), p_lateral, 0.0)
	transform = xf
	_rebuild_visuals()


## Where this feature's item boxes go (global transforms; empty for none).
## Ramps: a row across the top of the ramp, so cars grab them at take-off.
## Boosters with item_boxes: two boxes side by side on the pad / in the ring.
func item_box_transforms() -> Array[Transform3D]:
	var locals: Array[Vector3] = []
	match kind:
		Kind.JUMP_RAMP:
			var count := maxi(2, roundi(width / 4.5))
			var spacing := width / count
			for i in count:
				var x := (float(i) - (count - 1) * 0.5) * spacing
				locals.append(Vector3(x, ramp_height + 1.1, -length * 0.5 + 1.5))
		Kind.BOOST_PAD:
			if item_boxes:
				locals.append_array([Vector3(-1.3, 1.1, 0.0), Vector3(1.3, 1.1, 0.0)])
		Kind.BOOST_RING:
			if item_boxes:
				locals.append_array([Vector3(-1.5, 1.1, 0.0), Vector3(1.5, 1.1, 0.0)])
	var out: Array[Transform3D] = []
	for p in locals:
		out.append(global_transform * Transform3D(Basis(), p))
	return out


func is_broken() -> bool:
	return kind == Kind.BREAKABLE and _broken_time > 0.0


func _rebuild_visuals() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_emp_mat = null
	_sparks = null
	_visual = Node3D.new()
	add_child(_visual)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # vehicles
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		Kind.BOOST_PAD:
			box.size = Vector3(width, 2.0, 6.0)
			_pad_visual()
		Kind.BOOST_RING:
			box.size = Vector3(7.0, 7.0, 2.0)
			shape.position.y = 3.2
			_ring_visual()
		Kind.EMP_PUDDLE:
			box.size = Vector3(width, 2.0, width * 0.8)
			_puddle_visual()
		Kind.BREAKABLE:
			box.size = Vector3(width, 2.5, 1.6)
			shape.position.y = 1.0
			_barrier_visual()
		Kind.JUMP_RAMP:
			# The area only counts launches; the ramp itself is solid.
			box.size = Vector3(width, 3.0, 3.0)
			shape.position = Vector3(0, ramp_height + 1.0, -length * 0.5)
			_ramp_body()
		Kind.WATER:
			box.size = Vector3(width, 2.0, length)
			shape.position.y = 0.8
			_water_visual()
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	_area = area
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


func _mat(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation.z = rot_z
	mi.material_override = mat
	_visual.add_child(mi)
	return mi


func _pad_visual() -> void:
	_box(Vector3(width, 0.04, 6.0), Vector3(0, 0.05, 0), _mat(Color(0.05, 0.05, 0.1), 0.0))
	var glow := _mat(PAD_COLOR, 4.0)
	# Three chevrons pointing forward (-Z).
	for i in 3:
		for arm in [-1.0, 1.0]:
			var bar := _box(Vector3(width * 0.42, 0.06, 0.35), Vector3(arm * width * 0.19, 0.08, -1.6 + i * 1.5), glow)
			bar.rotation.y = -arm * 0.55 # arms trail back: the point faces the driving direction
	_light = _add_light(PAD_COLOR, 2.5, 7.0, Vector3(0, 1.0, 0))


func _ring_visual() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.3
	torus.outer_radius = 3.8
	torus.rings = 32
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position.y = 3.6
	ring.material_override = _mat(RING_COLOR, 4.5)
	_visual.add_child(ring)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.4, 0.6, 0.4), Vector3(side * 3.6, 0.3, 0), _mat(Color(0.1, 0.1, 0.14), 0.0))
	_light = _add_light(RING_COLOR, 3.0, 12.0, Vector3(0, 3.6, 0))


func _puddle_visual() -> void:
	var r := width * 0.5
	_emp_mat = ShaderMaterial.new()
	_emp_mat.shader = EMP_SHADER
	_emp_mat.set_shader_parameter("radius", r)
	_emp_mat.set_shader_parameter("flicker", 0.0 if GameSettings.reduced_flashing else 1.0)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.03
	cyl.radial_segments = 32
	disc.mesh = cyl
	disc.scale = Vector3(1, 1, 0.8)
	disc.position.y = 0.05
	disc.material_override = _emp_mat
	_visual.add_child(disc)
	# Raised yellow/black lip around the edge.
	var lip_mat := ShaderMaterial.new()
	lip_mat.shader = EMP_SHADER
	lip_mat.set_shader_parameter("mode", 1)
	var lip := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.12
	torus.outer_radius = r + 0.18
	torus.rings = 48
	torus.ring_segments = 8
	lip.mesh = torus
	lip.scale = Vector3(1, 0.35, 0.8)
	lip.position.y = 0.06
	lip.material_override = lip_mat
	_visual.add_child(lip)
	# Warning signs either side, facing oncoming cars (+Z is behind).
	var post_mat := _mat(Color(0.08, 0.08, 0.09), 0.0)
	var sign_mat := ShaderMaterial.new()
	sign_mat.shader = SIGN_SHADER
	for side in [-1.0, 1.0]:
		var x: float = side * (r + 0.6)
		_box(Vector3(0.12, 1.4, 0.12), Vector3(x, 0.7, 0), post_mat)
		var sign_quad := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.0)
		sign_quad.mesh = quad
		sign_quad.position = Vector3(x, 1.75, 0.08)
		sign_quad.material_override = sign_mat
		_visual.add_child(sign_quad)
	_sparks = _make_sparks(r)
	_light = _add_light(EMP_COLOR, 3.0, 8.0, Vector3(0, 0.8, 0))


## Short bright sparks popping off the puddle (off with reduced flashing).
func _make_sparks(r: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.35
	p.explosiveness = 0.6
	p.randomness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(r * 0.7, 0.02, r * 0.55)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	var m := _mat(Color(0.95, 0.85, 1.0), 6.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	p.position.y = 0.08
	p.emitting = not GameSettings.reduced_flashing
	_visual.add_child(p)
	return p


func _barrier_visual() -> void:
	var yellow := _mat(BARRIER_COLOR, 0.6)
	var black := _mat(Color(0.05, 0.05, 0.06), 0.0)
	var blocks := int(width / 1.6)
	for i in blocks:
		var x := (float(i) - (blocks - 1) * 0.5) * 1.6
		_box(Vector3(1.4, 1.0, 0.6), Vector3(x, 0.5, 0), yellow if i % 2 == 0 else black)
		_box(Vector3(1.42, 0.12, 0.62), Vector3(x, 0.85, 0), black if i % 2 == 0 else yellow)
	_light = _add_light(BARRIER_COLOR, 1.5, 6.0, Vector3(0, 1.5, 0))


## Solid wedge: low at the back (+Z), lip of ramp_height at the front (-Z).
func _ramp_body() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 # environment: the wheel rays drive up it
	body.collision_mask = 0
	var hw := width * 0.5
	var hl := length * 0.5
	var pts := PackedVector3Array([
		Vector3(-hw, 0, hl), Vector3(hw, 0, hl), Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl),
		Vector3(-hw, ramp_height, -hl), Vector3(hw, ramp_height, -hl),
	])
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	_visual.add_child(body)
	# Visual: sloped deck, side skirts, glowing chevrons and lip lights.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0, 1, 5], [0, 5, 4], [2, 4, 5], [2, 5, 3], [0, 4, 2], [1, 3, 5]]:
		var n := (pts[tri[1]] - pts[tri[0]]).cross(pts[tri[2]] - pts[tri[0]]).normalized()
		for i in tri:
			st.set_normal(n)
			st.add_vertex(pts[i])
	var deck := MeshInstance3D.new()
	deck.mesh = st.commit()
	var deck_mat := _mat(Color(0.12, 0.1, 0.14), 0.0)
	deck_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	deck.material_override = deck_mat
	_visual.add_child(deck)
	var glow := _mat(RAMP_COLOR, 4.0)
	var slope := atan2(ramp_height, length)
	for i in 3:
		var z := lerpf(hl * 0.6, -hl * 0.6, i / 2.0)
		var y := lerpf(0.0, ramp_height, (hl - z) / length) + 0.06
		for arm in [-1.0, 1.0]:
			var bar := _box(Vector3(width * 0.36, 0.05, 0.4), Vector3(arm * width * 0.16, y, z), glow)
			bar.rotation = Vector3(slope, -arm * 0.55, 0)
	_box(Vector3(width, 0.12, 0.2), Vector3(0, ramp_height, -hl + 0.1), glow)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.15, 0.15, length), Vector3(side * hw, ramp_height * 0.5 + 0.05, 0), glow).rotation.x = slope
	_light = _add_light(RAMP_COLOR, 2.5, 10.0, Vector3(0, ramp_height + 1.0, -hl))


func _water_visual() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	water.mesh = plane
	water.position.y = 0.06
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter("deep_color", water_tint.darkened(0.82))
	m.set_shader_parameter("shallow_color", water_tint.darkened(0.4))
	m.set_shader_parameter("opacity", 0.62)
	m.set_shader_parameter("rain_rings", 0.25)
	m.set_shader_parameter("murk", 0.4)
	m.set_shader_parameter("emission_strength", 0.06)
	# Feather about a metre in from the edges.
	m.set_shader_parameter("edge_fade", 1.0)
	m.set_shader_parameter("plane_size", Vector2(width, length))
	water.material_override = m
	_visual.add_child(water)
	_light = _add_light(water_tint.lightened(0.4), 1.2, maxf(width, length) * 0.6, Vector3(0, 1.0, 0))


func _add_light(color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = pos
	_visual.add_child(light)
	return light


func _on_body_entered(body: Node3D) -> void:
	var car := body as VehicleController
	if car == null or _cooldowns.get(car, 0.0) > 0.0:
		return
	match kind:
		Kind.BOOST_PAD:
			car.start_external_boost(boost_extra, boost_duration, boost_kick, "Boost pad", PAD_COLOR)
		Kind.BOOST_RING:
			car.start_external_boost(boost_extra, boost_duration, boost_kick, "Boost ring", RING_COLOR)
		Kind.EMP_PUDDLE:
			if car.status == null or not car.status.apply_attack(&"emp", 1.0):
				return
		Kind.BREAKABLE:
			if is_broken():
				return
			car.scrub_speed(smash_speed_kept)
			_smash()
		Kind.JUMP_RAMP:
			# Opens the trick window (E / gamepad X in the air).
			if car.trick != null:
				car.trick.on_ramp()
		Kind.WATER:
			pass # handled every frame in _physics_process
	_cooldowns[car] = 1.5
	triggered += 1


func _smash() -> void:
	_broken_time = rebuild_time
	CombatSfx.play_on(self, CombatSfx.BARRIER_SMASH, "Smash")
	for child in _visual.get_children():
		if child is MeshInstance3D:
			var block := child as MeshInstance3D
			var tween := create_tween()
			var fly := Vector3(randf_range(-2.0, 2.0), randf_range(1.5, 3.0), randf_range(-4.0, -1.0))
			tween.tween_property(block, "position", block.position + fly, 0.35)
			tween.parallel().tween_property(block, "scale", Vector3.ONE * 0.2, 0.35)
			tween.tween_callback(func() -> void: block.visible = false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for car in _cooldowns.keys():
		_cooldowns[car] -= delta
		if _cooldowns[car] <= 0.0:
			_cooldowns.erase(car)
	if _broken_time > 0.0:
		_broken_time -= delta
		if _broken_time <= 0.0:
			_rebuild_visuals()
	if kind == Kind.WATER and _area != null and _area.monitoring:
		for body in _area.get_overlapping_bodies():
			var car := body as VehicleController
			if car != null and car.status != null:
				car.status.apply_surface(&"wet", WET_LINGER)


func _process(delta: float) -> void:
	if _light == null or Engine.is_editor_hint():
		return
	_time += delta
	if kind != Kind.EMP_PUDDLE:
		return
	var calm := GameSettings.reduced_flashing
	if _emp_mat != null:
		_emp_mat.set_shader_parameter("flicker", 0.0 if calm else 1.0)
	if _sparks != null and _sparks.emitting == calm:
		_sparks.emitting = not calm
	if calm:
		_light.light_energy = 2.5
		return
	# Irregular stutter: random spikes that die off quickly, not a smooth pulse.
	_flash = maxf(_flash - delta * 9.0, 0.0)
	if _fx_rng.randf() < delta * 7.0:
		_flash = _fx_rng.randf_range(0.6, 1.0)
	_light.light_energy = 1.2 + 4.0 * _flash
