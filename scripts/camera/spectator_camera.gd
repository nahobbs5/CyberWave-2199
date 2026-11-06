class_name SpectatorCamera
extends ChaseCamera
## The 3-player split screen's fourth view: "elsewhere on the track", like a
## TV broadcast. Every few seconds it cuts to the most interesting car it
## can find (two cars fighting within a few metres, else the leader, else
## anyone), alternating a high chase shot with a trackside shot that
## watches the car go by.

## Seconds per shot.
const SHOT_TIME := 6.0
## Two cars closer than this (m) are a battle worth showing.
const BATTLE_DISTANCE := 15.0
## The trackside camera sits this far ahead of the car, off the road.
const TRACKSIDE_AHEAD := 55.0
const TRACKSIDE_HEIGHT := 7.5

enum Shot { CHASE, TRACKSIDE }

var race: RaceManager
var shot: Shot = Shot.CHASE
## Who's on screen ("LIVE  NAME").
var shown: RaceProgress
var caption: Label

var _shot_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _cuts: int = 0


func _init() -> void:
	save_preference = false
	allow_look_back = false


func setup(manager: RaceManager) -> void:
	race = manager
	_rng.seed = race.random_seed + 4242
	# A higher, wider TV-style chase than the players' cameras.
	var tv := CameraProfile.new()
	tv.display_name = "Broadcast"
	tv.distance = 13.0
	tv.height = 6.0
	tv.look_height = 1.0
	tv.look_ahead = 4.0
	tv.fov = 62.0
	tv.speed_fov_gain = 3.0
	tv.boost_fov_kick = 2.0
	profiles = [tv]
	profile_index = 0
	fov = tv.fov
	cut()


## The small "LIVE" caption for this view's HUD layer.
func make_caption() -> Label:
	caption = UIStyle.heading("", 18, Color.WHITE)
	caption.position = Vector2(18, 12)
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_update_caption()
	return caption


## Picks the next car and shot now.
func cut() -> void:
	_cuts += 1
	_shot_left = SHOT_TIME
	shown = pick_racer()
	if shown == null:
		return
	shot = Shot.TRACKSIDE if _cuts % 2 == 0 else Shot.CHASE
	set_target(shown.vehicle)
	if shot == Shot.TRACKSIDE:
		_place_trackside()
	_update_caption()


## The most interesting car: the chaser in the closest battle (preferring
## ones with an AI in them, since the players' own views show the players),
## else the leader, else anyone still racing.
func pick_racer() -> RaceProgress:
	if race == null:
		return null
	var standings := race.get_standings().filter(func(r: RaceProgress) -> bool:
		return not r.eliminated and is_instance_valid(r.vehicle) and r.vehicle.visible)
	if standings.is_empty():
		return null
	var best: RaceProgress = null
	var best_gap := BATTLE_DISTANCE
	for i in range(1, standings.size()):
		var ahead: RaceProgress = standings[i - 1]
		var behind: RaceProgress = standings[i]
		if ahead.is_player and behind.is_player:
			continue
		var gap := ahead.vehicle.global_position.distance_to(behind.vehicle.global_position)
		if gap < best_gap and behind != shown:
			best_gap = gap
			best = behind
	if best != null:
		return best
	var leader: RaceProgress = standings[0]
	if leader != shown or standings.size() == 1:
		return leader
	return standings[_rng.randi_range(0, standings.size() - 1)]


func _physics_process(delta: float) -> void:
	_shot_left -= delta
	if _shot_left <= 0.0 or target == null or not is_instance_valid(target) or not target.visible:
		cut()
	if target == null or not is_instance_valid(target):
		return
	if shot == Shot.TRACKSIDE:
		var to_car := target.global_position - global_position
		# Cut once the car has gone past and away.
		if to_car.dot(-global_transform.basis.z) < 0.0 and to_car.length() > 30.0:
			_shot_left = 0.0
		if to_car.length() > 0.5:
			look_at(target.global_position + Vector3.UP * 0.8, Vector3.UP)
	else:
		super._physics_process(delta)


func _place_trackside() -> void:
	var track := race.track
	var offset := track.wrap_offset(track.get_offset_at(target.global_position) + TRACKSIDE_AHEAD)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	# Just inside the road edge and high up, so the barriers don't block it.
	var spot := track.get_safe_transform(offset, side * (track.road_width * 0.5 - 1.0), TRACKSIDE_HEIGHT)
	global_position = spot.origin
	look_at(target.global_position + Vector3.UP * 0.8, Vector3.UP)
	fov = 55.0


func _update_caption() -> void:
	if caption == null:
		return
	caption.text = "LIVE  -  %s" % (shown.display_name.to_upper() if shown != null else "")
