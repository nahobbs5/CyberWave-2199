class_name Music
extends RefCounted
## Background music that carries across scene changes. Static like
## GameSession, so no autoload: one AudioStreamPlayer lives under the tree
## root and crossfades between tracks. Asking for the track that's already
## playing does nothing, so moving between menus doesn't restart the song.

const MENU := "res://music/ikoliks_aj-cyberpunk-cyberpunk-music-614562.mp3"
const GARAGE := "res://music/ikoliks-wings-of-hope-no-copyright-music-background-corporate-380579.mp3"
## Podium ceremony and the results screen (carries on from one to the other).
const VICTORY := "res://music/alex-morgan-victory-591331.mp3"

const FADE := 0.6
const SILENT_DB := -40.0
## Playback speed on a race's final lap (pitch rises with it, arcade style).
const FINAL_LAP_SPEED := 1.15
const SPEED_RAMP := 0.4

static var _player: AudioStreamPlayer
static var _path: String = ""
static var _tween: Tween
static var _speed_tween: Tween


## The file actually played: the web build ships smaller 96 kbps copies of
## the music as music/web/<same name>.ogg (the .mp3 originals are left out
## of that export), so it uses those when they're there.
static func file_for(path: String) -> String:
	if OS.has_feature("web"):
		var small := path.replace("res://music/", "res://music/web/").get_basename() + ".ogg"
		if ResourceLoader.exists(small):
			return small
	return path


static func play(tree: SceneTree, path: String) -> void:
	if path == _path:
		return
	_path = path
	var player := _ensure_player(tree)
	var stream := load(file_for(path)) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_restart_tween(tree)
	if player.playing:
		_tween.tween_property(player, "volume_db", SILENT_DB, FADE * 0.5)
	_tween.tween_callback(func() -> void:
		_reset_speed(player)
		player.stream = stream
		player.volume_db = SILENT_DB
		# On first launch the player is still waiting to be added to the tree
		# (the title opens mid scene change); start it once it's in.
		if player.is_inside_tree():
			player.play()
		else:
			player.tree_entered.connect(player.play, CONNECT_ONE_SHOT))
	_tween.tween_property(player, "volume_db", 0.0, FADE)


static func stop(tree: SceneTree) -> void:
	if _path == "":
		return
	_path = ""
	var player := _ensure_player(tree)
	_restart_tween(tree)
	_tween.tween_property(player, "volume_db", SILENT_DB, FADE)
	_tween.tween_callback(func() -> void:
		player.stop()
		_reset_speed(player))


## Path of the track playing (or fading in), "" when stopped.
static func current_path() -> String:
	return _path


## Ramps the playback speed (and pitch) of the current track, e.g.
## FINAL_LAP_SPEED on a race's last lap. 1.0 is normal.
static func set_speed(tree: SceneTree, scale: float) -> void:
	var player := get_player()
	if player == null:
		return
	if _speed_tween != null and _speed_tween.is_valid():
		_speed_tween.kill()
	_speed_tween = tree.create_tween()
	_speed_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_speed_tween.tween_property(player, "pitch_scale", scale, SPEED_RAMP)


## Current playback speed (1.0 when no music player exists).
static func get_speed() -> float:
	var player := get_player()
	return player.pitch_scale if player != null else 1.0


static func _reset_speed(player: AudioStreamPlayer) -> void:
	if _speed_tween != null and _speed_tween.is_valid():
		_speed_tween.kill()
	player.pitch_scale = 1.0


static func get_player() -> AudioStreamPlayer:
	return _player if is_instance_valid(_player) else null


static func _ensure_player(tree: SceneTree) -> AudioStreamPlayer:
	if not is_instance_valid(_player):
		GameSettings.ensure_loaded()
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayer"
		_player.bus = &"Music"
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_player)
	return _player


## Tweens run on the tree, not a scene node, so a scene change doesn't cut a fade.
static func _restart_tween(tree: SceneTree) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = tree.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
