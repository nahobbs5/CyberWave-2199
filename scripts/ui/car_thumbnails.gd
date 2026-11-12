class_name CarThumbnails
extends RefCounted
## Small pictures of cars: every car in its stock colours (the split-screen
## car strip), or each racer's car in its own look (the results table, see
## request_looks). There are no car image files, so they're rendered in a
## hidden SubViewport (front three-quarter view, transparent background).
## Stock pictures are kept for the rest of the run; look pictures only until
## the next request_looks. Headless runs have no renderer, so nothing is
## rendered there and callers draw empty frames.

const SIZE := Vector2i(240, 128)

## Vehicle id -> Texture2D.
static var _cache: Dictionary = {}
static var _busy: bool = false
static var _waiters: Array[Callable] = []
## Racer id -> Texture2D, from the last request_looks.
static var _look_cache: Dictionary = {}
## Bumped by each request_looks, so an older render that finishes late is dropped.
static var _look_job: int = 0


## The car's picture, or null while it isn't rendered (yet).
static func get_texture(vehicle_id: String) -> Texture2D:
	return _cache.get(vehicle_id)


static func is_done() -> bool:
	return _cache.size() >= VehicleCatalog.all().size()


## Renders the pictures if needed, then calls `on_ready` (straight away
## when they're already cached; never when there's no renderer).
static func request(tree: SceneTree, on_ready: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_done():
		on_ready.call()
		return
	_waiters.append(on_ready)
	if not _busy:
		_busy = true
		_render(tree)


## A racer's picture from the last request_looks, or null (not yet / headless).
static func get_look_texture(id: int) -> Texture2D:
	return _look_cache.get(id)


## Renders a picture per racer: `looks` is racer id -> RaceManager.racer_look()
## dictionary. `sizes` (optional) gives some ids a bigger picture (Vector2i).
## Calls `on_ready` once they're all done (never when there's no renderer).
static func request_looks(tree: SceneTree, looks: Dictionary, on_ready: Callable, sizes: Dictionary = {}) -> void:
	_look_cache.clear()
	_look_job += 1
	if DisplayServer.get_name() == "headless" or looks.is_empty():
		return
	_render_looks(tree, looks, on_ready, sizes, _look_job)


static func _render_looks(tree: SceneTree, looks: Dictionary, on_ready: Callable, sizes: Dictionary, job: int) -> void:
	var stage := _make_stage(tree, SIZE)
	var vp: SubViewport = stage[0]
	var car: VehicleController = stage[1]
	for id in looks:
		vp.size = sizes.get(id, SIZE)
		RaceManager.apply_look(car, looks[id])
		_lower_wheels(car)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if job != _look_job:
			vp.queue_free()
			return
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			_look_cache[id] = ImageTexture.create_from_image(img)
	vp.queue_free()
	if job == _look_job and on_ready.is_valid():
		on_ready.call()


static func _lower_wheels(car: VehicleController) -> void:
	for child in car.get_children():
		if child.name.begins_with("Wheel"):
			var wheel_pivot := child.get_node_or_null("Pivot") as Node3D
			if wheel_pivot != null:
				wheel_pivot.position.y = -0.38


static func _render(tree: SceneTree) -> void:
	var stage := _make_stage(tree, SIZE)
	var vp: SubViewport = stage[0]
	var car: VehicleController = stage[1]
	for v in VehicleCatalog.all():
		VehicleCosmetics.apply(car, v, {}, "")
		await tree.process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			_cache[v.id] = ImageTexture.create_from_image(img)
	vp.queue_free()
	_busy = false
	var waiting := _waiters.duplicate()
	_waiters.clear()
	for w: Callable in waiting:
		if w.is_valid():
			w.call()


## The hidden picture stage: [SubViewport, car].
static func _make_stage(tree: SceneTree, px: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.85)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.6
	fill.light_color = Color(0.75, 0.85, 1.0)
	vp.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 24.0
	vp.add_child(camera)
	camera.position = Vector3(5.2, 1.9, 5.2)
	camera.look_at(Vector3(0, 0.05, 0))
	var pivot := Node3D.new()
	pivot.rotation.y = VehiclePreview.START_YAW
	vp.add_child(pivot)
	var car := (load(VehiclePreview.CAR_SCENE) as PackedScene).instantiate() as VehicleController
	car.freeze = true
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.player_controlled = false
	car.is_player = false
	pivot.add_child(car)
	_lower_wheels(car)
	return [vp, car]
