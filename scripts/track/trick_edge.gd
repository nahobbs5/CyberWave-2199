@tool
class_name TrickEdge
extends Node3D
## A half-pipe (GDD 8.7): a stretch of the road's outside edge that curves
## up into a 4 m quarter-pipe against the wall, like a skate ramp. Ride into
## it at speed and the car is carried up the curve (rolling onto the wall),
## launched straight up above the lip, where it can Trick and grab the item
## boxes, then drops back onto the same wall and rides down onto the road,
## facing down the road. The whole ride is guided and follows the bend, so
## it always comes back clean (Mario Kart 8 style); the car keeps most of
## its speed. Slower than MIN_SPEED, or without room left to finish the
## ride, the curve is just a bank.
## One look for every track, tinted to its theme (tint).
## Geometry is built once in track space, so in a Mirror race it stays on
## the same physical edge (a bend's outside is still its outside); only the
## chevrons turn round. The ride works in either direction.

const GLOW := Color(0.0, 0.9, 1.0)
const DEFAULT_TINT := Color(0.52, 0.52, 0.55)
## Quarter-pipe radius = its height and how far it reaches in from the wall.
const RADIUS := 4.0
## Arc slices (from the road up to the vertical lip).
const SLICES := 8
## Ring spacing along the road.
const STEP := 2.0
## Each end eases from flat road up to the full pipe over this distance.
const TAPER := 8.0
## Slower than this along the road, the pipe is just a bank.
const MIN_SPEED := 15.0
## The ride: up the curve, in the air above the lip, back down.
const UP_TIME := 0.25
const DOWN_TIME := 0.25
## Air time above the lip: as long as the pipe has room for, up to MAX_AIR;
## less room than MIN_AIR (counted from where the car comes in) = no ride.
const MAX_AIR := 1.4
const MIN_AIR := 0.45
## Share of the car's speed along the road kept while riding the pipe (and
## no faster than RIDE_MAX_SPEED, so a 200cc car still gets its air time in
## the pipe), and when it comes back down onto the road.
const RIDE_SPEED_KEEP := 0.8
const RIDE_MAX_SPEED := 26.0
const EXIT_SPEED_KEEP := 0.9
const GRAVITY := 9.8
## The trigger covers the steep part of the curve: up from this angle
## (degrees from flat). Drifting wide over the low foot does nothing.
const TRIGGER_ANGLE := 15.0
## Car centre above the surface while it rides (wheels on the pipe).
const RIDE_CLEARANCE := 0.65
## Time after a ride before the same car can start another one here.
const COOLDOWN := 1.0

## Distance along the main loop of the span's middle (plus anchor_point).
@export var offset: float = 0.0
## If set, offset is measured from the road point nearest this layout point.
@export var anchor_point: Vector3 = Vector3.ZERO
## Span along the road.
@export var length: float = 70.0:
	set(value):
		length = value
		_queue_build()
## Which edge: -1 left, +1 right (of the forward driving direction).
@export_range(-1, 1) var side: int = 1:
	set(value):
		side = value
		_queue_build()
## Surface colour; transparent = plain concrete.
@export var tint: Color = Color(0, 0, 0, 0):
	set(value):
		tint = value
		_queue_build()

## Rides started (tests / telemetry).
var triggered: int = 0
## Mirror: chevrons point the other way.
var reversed: bool = false

var _track: TrackCircuit
var _visual: Node3D
var _area: Area3D
var _chevrons: Array[Node3D] = []
var _cooldowns: Dictionary = {}
## Cars riding now: car -> ride state (Dictionary).
var _rides: Dictionary = {}
## Track-local offset of the span's start on the forward curve.
var _start: float = 0.0
var _centre_local: Vector3 = Vector3.ZERO
var _box_spots: Array[Transform3D] = []
## Geometry frames along the span (track local), kept from the build: the
## ride uses them, so it is right after the curve is reversed for Mirror.
## x = in toward the road centre, y = up, -z = forward; origin = the wall's
## inner face at road level.
var _frames: Array[Transform3D] = []


func _queue_build() -> void:
	if _track != null and is_inside_tree():
		place_on_track.call_deferred(_track)


