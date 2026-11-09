class_name SplitScreen
extends Node
## Local split screen for 2-4 players (Mario Kart style). Built by
## RaceManager when the race config has more than one player.
##   2P   top half / bottom half
##   3P   P1 top left, P2 top right, P3 bottom left, a spectator camera
##        cutting between other cars bottom right
##   4P   one quarter each
## Every view is a SubViewport sharing the race's 3D world, with its own
## ChaseCamera, speed / drift panel and RaceHUD (which then lays out at the
## view's size). On top sits one shared overlay: the dividers, a single
## minimap (centre for 3-4P, right edge on the divider for 2P) and the
## results screen, which opens once every player is done.
##
## Some things are only for one player: their wrong-way sign and lock-on
## ring go on that player's private render layer, and the "P2" tag over a
## car is hidden from its own driver. Each camera's cull mask picks these.

const PLAYER_COLORS: Array[Color] = [
	Color(0.0, 0.9, 1.0), # P1 cyan
	Color(1.0, 0.2, 0.75), # P2 magenta
	Color(1.0, 0.78, 0.2), # P3 gold
	Color(0.3, 1.0, 0.45), # P4 green
]
const PROTOTYPE_HUD := preload("res://scenes/ui/prototype_hud.tscn")
## Render layer bits 11-14: drawn only in that player's view.
const PRIVATE_BIT := 10
## Render layer bits 15-18: drawn in every view except that player's.
const TAG_BIT := 14
const DIVIDER := 3.0
## HUD scale in a half-screen and in a quarter-screen view.
const HALF_HUD_SCALE := 0.72
const QUARTER_HUD_SCALE := 0.6

var race: RaceManager
## One per player, by player slot.
var views: Array[SubViewport] = []
var containers: Array[SubViewportContainer] = []
var cameras: Array[ChaseCamera] = []
var huds: Array[RaceHUD] = []
var prototype_huds: Array[PrototypeHUD] = []
## 3P only: the bottom-right "elsewhere on track" view.
var spectator: SpectatorCamera
var spectator_view: SubViewport
var spectator_container: SubViewportContainer
## Shared overlay: minimap and results.
var overlay: CanvasLayer
var minimap: Minimap
var results: ResultsScreen

var _views_layer: CanvasLayer
var _root: Control
var _dividers: Array[ColorRect] = []


static func private_layer(slot: int) -> int:
	return 1 << (PRIVATE_BIT + slot)


static func tag_layer(slot: int) -> int:
	return 1 << (TAG_BIT + slot)


## What player `slot`'s camera draws (-1 = the spectator: no private layers,
## every tag).
static func camera_mask(slot: int) -> int:
	var mask := 0xFFFFF
	for i in 4:
		mask &= ~private_layer(i)
	if slot >= 0:
		mask |= private_layer(slot)
		mask &= ~tag_layer(slot)
	return mask


