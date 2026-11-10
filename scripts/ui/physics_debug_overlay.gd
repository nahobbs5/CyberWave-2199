class_name PhysicsDebugOverlay
extends Label
## Live vehicle physics readout (docs/Cyberwave_2199_Vehicle_Physics_
## Implementation_Guide.md §9): speeds, mass, wheel contact, per-wheel
## spring length / compression / load, anti-roll, roll and pitch rates,
## air time and driving flags. F3 toggles it (VehicleController.debug_physics)
## in debug builds; every view's overlay follows the one flag.

var vehicle: VehicleController

static var _toggled_frame: int = -1


func _init(p_vehicle: VehicleController = null) -> void:
	vehicle = p_vehicle
	name = "PhysicsDebugOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 120)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("outline_size", 4)
	visible = false


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F3:
		return
	# Split screen has one overlay per view: toggle once per press.
	var frame := Engine.get_process_frames()
	if _toggled_frame != frame:
		_toggled_frame = frame
		VehicleController.debug_physics = not VehicleController.debug_physics


func _process(_delta: float) -> void:
	visible = VehicleController.debug_physics and is_instance_valid(vehicle)
	if visible:
		text = describe(vehicle)


## The readout text for a car (also used by tests).
static func describe(car: VehicleController) -> String:
	var b := car.global_transform.basis
	var av := car.angular_velocity
	var lines: Array[String] = []
	lines.append("PHYSICS  speed %.1f  fwd %.1f  lat %.1f m/s" % [car.linear_velocity.length(), car.forward_speed, car.lateral_speed])
	lines.append("mass %.0f kg  gravity x%.2f  %d ticks/s" % [car.mass, car.gravity_scale, Engine.physics_ticks_per_second])
	lines.append("ray hits %d  loaded %d  traction %.2f" % [car.ray_hit_wheels, car.grounded_wheels, car.traction_fraction])
	for i in car.wheel_load.size():
		var length := car.wheel_spring_length[i]
		lines.append("  wheel %d  len %s  comp %.3f  load %.0f N" % [i,
				"--" if length < 0.0 else "%.3f" % length, car.wheel_compression[i], car.wheel_load[i]])
	lines.append("anti-roll F %.0f  R %.0f N" % [car.anti_roll_force.x, car.anti_roll_force.y])
	lines.append("roll rate %.2f  pitch rate %.2f rad/s" % [av.dot(b.z), av.dot(b.x)])
	lines.append("air %.2f s  landed %.2f s ago" % [car.air_time, car.since_landing])
	var flags: Array[String] = []
	if car.drift.is_drifting():
		flags.append("drift L%d" % car.drift.level)
	if car.is_boosting():
		flags.append("boost")
	if car.is_tricking():
		flags.append("trick")
	if car.recovery != null and car.recovery.is_busy():
		flags.append("recovery")
	if car.is_flying():
		flags.append("flying")
	lines.append("flags: " + (", ".join(flags) if not flags.is_empty() else "-"))
	return "\n".join(lines)