## Called by the TrackCircuit once its curve is built.
func place_on_track(track: TrackCircuit) -> void:
	_track = track
	transform = Transform3D.IDENTITY
	var d := offset
	if anchor_point != Vector3.ZERO:
		d += track.curve.get_closest_offset(anchor_point)
	_start = track.wrap_offset(d - length * 0.5)
	_build()


## Where the item boxes go (global transforms).
func item_box_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if _track == null:
		return out
	for xf in _box_spots:
		out.append(_track.global_transform * xf)
	return out


## Middle of the span (global), for Overdrive's landing check.
func centre_global() -> Vector3:
	return _track.to_global(_centre_local) if _track != null else global_position


## Main-loop offset of the span's start (forward curve, as built).
func start_offset() -> float:
	return _start


## Built on its track (frames, colliders and trigger exist).
func is_built() -> bool:
	return not _frames.is_empty()


## True while `car` is riding this pipe.
func is_riding(car: VehicleController) -> bool:
	return _rides.has(car)


## Mirror: point the chevrons the other way (the geometry stays put).
func set_reversed(on: bool) -> void:
	if on == reversed:
		return
	reversed = on
	for c in _chevrons:
		c.transform.basis = c.transform.basis * Basis(Vector3.UP, PI)


## Pipe surface point as (u = metres in from the wall, h = height) at arc
## angle `theta` (0 = flat road at the foot, PI/2 = the vertical lip).
static func arc_point(theta: float) -> Vector2:
	return Vector2(RADIUS - RADIUS * sin(theta), RADIUS - RADIUS * cos(theta))


## Surface normal (pointing out of the pipe, toward its centre) as (u, h).
static func arc_normal(theta: float) -> Vector2:
	return Vector2(sin(theta), cos(theta))


## Arc angle of the surface below a point `u` metres in from the wall.
static func theta_at(u: float) -> float:
	return asin(clampf((RADIUS - u) / RADIUS, 0.0, 1.0))


func _surface_color() -> Color:
	return tint if tint.a > 0.0 else DEFAULT_TINT


## The road's own track-local frame at the wall's inner face, a distance
## into the span (x = right, y = up, -z = forward). Samples the curve, so
## only at build time.
func _safe(into: float) -> Transform3D:
	var o := _track.wrap_offset(_start + into)
	var inv := _track.global_transform.affine_inverse()
	return inv * _track.get_safe_transform(o, float(side) * _track.road_width * 0.5, 0.0)


## Geometry frame: as _safe but x points in toward the road centre. (On the
## right edge that makes it left-handed: only use it to place points.)
func _frame(into: float) -> Transform3D:
	var xf := _safe(into)
	return Transform3D(Basis(xf.basis.x * -float(side), xf.basis.y, xf.basis.z), xf.origin)


## The cached frame a distance into the span (interpolated; safe in Mirror).
func frame_at(into: float) -> Transform3D:
	var n := _frames.size() - 1
	var t := clampf(into / length, 0.0, 1.0) * n
	var i := mini(int(t), n - 1)
	var a := _frames[i]
	var b := _frames[i + 1]
	var k := t - i
	return Transform3D(Basis(a.basis.x.lerp(b.basis.x, k).normalized(), a.basis.y.lerp(b.basis.y, k).normalized(),
			a.basis.z.lerp(b.basis.z, k).normalized()), a.origin.lerp(b.origin, k))


## Pipe size at a distance into the span (eases in and out at the ends).
func scale_at(into: float) -> float:
	var a := smoothstep(0.0, TAPER, into) * smoothstep(0.0, TAPER, length - into)
	return maxf(a, 0.02)


