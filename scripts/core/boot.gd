class_name Boot
extends Control
## The first scene: the boot splash's skyline, in the same place, with a
## progress bar under it while the title menu (and every script it pulls in)
## loads on worker threads. Kept free of other game scripts so it starts at once.

const NEXT_SCENE := "res://scenes/menu/title_menu.tscn"
const SPLASH := preload("res://assets/logo/splash_skyline.png")
const BAR_COLOR := Color(0.0, 0.95, 1.0)
const BAR_SIZE := Vector2(420, 6)
## Gap between the bottom of the skyline and the bar, in screen pixels.
const BAR_GAP := 28.0

var progress_bar: ProgressBar
var _image: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_image = TextureRect.new()
	_image.texture = SPLASH
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_image)
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 1.0
	progress_bar.step = 0.0
	progress_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLOR
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", back)
	add_child(progress_bar)
	_layout()
	get_viewport().size_changed.connect(_layout)
	_load.call_deferred()


## The engine's splash (stretch mode Disabled) draws the image at its own pixel
## size in the middle of the window; match that through the UI's stretch.
func _layout() -> void:
	var scale_factor := get_viewport().get_final_transform().get_scale().x
	if scale_factor <= 0.0:
		scale_factor = 1.0
	var image_size := Vector2(SPLASH.get_size()) / scale_factor
	var view := get_viewport_rect().size
	_image.size = image_size
	_image.position = ((view - image_size) * 0.5).round()
	var bar_size := BAR_SIZE / scale_factor
	progress_bar.custom_minimum_size = bar_size
	progress_bar.size = bar_size
	progress_bar.position = Vector2((view.x - bar_size.x) * 0.5, _image.position.y + image_size.y + BAR_GAP / scale_factor)


func _load() -> void:
	var tree := get_tree()
	if ResourceLoader.load_threaded_request(NEXT_SCENE, "", true) != OK:
		tree.change_scene_to_file(NEXT_SCENE)
		return
	var progress := []
	while ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():
			progress_bar.value = maxf(progress_bar.value, float(progress[0]))
		await tree.process_frame
	progress_bar.value = 1.0
	await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(NEXT_SCENE) as PackedScene
	if scene != null:
		tree.change_scene_to_packed(scene)
	else:
		tree.change_scene_to_file(NEXT_SCENE)
