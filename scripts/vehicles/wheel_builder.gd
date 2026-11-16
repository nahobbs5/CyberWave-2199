class_name WheelBuilder
extends RefCounted
## Detailed wheels for the model cars: a lathed tyre with rounded sidewalls
## and a five-spoke rim with a brake disc behind it. Replaces the shared car
## scene's plain cylinder on Wheel*/Pivot/Mesh (purely visual).
##
## Meshes are built along local Y like the scene's CylinderMesh (the Mesh node
## is turned 90 degrees about Z, so Y is the axle). Both faces get a rim
## because the left and right wheels share one mesh.
##
##   Pivot/Mesh        tyre (rubber), nudged outward so it fills the arch
##   Pivot/Mesh/Rim    rim: surface 0 = rim metal (the Rims cosmetic recolours
##                     it), surface 1 = brake disc + dark barrel

const RADIUS := 0.38
const HALF_WIDTH := 0.16
const SEGMENTS := 24
const RIM_SURFACE := 0
const RIM_COLOR := Color(0.24, 0.25, 0.27)

static var _tyre: ArrayMesh
static var _rim: ArrayMesh


## Gives every wheel the detailed tyre and a rim. offsets: outward shift per
## axle in metres, {"front": f, "rear": r} (keeps the tyre face out past the
## body's flank).
static func dress(car: Node3D, offsets: Dictionary = {}) -> void:
	for ray in car.get_children():
		if not ray.name.begins_with("Wheel") or not ray is Node3D:
			continue
		var mesh := ray.get_node_or_null("Pivot/Mesh") as MeshInstance3D
		if mesh == null:
			continue
		if not mesh.has_meta("stock_mesh"):
			mesh.set_meta("stock_mesh", mesh.mesh)
		mesh.mesh = tyre_mesh()
		var front := (ray as Node3D).position.z < 0.0
		var side := signf((ray as Node3D).position.x)
		var off: float = offsets.get("front" if front else "rear", 0.0)
		var base := Vector3(side * off, 0.0, 0.0)
		mesh.set_meta("base_position", base)
		mesh.position = base * mesh.scale.x
		var rim := mesh.get_node_or_null("Rim") as MeshInstance3D
		if rim == null or not rim.has_meta("wheel_rim"):
			if rim != null:
				rim.free()
			rim = MeshInstance3D.new()
			rim.name = "Rim"
			rim.set_meta("wheel_rim", true)
			mesh.add_child(rim)
		rim.mesh = rim_mesh()
		rim.material_override = null
		rim.set_surface_override_material(RIM_SURFACE, null)


## Puts the scene's own cylinder back (box-car fallback).
static func undress(car: Node3D) -> void:
	for ray in car.get_children():
		if not ray.name.begins_with("Wheel"):
			continue
		var mesh := ray.get_node_or_null("Pivot/Mesh") as MeshInstance3D
		if mesh == null or not mesh.has_meta("stock_mesh"):
			continue
		mesh.mesh = mesh.get_meta("stock_mesh")
		mesh.remove_meta("stock_mesh")
		mesh.remove_meta("base_position")
		mesh.position = Vector3.ZERO
		var rim := mesh.get_node_or_null("Rim")
		if rim != null and rim.has_meta("wheel_rim"):
			rim.free()


static func is_dressed(mesh: Node3D) -> bool:
	return mesh != null and mesh.has_meta("stock_mesh")


## Recolours a dressed wheel's rim (null = the stock gunmetal).
static func set_rim_material(mesh: Node3D, mat: Material) -> void:
	var rim := mesh.get_node_or_null("Rim") as MeshInstance3D
	if rim != null:
		rim.set_surface_override_material(RIM_SURFACE, mat)


# --- meshes -----------------------------------------------------------------------

