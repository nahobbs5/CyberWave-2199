class_name HypostyleHallBuilder
extends RefCounted
## A hypostyle prayer hall like Kilwa's Great Mosque, laid on a square
## column grid inside an axis-aligned rectangle: square dressed-stone piers
## with a plinth and an impost band, pointed arcades running both ways
## between them, and a ceiling of flat vaults with some domed bays, some
## collapsed open to the sky. The outer walls are piers too (arches spring
## from them). Piers whose footprint would reach onto a road are left out,
## except the track's own road_columns, which stand in the road (the
## TrackCircuit gives them colliders). Visual only.
##
## Materials (keys): pier (dressed stone), arch (spandrel infill, coral
## rag), band (arch ring), ceiling, dome, rubble.

const COL_HALF := 0.75
const PLINTH := 0.35

var scenery: TrackScenery
var rect: Rect2
var grid: float = 12.0
var spring: float = 3.4
var rise: float = 6.0
var top: float = 10.2
## Chance a bay is domed / collapsed.
var dome_chance: float = 0.16
var collapse_chance: float = 0.1

## Grid points with a pier (Vector2i grid coords -> true; walls included).
var piers: Dictionary = {}
## Piers that stand on the road.
var road_piers: int = 0
var free_piers: int = 0
var arches: int = 0
var domes: int = 0
## Bays open to the sky (Vector2i of the bay's corner).
var collapsed: Dictionary = {}
## Bays that must get a dome (Vector2i); set before build().
var force_domes: Dictionary = {}
## Bays that collapse (Vector2i); set before build().
var force_collapsed: Dictionary = {}
## Bays whose dome has fallen in, open at the top (Vector2i); set before build().
var force_broken: Dictionary = {}
var nx: int = 0
var nz: int = 0


func _init(p_scenery: TrackScenery, p_rect: Rect2, p_grid: float = 12.0) -> void:
	scenery = p_scenery
	rect = p_rect
	grid = p_grid
	nx = int(round(rect.size.x / grid))
	nz = int(round(rect.size.y / grid))


func point(g: Vector2i) -> Vector3:
	return Vector3(rect.position.x + g.x * grid, 0.0, rect.position.y + g.y * grid)


## Grid cell (bay corner) holding a track-local point.
func bay_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - rect.position.x) / grid)), int(floor((p.z - rect.position.y) / grid)))


func contains(p: Vector3) -> bool:
	return rect.has_point(Vector2(p.x, p.z))


## Under a ceiling (inside the hall, not a collapsed bay).
func is_roofed(p: Vector3) -> bool:
	return contains(p) and not collapsed.has(bay_of(p))


