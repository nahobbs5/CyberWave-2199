extends SceneTree
## Scratch: Vale da Lua screenshots from several spots (temporary).
const SPOTS := {
	"start": [Vector3(-40, 4, -20), Vector3(150, -1, -28)],
	"falls": [Vector3(115, 5, 118), Vector3(178, -9, 200)],
	"shelf": [Vector3(330, 4, 12), Vector3(440, -1, 70)],
	"behind": [Vector3(500, 4, 372), Vector3(500, 3, 470)],
	"gorge": [Vector3(175, 5, 668), Vector3(70, -8, 610)],
	"east": [Vector3(305, 5, 205), Vector3(222, -9, 240)],
}

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var only := OS.get_cmdline_user_args().slice(1)
	var track := (load("res://scenes/tracks/vale_da_lua.tscn") as PackedScene).instantiate()
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
