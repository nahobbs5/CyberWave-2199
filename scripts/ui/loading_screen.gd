class_name LoadingScreen
extends CanvasLayer
## Full-screen track card shown while a slow scene loads (races, free drive),
## with a progress bar. Layout after "reference files/Cyberwave 2199_ Six
## Flags Track Loading Screen.png": the track's screenshot (TrackCard.photo_path)
## fills the screen, logo + title + detail top left, a TRACK MAP panel on the
## right, LOADING / % and a full-width bar along the bottom. A track without a
## screenshot gets the same layout on the plain background. The load runs in steps so the bar can move between
## them: the scene's files load on worker threads, then a race's track is
## built here piece by piece (road, then each feature and scenery set) while
## its textures load on worker threads, then the scene changes underneath
## and takes the built track. Each step still blocks the game while it runs,
## so the bar moves in jumps. The card fades out once the new scene has
## rendered a frame. It lives on the tree root so it survives the scene
## change. RaceManager waits for `closed` before the countdown.

signal closed

const FADE := 0.3
const TITLE_SIZE := 70
## Room for the title beside its slashes before it goes onto two lines.
const TITLE_WIDTH := 640.0
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
## The track's screenshot behind everything (null when it has none).
var photo: TextureRect
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
			"detail": "  /  ".join(parts),
			"track_path": TrackCatalog.scene_path(config.track_name),
		}
	if path == GameSession.FREE_DRIVE_SCENE:
		var practice := GameSession.practice_track
		return {"title": practice, "detail": "Practice", "track_path": TrackCatalog.scene_path(practice)}
	return {"title": "", "detail": "", "track_path": ""}


func build(card: Dictionary) -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks so the screen underneath can't be used mid-load.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	UIStyle.background(_root)
	var track_path := str(card.get("track_path", ""))

	# The track's screenshot fills the screen, shaded left and bottom for the
	# text. Without one (a new track) the plain background shows instead.
	var shot := TrackCard.photo_path(track_path) if track_path != "" else ""
	if shot != "":
		photo = TextureRect.new()
		photo.name = "Photo"
		photo.texture = load(shot) as Texture2D
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(photo)
		_root.add_child(_Shade.new())

	# Top left: logo, then the title and detail with magenta slashes beside them.
	var left := VBoxContainer.new()
	left.anchor_right = 0.58
	left.offset_left = 44
	left.offset_top = 28
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	var logo := UIStyle.logo(Vector2(290, 100))
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(logo)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(row)
	var accent := _Accent.new()
	row.add_child(accent)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	title_label = UIStyle.stat("", TITLE_SIZE, Color.WHITE)
	title_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	title_label.text = balanced_title(str(card.get("title", "")).to_upper(), UIStyle.slanted_font(true))
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.0, 0.08, 0.85))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.add_theme_constant_override("line_spacing", -14)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.visible = title_label.text != ""
	text.add_child(title_label)
	detail_label = UIStyle.label(str(card.get("detail", "")), 24, Color(0.86, 0.84, 0.92))
	detail_label.add_theme_font_override("font", UIStyle.slanted_font(false))
	detail_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	detail_label.add_theme_constant_override("outline_size", 4)
	detail_label.visible = detail_label.text != ""
	text.add_child(detail_label)
	accent.visible = title_label.visible

	# Right: the TRACK MAP panel.
	if track_path != "":
		var panel := _MapPanel.new()
		panel.anchor_left = 0.61
		panel.anchor_right = 0.985
		panel.anchor_top = 0.07
		panel.anchor_bottom = 0.76
		_root.add_child(panel)
		var heading := UIStyle.stat("TRACK MAP", 26, Color.WHITE)
		heading.add_theme_font_override("font", UIStyle.slanted_font(true))
		heading.position = Vector2(42, 20)
		panel.add_child(heading)
		thumbnail = TrackThumbnail.new(track_path, Vector2.ZERO)
		thumbnail.show_background = false
		thumbnail.line_width = 5.0
		thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumbnail.offset_left = 36
		thumbnail.offset_right = -36
		thumbnail.offset_top = 76
		thumbnail.offset_bottom = -36
		panel.add_child(thumbnail)

	# Bottom: LOADING ... 80%, then a full-width bar.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -44
	bottom.offset_bottom = -44
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	var status := HBoxContainer.new()
	bottom.add_child(status)
	var loading := UIStyle.stat("LOADING", 24, Color.WHITE)
	loading.add_theme_font_override("font", UIStyle.heading_font())
	loading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(loading)
	percent_label = UIStyle.stat("0%", 24, Color.WHITE)
	percent_label.add_theme_font_override("font", UIStyle.heading_font())
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(percent_label)
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.CYAN
	fill.set_corner_radius_all(5)
	fill.shadow_color = Color(UIStyle.CYAN, 0.35)
	fill.shadow_size = 6
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.16)
	back.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", back)
	bottom.add_child(progress_bar)


