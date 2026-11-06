class_name GameSettings
extends RefCounted
## Settings and accessibility (GDD 11.9, 13.1, 14.2 SettingsManager): HUD
## scale, motion blur, camera shake, reduced flashing, audio volumes and
## control rebinds. Stored in user://settings.cfg next to the camera view
## (which ChaseCamera saves in its own [camera] section).
##
## Static, loaded on first use (InputSetup.ensure_actions calls ensure_loaded
## at every scene start), so any script can read the values directly.

const BUSES: Array[String] = ["Music", "SFX"]

## Tests point this somewhere else.
static var path: String = "user://settings.cfg"

static var hud_scale: float = 1.0
static var motion_blur: bool = false
## 0 = off, 1 = full.
static var camera_shake: float = 0.6
static var reduced_flashing: bool = false
## Linear 0..1.
static var master_volume: float = 1.0
static var music_volume: float = 0.8
static var sfx_volume: float = 1.0
## { action: { "key": "k:87", "pad": "b:0" } } (InputSetup format).
static var bindings: Dictionary = {}

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func load_settings() -> void:
	_loaded = true
	reset_values()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		hud_scale = clampf(float(config.get_value("display", "hud_scale", hud_scale)), 0.75, 1.5)
		motion_blur = bool(config.get_value("display", "motion_blur", motion_blur))
		camera_shake = clampf(float(config.get_value("display", "camera_shake", camera_shake)), 0.0, 1.0)
		reduced_flashing = bool(config.get_value("display", "reduced_flashing", reduced_flashing))
		master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
		var saved: Variant = config.get_value("controls", "bindings", {})
		if saved is Dictionary:
			bindings = saved
	apply_audio()


## Defaults for everything except bindings.
static func reset_values() -> void:
	hud_scale = 1.0
	motion_blur = false
	camera_shake = 0.6
	reduced_flashing = false
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	bindings = {}


static func save_settings() -> bool:
	var config := ConfigFile.new()
	config.load(path) # keep the [camera] section
	config.set_value("display", "hud_scale", hud_scale)
	config.set_value("display", "motion_blur", motion_blur)
	config.set_value("display", "camera_shake", camera_shake)
	config.set_value("display", "reduced_flashing", reduced_flashing)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("controls", "bindings", bindings)
	return config.save(path) == OK


## Records a rebind (one device) and applies it now.
static func set_binding(action: StringName, event: InputEvent) -> void:
	var entry: Dictionary = bindings.get(String(action), {})
	entry["key" if event is InputEventKey else "pad"] = InputSetup.event_to_string(event)
	bindings[String(action)] = entry
	InputSetup.replace_device_events(action, event)


## Forgets every rebind and restores the default controls.
static func reset_bindings() -> void:
	bindings = {}
	for action in InputSetup.DEFAULTS:
		InputSetup.reset_action(action)


# --- audio -------------------------------------------------------------------------

## Creates the Music and SFX buses (sending to Master) if the project has none.
static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")


static func apply_audio() -> void:
	ensure_buses()
	_set_volume("Master", master_volume)
	_set_volume("Music", music_volume)
	_set_volume("SFX", sfx_volume)


## Sets one volume ("master", "music" or "sfx", 0-1) and applies it.
static func set_volume(bus: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match bus:
		"master":
			master_volume = linear
		"music":
			music_volume = linear
		_:
			sfx_volume = linear
	apply_audio()


## The current volume (0-1) for "master", "music" or "sfx".
static func volume(bus: String) -> float:
	match bus:
		"master":
			return master_volume
		"music":
			return music_volume
		_:
			return sfx_volume


static func _set_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))
