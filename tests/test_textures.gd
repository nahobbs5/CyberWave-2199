extends SceneTree
## Every track is textured: road, walls and ground use Poly Haven sets (or a
## deliberate material such as Gardens' glass), every texture a track or a
## scenery script names exists, and the procedural shaders carry the
## optional Poly Haven detail. Quick (no track is built). Run from the
## project root:
##   godot --headless --import
##   godot --headless -s res://tests/test_textures.gd

const TEXTURES := "res://assets/textures/polyhaven/%s/%s_diff_1k.jpg"
const SCRIPT_DIRS := ["res://scripts/track/", "res://scripts/track/scenery/"]
const DETAIL_SHADERS := ["res://assets/shaders/moon_rock.gdshader", "res://assets/shaders/glacier_ice.gdshader",
		"res://assets/shaders/crazy_house.gdshader"]

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_tracks()
	_test_scenery_scripts()
	_test_shaders()
	print("\n%d checks passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _exists(texture_name: String) -> bool:
	return ResourceLoader.exists(TEXTURES % [texture_name, texture_name])


func _test_tracks() -> void:
	_current = "tracks"
	print("- road, walls and ground on every track")
	for track_name in TrackCatalog.names():
		var track := TrackCatalog.scene(track_name).instantiate() as TrackCircuit
		var road := track.road_material != null or _exists(track.road_texture)
		var walls := track.barrier_material != null or _exists(track.barrier_texture)
		var ground := _exists(track.ground_texture)
		_check(road and walls and ground, "%s: road %s, walls %s, ground %s" % [track_name,
				"material" if track.road_material != null else track.road_texture,
				"material" if track.barrier_material != null else track.barrier_texture, track.ground_texture])
		track.free()


## Texture names in textured(...), texture_material(...), shader_detail(...)
## and _set_rock_textures(...) calls across the scenery scripts.
func _test_scenery_scripts() -> void:
	_current = "scenery scripts"
	print("- every texture a scenery script names exists")
	var patterns := [
		'textured\\("[^"]*",\\s*"([a-z0-9_]+)"',
		'texture_material\\("([a-z0-9_]+)"',
		'shader_detail\\([^,]+,\\s*"([a-z0-9_]+)"',
		'_set_rock_textures\\([^,]+,\\s*"([a-z0-9_]+)",\\s*"([a-z0-9_]+)"',
	]
	var regexes: Array[RegEx] = []
	for p in patterns:
		var re := RegEx.new()
		re.compile(p)
		regexes.append(re)
	var named := {}
	var missing := []
	for dir_path in SCRIPT_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path + file)
			for re in regexes:
				for m in re.search_all(text):
					for g in range(1, m.get_group_count() + 1):
						var texture_name := m.get_string(g)
						named[texture_name] = true
						if not _exists(texture_name):
							missing.append("%s in %s" % [texture_name, file])
	_check(named.size() >= 30, "scenery scripts use many texture sets (%d)" % named.size())
	_check(missing.is_empty(), "no missing texture sets (%s)" % [missing])
	for key: String in ["vegas_scenery.gd", "glacier_scenery.gd", "vale_da_lua_scenery.gd", "crazy_house_scenery.gd"]:
		var text := FileAccess.get_file_as_string("res://scripts/track/" + key)
		_check(text.contains("textured(") or text.contains("shader_detail("), "%s uses Poly Haven textures" % key)


func _test_shaders() -> void:
	_current = "shaders"
	print("- procedural shaders take Poly Haven detail")
	for path: String in DETAIL_SHADERS:
		var shader := load(path) as Shader
		var names := []
		for u in shader.get_shader_uniform_list(true):
			names.append(u["name"])
		_check(names.has("detail_albedo") and names.has("detail_normal") and names.has("detail_strength"),
				"%s has detail uniforms" % path.get_file())
