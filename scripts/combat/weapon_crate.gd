class_name WeaponCrate
extends Area3D
## Question-mark crate (GDD 6.1, 8.7). Gives a random weapon to a racer with a
## free slot; a full inventory leaves the crate in place. Respawns after a delay.
##
## Look (ref 'reference files/Four Neon Item Crates in Tunnel.png'): a beveled
## graphite shell with reinforced metal corners, a segmented magenta frame on the
## front, back and top, diagonal magenta stripes on the sides, a big white "?" on
## the front and back, and a magenta glow pool on the road below. It bobs and
## sways side to side (local +Z faces oncoming cars). On pickup the frame snaps
## outward in a flash; before a respawn the frame lights up first, then the crate
## and its "?" appear.

const SIZE := 1.2
const MAGENTA := Color(1.0, 0.15, 0.75)
const FRAME_ENERGY := 2.5
## Pickup flash: frame scales out and fades.
const FLASH_TIME := 0.25
const FLASH_SCALE := 1.8
const FLASH_ENERGY := 8.0
## Reduced flashing (GDD 11.9): smaller, dimmer, slower.
const FLASH_TIME_REDUCED := 0.4
const FLASH_SCALE_REDUCED := 1.3
const FLASH_ENERGY_REDUCED := 4.0
## The frame lights up this long before the crate comes back.
const PRELIGHT_TIME := 0.4
const SETTLE_TIME := 0.2
const SWAY := 0.35 # radians either side
const BOB := 0.15
## Glow pool: placed on whatever is below within this distance, else hidden.
const GLOW_RAY := 1.8

var manager: WeaponManager
var respawn_time: float = 3.0

var _cooldown: float = 0.0
var _visual: Node3D
var _body: Node3D
var _frame: MeshInstance3D
var _frame_mat: StandardMaterial3D
var _glow: MeshInstance3D
var _glow_placed := false
var _time: float = 0.0
var _phase: float = 0.0
var _flash_t: float = 0.0
var _settle_t: float = 0.0

static var _shell_mesh: Mesh
static var _corner_mesh: Mesh
static var _frame_mesh: Mesh
static var _stripe_mesh: Mesh
static var _glow_mesh: Mesh
static var _shell_mat: StandardMaterial3D
static var _corner_mat: StandardMaterial3D
static var _stripe_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # vehicles
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.4, 2.2)
	shape.shape = box
	add_child(shape)
	_build_shared()
	_phase = fposmod(global_position.x * 0.37 + global_position.z * 0.61, TAU)
	_time = _phase

	_visual = Node3D.new()
	add_child(_visual)
	_body = Node3D.new()
	_visual.add_child(_body)
	_body.add_child(_mesh_instance(_shell_mesh, _shell_mat))
	_body.add_child(_mesh_instance(_corner_mesh, _corner_mat))
	_body.add_child(_mesh_instance(_stripe_mesh, _stripe_mat))
	for back: bool in [false, true]:
		var mark := Label3D.new()
		mark.text = "?"
		mark.font_size = 128
		mark.pixel_size = 0.0085
		mark.outline_size = 24
		mark.modulate = Color(1, 1, 1)
		mark.outline_modulate = Color(0.05, 0.0, 0.08)
		mark.double_sided = false
		mark.shaded = false
		mark.position = Vector3(0, 0.02, SIZE * 0.5 + 0.012) * (-1.0 if back else 1.0)
		if back:
			mark.rotation.y = PI
		_body.add_child(mark)

	_frame_mat = _stripe_mat.duplicate()
	_frame = _mesh_instance(_frame_mesh, _frame_mat)
	_visual.add_child(_frame)

	_glow = _mesh_instance(_glow_mesh, _glow_mat)
	_glow.visible = false
	add_child(_glow)
	body_entered.connect(_on_body_entered)


func is_available() -> bool:
	return _cooldown <= 0.0


func _on_body_entered(body: Node3D) -> void:
	var vehicle := body as VehicleController
	if vehicle == null or not is_available():
		return
	if manager.try_give_weapon(vehicle):
		_cooldown = respawn_time
		_body.visible = false
		_glow.visible = false
		_settle_t = 0.0
		_flash_t = _flash_time()


func _physics_process(delta: float) -> void:
	if not _glow_placed:
		_place_glow()
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_body.visible = true
			_glow.visible = _glow_placed and _glow.position.y < 0.0
			_settle_t = SETTLE_TIME


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y = SWAY * sin(_time * 1.6)
	_visual.position.y = BOB * sin(_time * 2.2)
	_update_frame(delta)


## Frame state: pickup flash -> hidden -> prelight -> settle -> steady.
func _update_frame(delta: float) -> void:
	var reduced := GameSettings.reduced_flashing
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
		var p := 1.0 - _flash_t / _flash_time()
		var grow := 1.0 - (1.0 - p) * (1.0 - p) # ease out
		_frame.visible = _flash_t > 0.0
		_frame.scale = Vector3.ONE * lerpf(1.0, FLASH_SCALE_REDUCED if reduced else FLASH_SCALE, grow)
		_set_frame((FLASH_ENERGY_REDUCED if reduced else FLASH_ENERGY) * (1.0 - p), 1.0 - p)
	elif _cooldown > 0.0:
		_frame.scale = Vector3.ONE
		if _cooldown <= PRELIGHT_TIME:
			var q := 1.0 - _cooldown / PRELIGHT_TIME
			_frame.visible = true
			_set_frame((FLASH_ENERGY_REDUCED if reduced else FLASH_ENERGY) * q, q)
		else:
			_frame.visible = false
	elif _settle_t > 0.0:
		_settle_t = maxf(_settle_t - delta, 0.0)
		var s := _settle_t / SETTLE_TIME
		_frame.visible = true
		_frame.scale = Vector3.ONE
		_set_frame(lerpf(FRAME_ENERGY, FLASH_ENERGY_REDUCED if reduced else FLASH_ENERGY, s), 1.0)
	elif not _frame.visible or _frame.scale != Vector3.ONE:
		_frame.visible = true
		_frame.scale = Vector3.ONE
		_set_frame(FRAME_ENERGY, 1.0)


