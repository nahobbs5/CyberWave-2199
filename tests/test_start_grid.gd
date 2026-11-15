extends SceneTree
## Starting grid checks on every track: all 8 slots on the road with room to
## the walls, cars well apart, the grid on a straight behind the line, and a
## painted slot (bracket + number 1-8) under every car.
##   godot --headless --fixed-fps 60 -s res://tests/test_start_grid.gd

const SLOTS := 8
const CAR_HALF_WIDTH := 1.2
const WALL_ROOM := 0.8
const MIN_GAP := 5.5
const MAX_TURN_DEG := 12.0
const MIN_MAIN_WIDTH := 14.0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	for path in TrackOutlines.scene_paths():
		_current = path.get_file().get_basename()
		print("- " + _current)
		var track := (load(path) as PackedScene).instantiate() as TrackCircuit
		root.add_child(track)
		await process_frame
		await process_frame
		_check_track(track)
		track.queue_free()
		await process_frame
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _check_track(track: TrackCircuit) -> void:
	var half := track.road_width * 0.5
	_check(track.road_width >= MIN_MAIN_WIDTH, "main road at least %.0f m (%.1f)" % [MIN_MAIN_WIDTH, track.road_width])
	var lat := track.grid_lateral_m()
	_check(lat + CAR_HALF_WIDTH + WALL_ROOM <= half + 0.01,
			"grid columns leave room to the walls (%.1f m out on a %.0f m road)" % [lat, track.road_width])
	_check(lat * 2.0 >= MIN_GAP, "columns at least %.1f m apart (%.1f)" % [MIN_GAP, lat * 2.0])
	var origins: Array[Vector3] = []
	for slot in SLOTS:
		origins.append(track.get_grid_transform(slot).origin)
	var closest := INF
	for i in SLOTS:
		for j in range(i + 1, SLOTS):
			closest = minf(closest, origins[i].distance_to(origins[j]))
	_check(closest >= MIN_GAP, "every car at least %.1f m from the next (%.1f)" % [MIN_GAP, closest])
	var line_dir := track.get_tangent_at(track.start_line_offset)
	var worst := 0.0
	for slot in SLOTS:
		var fwd := -track.get_grid_transform(slot).basis.z
		fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
		worst = maxf(worst, rad_to_deg(fwd.angle_to(line_dir)))
	_check(worst <= MAX_TURN_DEG, "the grid is on a straight (worst heading %.1f deg)" % worst)
	# Each slot sits behind the line, in order.
	var ordered := true
	for slot in SLOTS:
		var back := track.wrapped_delta(track.get_grid_offset(slot), track.start_line_offset)
		ordered = ordered and back > 0.0 and back < 70.0
		if slot > 0:
			ordered = ordered and back > track.wrapped_delta(track.get_grid_offset(slot - 1), track.start_line_offset)
	_check(ordered, "slots go back from the line in order")
	var markers := track.get_node_or_null("_GenGridMarkers")
	_check(markers != null and markers.get_child_count() == SLOTS, "a painted slot per car")
	if markers == null:
		return
	var numbers_ok := true
	var under_ok := true
	for slot in SLOTS:
		var m := markers.get_node_or_null("Slot%d" % (slot + 1)) as Node3D
		if m == null:
			numbers_ok = false
			continue
		var label := m.get_node_or_null("Number") as Label3D
		numbers_ok = numbers_ok and label != null and label.text == str(slot + 1)
		var car := track.get_grid_transform(slot).origin
		var flat := Vector2(m.global_position.x - car.x, m.global_position.z - car.z).length()
		under_ok = under_ok and flat < 0.3 and absf(car.y - m.global_position.y - 0.9) < 0.3
	_check(numbers_ok, "slots numbered 1-%d" % SLOTS)
	_check(under_ok, "each slot sits on the road under its car")
