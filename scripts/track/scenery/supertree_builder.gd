class_name SupertreeBuilder
extends RefCounted
## Gardens by the Bay Supertrees for a TrackScenery: a tapered trunk wrapped
## in planting with steel ribs climbing it, then a funnel canopy of radial
## branching steel that opens out at the top, with a glowing inner cone and a
## rim ring. The steel uses the light-show shader (supertree.gdshader), so
## the whole grove changes colour at night. Everything goes into the
## scenery's batches (a few draw calls for the whole grove). Visual only.
##
## Material keys (registered by ensure_materials): "st_planting" (trunk
## greenery), "st_steel" (ribs and canopy frame, light show), "st_inner"
## (the inner funnel, softer light show), "st_rim" (the top ring).

const SHADER := preload("res://assets/shaders/supertree.gdshader")
## Share of the height where the canopy starts to open out.
const CANOPY_START := 0.72
const BRANCHES := 18

var scenery: TrackScenery
## Base positions and sizes of every tree placed ([Vector3, height, radius]).
var placed: Array = []


func _init(p_scenery: TrackScenery) -> void:
	scenery = p_scenery
	ensure_materials()


func ensure_materials() -> void:
	if scenery.get_material("st_steel") != null:
		return
	scenery.textured("st_planting", "forest_leaves_02", Color(0.32, 0.5, 0.3), 3.0)
	var steel := ShaderMaterial.new()
	steel.shader = SHADER
	steel.set_shader_parameter("height_ramp", 0.6)
	scenery.register_material("st_steel", steel)
	var inner := ShaderMaterial.new()
	inner.shader = SHADER
	inner.set_shader_parameter("energy", 1.3)
	inner.set_shader_parameter("base_color", Color(0.12, 0.1, 0.14))
	scenery.register_material("st_inner", inner)
	scenery.material("st_rim", Color(0.95, 0.9, 1.0), 1.8)


## Lowest and highest points of a tree's canopy (track-local y) for a tree
## standing at base_y with this height.
static func canopy_span(base_y: float, height: float) -> Vector2:
	return Vector2(base_y + height * CANOPY_START, base_y + height)


## One Supertree standing at `base` (track-local, on the ground).
func add(base: Vector3, height: float, radius: float) -> void:
	placed.append([base, height, radius])
	var rng := scenery.rng
	var trunk_top := height * CANOPY_START
	var r_base := clampf(height * 0.075, 2.0, 4.0)
	var r_top := r_base * 0.55
	var xf := Transform3D(Basis.IDENTITY, base)
	# Trunk: a column of planting with a flared foot.
	scenery.add_cyl("st_planting", r_base * 1.25, height * 0.08, xf, 12, r_base)
	scenery.add_cyl("st_planting", r_base, trunk_top - height * 0.08, xf.translated(Vector3(0, height * 0.08, 0)), 12, r_top)
	# Steel ribs climbing the trunk in a gentle twist, just proud of it.
	var ribs := 10
	var twist := rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
	for i in ribs:
		var a0 := TAU * i / ribs
		var prev := Vector3.ZERO
		for k in 7:
			var t := k / 6.0
			var y := t * trunk_top
			var r := lerpf(r_base * 1.08, r_top * 1.1, t) + 0.15
			var a := a0 + twist * t
			var p := base + Vector3(cos(a) * r, y, sin(a) * r)
			if k > 0:
				_beam("st_steel", prev, p, 0.28)
			prev = p
	# Canopy: radial branches that fork twice on the way out and up.
	var canopy_base := base + Vector3(0, trunk_top, 0)
	for i in BRANCHES:
		var a := TAU * i / BRANCHES + rng.randf_range(-0.05, 0.05)
		var dir := Vector3(cos(a), 0, sin(a))
		var p0 := canopy_base + dir * r_top
		var p1 := base + dir * radius * 0.45 + Vector3(0, height * 0.84, 0)
		var p2 := base + dir * radius * 0.8 + Vector3(0, height * 0.95, 0)
		_beam("st_steel", p0, p1, 0.32)
		_beam("st_steel", p1, p2, 0.24)
		for side in [-1.0, 1.0]:
			var fork := Basis(Vector3.UP, side * rng.randf_range(0.14, 0.22)) * dir
			var tip := base + fork * radius * rng.randf_range(0.97, 1.08) + Vector3(0, height * rng.randf_range(0.98, 1.03), 0)
			_beam("st_steel", p2, tip, 0.16)
			# Little twigs at the ends, like the real frames.
			var twig := tip + (Basis(Vector3.UP, side * 0.5) * fork) * radius * 0.12 + Vector3(0, height * 0.02, 0)
			_beam("st_steel", tip, twig, 0.1)
	# Rings tying the branches together.
	_ring("st_steel", base + Vector3(0, height * 0.84, 0), radius * 0.45, 0.22, 18)
	_ring("st_rim", base + Vector3(0, height * 0.95, 0), radius * 0.8, 0.26, 24)
	# The inner funnel (the planters / solar canopy) glowing from within.
	scenery.add_cyl("st_inner", r_top * 1.05, height * 0.2, Transform3D(Basis.IDENTITY, canopy_base), 14, radius * 0.42)
	scenery.add_cyl("st_inner", radius * 0.42, height * 0.025, Transform3D(Basis.IDENTITY, canopy_base + Vector3(0, height * 0.2, 0)), 14, radius * 0.38)


## A square beam from a to b.
func _beam(key: String, a: Vector3, b: Vector3, thickness: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	scenery.add_box(key, Vector3(thickness, thickness, l), Transform3D(Basis.looking_at(d / l, up), (a + b) * 0.5))


func _ring(key: String, centre: Vector3, radius: float, thickness: float, segments: int) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		_beam(key, centre + Vector3(cos(a0), 0, sin(a0)) * radius, centre + Vector3(cos(a1), 0, sin(a1)) * radius, thickness)