func _set_frame(energy: float, alpha: float) -> void:
	_frame_mat.emission_energy_multiplier = energy
	var c := MAGENTA
	c.a = alpha
	_frame_mat.albedo_color = c
	_frame_mat.transparency = (BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.999
			else BaseMaterial3D.TRANSPARENCY_DISABLED)


func _flash_time() -> float:
	return FLASH_TIME_REDUCED if GameSettings.reduced_flashing else FLASH_TIME


## One ray down to lay the glow pool on the road (or ramp) under the crate.
## Floating crates (half-pipe hops) get none.
func _place_glow() -> void:
	if not is_inside_tree():
		return
	_glow_placed = true
	var from := global_position
	var to := from - global_basis.y.normalized() * GLOW_RAY
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var local: Vector3 = to_local(hit.position)
	_glow.position = Vector3(0, local.y + 0.04, 0)
	_glow.visible = _body.visible


static func _mesh_instance(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- shared geometry ------------------------------------------------------------

static func _build_shared() -> void:
	if _shell_mesh != null:
		return
	var h := SIZE * 0.5

	# Shell: three crossed boxes give a stepped bevel on every edge.
	var bevel := 0.06
	var shell := SurfaceTool.new()
	for axis: int in 3:
		var s := Vector3.ONE * (SIZE - bevel * 2.0)
		s[axis] = SIZE
		_append_box(shell, s, Transform3D.IDENTITY)
	_shell_mesh = shell.commit()

	# Reinforced corners: a cap block plus a thin lip on each of its three faces.
	var corners := SurfaceTool.new()
	var cap := 0.24
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var sgn := Vector3(sx, sy, sz)
				var c := sgn * (h - cap * 0.5 + 0.025)
				_append_box(corners, Vector3.ONE * cap, Transform3D(Basis(), c))
				var lip := Vector3.ONE * (cap * 0.7)
				_append_box(corners, lip, Transform3D(Basis(), sgn * (h - cap * 0.35 + 0.04)))
	_corner_mesh = corners.commit()

	# Segmented frame: an octagonal ring of eight bars on front, back and top.
	var frame := SurfaceTool.new()
	var faces: Array[Basis] = [
		Basis(), # front (+Z)
		Basis(Vector3.UP, PI), # back (-Z)
		Basis(Vector3.RIGHT, -PI * 0.5), # top (+Y)
	]
	var r := h * 0.78 # ring half-size
	var t := 0.065 # bar thickness
	var d := 0.03 # proud of the face
	var side_len := r * 0.9
	var diag := (r - side_len * 0.5) * sqrt(2.0) - 0.07
	for fb in faces:
		for i in 4:
			var rot := Basis(Vector3.BACK, i * PI * 0.5)
			var side_xf := Transform3D(fb * rot, fb * (rot * Vector3(0, r, h + d * 0.5)))
			_append_box(frame, Vector3(side_len, t, d), side_xf)
			var mid := (Vector3(side_len * 0.5, r, 0) + Vector3(r, side_len * 0.5, 0)) * 0.5
			var drot := rot * Basis(Vector3.BACK, -PI * 0.25)
			var diag_xf := Transform3D(fb * drot,
					fb * (rot * Vector3(mid.x, mid.y, h + d * 0.5)))
			_append_box(frame, Vector3(diag, t, d), diag_xf)
	_frame_mesh = frame.commit()

	# Side stripes: two diagonal bars on the left and right faces.
	var stripes := SurfaceTool.new()
	for sx: float in [-1.0, 1.0]:
		var face := Basis(Vector3.UP, sx * PI * 0.5)
		for k: float in [-1.0, 1.0]:
			var pos := face * Vector3(k * 0.13, 0, h + 0.015)
			var bar := Basis(face.z, PI * 0.25 * sx) * face
			_append_box(stripes, Vector3(0.62, 0.07, 0.03), Transform3D(bar, pos))
	_stripe_mesh = stripes.commit()

	var glow := PlaneMesh.new()
	glow.size = Vector2(2.3, 1.8)
	_glow_mesh = glow

	_shell_mat = StandardMaterial3D.new()
	_shell_mat.albedo_color = Color(0.24, 0.12, 0.30)
	_shell_mat.metallic = 0.6
	_shell_mat.roughness = 0.45
	_shell_mat.emission_enabled = true
	_shell_mat.emission = Color(0.16, 0.03, 0.20)
	_shell_mat.emission_energy_multiplier = 0.6

	_corner_mat = StandardMaterial3D.new()
	_corner_mat.albedo_color = Color(0.62, 0.63, 0.66)
	_corner_mat.metallic = 0.8
	_corner_mat.roughness = 0.35
	_corner_mat.emission_enabled = true
	_corner_mat.emission = Color(0.25, 0.25, 0.28)
	_corner_mat.emission_energy_multiplier = 0.5

	_stripe_mat = WeaponManager.glow_material(MAGENTA, FRAME_ENERGY)

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.15, 0.75, 0.75))
	grad.set_color(1, Color(1.0, 0.15, 0.75, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_texture = tex
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _append_box(st: SurfaceTool, size: Vector3, xf: Transform3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, xf)
