class_name TrackThumbnail
extends Control
## A track's outline for menu cards, from its TrackCircuit control points.
## Read from the baked TrackOutlines (no scene loading); a scene missing from
## it is read from the scene itself. Outlines are cached per scene.

static var _cache: Dictionary = {}
static var _baked: TrackOutlines

var outline: PackedVector2Array = PackedVector2Array()


func _init(scene_path: String = "", side: Vector2 = Vector2(220, 150)) -> void:
	custom_minimum_size = side
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if scene_path != "":
		outline = control_points_2d(scene_path)


## The track's control points seen from above (x, z), or empty.
static func control_points_2d(scene_path: String) -> PackedVector2Array:
	if _cache.has(scene_path):
		return _cache[scene_path]
	if _baked == null:
		_baked = TrackOutlines.baked()
	var out: PackedVector2Array
	if _baked != null and _baked.outlines.has(scene_path):
		out = _baked.outlines[scene_path]
	else:
		push_warning("TrackThumbnail: %s isn't in %s; loading the scene (rebake outlines)" % [scene_path, TrackOutlines.PATH])
		out = TrackOutlines.read_from_scene(scene_path)
	_cache[scene_path] = out
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.02, 0.12, 0.7))
	if outline.size() < 3:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		lo = lo.min(p)
		hi = hi.max(p)
	var span := (hi - lo).max(Vector2.ONE)
	var room := size - Vector2.ONE * 20.0
	var s := minf(room.x / span.x, room.y / span.y)
	var offset := (size - span * s) * 0.5
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(offset + (p - lo) * s)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.22, 0.16, 0.32, 0.95), 8.0, true)
	draw_polyline(pts, UIStyle.MAGENTA, 2.5, true)
	# Start: a white tick across the first segment.
	var dir := (pts[1] - pts[0]).normalized()
	var across := Vector2(-dir.y, dir.x) * 7.0
	draw_line(pts[0] - across, pts[0] + across, Color.WHITE, 3.0)