## Puts every visual under `node` on these render layers only.
static func set_render_layer(node: Node, layers: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers
	for child in node.get_children():
		set_render_layer(child, layers)


## View rects (layout space) for `players` humans in a screen of `size`.
## 3P returns four: the last is the spectator's.
static func view_rects(players: int, size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half := size * 0.5
	if players <= 2:
		rects.append(Rect2(0, 0, size.x, half.y))
		rects.append(Rect2(0, half.y, size.x, size.y - half.y))
		return rects
	rects.append(Rect2(0, 0, half.x, half.y))
	rects.append(Rect2(half.x, 0, size.x - half.x, half.y))
	rects.append(Rect2(0, half.y, half.x, size.y - half.y))
	rects.append(Rect2(half.x, half.y, size.x - half.x, size.y - half.y))
	return rects


func view_count() -> int:
	return views.size() + (1 if spectator_view != null else 0)


## The rect each view covers, in layout space (tests).
func view_rect(index: int) -> Rect2:
	var c := containers[index] if index < containers.size() else spectator_container
	return Rect2(c.position, c.size * c.scale)


func setup(manager: RaceManager, template: ChaseCamera) -> void:
	race = manager
	var count := race.players.size()
	_views_layer = CanvasLayer.new()
	_views_layer.name = "Views"
	_views_layer.layer = -1
	add_child(_views_layer)
	_root = Control.new()
	_root.name = "ViewsRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_views_layer.add_child(_root)

	var hud_scale := GameSettings.hud_scale * (HALF_HUD_SCALE if count <= 2 else QUARTER_HUD_SCALE)
	for i in count:
		var human := race.players[i]
		var view := _make_view("P%dView" % (i + 1), i == 0)
		var camera := template.duplicate() as ChaseCamera
		camera.name = "Camera"
		camera.save_preference = i == 0 # player 1's view choice is the one remembered
		camera.input_prefix = StringName(InputSetup.player_prefix(i))
		camera.cull_mask = camera_mask(i)
		view.add_child(camera)
		camera.current = true
		camera.set_target(human.vehicle)
		cameras.append(camera)

		var proto := PROTOTYPE_HUD.instantiate() as PrototypeHUD
		proto.show_lap_info = false
		view.add_child(proto)
		proto.setup(human.vehicle, camera, race.track)
		prototype_huds.append(proto)

		var hud := RaceHUD.new()
		hud.name = "RaceHUD"
		hud.racer = human
		hud.split_view = true
		hud.hide_standings = count > 2
		hud.prototype_hud = proto
		view.add_child(hud)
		hud.setup(race)
		HudScaler.apply(hud, hud_scale)
		HudScaler.apply(proto, hud_scale)
		huds.append(hud)
		_clear_centre(i, count, hud, proto)

	if count == 3:
		spectator_view = _make_view("SpectatorView", false)
		spectator_container = spectator_view.get_parent() as SubViewportContainer
		containers.erase(spectator_container)
		views.erase(spectator_view)
		spectator = SpectatorCamera.new()
		spectator.name = "Spectator"
		spectator.far_chase = template.far_chase
		spectator.cull_mask = camera_mask(-1)
		spectator_view.add_child(spectator)
		spectator.current = true
		spectator.setup(race)
		var label_layer := CanvasLayer.new()
		spectator_view.add_child(label_layer)
		var caption := spectator.make_caption()
		label_layer.add_child(caption)
		HudScaler.apply(label_layer, hud_scale)
		# Its top-left corner is under the minimap.
		to_bottom_right(caption)

	for i in (1 if count == 2 else 2):
		var line := ColorRect.new()
		line.color = Color(UIStyle.MAGENTA, 0.9)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(line)
		_dividers.append(line)

	_build_overlay(count)
	get_viewport().size_changed.connect(_layout)
	_layout()


## The shared minimap covers each view's corner nearest the middle of the
## screen, so whatever HUD panel sits there moves to the view's bottom-right
## corner, which is free in split screen (Mario Kart style: HUD at the
## outer edges).
func _clear_centre(slot: int, count: int, hud: RaceHUD, proto: PrototypeHUD) -> void:
	if count == 2 and slot == 1:
		to_bottom_right(hud.items) # bottom half: items were top right
	elif count >= 3:
		match slot:
			1:
				to_bottom_right(proto.speed_panel) # top right: speed was bottom left
			2:
				to_bottom_right(hud.items) # bottom left: items were top right
			3:
				to_bottom_right(hud.info_column()) # bottom right: info was top left


static func to_bottom_right(control: Control, margin: float = 20.0) -> void:
	control.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var size := control.get_combined_minimum_size()
	control.offset_left = -margin - size.x
	control.offset_right = -margin
	control.offset_top = -margin - size.y
	control.offset_bottom = -margin


func _make_view(view_name: String, listener: bool) -> SubViewport:
	var container := SubViewportContainer.new()
	container.name = view_name + "Container"
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(container)
	var view := SubViewport.new()
	view.name = view_name
	view.size_2d_override_stretch = true
	view.audio_listener_enable_3d = listener
	view.handle_input_locally = false
	# Match the main window's quality settings (a SubViewport's own default
	# has no shadow atlas, so lamps would lose their shadows).
	var main := get_viewport()
	view.msaa_3d = main.msaa_3d
	view.screen_space_aa = main.screen_space_aa
	view.use_debanding = main.use_debanding
	view.scaling_3d_mode = main.scaling_3d_mode
	view.scaling_3d_scale = main.scaling_3d_scale
	view.positional_shadow_atlas_size = main.positional_shadow_atlas_size
	view.positional_shadow_atlas_16_bits = main.positional_shadow_atlas_16_bits
	container.add_child(view)
	containers.append(container)
	views.append(view)
	return view


func _build_overlay(count: int) -> void:
	overlay = CanvasLayer.new()
	overlay.name = "SharedOverlay"
	overlay.layer = 5
	add_child(overlay)
	var anchor := Control.new()
	anchor.name = "MinimapAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap = Minimap.new()
	minimap.name = "Minimap"
	if count <= 2:
		# On the right end of the divider.
		anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		minimap.position = Vector2(-Minimap.MAP_SIZE.x - 16.0, -Minimap.MAP_SIZE.y * 0.5)
	else:
		# Where the four views meet.
		anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		minimap.position = -Minimap.MAP_SIZE * 0.5
	overlay.add_child(anchor)
	anchor.add_child(minimap)
	minimap.setup(race)

	results = ResultsScreen.new()
	overlay.add_child(results)
	results.continue_pressed.connect(func() -> void: race.continue_after_results())
	results.menu_pressed.connect(func() -> void: race.quit_to_menu())
	race.all_players_finished.connect(func() -> void:
		for hud in huds:
			hud.announcer.announce("", 0.01, Color.WHITE)
		minimap.get_parent().visible = false
		PodiumCeremony.open_then(race, results))
	HudScaler.apply(overlay, GameSettings.hud_scale)


## Places the views to fill the window. Each view renders at the window's
## real pixel size (not the 1280x720 layout size), so split views stay sharp
## on big screens, while its HUD still lays out in layout units.
func _layout() -> void:
	if _root == null:
		return
	var size := get_viewport().get_visible_rect().size
	var window_px := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else size
	var pixels := maxf(0.25, window_px.y / maxf(size.y, 1.0))
	var rects := view_rects(race.players.size(), size)
	var all: Array[SubViewportContainer] = containers.duplicate()
	if spectator_container != null:
		all.append(spectator_container)
	for i in all.size():
		var rect := rects[i]
		var container := all[i]
		var view := container.get_child(0) as SubViewport
		var px := Vector2i((rect.size * pixels).round()).max(Vector2i.ONE)
		view.size = px
		view.size_2d_override = Vector2i(rect.size.round()).max(Vector2i.ONE)
		container.position = rect.position
		container.size = Vector2(px)
		container.scale = Vector2.ONE / pixels
	if not _dividers.is_empty():
		_dividers[0].position = Vector2(0, size.y * 0.5 - DIVIDER * 0.5)
		_dividers[0].size = Vector2(size.x, DIVIDER)
	if _dividers.size() > 1:
		_dividers[1].position = Vector2(size.x * 0.5 - DIVIDER * 0.5, 0)
		_dividers[1].size = Vector2(DIVIDER, size.y)