static func tyre_mesh() -> ArrayMesh:
	if _tyre != null:
		return _tyre
	# Profile (radius, y) from the outer bead over the tread to the inner bead.
	var prof: Array[Vector2] = [
		Vector2(0.262, 0.150), Vector2(0.300, 0.160), Vector2(0.340, 0.158),
		Vector2(0.366, 0.146), Vector2(0.378, 0.124), Vector2(0.380, 0.07),
		Vector2(0.380, 0.0),
		Vector2(0.380, -0.07), Vector2(0.378, -0.124), Vector2(0.366, -0.146),
		Vector2(0.340, -0.158), Vector2(0.300, -0.160), Vector2(0.262, -0.150),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(st, prof, Vector2(0.32, 0.0))
	_tyre = st.commit()
	_tyre.surface_set_material(0, _mat(Color(0.055, 0.055, 0.065), 0.0, 0.92))
	return _tyre


static func rim_mesh() -> ArrayMesh:
	if _rim != null:
		return _rim
	var metal := SurfaceTool.new()
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [1.0, -1.0]:
		# Lip and dish: from the bead in to the spoke ends.
		var lip: Array[Vector2] = [
			Vector2(0.266, 0.148 * s), Vector2(0.258, 0.156 * s), Vector2(0.236, 0.152 * s),
			Vector2(0.214, 0.132 * s),
		]
		_lathe(metal, lip, Vector2(0.24, 0.10 * s), false)
		# Five spokes, each a tapered bar.
		for k in 5:
			var a := TAU * k / 5.0
			_spoke(metal, a, s)
		# Hub cap.
		var hub: Array[Vector2] = [
			Vector2(0.075, 0.130 * s), Vector2(0.06, 0.150 * s), Vector2(0.0, 0.155 * s),
		]
		_lathe(metal, hub, Vector2(0.0, 0.10 * s), false)
		# Brake disc (face + edge), set back behind the spokes.
		var disc: Array[Vector2] = [
			Vector2(0.20, 0.06 * s), Vector2(0.20, 0.085 * s), Vector2(0.0, 0.085 * s),
		]
		_lathe(dark, disc, Vector2(0.1, 0.0), false)
	# Dark barrel so the gaps between spokes read as depth, not sky.
	var barrel: Array[Vector2] = [Vector2(0.258, 0.15), Vector2(0.258, -0.15)]
	_lathe(dark, barrel, Vector2(0.4, 0.0), false)
	_rim = metal.commit()
	_rim.surface_set_material(0, _mat(RIM_COLOR, 0.8, 0.3))
	dark.commit(_rim)
	_rim.surface_set_material(1, _mat(Color(0.12, 0.12, 0.13), 0.5, 0.55))
	return _rim


## Revolves a (radius, y) profile round Y with smooth normals pointing away
## from `inside` (a point in the same profile plane).
static func _lathe(st: SurfaceTool, prof: Array[Vector2], inside: Vector2, smooth := true) -> void:
	var n := prof.size()
	var pn: Array[Vector2] = []
	for j in n:
		var t := prof[mini(j + 1, n - 1)] - prof[maxi(j - 1, 0)]
		var nn := Vector2(t.y, -t.x).normalized()
		if nn.dot(prof[j] - inside) < 0.0:
			nn = -nn
		pn.append(nn)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		for j in n - 1:
			var p := [_rev(prof[j], a0), _rev(prof[j + 1], a0), _rev(prof[j + 1], a1), _rev(prof[j], a1)]
			var face_in := _rev(inside, (a0 + a1) * 0.5)
			if smooth:
				var ns := [_rev_n(pn[j], a0), _rev_n(pn[j + 1], a0), _rev_n(pn[j + 1], a1), _rev_n(pn[j], a1)]
				_tri_n(st, p[0], p[1], p[2], ns[0], ns[1], ns[2], face_in)
				_tri_n(st, p[0], p[2], p[3], ns[0], ns[2], ns[3], face_in)
			else:
				CarModelBuilder._quad(st, p[0], p[1], p[2], p[3], face_in)


static func _spoke(st: SurfaceTool, angle: float, s: float) -> void:
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var r0 := 0.07
	var r1 := 0.222
	var w0 := 0.036
	var w1 := 0.022
	var y_front := 0.142 * s
	var y_back := 0.112 * s
	var c := dir * ((r0 + r1) * 0.5) + Vector3(0.0, (y_front + y_back) * 0.5, 0.0)
	var p := []
	for y in [y_back, y_front]:
		p.append(dir * r0 - side * w0 + Vector3(0, y, 0))
		p.append(dir * r0 + side * w0 + Vector3(0, y, 0))
		p.append(dir * r1 + side * w1 + Vector3(0, y - 0.012 * s, 0))
		p.append(dir * r1 - side * w1 + Vector3(0, y - 0.012 * s, 0))
	# p[0..3] back face, p[4..7] front face.
	CarModelBuilder._quad(st, p[4], p[5], p[6], p[7], c)
	CarModelBuilder._quad(st, p[0], p[1], p[5], p[4], c)
	CarModelBuilder._quad(st, p[1], p[2], p[6], p[5], c)
	CarModelBuilder._quad(st, p[2], p[3], p[7], p[6], c)
	CarModelBuilder._quad(st, p[3], p[0], p[4], p[7], c)


static func _rev(p: Vector2, a: float) -> Vector3:
	return Vector3(cos(a) * p.x, p.y, sin(a) * p.x)


static func _rev_n(n: Vector2, a: float) -> Vector3:
	return Vector3(cos(a) * n.x, n.y, sin(a) * n.x).normalized()


## Triangle with per-vertex normals, wound so its face points away from `inside`.
static func _tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, inside: Vector3) -> void:
	CarModelBuilder._tri_n(st, a, b, c, na, nb, nc, inside)


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
