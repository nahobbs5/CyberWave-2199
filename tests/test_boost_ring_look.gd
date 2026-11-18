extends SceneTree
## Boost ring look (TrackFeature._ring_visual, boost_ring.gdshader): slim
## graphite frame, segmented magenta rim, four amber marker pods, two feet,
## clear centre; two rim pulses on approach, inner-edge flash on the pass.
## No track is built. Run from the project root:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_boost_ring_look.gd

const CAR := "res://scenes/vehicles/placeholder_car.tscn"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	PlayerProfile.save_path = "user://test_ring_look_profile.json"
	GameSettings.path = "user://test_ring_look_settings.cfg"
	InputSetup.ensure_actions()
	_run_all.call_deferred()


func _run_all() -> void:
	GameSettings.reset_values()
	_test_parts()
	await _test_approach()
	await _test_pass()
	await _test_calm()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _make_ring() -> TrackFeature:
	var ring := TrackFeature.new()
	ring.kind = TrackFeature.Kind.BOOST_RING
	root.add_child(ring)
	return ring


func _make_car() -> VehicleController:
	var car := (load(CAR) as PackedScene).instantiate() as VehicleController
	car.position = Vector3(0, 0, 60)
	root.add_child(car)
	return car


func _parts(node: Node, part: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in node.find_children(part, "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0


func _test_parts() -> void:
	_current = "parts"
	var a := _make_ring()
	var b := _make_ring()
	var pad := TrackFeature.new()
	pad.kind = TrackFeature.Kind.BOOST_PAD
	root.add_child(pad)
	var frames := _parts(a, "RingFrame")
	var rims := _parts(a, "RingRim")
	_check(frames.size() == 1 and frames[0].mesh.get_faces().size() > 0, "one frame mesh")
	_check(rims.size() == 1 and rims[0].material_override is ShaderMaterial, "one shader rim")
	_check(a.ring_material() != null and a.ring_material().shader == TrackFeature.RING_SHADER, "rim uses boost_ring.gdshader")
	_check(_parts(a, "RingMarker?").size() == 4, "four marker pods")
	_check(_parts(a, "RingLamp?").size() == 8, "an amber lamp on each face of each pod")
	_check(_parts(a, "RingFoot?").size() == 2, "two feet")
	_check(_parts(a, "RingLamp?")[0].material_override == _parts(pad, "PadCornerLight*")[0].material_override, "amber lamps match the pads'")
	_check(frames[0].material_override == _parts(pad, "PadFrame")[0].material_override, "graphite matches the pad frame")
	_check(_parts(b, "RingFrame")[0].mesh == frames[0].mesh and _parts(b, "RingRim")[0].mesh == rims[0].mesh, "rings share frame and rim meshes")
	_check(b.ring_material() != a.ring_material(), "each ring has its own rim material")
	# Clear centre: every mesh vertex stays outside the opening.
	var hub := Vector3(0, TrackFeature.RING_CENTER_Y, 0)
	var nearest := INF
	for mi in _parts(a, "*"):
		var faces := mi.mesh.get_faces()
		for v in faces:
			var p: Vector3 = mi.transform * v
			nearest = minf(nearest, Vector2(p.x - hub.x, p.y - hub.y).length())
	_check(nearest > 3.2, "centre stays clear (nearest %.2f m from the hub)" % nearest)
	# Frame sits on the road, not floating above it.
	var aabb := frames[0].mesh.get_aabb()
	var bottom := TrackFeature.RING_CENTER_Y + aabb.position.y
	_check(bottom < 0.05 and bottom > -0.3, "frame bottom at road level (%.2f)" % bottom)
	# Boost trigger unchanged, plus the approach area.
	var trigger: Area3D = null
	var approach: Area3D = null
	for area in a.find_children("*", "Area3D", true, false):
		if area.name == "RingApproach":
			approach = area
		else:
			trigger = area
	var cs := trigger.get_child(0) as CollisionShape3D
	_check((cs.shape as BoxShape3D).size.is_equal_approx(Vector3(7.0, 7.0, 2.0)) and is_equal_approx(cs.position.y, 3.2), "trigger box unchanged")
	_check(approach != null and ((approach.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.z > 30.0, "approach area reaches both ways")
	for n in [a, b, pad]:
		n.queue_free()


func _test_approach() -> void:
	_current = "approach"
	var ring := _make_ring()
	var car := _make_car()
	await process_frame
	_check(ring.ring_sweep() == 0.0, "idle ring has no pulses")
	ring.call("_on_approach", car)
	_check(ring.ring_sweep() == 1.0, "approach starts the pulses")
	_check(ring.triggered == 0, "approach does not count as a boost")
	await _wait(0.3)
	var mid: float = ring.ring_material().get_shader_parameter("sweep")
	_check(mid > 0.2 and mid < 1.0, "pulses running in the shader (%.2f)" % mid)
	ring.call("_on_approach", car)
	_check(ring.ring_sweep() < 1.0, "a second car mid-lap does not restart it")
	await _wait(0.8)
	_check(ring.ring_sweep() == 0.0, "pulses finish within ~1 s")
	_check(float(ring.ring_material().get_shader_parameter("sweep")) == 0.0, "shader sweep back to 0")
	ring.queue_free()
	car.queue_free()


func _test_pass() -> void:
	_current = "pass"
	var ring := _make_ring()
	var car := _make_car()
	await process_frame
	_check(ring.ring_flash() == 0.0, "idle ring does not flash")
	ring.call("_on_body_entered", car)
	_check(ring.triggered == 1, "pass-through boosts")
	_check(ring.ring_flash() == 1.0, "pass-through starts the flash")
	await process_frame
	await process_frame
	var shown: float = ring.ring_material().get_shader_parameter("flash")
	_check(shown > 0.5, "flash pushed to the shader (%.2f)" % shown)
	await _wait(0.6)
	_check(ring.ring_flash() == 0.0, "flash fades within ~0.5 s")
	ring.call("_on_body_entered", car)
	_check(ring.ring_flash() == 0.0 and ring.triggered == 1, "no re-flash during cooldown")
	ring.queue_free()
	car.queue_free()


func _test_calm() -> void:
	_current = "reduced flashing"
	GameSettings.reduced_flashing = true
	var ring := _make_ring()
	var car := _make_car()
	await process_frame
	_check(float(ring.ring_material().get_shader_parameter("calm")) == 1.0, "calm pulses")
	ring.call("_on_approach", car)
	ring.call("_on_body_entered", car)
	await process_frame
	await process_frame
	var shown: float = ring.ring_material().get_shader_parameter("flash")
	_check(shown > 0.0 and shown <= 0.35, "flash is a soft brighten (%.2f)" % shown)
	GameSettings.reduced_flashing = false
	await process_frame
	await process_frame
	_check(float(ring.ring_material().get_shader_parameter("calm")) == 0.0, "follows the setting live")
	ring.queue_free()
	car.queue_free()
