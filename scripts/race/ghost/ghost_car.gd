class_name GhostCar
extends Node3D
## A Time Trial ghost (GDD 2.5): the recorded car played back as a hologram
## you drive through. Built from the race's car scene with the ghost car's
## model, then frozen: no physics, no collisions, not in the vehicles group
## (AI, weapons and recovery never see it). Follows race time through
## GhostData.sample(), spins its wheels from the recorded speed, fades when
## the camera is close (so it never hides your own car) and after it finishes.

const SHADER := preload("res://assets/shaders/ghost_car.gdshader")
const RIVAL_TINT := Color(1.0, 0.35, 0.85)
const EXPERT_TINT := Color(1.0, 0.78, 0.2)
const BEST_TINT := Color(0.2, 0.9, 1.0)
## Camera distance (m) where the ghost starts / finishes fading in.
const NEAR_FADE := Vector2(3.5, 9.0)

var data: GhostData
var kind: TimeTrialCatalog.Ghost = TimeTrialCatalog.Ghost.RIVAL
var car: VehicleController
var tint: Color = RIVAL_TINT
var material: ShaderMaterial
var tag: Label3D
## Race time the ghost was last placed at.
var time: float = 0.0
var _spin: float = 0.0
var _done_time: float = -1.0


## Builds the ghost car. `vehicle` is the car it drives (null = V8 Specter).
func setup(p_data: GhostData, p_kind: TimeTrialCatalog.Ghost, car_scene: PackedScene, vehicle: VehicleData,
		visual_scale: float = VehicleController.TRACK_VISUAL_SCALE) -> void:
	data = p_data
	kind = p_kind
	if vehicle == null:
		vehicle = VehicleCatalog.by_id(data.vehicle_id)
	match kind:
		TimeTrialCatalog.Ghost.EXPERT:
			tint = EXPERT_TINT
		TimeTrialCatalog.Ghost.BEST:
			tint = BEST_TINT
		_:
			tint = RIVAL_TINT
	car = car_scene.instantiate() as VehicleController
	car.name = "GhostVehicle"
	car.stats = vehicle.stats
	car.freeze = true
	car.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	car.collision_layer = 0
	car.collision_mask = 0
	add_child(car)
	car.remove_from_group(VehicleController.GROUP)
	car.input_enabled = false
	car.player_controlled = false
	for child in car.get_children():
		if child is RayCast3D:
			(child as RayCast3D).enabled = false
	VehicleCosmetics.apply_model(car, vehicle)
	car.set_visual_scale(visual_scale)
	car.process_mode = Node.PROCESS_MODE_DISABLED
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", tint)
	_ghostify(car)
	tag = Label3D.new()
	tag.name = "GhostTag"
	tag.text = label_text()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 1.8 * visual_scale, 0.0)
	tag.pixel_size = 0.008
	tag.font_size = 40
	tag.outline_size = 10
	tag.modulate = tint.lightened(0.3)
	tag.no_depth_test = false
	add_child(tag)
	place(0.0)


## "RIVAL · EMPYREAN S", "EXPERT · EMPYREAN S", "YOUR BEST".
func label_text() -> String:
	if kind == TimeTrialCatalog.Ghost.BEST:
		return "YOUR BEST"
	var v := VehicleCatalog.by_id(data.vehicle_id)
	return "%s · %s" % [TimeTrialCatalog.GHOST_NAMES[kind].to_upper(), v.display_name.to_upper()]


## Every mesh drawn with the ghost shader; lights and particles hidden.
func _ghostify(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif child is GeometryInstance3D and not child is Label3D and not child is MeshInstance3D:
			(child as Node3D).visible = false
		elif child is Light3D:
			(child as Light3D).visible = false
		elif child is Label3D:
			(child as Label3D).modulate = Color(tint, 0.35)
		_ghostify(child)


## Puts the ghost where the recording is at race time `t`.
func place(t: float, delta: float = 0.0) -> void:
	time = t
	if data == null or car == null:
		return
	var s := data.sample(t)
	car.global_transform = s.transform
	var body := car.get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation.y = float(s.yaw)
	car.visual_yaw = float(s.yaw)
	_spin = fmod(_spin - float(s.speed) / (car.stats.wheel_radius * car.visual_scale) * delta, TAU)
	for child in car.get_children():
		var ray := child as RayCast3D
		if ray == null or not ray.name.begins_with("Wheel"):
			continue
		var pivot := ray.get_node_or_null("Pivot") as Node3D
		if pivot == null:
			continue
		pivot.position = Vector3(0.0, -car.stats.suspension_rest_length * 0.6, 0.0) + car._wheel_visual_offset(ray)
		var steer := -float(s.steer) * 0.45 if ray.name.begins_with("WheelF") else 0.0
		pivot.rotation = Vector3(_spin, steer + float(s.yaw), 0.0)
	# Exhaust flames while the recording was boosting (its Nitros, drift boosts).
	for flame_name in ["FlameL", "FlameR"]:
		var flame := car.get_node_or_null("Feedback/" + flame_name) as Node3D
		if flame != null:
			flame.visible = bool(s.boosting)
	if bool(s.done) and _done_time < 0.0:
		_done_time = t
	tag.global_position = car.global_position + Vector3(0.0, 1.8 * car.visual_scale, 0.0)
	_update_fade(t)


func is_finished() -> bool:
	return _done_time >= 0.0


## 0..1 visibility now (tests).
func fade() -> float:
	return float(material.get_shader_parameter("fade"))


func _update_fade(t: float) -> void:
	var f := 1.0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var d := cam.global_position.distance_to(car.global_position)
		f = smoothstep(NEAR_FADE.x, NEAR_FADE.y, d)
	if _done_time >= 0.0:
		f *= clampf(1.0 - (t - _done_time) / 1.5, 0.0, 1.0)
	material.set_shader_parameter("fade", f)
	tag.visible = f > 0.05
	tag.modulate.a = f
