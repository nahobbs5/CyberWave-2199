class_name SlipstreamRing
extends Node3D
## Neon arches standing around the car while it drafts (see Slipstream):
## a bright inner ring and a fainter outer one, rippling backward like
## rushing air and brightening as the slipstream meter fills. When the
## boost fires they shoot back, widen and fade. Reduced flashing: no ripple
## or burst, just a steady glow. Lives under the car's Feedback node, so it
## follows the car's visual scale.

const SHADER := preload("res://assets/shaders/slipstream_ring.gdshader")
const COLOR := Color(0.2, 0.9, 1.0)
## Inner and outer ring: radius (m), band width (m), z offset (m, + = back), brightness.
const RINGS := [
	[1.75, 0.4, 0.4, 1.0],
	[2.15, 0.48, 1.1, 0.55],
]
## Ring centre height relative to the car origin (m): about road level,
## so the arches rise from the road beside the car.
const CENTRE_Y := -0.45
## Ripple: how far back each ring slides (m) and grows per loop, and loops/s.
const RIPPLE_DIST := 0.8
const RIPPLE_GROW := 0.12
const RIPPLE_RATE := 1.2
## Burst on the boost: duration (s), how far back (m) and how much wider.
const BURST_TIME := 0.45
const BURST_DIST := 3.0
const BURST_GROW := 0.6
const SEGMENTS := 40

var vehicle: VehicleController
## Current brightness 0..1 (eased toward the meter; tests).
var strength: float = 0.0
## 1 right after a slipstream boost, falling to 0 (tests).
var burst: float = 0.0

var _meshes: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _time: float = 0.0


func _init() -> void:
	name = "SlipstreamRing"
	for spec in RINGS:
		var mesh := MeshInstance3D.new()
		mesh.mesh = arch_mesh(spec[0], spec[1])
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("color", COLOR)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visible = false
		add_child(mesh)
		_meshes.append(mesh)
		_materials.append(material)


## Follows `car`: lights up with its slipstream and bursts on its boost.
func attach(car: VehicleController) -> void:
	vehicle = car
	car.slipstream_boost.connect(_on_boost)


## Whether any ring is on screen.
func is_shown() -> bool:
	return _meshes[0].visible


func _on_boost() -> void:
	if not GameSettings.reduced_flashing:
		burst = 1.0


func _process(delta: float) -> void:
	_time += delta
	var want := 0.0
	if is_instance_valid(vehicle) and vehicle.in_slipstream:
		want = 0.35 + 0.65 * vehicle.slipstream_charge
	strength = move_toward(strength, want, delta * 3.0)
	burst = move_toward(burst, 0.0, delta / BURST_TIME)
	var calm := GameSettings.reduced_flashing
	var shown := strength > 0.01 or burst > 0.0
	for i in _meshes.size():
		var mesh := _meshes[i]
		mesh.visible = shown
		if not shown:
			continue
		var spec: Array = RINGS[i]
		var z: float = spec[2]
		var grow := 1.0
		var bright: float = spec[3]
		if burst > 0.0:
			# Shoot back and widen, fading as it goes.
			var t := 1.0 - burst
			z += BURST_DIST * t
			grow += BURST_GROW * t
			bright *= maxf(strength, burst)
		elif not calm:
			# Ripple backward, half a loop apart, fading in and out.
			var phase := fposmod(_time * RIPPLE_RATE + 0.5 * i, 1.0)
			z += RIPPLE_DIST * phase
			grow += RIPPLE_GROW * phase
			bright *= strength * (0.6 + 0.4 * sin(phase * PI))
		else:
			bright *= strength
		mesh.position = Vector3(0.0, CENTRE_Y, z)
		mesh.scale = Vector3(grow, grow, 1.0)
		var material := _materials[i]
		material.set_shader_parameter("strength", clampf(bright, 0.0, 1.0))
		material.set_shader_parameter("flash", burst)
		material.set_shader_parameter("flow_speed", 0.0 if calm else 1.6)


## A flat half-circle band in the XY plane (an arch over the car), centred
## on the origin. UV.x runs along the arc, UV.y across the band.
static func arch_mesh(radius: float, width: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for s in SEGMENTS + 1:
		var u := float(s) / SEGMENTS
		var angle := PI * u
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		verts.append(dir * (radius - width * 0.5))
		verts.append(dir * (radius + width * 0.5))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		if s < SEGMENTS:
			var a := s * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