## Track-local surface point and normal at `into` and arc angle `theta`.
func surface(into: float, theta: float) -> Array[Vector3]:
	var f := frame_at(into)
	var k := scale_at(into)
	var p := arc_point(theta) * k
	var nrm := arc_normal(theta)
	return [f.origin + f.basis.x * p.x + f.basis.y * p.y, (f.basis.x * nrm.x + f.basis.y * nrm.y).normalized()]


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chevrons.clear()
	_box_spots.clear()
	_frames = []
	_rides.clear()
	reversed = false
	if _track == null or _track.curve == null or _track.curve.point_count < 2:
		return
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var n := maxi(2, ceili(length / STEP))
	var frames: Array[Transform3D] = []
	for i in n + 1:
		frames.append(_frame(length * float(i) / n))
	_frames = frames
	var mid := length * 0.5
	var fm := frame_at(mid)
	_centre_local = fm.origin + fm.basis.x * (RADIUS * 0.5)
	_build_colliders(n)
	_build_surface(n)
	_build_trigger(n)
	_build_markings(n)
	# Item boxes above the lip, either side of the middle, where the car
	# flies past them on the way up or down.
	for along in [-10.0, 10.0]:
		var f := frame_at(mid + along)
		_box_spots.append(Transform3D(_safe(mid + along).basis,
				f.origin + f.basis.x * (RIDE_CLEARANCE + 0.3) + f.basis.y * (RADIUS + 0.9)))
	for into in [length * 0.3, length * 0.7]:
		var light := OmniLight3D.new()
		light.light_color = GLOW
		light.light_energy = 1.6
		light.omni_range = 10.0
		var f := frame_at(into)
		light.position = f.origin + f.basis.x * RADIUS + f.basis.y * (RADIUS * 0.8)
		_visual.add_child(light)


func _build_colliders(n: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1 # environment: the wheel rays drive on it
	body.collision_mask = 0
	# One convex slab per ring step and arc slice: the surface quad plus the
	# same quad pushed 0.4 m back into the pipe. The body joins the tree
	# after its shapes (Jolt rebuilds per shape otherwise).
	for i in n:
		var into0 := length * float(i) / n
		var into1 := length * float(i + 1) / n
		for j in SLICES:
			var t0 := PI * 0.5 * float(j) / SLICES
			var t1 := PI * 0.5 * float(j + 1) / SLICES
			var pts := PackedVector3Array()
			for into: float in [into0, into1]:
				for t: float in [t0, t1]:
					var s := surface(into, t)
					pts.append(s[0])
					pts.append(s[0] - s[1] * 0.4)
			var shape := CollisionShape3D.new()
			var hull := ConvexPolygonShape3D.new()
			hull.points = pts
			shape.shape = hull
			body.add_child(shape)
	_visual.add_child(body)


func _mat(color: Color, emission: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## The curved face (smooth shaded) with darker seams every 6 m like poured
## concrete sections; drawn from both sides so nothing shows through.
func _build_surface(n: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := SLICES * 2
	var pts: Array = []
	var nrms: Array = []
	for i in n + 1:
		var into := length * float(i) / n
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		for j in cols + 1:
			var s := surface(into, PI * 0.5 * float(j) / cols)
			row.append(s[0])
			nrow.append(s[1])
		pts.append(row)
		nrms.append(nrow)
	for i in n:
		for j in cols:
			var v: Array[Vector3] = [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1], pts[i][j + 1]]
			var nv: Array[Vector3] = [nrms[i][j], nrms[i + 1][j], nrms[i + 1][j + 1], nrms[i][j + 1]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nv[k])
				st.add_vertex(v[k])
	var mi := MeshInstance3D.new()
	mi.name = "PipeSurface"
	mi.mesh = st.commit()
	var m := _mat(_surface_color())
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_visual.add_child(mi)
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var into := 6.0
	while into < length - 1.0:
		var f := frame_at(into)
		var w := f.basis.z.normalized() * 0.06
		for j in cols:
			var s0 := surface(into, PI * 0.5 * float(j) / cols)
			var s1 := surface(into, PI * 0.5 * float(j + 1) / cols)
			var p0: Vector3 = s0[0] + s0[1] * 0.01
			var p1: Vector3 = s1[0] + s1[1] * 0.01
			_quad(seams, p0 - w, p1 - w, p1 + w, p0 + w)
		into += 6.0
	var sm := MeshInstance3D.new()
	sm.name = "Seams"
	sm.mesh = seams.commit()
	var dark := _mat(_surface_color().darkened(0.35))
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.material_override = dark
	_visual.add_child(sm)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## Trigger boxes over the steep part of the curve (skipping the tapers).
func _build_trigger(n: int) -> void:
	_area = Area3D.new()
	_area.name = "Trigger"
	_area.collision_layer = 0
	_area.collision_mask = 2 # vehicles
	_area.monitorable = false
	var reach := arc_point(deg_to_rad(TRIGGER_ANGLE)).x
	var h := RADIUS + 1.0
	var skip := ceili(TAPER / STEP)
	for i in range(skip, n - skip):
		var f0 := _frames[i]
		var f1 := _frames[i + 1]
		var seg := f0.origin.distance_to(f1.origin)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(reach, h, seg + 0.2)
		shape.shape = box
		var x := f0.basis.x.normalized()
		var y := f0.basis.y.normalized()
		var mid := (f0.origin + f1.origin) * 0.5 + x * (reach * 0.5) + y * (h * 0.5)
		# The frame may be left-handed (right edge): build a proper basis.
		shape.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), mid)
		_area.add_child(shape)
	add_child(_area)


