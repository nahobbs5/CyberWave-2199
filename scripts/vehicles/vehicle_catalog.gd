class_name VehicleCatalog
extends RefCounted
## The eight vehicles, all available from the start (GDD 5.1, 9.1).

const PATHS: Array[String] = [
	"res://resources/vehicles/v8_specter.tres",
	"res://resources/vehicles/aurora_gt.tres",
	"res://resources/vehicles/empyrean_s.tres",
	"res://resources/vehicles/nexus_x.tres",
	"res://resources/vehicles/riviera_88.tres",
	"res://resources/vehicles/orbiter.tres",
	"res://resources/vehicles/valkyrie_r.tres",
	"res://resources/vehicles/cipher_evo.tres",
]

## Display ranges for the four primary stats (GDD 5.2), shown as 1-10 bars.
const STAT_RANGES := {
	"Top speed": [41.0, 47.0],
	"Acceleration": [12.0, 16.5],
	"Handling": [2.1, 2.7],
	"Drift": [1.2, 1.65],
}

static var _all: Array[VehicleData] = []


static func all() -> Array[VehicleData]:
	if _all.is_empty():
		for path in PATHS:
			_all.append(load(path) as VehicleData)
	return _all


static func by_id(id: String) -> VehicleData:
	for v in all():
		if v.id == id:
			return v
	return all()[0]


static func index_of(id: String) -> int:
	var list := all()
	for i in list.size():
		if list[i].id == id:
			return i
	return 0


## The four primary stats in display order.
static func primary_stats(stats: VehicleStats) -> Array[float]:
	return [stats.top_speed, stats.acceleration, stats.handling, stats.drift]


## 1-10 rating for the stats screen.
static func rating(stat_name: String, value: float) -> int:
	var r: Array = STAT_RANGES[stat_name]
	return clampi(roundi(remap(value, r[0], r[1], 1.0, 10.0)), 1, 10)
