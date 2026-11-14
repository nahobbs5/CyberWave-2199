class_name MedinaHouseBuilder
extends RefCounted
## Chefchaouen's houses (GDD 8.6i): plain blocks of washed blue or white
## plaster lining the streets, a deeper blue band along the foot of the wall,
## patches of exposed stone, arched doors painted deep blue, small windows
## behind iron grilles, blue shutters, little tiled awnings, wall lanterns
## and flowerpots. Each house faces the road it lines and steps down the
## hill with it (its walls run well below the road, so nothing floats).

var scenery: TrackScenery
var houses: int = 0
var doors: int = 0
var flowerpots: int = 0
var lanterns: int = 0
## Facades on these routes get rows of flowerpots (the stairway).
var pot_heavy: bool = false

const STOREY := 2.9
const WALL_KEYS := ["wall_blue", "wall_blue", "wall_blue", "wall_sky", "wall_white", "wall_pale"]
const POT_KEYS := ["pot_terracotta", "pot_terracotta", "pot_yellow", "pot_green", "pot_red", "pot_blue"]


func _init(p_scenery: TrackScenery) -> void:
	scenery = p_scenery


## A house whose front wall stands `front` metres right (side +1) or left
## (side -1) of a road point, facing the road. `road_y` is the road height in
## front; `width` runs along the road, `depth` away from it.
func house(at: Vector3, fwd: Vector3, side: float, front: float, road_y: float, width: float, depth: float,
		height: float) -> bool:
	var rng := scenery.rng
	var right := fwd.cross(Vector3.UP).normalized()
	var out := right * side # away from the road
	var face := at + out * front
	var centre := face + out * depth * 0.5
	# Keep the whole footprint off every road (other routes run close by).
	for c: Vector2 in [Vector2(0.5, 0.0), Vector2(-0.5, 0.0), Vector2(0.0, 0.0), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
			Vector2(0.5, 1.0), Vector2(-0.5, 1.0), Vector2(0.0, 0.25)]:
		var p := face + fwd * c.x * width + out * c.y * depth
		if scenery.edge_distance(p) < scenery.track.barrier_thickness * 0.5 + 0.1:
			return false
	var below := 6.0
	var basis := Basis(out.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, out)
	# basis.x runs along the facade, z points away from the road.
	var wall: String = WALL_KEYS[rng.randi() % WALL_KEYS.size()]
	var total := height + below
	scenery.add_box(wall, Vector3(width, total, depth), Transform3D(basis, Vector3(centre.x, road_y - below + total * 0.5, centre.z)))
	# Flat roof with a parapet lip.
	scenery.add_box(wall, Vector3(width + 0.2, 0.35, 0.3), Transform3D(basis, Vector3(face.x, road_y + height + 0.17, face.z) + out * 0.15))
	var front_xf := Transform3D(basis, Vector3(face.x, road_y, face.z))
	# Deeper blue band along the foot (the wall stays blue where it's white).
	var band := rng.randf_range(0.9, 1.5)
	scenery.add_box("wall_deep", Vector3(width + 0.02, band + 0.6, 0.08), front_xf.translated_local(Vector3(0, (band - 0.6) * 0.5, -0.03)))
	# Exposed stone where the plaster has fallen.
	if rng.randf() < 0.35:
		var sw := rng.randf_range(0.8, 2.2)
		var sh := rng.randf_range(0.6, 1.6)
		scenery.add_box("stone", Vector3(sw, sh, 0.06), front_xf.translated_local(Vector3(rng.randf_range(-width * 0.3, width * 0.3), rng.randf_range(1.6, maxf(1.7, height - 2.0)), -0.04)))
	# Door (arched, deep blue) or not.
	var door_x := rng.randf_range(-width * 0.25, width * 0.25)
	if rng.randf() < 0.45 and width > 3.0:
		_door(front_xf, door_x)
	# Windows on each storey above the ground floor.
	var storeys := maxi(1, int(height / STOREY))
	for s in range(1, storeys):
		var wy := s * STOREY + 0.9
		var count := 1 if width < 6.0 else 2
		for k in count:
			var wx := (k - (count - 1) * 0.5) * width * 0.45 + rng.randf_range(-0.3, 0.3)
			_window(front_xf, wx, wy)
	if rng.randf() < 0.3:
		_window(front_xf, -door_x * 0.8 + 0.9, 1.4)
	# Wall lantern by the door.
	if rng.randf() < 0.18:
		_lantern(front_xf.translated_local(Vector3(door_x + 1.3, 2.7, -0.2)))
	# Flowerpots on the wall (rows of them on the stairway).
	var pots := 0
	if pot_heavy:
		pots = rng.randi_range(2, 5)
	elif rng.randf() < 0.15:
		pots = rng.randi_range(1, 2)
	for k in pots:
		var px := rng.randf_range(-width * 0.42, width * 0.42)
		var py := rng.randf_range(1.6, minf(4.2, height - 0.5))
		pot(front_xf.translated_local(Vector3(px, py, -0.22)), true)
	houses += 1
	return true


