extends SceneTree
## Boost-pad patterns (TrackFeature._place_pattern): every main-road pad is a
## single, a diagonal of three or a triangle, fixed per track. Run:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/test_boost_patterns.gd

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var seen := {}
	var all_on_road := true
	var groups_ok := true
	for entry in TrackCatalog.TRACKS:
		var path: String = entry[1]
		if path == TrackCatalog.TEST_CIRCUIT or not ResourceLoader.exists(path):
			continue
		_current = String(entry[0])
		var track := await _load(path)
		var pads := _pads(track)
		for pad in pads:
			seen[pad.pattern] = true
			var p := pad.global_position
			all_on_road = all_on_road and track.is_on_road(p)
		# Each authored pad brings the right number of copies.
		for pad in pads.filter(func(f: TrackFeature) -> bool: return not f.pattern_copy):
			var copies := pads.filter(func(f: TrackFeature) -> bool:
				return f.pattern_copy and String(f.name).begins_with(TrackCircuit.GENERATED_PREFIX + String(pad.name) + "_")).size()
			var want := 0 if pad.pattern == &"single" else 2
			# Kilwa drops a copy that would sit under a column.
			groups_ok = groups_ok and (copies == want or (track.road_columns.size() > 0 and copies <= want))
		var layout := _layout(track)
		track.rebuild()
		await process_frame
		_check(_layout(track) == layout, "rebuilding gives the same pads, no duplicates (%d)" % layout.size())
		track.queue_free()
		await process_frame
		var again := await _load(path)
		_check(_layout(again) == layout, "same pattern every time the track loads")
		again.queue_free()
		await process_frame
	_current = "all tracks"
	_check(all_on_road, "every boost pad sits on the road")
	_check(groups_ok, "each pattern has its pads (single 1, diagonal 3, triangle 3)")
	_check(seen.has(&"single") and seen.has(&"diagonal") and seen.has(&"triangle"),
			"all three patterns appear across the tracks (%s)" % [seen.keys()])
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _load(path: String) -> TrackCircuit:
	var track := (load(path) as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	await process_frame
	await process_frame
	return track


func _pads(track: TrackCircuit) -> Array[TrackFeature]:
	var out: Array[TrackFeature] = []
	for child in track.get_children():
		var f := child as TrackFeature
		if f != null and f.kind == TrackFeature.Kind.BOOST_PAD and f.on_shortcut == "" and not f.is_queued_for_deletion():
			out.append(f)
	return out


## Pad positions, rounded, sorted (compares layouts across loads).
func _layout(track: TrackCircuit) -> Array:
	var out: Array = []
	for pad in _pads(track):
		var p := track.to_local(pad.global_position)
		out.append("%s %.1f %.1f %.1f" % [pad.pattern, p.x, p.y, p.z])
	out.sort()
	return out


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])
