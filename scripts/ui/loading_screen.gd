class_name LoadingScreen
extends CanvasLayer
## Full-screen track card shown while a slow scene loads (races, free drive),
## with a progress bar. The load runs in steps so the bar can move between
## them: the scene's files load on worker threads, then a race's track is
## built here piece by piece (road, then each feature and scenery set) while
## its textures load on worker threads, then the scene changes underneath
## and takes the built track. Each step still blocks the game while it runs,
## so the bar moves in jumps. The card fades out once the new scene has
## rendered a frame. It lives on the tree root so it survives the scene
## change. RaceManager waits for `closed` before the countdown.

signal closed

const FADE := 0.3
## Frames to wait so the card is on screen before the blocking load, and
## after the new scene so its first frame (and shader warm-up) is done.
const FRAMES_BEFORE := 2
const FRAMES_AFTER := 2

## Where each step ends on the bar (0-1), roughly in proportion to its time.
## The rest is setting up the race (cars, racing line, HUD).
const FILES_END := 0.12
const BUILD_END := 0.78
const TEXTURES_END := 0.8
## Without a track to build, the files step runs to here.
const FILES_ONLY_END := 0.8
## Build time of the road (build_base) and of a scenery set, in track features.
const BASE_WEIGHT := 6.0
const SCENERY_WEIGHT := 30.0

## The loading screen on screen now, or null.
static var active: LoadingScreen
## The track built for the next race, until RaceManager takes it.
static var _built_track: TrackCircuit

var title_label: Label
var detail_label: Label
var thumbnail: TrackThumbnail
var progress_bar: ProgressBar
var percent_label: Label
var _root: Control


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LoadingScreen"


## Shows the card for `path`, then changes to it. Ignored if a load is
## already under way (a double press can't start two loads).
static func change_to(tree: SceneTree, path: String) -> void:
	if active != null:
		return
	var screen := LoadingScreen.new()
	screen.build(card_for(path))
	active = screen
	# Deferred: the root may be busy if this is called from a _ready.
	tree.root.add_child.call_deferred(screen)
	screen._run.call_deferred(path)


## What the card says for a scene: {title, detail, track_path, mode}.
static func card_for(path: String) -> Dictionary:
	if path == GameSession.RACE_SCENE and GameSession.current != null:
		var config := GameSession.current
		var parts: PackedStringArray = []
		var location := TrackCatalog.location(config.track_name)
		if location != "":
			parts.append(location)
		var mode := RaceConfig.MODE_NAMES[config.mode]
		if config.championship != null and config.championship.race_count() > 1:
			mode += "  -  Race %d of %d" % [config.championship.race_index + 1, config.championship.race_count()]
		parts.append(mode)
		return {
			"title": config.track_name,
			"detail": "   |   ".join(parts),
			"track_path": TrackCatalog.scene_path(config.track_name),
		}
	if path == GameSession.FREE_DRIVE_SCENE:
		return {"title": "Free Drive", "detail": "Practice", "track_path": TrackCatalog.TEST_CIRCUIT}
	return {"title": "", "detail": "", "track_path": ""}


func build(card: Dictionary) -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks so the screen underneath can't be used mid-load.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	UIStyle.background(_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(UIStyle.logo(Vector2(360, 120)))
	title_label = UIStyle.heading(str(card.get("title", "")).to_upper(), 44, UIStyle.MAGENTA)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.visible = title_label.text != ""
	box.add_child(title_label)
	detail_label = UIStyle.label(str(card.get("detail", "")), 20, UIStyle.MUTED)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.visible = detail_label.text != ""
	box.add_child(detail_label)
	var track_path := str(card.get("track_path", ""))
	if track_path != "":
		thumbnail = TrackThumbnail.new(track_path, Vector2(420, 260))
		thumbnail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(thumbnail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var loading := UIStyle.heading("LOADING", 24, UIStyle.CYAN)
	row.add_child(loading)
	percent_label = UIStyle.heading("0%", 24, UIStyle.CYAN)
	percent_label.custom_minimum_size.x = 70
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent_label)
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(420, 10)
	progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.CYAN
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	back.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", back)
	box.add_child(progress_bar)


## Nothing underneath gets keys, buttons or clicks while loading.
func _input(_event: InputEvent) -> void:
	if active == self:
		get_viewport().set_input_as_handled()


