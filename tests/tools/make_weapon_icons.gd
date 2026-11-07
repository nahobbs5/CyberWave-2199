extends SceneTree
## Dev tool: builds the advanced-weapon HUD icons (192x192 PNGs, like the
## others in assets/ui/weapons). The drone and Overdrive icons are crops of
## the concept art; System Override is a symbol drawn as SVG
## (system_override_icon.svg.txt, kept as .txt so Godot doesn't import it).
##   godot --headless -s res://tests/tools/make_weapon_icons.gd
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = [ProjectSettings.globalize_path("res://tests/tools/system_override_icon.svg.txt")]
	var art := "res://reference files/Weapons concept_art/"
	_crop(art + "hunter_killer_drone.png", "res://assets/ui/weapons/hunter_killer_drone.png", 26)
	_crop(art + "overdrive_protocol.png", "res://assets/ui/weapons/overdrive_protocol.png", 14)
	var svg := FileAccess.get_file_as_string(args[0])
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	print("svg ", err, " ", img.get_size())
	img.convert(Image.FORMAT_RGB8)
	img.save_png("res://assets/ui/weapons/system_override.png")
	quit()

## Square centre crop below `top` px (skips the concept sheet's title bar).
func _crop(src: String, dst: String, top: int) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	var side := mini(img.get_width(), img.get_height() - top - 4)
	var x := (img.get_width() - side) / 2
	var y := top
	var square := img.get_region(Rect2i(x, y, side, side))
	square.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	square.convert(Image.FORMAT_RGB8)
	print(dst, " ", square.save_png(dst))
