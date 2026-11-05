class_name HudScaler
extends RefCounted
## HUD scale accessibility setting (GDD 11.9). Moves a CanvasLayer's
## controls under one root sized to viewport / scale and scales the layer,
## so anchored and full-screen controls keep fitting the screen.


static func apply(layer: CanvasLayer, hud_scale: float) -> void:
	var root := layer.get_node_or_null("HudScaleRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "HudScaleRoot"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var children := layer.get_children()
		layer.add_child(root)
		for child in children:
			if child is Control:
				child.reparent(root, false)
		var viewport := layer.get_viewport()
		if viewport != null:
			viewport.size_changed.connect(_resize.bind(layer, root))
	layer.scale = Vector2.ONE * hud_scale
	_resize(layer, root)


static func _resize(layer: CanvasLayer, root: Control) -> void:
	if not is_instance_valid(layer) or not is_instance_valid(root) or layer.get_viewport() == null:
		return
	var s := maxf(layer.scale.x, 0.01)
	root.position = Vector2.ZERO
	root.size = layer.get_viewport().get_visible_rect().size / s