## Shows how far along the load is (0-1). It never moves backwards.
func set_progress(value: float) -> void:
	if progress_bar == null:
		return
	progress_bar.value = maxf(progress_bar.value, clampf(value, 0.0, 1.0))
	percent_label.text = "%d%%" % floori(progress_bar.value * 100.0)


func get_progress() -> float:
	return progress_bar.value if progress_bar != null else 0.0


func _run(path: String) -> void:
	var tree := get_tree()
	for i in FRAMES_BEFORE:
		await tree.process_frame
	# The game keeps running between steps now: freeze the old screen.
	if tree.current_scene != null:
		tree.current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var track_scene: PackedScene = null
	if path == GameSession.RACE_SCENE and GameSession.current != null:
		track_scene = GameSession.current.track_scene
	var files_end := FILES_END if track_scene != null else FILES_ONLY_END
	var scene := await _load_threaded(path, files_end) as PackedScene
	if track_scene != null:
		_built_track = await _build_track(track_scene)
	# Setting up the scene (cars, racing line, HUD) is the last blocking step.
	await tree.process_frame
	if scene != null:
		tree.change_scene_to_packed(scene)
	else:
		tree.change_scene_to_file(path)
	await tree.scene_changed
	set_progress(1.0)
	for i in FRAMES_AFTER:
		await tree.process_frame
	await dismiss()


## Loads `path` and everything it uses on worker threads, moving the bar up to
## `to` as it goes. Null if the threaded load failed.
func _load_threaded(path: String, to: float) -> Resource:
	if ResourceLoader.load_threaded_request(path, "", true) != OK:
		return null
	var from := get_progress()
	var progress := []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():
			set_progress(lerpf(from, to, float(progress[0])))
		await get_tree().process_frame
	set_progress(to)
	return ResourceLoader.load_threaded_get(path)


## Builds a race track here, a step per frame, with its textures loading on
## worker threads meanwhile. It stays hidden and paused until the race takes it.
func _build_track(packed: PackedScene) -> TrackCircuit:
	var tree := get_tree()
	TrackCircuit.defer_build = true
	var track := packed.instantiate() as TrackCircuit
	if track == null:
		TrackCircuit.defer_build = false
		return null
	track.visible = false
	track.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(track)
	TrackCircuit.defer_build = false
	TrackScenery.async_textures = true
	var from := get_progress()
	await tree.process_frame
	if track.build_base():
		var nodes := track.placeables()
		var total := BASE_WEIGHT
		for node in nodes:
			total += SCENERY_WEIGHT if node is TrackScenery else 1.0
		var done := BASE_WEIGHT
		set_progress(lerpf(from, BUILD_END, done / total))
		await tree.process_frame
		for node in nodes:
			var weight := SCENERY_WEIGHT if node is TrackScenery else 1.0
			# Scenery builds call back part-way through so the bar keeps moving.
			var start := done
			TrackScenery.stepper = func(share: float) -> void:
				set_progress(lerpf(from, BUILD_END, (start + weight * share) / total))
				await tree.process_frame
			await node.place_on_track(track)
			TrackScenery.stepper = Callable()
			done += weight
			set_progress(lerpf(from, BUILD_END, done / total))
			await tree.process_frame
	TrackScenery.async_textures = false
	while TrackScenery.texture_progress() < 1.0:
		set_progress(lerpf(BUILD_END, TEXTURES_END, TrackScenery.texture_progress()))
		await tree.process_frame
	TrackScenery.finish_textures()
	set_progress(TEXTURES_END)
	remove_child(track)
	return track


## The track the loading screen built for `path`, now owned by the caller and
## ready to add to its scene; null if none was built for it.
static func take_track(path: String) -> TrackCircuit:
	var track := _built_track
	_built_track = null
	if track == null:
		return null
	if track.scene_file_path != path:
		track.free()
		return null
	track.visible = true
	track.process_mode = Node.PROCESS_MODE_INHERIT
	return track


## Fades out, emits `closed` and frees the screen.
func dismiss() -> void:
	if is_inside_tree() and _root != null:
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, FADE)
		await tween.finished
	if active == self:
		active = null
	TrackScenery.stepper = Callable()
	TrackScenery.async_textures = false
	# A built track nobody took (the scene didn't want it).
	if _built_track != null:
		_built_track.free()
		_built_track = null
	closed.emit()
	queue_free()
