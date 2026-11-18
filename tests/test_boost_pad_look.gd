extends SceneTree
## Boost pad look (TrackFeature._pad_visual, boost_pad.gdshader): beveled
## frame, ribbed chevron plate, amber corner lights, crossing flash.
## No track is built. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_boost_pad_look.gd

const CAR := "res://scenes/vehicles/placeholder_car.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_pad_look_profile.json"
	GameSettings.path = "user://test_pad_look_settings.cfg"
	InputSetup.ensure_actions()
	_run_all.call_deferred()


func _run_all() -> void:
	GameSettings.reset_values()
	_test_parts()
	await _test_flash()
	await _test_calm()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _make_pad(w: float) -> TrackFeature:
	var pad := TrackFeature.new()
	pad.kind = TrackFeature.Kind.BOOST_PAD
	pad.width = w
	root.add_child(pad)
	return pad


func _parts(pad: TrackFeature, part: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in pad.find_children(part, "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


func _test_parts() -> void:
	_current = "parts"
	var a := _make_pad(5.0)
	var b := _make_pad(5.0)
	var c := _make_pad(7.0)
	var frames := _parts(a, "PadFrame")
	var plates := _parts(a, "PadPlate")
	_check(frames.size() == 1 and frames[0].mesh.get_faces().size() > 0, "one beveled frame mesh")
	_check(plates.size() == 1 and plates[0].material_override is ShaderMaterial, "one shader plate")
	var mat := a.pad_material()
	_check(mat != null and mat.shader == TrackFeature.PAD_SHADER, "plate uses boost_pad.gdshader")
	_check(_parts(a, "PadCornerLight*").size() == 4, "four amber corner lights")
	# Frame spans the pad and stays low enough to drive over.
	var aabb := frames[0].mesh.get_aabb()
	_check(is_equal_approx(aabb.size.x, 5.0) and is_equal_approx(aabb.size.z, TrackFeature.PAD_LENGTH), "frame is width x 6 m (%s)" % aabb.size)
	_check(aabb.end.y <= 0.15, "frame stays under 15 cm (%.2f)" % aabb.end.y)
	# Shared frame / lights, own plate material.
	_check(_parts(b, "PadFrame")[0].mesh == frames[0].mesh, "same width shares the frame mesh")
	_check(_parts(c, "PadFrame")[0].mesh != frames[0].mesh, "other width gets its own frame")
	_check(_parts(b, "PadCornerLight*")[0].material_override == _parts(a, "PadCornerLight*")[0].material_override, "corner lights share a material")
	_check(b.pad_material() != mat, "each pad has its own plate material")
	var plate_size: Vector2 = mat.get_shader_parameter("plate_size")
	_check(plate_size.x < 5.0 and plate_size.y < TrackFeature.PAD_LENGTH, "plate sits inside the frame")
	# Trigger area unchanged.
	var area := a.find_children("*", "Area3D", true, false)[0] as Area3D
	var box := (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_check(box.size.is_equal_approx(Vector3(5.0, 2.0, 6.0)), "trigger box unchanged (%s)" % box.size)
	for p in [a, b, c]:
		p.queue_free()


func _test_flash() -> void:
	_current = "flash"
	var pad := _make_pad(5.0)
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.position = Vector3(0, 0, 40)
	root.add_child(car)
	await process_frame
	_check(pad.pad_flash() == 0.0, "idle pad does not flash")
	pad.call("_on_body_entered", car)
	_check(pad.pad_flash() == 1.0, "crossing starts the flash")
	await process_frame
	await process_frame
	var shown: float = pad.pad_material().get_shader_parameter("flash")
	_check(shown > 0.5, "flash pushed to the shader (%.2f)" % shown)
	var t := 0.0
	while t < 0.6:
		await process_frame
		t += 1.0 / 60.0
	_check(pad.pad_flash() == 0.0, "flash fades within ~0.5 s")
	_check(float(pad.pad_material().get_shader_parameter("flash")) == 0.0, "shader flash back to 0")
	# Within the 1.5 s cooldown a second entry neither boosts nor flashes.
	pad.call("_on_body_entered", car)
	_check(pad.pad_flash() == 0.0, "no re-flash during cooldown")
	pad.queue_free()
	car.queue_free()


func _test_calm() -> void:
	_current = "reduced flashing"
	GameSettings.reduced_flashing = true
	var pad := _make_pad(5.0)
	await process_frame
	_check(float(pad.pad_material().get_shader_parameter("calm")) == 1.0, "calm pulse")
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.position = Vector3(0, 0, 40)
	root.add_child(car)
	await process_frame
	pad.call("_on_body_entered", car)
	await process_frame
	await process_frame
	var shown: float = pad.pad_material().get_shader_parameter("flash")
	_check(shown > 0.0 and shown <= 0.35, "flash is a soft brighten (%.2f)" % shown)
	GameSettings.reduced_flashing = false
	await process_frame
	await process_frame
	_check(float(pad.pad_material().get_shader_parameter("calm")) == 0.0, "follows the setting live")
	pad.queue_free()
	car.queue_free()
