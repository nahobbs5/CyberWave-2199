class_name LoadingScreen
extends CanvasLayer
## Full-screen track card shown while a slow scene loads (races, free drive).
## Tracks build their road, barriers and scenery in _ready on the main
## thread, so the game can't animate during that time; the card is drawn
## first, then the scene changes underneath it, and it fades out once the
## new scene has rendered a frame. It lives on the tree root so it survives
## the scene change. RaceManager waits for `closed` before the countdown.

signal closed

const FADE := 0.3
## Frames to wait so the card is on screen before the blocking load, and
## after the new scene so its first frame (and shader warm-up) is done.
const FRAMES_BEFORE := 2
const FRAMES_AFTER := 2

## The loading screen on screen now, or null.
static var active: LoadingScreen

var title_label: Label
var detail_label: Label
var thumbnail: TrackThumbnail
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
	var loading := UIStyle.heading("LOADING...", 24, UIStyle.CYAN)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(loading)


func _run(path: String) -> void:
	var tree := get_tree()
	for i in FRAMES_BEFORE:
		await tree.process_frame
	tree.change_scene_to_file(path)
	await tree.scene_changed
	for i in FRAMES_AFTER:
		await tree.process_frame
	await dismiss()


## Fades out, emits `closed` and frees the screen.
func dismiss() -> void:
	if is_inside_tree() and _root != null:
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, FADE)
		await tween.finished
	if active == self:
		active = null
	closed.emit()
	queue_free()
