class_name IncaGateway
extends RefCounted
## An Inca trapezoidal gateway the road drives through: jambs leaning in
## toward a flat stone lintel, with a recessed second frame on both faces
## (double-jamb, the mark of an important doorway) and a stone wall piece
## above the lintel. Built in the road frame: local X across the road,
## -Z along it, origin on the centre line at road level. Visual only: the
## jambs stand outside the barriers and the lintel is above Overdrive flight.

## Opening half-width at the road and under the lintel, and lintel height.
const BOTTOM_HALF := 8.8
const TOP_HALF := 7.3
const HEIGHT := 7.6
const JAMB := 2.6
const DEPTH := 2.4
## The recessed outer frame on each face: this much wider and taller.
const STEP := 0.7


## Builds one gateway; returns its clear opening as Vector3(bottom half,
## top half, lintel underside) for tests.
static func build(scenery: TrackScenery, xf: Transform3D, stone_key: String, lintel_key: String) -> Vector3:
	_frame(scenery, xf, BOTTOM_HALF, TOP_HALF, HEIGHT, DEPTH, stone_key, lintel_key)
	for face in [-1.0, 1.0]:
		var outer := xf.translated_local(Vector3(0, 0, face * (DEPTH * 0.5 + 0.3)))
		_frame(scenery, outer, BOTTOM_HALF + STEP, TOP_HALF + STEP, HEIGHT + STEP, 0.6, stone_key, lintel_key)
	# Wall above the lintel, stepping in at the top.
	var w := BOTTOM_HALF + STEP + JAMB
	var y0 := HEIGHT + STEP + 1.0
	scenery.add_prism(stone_key, PackedVector2Array([Vector2(-w, y0), Vector2(w, y0), Vector2(w - 1.6, y0 + 2.4),
			Vector2(-w + 1.6, y0 + 2.4)]), DEPTH + 1.2, xf)
	return Vector3(BOTTOM_HALF, TOP_HALF, HEIGHT)


static func _frame(scenery: TrackScenery, xf: Transform3D, bottom: float, top: float, height: float, depth: float,
		stone_key: String, lintel_key: String) -> void:
	for side in [-1.0, 1.0]:
		var outer := bottom + JAMB
		var poly := PackedVector2Array([Vector2(side * bottom, 0), Vector2(side * outer, 0),
				Vector2(side * outer, height), Vector2(side * top, height)])
		scenery.add_prism(stone_key, poly, depth, xf)
	# The lintel: one long dressed stone across the top.
	scenery.add_box(lintel_key, Vector3((bottom + JAMB) * 2.0 + 0.6, 1.0, depth + 0.1),
			xf.translated_local(Vector3(0, height + 0.5, 0)))
