class_name SwahiliHouseBuilder
extends RefCounted
## Swahili coast village houses for a TrackScenery (Kilwa Kisiwani): one
## storey, coral-rag walls with patchy lime plaster, a dark carved wooden
## door in a dressed frame, small shuttered windows, and a steep makuti
## (palm-thatch) roof on most; some flat-roofed with a parapet, some
## roofless ruins. Visual only.
##
## Materials (keys): wall keys passed in (plastered and bare coral rag),
## frame (dressed stone), door (dark wood), shutter, thatch, rubble.

var scenery: TrackScenery
var wall_keys: Array[String] = []
var houses: int = 0
var thatched: int = 0
var ruined: int = 0


func _init(p_scenery: TrackScenery, p_wall_keys: Array[String]) -> void:
	scenery = p_scenery
	wall_keys = p_wall_keys


## A house on the ground at xf (local X along its length, -Z = the street
## side with the door). opts: ruined (bool), flat (bool).
func house(xf: Transform3D, length: float, depth: float, opts: Dictionary = {}) -> void:
	var rng := scenery.rng
	var wall_key: String = wall_keys[rng.randi() % wall_keys.size()]
	var ruin := bool(opts.get("ruined", false))
	var flat := bool(opts.get("flat", false))
	var wall_h := rng.randf_range(3.0, 3.6)
	var t := 0.45
	houses += 1
	if ruin:
		ruined += 1
	# Four walls (a ruin has broken, uneven tops).
	var walls := [
		[Vector3(0, 0, -depth * 0.5 + t * 0.5), length, 0.0],
		[Vector3(0, 0, depth * 0.5 - t * 0.5), length, 0.0],
		[Vector3(-length * 0.5 + t * 0.5, 0, 0), depth, PI * 0.5],
		[Vector3(length * 0.5 - t * 0.5, 0, 0), depth, PI * 0.5],
	]
	for i in walls.size():
		var w: Array = walls[i]
		var wxf := xf * Transform3D(Basis(Vector3.UP, w[2]), w[0])
		var wl: float = w[1]
		if ruin:
			var pieces := 3
			for k in pieces:
				var h := wall_h * rng.randf_range(0.25, 1.0)
				if rng.randf() < 0.25:
					continue
				var seg := wl / pieces
				scenery.add_box(wall_key, Vector3(seg, h, t), wxf.translated_local(Vector3(-wl * 0.5 + seg * (k + 0.5), h * 0.5, 0)))
		elif i == 0:
			# Street wall with the doorway in the middle.
			var door_w := 1.3
			var side_w := (wl - door_w) * 0.5
			for s in [-1.0, 1.0]:
				scenery.add_box(wall_key, Vector3(side_w, wall_h, t),
						wxf.translated_local(Vector3(s * (door_w + side_w) * 0.5, wall_h * 0.5, 0)))
			scenery.add_box(wall_key, Vector3(door_w, wall_h - 2.3, t), wxf.translated_local(Vector3(0, 2.3 + (wall_h - 2.3) * 0.5, 0)))
			# Carved door, stone frame, a window either side.
			scenery.add_box("door", Vector3(door_w, 2.3, 0.12), wxf.translated_local(Vector3(0, 1.15, 0.05)))
			scenery.add_box("frame", Vector3(door_w + 0.5, 0.3, t + 0.12), wxf.translated_local(Vector3(0, 2.45, 0)))
			for s in [-1.0, 1.0]:
				scenery.add_box("frame", Vector3(0.22, 2.3, t + 0.1), wxf.translated_local(Vector3(s * (door_w * 0.5 + 0.11), 1.15, 0)))
				if side_w > 1.6:
					scenery.add_box("shutter", Vector3(0.7, 0.8, t + 0.06),
							wxf.translated_local(Vector3(s * (door_w * 0.5 + side_w * 0.5), 1.9, 0)))
		else:
			scenery.add_box(wall_key, Vector3(wl, wall_h, t), wxf.translated_local(Vector3(0, wall_h * 0.5, 0)))
	if ruin:
		for k in 3:
			var p := xf * Vector3(rng.randf_range(-length * 0.6, length * 0.6), 0, rng.randf_range(-depth * 0.7, depth * 0.7))
			var s := rng.randf_range(0.4, 0.9)
			scenery.add_box("rubble", Vector3(s * 1.4, s * 0.6, s), scenery.xform(p + Vector3(0, s * 0.25, 0), rng.randf() * TAU))
		return
	if flat:
		scenery.add_box(wall_key, Vector3(length, 0.3, depth), xf.translated_local(Vector3(0, wall_h + 0.15, 0)))
		for s in [-1.0, 1.0]:
			scenery.add_box(wall_key, Vector3(length, 0.6, t), xf.translated_local(Vector3(0, wall_h + 0.6, s * (depth * 0.5 - t * 0.5))))
		return
	# Makuti roof: a steep hip roof overhanging the walls.
	thatched += 1
	var over := 0.6
	var rise := depth * 0.55
	var hl := length * 0.5 + over
	var hd := depth * 0.5 + over
	var ridge := maxf(0.4, hl - hd)
	var y0 := wall_h - 0.1
	var p := [xf * Vector3(-hl, y0, -hd), xf * Vector3(hl, y0, -hd), xf * Vector3(hl, y0, hd), xf * Vector3(-hl, y0, hd)]
	var r0 := xf * Vector3(-ridge, y0 + rise, 0)
	var r1 := xf * Vector3(ridge, y0 + rise, 0)
	var inside := xf * Vector3(0, y0 + rise * 0.3, 0)
	scenery.add_quad("thatch", p[0], p[1], r1, r0, inside)
	scenery.add_quad("thatch", p[2], p[3], r0, r1, inside)
	scenery.add_quad("thatch", p[1], p[2], r1, r1, inside)
	scenery.add_quad("thatch", p[3], p[0], r0, r0, inside)
	# Underside, so the eaves aren't see-through from below.
	scenery.add_quad("thatch", p[0], p[1], p[2], p[3], inside + Vector3(0, 5, 0))