func build() -> void:
	var track := scenery.track
	var rng := scenery.rng
	var road_set := {}
	for c in track.road_columns:
		road_set[bay_of(Vector3(c.x + grid * 0.5, 0, c.y + grid * 0.5))] = true
	# Piers: walls all round, the grid inside unless on a road.
	for gz in nz + 1:
		for gx in nx + 1:
			var g := Vector2i(gx, gz)
			var on_wall := gx == 0 or gz == 0 or gx == nx or gz == nz
			var p := point(g)
			if road_set.has(g):
				piers[g] = true
				road_piers += 1
				_pier(p)
				continue
			if on_wall:
				# Wall piers only where the wall stands (not in a doorway).
				if scenery.edge_distance(p) > 1.2:
					piers[g] = true
				continue
			if scenery.edge_distance(p) >= COL_HALF + 0.2:
				piers[g] = true
				free_piers += 1
				_pier(p)
	# Arcades between neighbouring piers, both ways.
	for g: Vector2i in piers:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var h: Vector2i = g + d
			if not piers.has(h):
				continue
			var on_wall_line: bool = (d.x == 1 and (g.y == 0 or g.y == nz)) or (d.y == 1 and (g.x == 0 or g.x == nx))
			if on_wall_line:
				continue
			var a := point(g)
			var b := point(h)
			var xf := Transform3D(Basis.looking_at((b - a).normalized().cross(Vector3.UP), Vector3.UP), (a + b) * 0.5)
			PointedArch.arch_wall(scenery, "arch", xf, grid - COL_HALF * 2.0, spring, rise, top, 1.1, "band", 0.4)
			arches += 1
	# Ceiling bays.
	for gz in nz:
		for gx in nx:
			var g := Vector2i(gx, gz)
			var centre := point(g) + Vector3(grid * 0.5, 0, grid * 0.5)
			if force_broken.has(g):
				collapsed[g] = true
				_domed_bay(centre, true)
				continue
			if force_collapsed.has(g) or (not force_domes.has(g) and rng.randf() < collapse_chance):
				collapsed[g] = true
				_collapsed_bay(centre)
				continue
			if force_domes.has(g) or rng.randf() < dome_chance:
				_domed_bay(centre, false)
				continue
			scenery.add_box("ceiling", Vector3(grid + 0.2, 0.9, grid + 0.2), scenery.xform(centre + Vector3(0, top + 0.45, 0)))
			# A shallow saucer dome on the roof, as on the real hall.
			scenery.add_cyl("dome", grid * 0.38, 0.9, scenery.xform(centre + Vector3(0, top + 0.9, 0)), 10, grid * 0.18)


## A domed bay: pendentive corners, an octagonal ring and the dome.
func _domed_bay(centre: Vector3, broken: bool) -> void:
	var h := grid * 0.5
	var y := top + 0.45
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner := centre + Vector3(c.x * h, y, c.y * h)
		var e1 := centre + Vector3(c.x * h, y, 0)
		var e2 := centre + Vector3(0, y, c.y * h)
		var mid := centre + Vector3(c.x * h * 0.35, y, c.y * h * 0.35)
		scenery.add_quad("ceiling", corner, e1, mid, e2, centre + Vector3(0, y + 3.0, 0))
		scenery.add_box("ceiling", Vector3(0.9, 0.9, 0.9), scenery.xform(corner))
	PointedArch.dome(scenery, "dome", centre + Vector3(0, y, 0), h * 0.92, grid * 0.62, 1.6 if broken else 0.0)
	domes += 1


## A bay open to the sky: broken vault edges and rubble on the floor (off
## the road).
func _collapsed_bay(centre: Vector3) -> void:
	var rng := scenery.rng
	var h := grid * 0.5
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner := centre + Vector3(c.x * h * 0.82, top + 0.2, c.y * h * 0.82)
		scenery.add_box("ceiling", Vector3(rng.randf_range(1.4, 3.0), 0.9, rng.randf_range(1.4, 3.0)),
				scenery.xform(corner, rng.randf() * 0.3))
	for i in 5:
		var p := centre + Vector3(rng.randf_range(-h, h), 0, rng.randf_range(-h, h))
		if scenery.clear(p, 1.2):
			var s := rng.randf_range(0.5, 1.3)
			scenery.add_box("rubble", Vector3(s * 1.6, s * 0.7, s), scenery.xform(p + Vector3(0, s * 0.3, 0), rng.randf() * TAU))


func _pier(p: Vector3) -> void:
	var w := COL_HALF * 2.0
	scenery.add_box("pier", Vector3(w + 0.3, PLINTH, w + 0.3), scenery.xform(p + Vector3(0, PLINTH * 0.5, 0)))
	scenery.add_box("pier", Vector3(w, spring, w), scenery.xform(p + Vector3(0, spring * 0.5, 0)))
	# Impost band where the arches spring.
	scenery.add_box("band", Vector3(w + 0.35, 0.32, w + 0.35), scenery.xform(p + Vector3(0, spring - 0.1, 0)))
	# The pier carries on up between the arches to the ceiling.
	scenery.add_box("arch", Vector3(w, top - spring, w), scenery.xform(p + Vector3(0, spring + (top - spring) * 0.5, 0)))
