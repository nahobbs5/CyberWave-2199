@tool
class_name GlbProp
extends RefCounted
## Loads a Blender .glb (from res://models/) as one mesh: every
## MeshInstance3D in it is baked into a single ArrayMesh with one surface per
## material, so a prop of thousands of objects (leaves, debris, ribs) costs a
## draw call per material. Visual only, no collision. Merged meshes are
## cached by path, so rebuilding a track or racing it again reuses them.

static var _cache: Dictionary = {}


## The merged mesh for a .glb. Nodes whose names start with anything in
## `skip` are left out, with their children. `tint` multiplies every
## material's albedo (dark scenes can dim a model without a re-export).
## `overrides` maps a Blender material name to a Material used instead (not
## tinted). Blender's procedural node materials export to glTF as plain
## white, so a track can stand its own textured materials in for them.
## The first call for a path, skip, tint and override names is cached and
## keeps its materials.
static func merged(path: String, skip: PackedStringArray = PackedStringArray(),
		tint: Color = Color.WHITE, overrides: Dictionary = {}) -> ArrayMesh:
	var names: Array = overrides.keys()
	names.sort()
	var key := "%s|%s|%s|%s" % [path, ",".join(skip), tint.to_html(), ",".join(names)]
	if _cache.has(key):
		return _cache[key]
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("GlbProp: can't load %s" % path)
		return null
	var scene := packed.instantiate() as Node3D
	# One SurfaceTool per material; materials compared by resource.
	var tools: Dictionary = {}
	var order: Array[Material] = []
	_collect(scene, Transform3D.IDENTITY, skip, tools, order, true)
	scene.free()
	var mesh := ArrayMesh.new()
	for mat in order:
		var st := tools[mat] as SurfaceTool
		st.commit(mesh)
		var used := mat
		if overrides.has(mat.resource_name):
			used = overrides[mat.resource_name]
		elif tint != Color.WHITE and mat is BaseMaterial3D:
			used = mat.duplicate()
			(used as BaseMaterial3D).albedo_color *= tint
		mesh.surface_set_material(mesh.get_surface_count() - 1, used)
	_cache[key] = mesh
	return mesh


## Total triangles in a mesh (tests and budgets).
static func triangle_count(mesh: Mesh) -> int:
	var tris := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			tris += (idx as PackedInt32Array).size() / 3
		else:
			tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


static func clear_cache() -> void:
	_cache.clear()


static func _collect(node: Node, parent_xf: Transform3D, skip: PackedStringArray,
		tools: Dictionary, order: Array[Material], is_root: bool) -> void:
	if not is_root:
		for prefix in skip:
			if String(node.name).begins_with(prefix):
				return
	var xf := parent_xf
	if node is Node3D and not is_root:
		xf = parent_xf * (node as Node3D).transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null and mi.visible:
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = StandardMaterial3D.new()
			if not tools.has(mat):
				var st := SurfaceTool.new()
				tools[mat] = st
				order.append(mat)
			(tools[mat] as SurfaceTool).append_from(mi.mesh, s, xf)
	for child in node.get_children():
		_collect(child, xf, skip, tools, order, false)