## A glowing cyan coping along the lip, a dimmer line along the foot, and
## three chevrons up the face pointing the driving way.
func _build_markings(n: int) -> void:
	var glow := _mat(GLOW, 3.5)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lip := SurfaceTool.new()
	lip.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foot := SurfaceTool.new()
	foot.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var into0 := length * float(i) / n
		var into1 := length * float(i + 1) / n
		var f0 := frame_at(into0)
		var f1 := frame_at(into1)
		var x0 := f0.basis.x.normalized()
		var x1 := f1.basis.x.normalized()
		var y0 := f0.basis.y.normalized()
		var y1 := f1.basis.y.normalized()
		# Coping: a strip over the top of the lip and down its inner face.
		var top0: Vector3 = surface(into0, PI * 0.5)[0] + y0 * 0.04
		var top1: Vector3 = surface(into1, PI * 0.5)[0] + y1 * 0.04
		_quad(lip, top0 - x0 * 0.05, top1 - x1 * 0.05, top1 + x1 * 0.25, top0 + x0 * 0.25)
		_quad(lip, top0 + x0 * 0.25, top1 + x1 * 0.25, top1 + x1 * 0.25 - y1 * 0.18, top0 + x0 * 0.25 - y0 * 0.18)
		# Foot line on the road where the curve starts.
		var a := surface(into0, deg_to_rad(8.0))
		var b := surface(into1, deg_to_rad(8.0))
		_quad(foot, a[0] - x0 * 0.08 + a[1] * 0.02, b[0] - x1 * 0.08 + b[1] * 0.02,
				b[0] + x1 * 0.08 + b[1] * 0.02, a[0] + x0 * 0.08 + a[1] * 0.02)
	var lm := MeshInstance3D.new()
	lm.name = "LipGlow"
	lm.mesh = lip.commit()
	lm.material_override = glow
	_visual.add_child(lm)
	var fmi := MeshInstance3D.new()
	fmi.name = "FootLine"
	fmi.mesh = foot.commit()
	var dim := _mat(GLOW.darkened(0.3), 1.2)
	dim.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmi.material_override = dim
	_visual.add_child(fmi)
	# Chevrons lying on the face halfway up, pointing the driving way.
	for c in 3:
		var into := length * (0.3 + 0.2 * c)
		var s := surface(into, deg_to_rad(45.0))
		var fwd := -_safe(into).basis.z.normalized()
		var up: Vector3 = s[1]
		fwd = (fwd - up * fwd.dot(up)).normalized()
		var right := fwd.cross(up).normalized()
		var chev := Node3D.new()
		chev.name = "Chevron%d" % c
		chev.transform = Transform3D(Basis(right, up, -fwd), s[0] + up * 0.05)
		for arm in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.4, 0.04, 0.32)
			bar.mesh = bm
			bar.material_override = glow
			# Arms trail back from a point facing forward (-z).
			bar.rotation.y = -arm * 0.6
			bar.position = Vector3(arm * 1.4 * 0.4, 0.0, 1.4 * 0.25)
			chev.add_child(bar)
		_visual.add_child(chev)
		_chevrons.append(chev)


# --- the ride ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for car in _cooldowns.keys():
		_cooldowns[car] -= delta
		if _cooldowns[car] <= 0.0:
			_cooldowns.erase(car)
	for car in _rides.keys():
		_advance(car, delta)
	if _area == null or not _area.monitoring:
		return
	for body in _area.get_overlapping_bodies():
		var car := body as VehicleController
		if car != null and not _cooldowns.has(car) and not _rides.has(car):
			try_ride(car)