func _door(front: Transform3D, x: float) -> void:
	var rng := scenery.rng
	var w := rng.randf_range(1.1, 1.5)
	var h := rng.randf_range(2.1, 2.5)
	var key := "door_blue" if rng.randf() < 0.8 else "door_wood"
	# White (or deep blue) frame, the door leaf set in, a round arch on top.
	var frame_key := "wall_white" if rng.randf() < 0.6 else "wall_deep"
	scenery.add_box(frame_key, Vector3(w + 0.5, h + 0.35, 0.1), front.translated_local(Vector3(x, (h + 0.35) * 0.5, -0.06)))
	scenery.add_box(key, Vector3(w, h, 0.12), front.translated_local(Vector3(x, h * 0.5, -0.1)))
	var arch := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		arch.append(Vector2(cos(a) * w * 0.5, sin(a) * w * 0.55))
	scenery.add_prism(key, arch, 0.12, front.translated_local(Vector3(x, h, -0.1)))
	var ring := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		ring.append(Vector2(cos(a) * (w * 0.5 + 0.25), sin(a) * (w * 0.55 + 0.25)))
	scenery.add_prism(frame_key, ring, 0.1, front.translated_local(Vector3(x, h + 0.02, -0.06)))
	# Studs.
	if key == "door_blue" and rng.randf() < 0.5:
		for r in 3:
			for c in 2:
				scenery.add_box("brass", Vector3(0.06, 0.06, 0.05), front.translated_local(Vector3(x + (c - 0.5) * w * 0.5, 0.7 + r * 0.55, -0.18)))
	doors += 1


func _window(front: Transform3D, x: float, y: float) -> void:
	var rng := scenery.rng
	var w := rng.randf_range(0.7, 1.1)
	var h := rng.randf_range(0.8, 1.2)
	scenery.add_box("window_dark", Vector3(w, h, 0.06), front.translated_local(Vector3(x, y, -0.02)))
	if rng.randf() < 0.55:
		# Iron grille.
		for i in 4:
			scenery.add_box("iron", Vector3(0.04, h, 0.04), front.translated_local(Vector3(x - w * 0.375 + i * w * 0.25, y, -0.12)))
		scenery.add_box("iron", Vector3(w, 0.04, 0.04), front.translated_local(Vector3(x, y, -0.12)))
	else:
		# Blue (sometimes wooden) shutters, folded open.
		var key := "shutter_blue" if rng.randf() < 0.75 else "door_wood"
		for s in [-1.0, 1.0]:
			scenery.add_box(key, Vector3(w * 0.5, h + 0.1, 0.05), front.translated_local(Vector3(x + s * (w * 0.75), y, -0.06)))
	if rng.randf() < 0.3:
		# A small tiled awning over it.
		var tile := "tile_green" if rng.randf() < 0.5 else "tile_red"
		scenery.add_box(tile, Vector3(w + 0.5, 0.12, 0.55), front.translated_local(Vector3(x, y + h * 0.5 + 0.3, -0.3)).rotated_local(Vector3.RIGHT, -0.35))


func _lantern(xf: Transform3D) -> void:
	scenery.add_box("brass", Vector3(0.06, 0.06, 0.4), xf.translated_local(Vector3(0, 0.25, 0.15)))
	scenery.add_box("lantern_glass", Vector3(0.28, 0.42, 0.28), xf)
	scenery.add_box("brass", Vector3(0.34, 0.06, 0.34), xf.translated_local(Vector3(0, 0.24, 0)))
	lanterns += 1


## A flowerpot with a plant (on a wall bracket if `on_wall`).
func pot(xf: Transform3D, on_wall: bool = false) -> void:
	var rng := scenery.rng
	var key: String = POT_KEYS[rng.randi() % POT_KEYS.size()]
	var r := rng.randf_range(0.14, 0.24)
	var h := r * rng.randf_range(1.1, 1.6)
	if on_wall:
		scenery.add_box("iron", Vector3(r * 2.2, 0.03, r * 1.6), xf.translated_local(Vector3(0, -0.02, 0.05)))
	scenery.add_cyl(key, r * 0.75, h, xf, 7, r)
	var plant := "plant" if rng.randf() < 0.8 else "flower"
	scenery.add_sphere(plant, r * rng.randf_range(1.0, 1.6), xf.translated_local(Vector3(0, h + r * 0.5, 0)), 3, 6)
	flowerpots += 1