## A title too wide for the column is split into two lines of about equal
## width at a space ("SIX FLAGS" / "NEW ORLEANS"), not filled left to right.
static func balanced_title(text: String, font: Font) -> String:
	var width := func(t: String) -> float:
		return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	if width.call(text) <= TITLE_WIDTH:
		return text
	var words := text.split(" ", false)
	var best := text
	var best_w := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(width.call(a), width.call(b))
		if w < best_w:
			best_w = w
			best = a + "\n" + b
	return best


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
	elif path == GameSession.FREE_DRIVE_SCENE:
		var practice := TrackCatalog.scene_path(GameSession.practice_track)
		if practice != TrackCatalog.TEST_CIRCUIT:
			track_scene = load(practice) as PackedScene
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


## Darkens the screenshot: strongly on the left (behind the title), along the
## bottom (behind the bar), and a little everywhere.
class _Shade extends Control:
	func _init() -> void:
		name = "Shade"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dark := Color(0.03, 0.0, 0.06)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.0, 0.12, 0.22))
		# Left: solid-ish to 25%, clear by 62%.
		_band(Vector2(0, 0), Vector2(w * 0.25, h), Color(dark, 0.72), Color(dark, 0.6), true)
		_band(Vector2(w * 0.25, 0), Vector2(w * 0.62, h), Color(dark, 0.6), Color(dark, 0.0), true)
		# Bottom: clear at 66% height, dark at the edge.
		_band(Vector2(0, h * 0.66), Vector2(w, h), Color(dark, 0.0), Color(dark, 0.85), false)

	func _band(a: Vector2, b: Vector2, from: Color, to: Color, horizontal: bool) -> void:
		var pts := PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
		var cols := PackedColorArray([from, to, to, from]) if horizontal else PackedColorArray([from, from, to, to])
		draw_polygon(pts, cols)


## Magenta slashes beside the title: a tall thin bar, two short ones lower down.
class _Accent extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(16, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var lean := 0.05 # x shift per unit of height
		var top := 8.0
		var bar_bottom := h - 44.0
		_slash(top, bar_bottom, 3.0, lean, Color(UIStyle.MAGENTA, 0.9))
		for i in 2:
			var y := h - 34.0 + i * 12.0
			_slash(y, y + 8.0, 7.0, 0.9, UIStyle.MAGENTA)

	func _slash(y0: float, y1: float, width: float, lean: float, color: Color) -> void:
		var x0 := 2.0 + (y1 - y0) * lean
		var pts := PackedVector2Array([
			Vector2(x0, y0), Vector2(x0 + width, y0),
			Vector2(x0 + width - (y1 - y0) * lean, y1), Vector2(x0 - (y1 - y0) * lean, y1)])
		draw_colored_polygon(pts, color)


## The TRACK MAP frame: dark glass, a faint grid, a thin magenta border and
## bright angled brackets on the top-left and bottom-right corners.
class _MapPanel extends Control:
	const CUT := 18.0
	const GRID := 26.0

	func _init() -> void:
		name = "MapPanel"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var shape := PackedVector2Array([Vector2(CUT, 0), Vector2(w, 0), Vector2(w, h - CUT),
				Vector2(w - CUT, h), Vector2(0, h), Vector2(0, CUT)])
		draw_colored_polygon(shape, Color(0.05, 0.01, 0.1, 0.72))
		var grid := Color(UIStyle.MAGENTA, 0.07)
		var x := GRID
		while x < w:
			draw_line(Vector2(x, 2), Vector2(x, h - 2), grid, 1.0)
			x += GRID
		var y := GRID
		while y < h:
			draw_line(Vector2(2, y), Vector2(w - 2, y), grid, 1.0)
			y += GRID
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, Color(UIStyle.MAGENTA, 0.55), 1.5, true)
		# Corner brackets.
		var bright := Color(1.0, 0.35, 0.92)
		var tl := PackedVector2Array([Vector2(0, CUT + 46), Vector2(0, CUT), Vector2(CUT, 0), Vector2(CUT + 70, 0)])
		var br := PackedVector2Array([Vector2(w, h - CUT - 46), Vector2(w, h - CUT), Vector2(w - CUT, h), Vector2(w - CUT - 70, h)])
		for b in [tl, br]:
			draw_polyline(b, Color(bright, 0.3), 9.0, true)
			draw_polyline(b, bright, 3.5, true)
