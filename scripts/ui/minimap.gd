class_name Minimap
extends Control
## Race minimap (GDD 11.5), bottom-right of the race HUD. Draws the circuit
## (and any shortcuts, dimmer), the start line, the elimination gate in
## Elimination, every active racer as a dot in their colour, and the player
## as a larger arrow showing their heading. North-up in layout space.

const MAP_SIZE := Vector2(250, 200)
const PADDING := 12.0

var race: RaceManager

var _main: PackedVector2Array = PackedVector2Array()
var _shortcuts: Array[PackedVector2Array] = []
var _bounds_min := Vector2.ZERO
var _scale: float = 1.0
var _origin := Vector2.ZERO


func _init() -> void:
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(manager: RaceManager) -> void:
	race = manager
	var track := race.track
	_main = _sample(track, track.curve, 8.0, true)
	_shortcuts.clear()
	for sc in track.shortcuts:
		_shortcuts.append(_sample(track, sc.curve, 6.0, false))
	# Fit everything into the rect, keeping the aspect ratio.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var all := _main.duplicate()
	for line in _shortcuts:
		all.append_array(line)
	for p in all:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := (hi - lo).max(Vector2.ONE)
	var room := MAP_SIZE - Vector2.ONE * PADDING * 2.0
	_scale = minf(room.x / span.x, room.y / span.y)
	_bounds_min = lo
	_origin = Vector2.ONE * PADDING + (room - span * _scale) * 0.5
	queue_redraw()


## Map position (in this control) of a world position.
func world_to_map(world: Vector3) -> Vector2:
	var local := race.track.to_local(world)
	return _origin + (Vector2(local.x, local.z) - _bounds_min) * _scale


## Racers currently drawn (tests).
func visible_racers() -> Array[RaceProgress]:
	var out: Array[RaceProgress] = []
	if race == null:
		return out
	for racer in race.racers:
		if not racer.eliminated and is_instance_valid(racer.vehicle) and racer.vehicle.visible:
			out.append(racer)
	return out


func shortcut_count() -> int:
	return _shortcuts.size()


func _sample(track: TrackCircuit, curve: Curve3D, step: float, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var length := curve.get_baked_length()
	var d := 0.0
	while d < length:
		var p := curve.sample_baked(d)
		out.append(Vector2(p.x, p.z))
		d += step
	var last := curve.sample_baked(length)
	out.append(Vector2(last.x, last.z))
	if closed and out.size() > 1:
		out.append(out[0])
	return out


func _to_map(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = _origin + (points[i] - _bounds_min) * _scale
	return out


func _process(_delta: float) -> void:
	if race != null and visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.02, 0.01, 0.06, 0.6))
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(1.0, 0.2, 0.85, 0.5), false, 1.5)
	if race == null or _main.size() < 2:
		return
	var track := race.track
	for line in _shortcuts:
		var mapped := _to_map(line)
		draw_polyline(mapped, Color(0.35, 0.3, 0.45, 0.9), 5.0, true)
		draw_polyline(mapped, Color(0.0, 0.9, 1.0, 0.45), 1.5, true)
	var main := _to_map(_main)
	draw_polyline(main, Color(0.35, 0.33, 0.45), 7.0, true)
	draw_polyline(main, Color(1.0, 0.25, 0.85), 2.0, true)
	_draw_tick(track, track.start_line_offset, Color.WHITE)
	if race.elimination != null:
		_draw_tick(track, track.get_checkpoint_offset(race.elimination.gate_index), Color(1.0, 0.2, 0.3))
	for racer in visible_racers():
		if racer.is_player:
			continue
		draw_circle(world_to_map(racer.vehicle.global_position), 3.5, racer.color.lightened(0.35))
	if race.player != null and not race.player.eliminated:
		var car := race.player.vehicle
		var p := world_to_map(car.global_position)
		var fwd3 := race.track.global_transform.basis.inverse() * -car.global_transform.basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		if fwd == Vector2.ZERO:
			fwd = Vector2.UP
		var side := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([p + fwd * 8.0, p - fwd * 5.0 + side * 5.0, p - fwd * 5.0 - side * 5.0])
		draw_colored_polygon(tri, Color(1.0, 0.2, 0.85))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.2, true)


func _draw_tick(track: TrackCircuit, offset: float, color: Color) -> void:
	var c := track.get_center_at(offset)
	var right := track.get_tangent_at(offset).cross(Vector3.UP).normalized() * (track.road_width * 0.9)
	draw_line(world_to_map(c - right), world_to_map(c + right), color, 3.0)