## Starts the ride if the car is fast enough along the road and there's room
## left in the pipe to finish it. Returns whether it started.
func try_ride(car: VehicleController) -> bool:
	if _frames.is_empty() or car.is_flying() or car.is_held() \
			or (car.status != null and car.status.has(&"overdrive")):
		return false
	var local := _track.to_local(car.global_position)
	var into := _into_at(local)
	var f := frame_at(into)
	var fwd := -f.basis.z.normalized()
	var v := _track.global_transform.basis.inverse() * car.linear_velocity
	var along := v.dot(fwd)
	if absf(along) < MIN_SPEED:
		return false
	var dir := signf(along)
	var speed := minf(absf(along) * RIDE_SPEED_KEEP, RIDE_MAX_SPEED)
	# Room left in the driving direction, to the start of the far taper.
	var room := (length - TAPER - into) if dir > 0.0 else (into - TAPER)
	var air := minf(room / speed - UP_TIME - DOWN_TIME, MAX_AIR)
	if air < MIN_AIR:
		return false
	var u := (local - f.origin).dot(f.basis.x.normalized()) - RIDE_CLEARANCE * 0.5
	_rides[car] = {
		"t": 0.0, "into": into, "dir": dir, "speed": speed, "exit": absf(along) * EXIT_SPEED_KEEP,
		"air": air, "theta0": clampf(theta_at(u / maxf(scale_at(into), 0.05)), deg_to_rad(10.0), deg_to_rad(70.0)),
		"last": car.global_position, "window": false,
	}
	triggered += 1
	_advance(car, 0.0)
	return true


## Distance into the span of a track-local point (nearest cached frame,
## refined along its forward axis).
func _into_at(local: Vector3) -> float:
	var best := 0
	for i in _frames.size():
		if _frames[i].origin.distance_squared_to(local) < _frames[best].origin.distance_squared_to(local):
			best = i
	var f := _frames[best]
	var into := length * float(best) / (_frames.size() - 1)
	into += (local - f.origin).dot(-f.basis.z.normalized())
	return clampf(into, 0.0, length)


## Places the riding car for this step: up the curve, in the air above the
## lip, back down the curve; then hands it back to the driver on the road.
func _advance(car: VehicleController, delta: float) -> void:
	if not is_instance_valid(car) or not car.is_inside_tree():
		_rides.erase(car)
		return
	var r: Dictionary = _rides[car]
	if car.is_held() or car.has_pending_teleport() or (r.t > 0.0 and not car.is_flying()):
		_finish(car, false) # recovery (or a reset) took over
		return
	r.t += delta
	r.into = clampf(r.into + r.dir * r.speed * delta, 0.0, length)
	var t: float = r.t
	var air: float = r.air
	var theta := PI * 0.5
	var lift := 0.0
	if t < UP_TIME:
		var k := t / UP_TIME
		theta = lerpf(r.theta0, PI * 0.5, k * k * (3.0 - 2.0 * k))
	elif t < UP_TIME + air:
		var ta := t - UP_TIME
		lift = GRAVITY * air * 0.5 * ta - 0.5 * GRAVITY * ta * ta
		if not r.window:
			r.window = true
			if car.trick != null:
				car.trick.on_ramp()
	elif t < UP_TIME + air + DOWN_TIME:
		var k := (t - UP_TIME - air) / DOWN_TIME
		theta = lerpf(PI * 0.5, 0.0, k * k * (3.0 - 2.0 * k))
	else:
		_finish(car, true)
		return
	var s := surface(r.into, theta)
	var f := frame_at(r.into)
	var up: Vector3 = s[1]
	var fwd := (-f.basis.z.normalized()) * float(r.dir)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var back := -fwd
	var right := up.cross(back).normalized()
	var pos: Vector3 = s[0] + up * RIDE_CLEARANCE + f.basis.y.normalized() * lift
	var xf := _track.global_transform * Transform3D(Basis(right, up, back), pos)
	var velocity: Vector3 = (xf.origin - r.last) / delta if delta > 0.0 \
			else _track.global_transform.basis * (fwd * float(r.speed))
	r.last = xf.origin
	car.fly_to(xf, velocity)


## Back on the road at the foot of the pipe, driving on down the road.
func _finish(car: VehicleController, clean: bool) -> void:
	var r: Dictionary = _rides[car]
	_rides.erase(car)
	_cooldowns[car] = COOLDOWN
	if clean and is_instance_valid(car) and car.is_flying():
		car.end_flight(r.exit)
