class_name WeaponCrate
extends Area3D
## Question-mark crate (GDD 6.1, 8.7). Gives a random weapon to a racer with a
## free slot; a full inventory leaves the crate in place. Respawns after a delay.

var manager: WeaponManager
var respawn_time: float = 3.0

var _cooldown: float = 0.0
var _visual: Node3D
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # vehicles
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.4, 2.2)
	shape.shape = box
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3.ONE * 1.2
	cube.mesh = cube_mesh
	var mat := WeaponManager.glow_material(Color(1.0, 0.2, 0.85), 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.2, 0.85, 0.55)
	cube.material_override = mat
	_visual.add_child(cube)
	var mark := Label3D.new()
	mark.text = "?"
	mark.font_size = 96
	mark.pixel_size = 0.012
	mark.outline_size = 12
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = false
	_visual.add_child(mark)
	body_entered.connect(_on_body_entered)


func is_available() -> bool:
	return _cooldown <= 0.0


func _on_body_entered(body: Node3D) -> void:
	var vehicle := body as VehicleController
	if vehicle == null or not is_available():
		return
	if manager.try_give_weapon(vehicle):
		_cooldown = respawn_time
		_visual.visible = false


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_visual.visible = true


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y = _time * 1.5
	_visual.position.y = 0.2 * sin(_time * 2.5)
