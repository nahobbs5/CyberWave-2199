extends SceneTree
## Scratch: Crazy House screenshots from several spots (temporary).
const SPOTS := {
	"root": [Vector3(-230, 4, 25), Vector3(-60, 7, 0)],
	"well": [Vector3(170, 4, 10), Vector3(300, 14, 130)],
	"rooms": [Vector3(515, 4, 150), Vector3(560, 6, 330)],
	"gables": [Vector3(545, 4, 365), Vector3(420, 8, 390)],
	"lava": [Vector3(410, 4, 610), Vector3(250, 6, 680)],
	"bones": [Vector3(-300, 4, 560), Vector3(-250, 8, 400)],
	"tunnel": [Vector3(240, 3, 445), Vector3(60, 4, 470)],
}

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var only := OS.get_cmdline_user_args().slice(1)
	var track := (load("res://scenes/tracks/crazy_house.tscn") as PackedScene).instantiate()
	root.add_child(track)
	var cam := Camera3D.new()
	cam.fov = 70
	root.add_child(cam)
	cam.current = true
	for name in SPOTS:
		if not only.is_empty() and not only.has(name):
			continue
		cam.position = SPOTS[name][0]
		cam.look_at(SPOTS[name][1])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
		print("saved ", name)
	quit()
