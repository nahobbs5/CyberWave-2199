extends SceneTree
## Dev tool: renders each track's screenshot, used by the race cards on the
## cup screens (TrackCard) and as the loading screen background (LoadingScreen),
## and saves it as assets/ui/tracks/<scene file name>.png.
## Needs a real display (not --headless). Run from the project root:
##   godot --path . -s res://tests/tools/track_cards.gd
##   godot --path . -s res://tests/tools/track_cards.gd -- vegas_overdrive hoia_baciu
##   godot --path . -s res://tests/tools/track_cards.gd -- --size=2560x1440 --ss=2 six_flags_new_orleans
## With no names, every built track in every cup is shot. Names are scene file
## names; tracks outside the cups (test_circuit) can be named too.
##   --size=WxH  output size (default 1920x1080), whatever the window size is:
##               the shot renders in an offscreen viewport.
##   --ss=N      supersampling: render N times larger and scale down (default 1;
##               2 gives smoother edges and foliage, slower).
## Each PNG's .import is set to mipmaps on (so the small cup cards don't
## shimmer) and lossy WebP (so the web build stays small). Then open the
## editor (or run --import) so the new PNGs are imported.
## Hand-made pictures can be dropped in at the same path instead (any 16:9
## size; the cards and loading screen crop to fit). Run this tool with
## --fix-imports afterwards (or tick Mipmaps > Generate in the Import dock).
##
## The camera sits on the road at SPOTS[name] = [lap fraction, height,
## metres back, metres to the side, metres ahead it looks at].

const OUT_DIR := "res://assets/ui/tracks/"
const DEFAULT_SIZE := Vector2i(1920, 1080)
## Import settings every track picture should have (see fix_import()).
const IMPORT_PARAMS := {
	"compress/mode": "1",
	"compress/lossy_quality": "0.85",
	"mipmaps/generate": "true",
}
const DEFAULT_SPOT := [0.02, 6.0, 0.0, 3.0, 45.0]
const SPOTS := {
	"vegas_overdrive": [0.02, 6.0, 0.0, 3.0, 45.0],
}
## Frames to wait so deferred scenery finishes building.
const SETTLE_FRAMES := 180


func _initialize() -> void:
	_go.call_deferred()


var _size := DEFAULT_SIZE
var _ss := 1
var _viewport: SubViewport


func _go() -> void:
	GameSession.scene_changes_enabled = false
	var wanted: PackedStringArray = []
	var fix_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			_size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--ss="):
			_ss = clampi(int(arg.trim_prefix("--ss=")), 1, 4)
		elif arg == "--fix-imports":
			fix_only = true
		else:
			wanted.append(arg)
	if fix_only:
		for f in DirAccess.get_files_at(OUT_DIR):
			if f.get_extension() == "png":
				fix_import(OUT_DIR + f)
		quit()
		return
	_viewport = SubViewport.new()
	_viewport.size = _size * _ss
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(_viewport)
	var scenes: PackedStringArray = []
	for cup in GrandPrixData.all_cups():
		for i in cup.track_names.size():
			if not cup.is_track_built(i):
				continue
			var scene := cup.track_scenes[i] if i < cup.track_scenes.size() else TrackCatalog.scene_path(cup.track_names[i])
			var key := scene.get_file().get_basename()
			if not scenes.has(scene) and (wanted.is_empty() or wanted.has(key)):
				scenes.append(scene)
	# Named tracks outside the cups (e.g. test_circuit) by scene file name.
	for key in wanted:
		var path := "res://scenes/tracks/%s.tscn" % key
		if scenes.has(path):
			continue
		if ResourceLoader.exists(path):
			scenes.append(path)
		elif not Array(scenes).any(func(s: String) -> bool: return s.get_file().get_basename() == key):
			push_warning("track_cards: no track scene named '%s'" % key)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for scene in scenes:
		await _shoot(scene)
	quit()


func _shoot(scene_path: String) -> void:
	var key := scene_path.get_file().get_basename()
	var spot: Array = SPOTS.get(key, DEFAULT_SPOT)
	var node := (load(scene_path) as PackedScene).instantiate()
	_viewport.add_child(node)
	await process_frame
	var track := node as TrackCircuit
	if track == null:
		var found := node.find_children("*", "TrackCircuit", true, false)
		track = found.front() if not found.is_empty() else null
	if track == null:
		push_warning("%s: no TrackCircuit" % scene_path)
		node.queue_free()
		return
	var off := track.wrap_offset(float(spot[0]) * track.curve.get_baked_length())
	var right := track.get_tangent_at(off).cross(Vector3.UP).normalized()
	var cam := Camera3D.new()
	cam.fov = 62
	_viewport.add_child(cam)
	cam.global_position = track.to_global(track.get_center_at(track.wrap_offset(off - float(spot[2])))) \
			+ Vector3.UP * float(spot[1]) + right * float(spot[3])
	cam.look_at(track.to_global(track.get_center_at(track.wrap_offset(off + float(spot[4])))) + Vector3.UP)
	cam.current = true
	for i in SETTLE_FRAMES:
		await process_frame
	var out := OUT_DIR + key + ".png"
	var image := _viewport.get_texture().get_image()
	if _ss > 1:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	image.save_png(ProjectSettings.globalize_path(out))
	fix_import(out)
	print("saved %s (%dx%d)" % [out, image.get_width(), image.get_height()])
	cam.queue_free()
	node.queue_free()
	await process_frame
	await process_frame


## Sets IMPORT_PARAMS in a track picture's .import file (written fresh if the
## picture hasn't been imported yet). Returns true if it changed anything.
static func fix_import(png_path: String) -> bool:
	var import_path := ProjectSettings.globalize_path(png_path + ".import")
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		cfg.set_value("remap", "importer", "texture")
		cfg.set_value("remap", "type", "CompressedTexture2D")
	var changed := false
	for key: String in IMPORT_PARAMS:
		var want: Variant = str_to_var(IMPORT_PARAMS[key])
		if not cfg.has_section_key("params", key) or cfg.get_value("params", key) != want:
			cfg.set_value("params", key, want)
			changed = true
	if changed:
		cfg.save(import_path)
		print("import settings fixed: ", png_path)
	return changed
