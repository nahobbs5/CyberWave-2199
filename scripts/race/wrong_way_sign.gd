class_name WrongWaySign
extends Node3D
## A neon WRONG WAY sign that hangs over the road ahead of the player's car
## while they drive against the track. It pops in, pulses, and always faces
## the car. Built in code; RaceManager drives it through update().

const AHEAD := 25.0
const HEIGHT := 6.0
const BOARD_SIZE := Vector2(10.0, 3.6)
const FRAME := 0.25
const POP_TIME := 0.2
const PULSE_HZ := 2.0

var shown: bool = false
var _amount: float = 0.0
var _time: float = 0.0
var _frame_mat: StandardMaterial3D
var _title: Label3D
var _placed: bool = false


func _init() -> void:
	name = "WrongWaySign"
	visible = false
	top_level = true
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.03, 0.02, 0.04)
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_box(Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.15), Vector3(0.0, 0.0, -0.1), back_mat)

	_frame_mat = StandardMaterial3D.new()
	_frame_mat.albedo_color = UIStyle.DANGER
	_frame_mat.emission_enabled = true
	_frame_mat.emission = UIStyle.DANGER
	_frame_mat.emission_energy_multiplier = 4.0
	var hw := BOARD_SIZE.x * 0.5
	var hh := BOARD_SIZE.y * 0.5
	_add_box(Vector3(BOARD_SIZE.x, FRAME, 0.2), Vector3(0.0, hh, 0.0), _frame_mat)
	_add_box(Vector3(BOARD_SIZE.x, FRAME, 0.2), Vector3(0.0, -hh, 0.0), _frame_mat)
	_add_box(Vector3(FRAME, BOARD_SIZE.y, 0.2), Vector3(-hw, 0.0, 0.0), _frame_mat)
	_add_box(Vector3(FRAME, BOARD_SIZE.y, 0.2), Vector3(hw, 0.0, 0.0), _frame_mat)

	_title = _label("WRONG WAY", 260, UIStyle.DANGER, 0.45)
	_label("TURN AROUND", 130, Color.WHITE, -1.05)


## Show or hide the sign and keep it over the road ahead of `car`.
func update(track: TrackCircuit, car: Node3D, active: bool, delta: float) -> void:
	shown = active
	_time += delta
	_amount = move_toward(_amount, 1.0 if active else 0.0, delta / POP_TIME)
	visible = _amount > 0.0
	if not visible:
		_placed = false
		return
	var car_pos := car.global_position
	var target: Vector3
	if track.get_shortcut_at(car_pos) == null:
		# The car is driving backwards, so "ahead" is a lower track offset.
		target = track.get_center_at(track.get_offset_at(car_pos) - AHEAD)
	else:
		target = car_pos - track.get_direction_at(car_pos) * AHEAD
	target += Vector3.UP * HEIGHT
	if _placed:
		target = global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	_placed = true
	var away := target - car_pos
	away.y = 0.0
	var facing := Basis.looking_at(away.normalized(), Vector3.UP) if away.length() > 0.1 else global_basis.orthonormalized()
	var s := ease(_amount, -2.0) # quick pop with a soft finish
	global_transform = Transform3D(facing.scaled(Vector3.ONE * maxf(s, 0.01)), target)
	var pulse := 0.5 + 0.5 * sin(_time * TAU * PULSE_HZ)
	_frame_mat.emission_energy_multiplier = lerpf(1.5, 6.0, pulse)
	_title.modulate = UIStyle.DANGER.lerp(Color(1.0, 0.6, 0.6), pulse * 0.5)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = mat
	box.position = pos
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(box)


func _label(text: String, font_size: int, color: Color, y: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UIStyle.heading_font()
	label.font_size = font_size
	label.pixel_size = 0.005
	label.modulate = color
	label.outline_size = 24
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(0.0, y, 0.05)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label
