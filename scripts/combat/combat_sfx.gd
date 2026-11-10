class_name CombatSfx
extends RefCounted
## One-shot weapon and track sounds. Each plays from a 3D player parented to
## a car (or a dropped strip / track feature), so it follows that node and is
## loud only near it. The player frees itself when the clip ends (or when the
## node is freed).

const SHIELD_UP := preload("res://sounds/vadim_makes_sound-sci-fi-energy-shield-activation-566095.mp3")
const SHIELD_DOWN := preload("res://sounds/freesound_community-shielddrop-94887.mp3")
const OVERRIDE := preload("res://sounds/49053354-electrical-current-2-307466.mp3")
const RAILGUN := preload("res://sounds/rescopicsound-sci-fi-weapon-shoot-firing-pulse-tm-05-233825.mp3")
const EMP := preload("res://sounds/freesound_community-electric_zap_001-6374.mp3")
const SPIKE_DROP := preload("res://sounds/freesound_community-crowbar-drop-1-rear-88429.mp3")
const BARRIER_SMASH := preload("res://sounds/freesound_community-planks-clattering-14700Short.mp3")
const HK_LAUNCH := preload("res://sounds/fronbondi_skegs-field-launching-a-small-model-rocket-recording-240139.mp3")
const HK_WARNING := preload("res://sounds/freesound_community-missile-lock-detected-34074JustBeeps.mp3")
const HK_EXPLOSION := preload("res://sounds/voicebosch-missile-explosion-168600.mp3")

## Headroom above each clip's level for the closest listener (Godot caps a
## 3D sound at max_db, so raising volume_db alone does nothing).
const HEADROOM_DB := 3.0

## Distance (m) at which a sound is at full volume before it starts fading.
const UNIT_SIZE := 12.0


## Level (dB) for each clip, so its loudest moments sit just above the race
## music (music averages about -11 dB; the clips were mastered anywhere from
## -5 to -30 dB, measured as peak and loudest 100 ms).
static func level_db(stream: AudioStream) -> float:
	match stream:
		SHIELD_UP: return 5.0
		SHIELD_DOWN: return 7.0
		OVERRIDE: return -2.0
		RAILGUN: return -5.0
		EMP: return 6.0
		SPIKE_DROP: return 5.0
		BARRIER_SMASH: return 7.0
		HK_LAUNCH: return 3.0
		HK_WARNING: return 8.0
		HK_EXPLOSION: return 5.0
	return 0.0


## Plays `stream` on `node` at its level plus `volume_db`, and returns the
## player (null when `node` isn't in the scene tree). Players are named
## "Sfx<name>" so tests can find them.
static func play_on(node: Node3D, stream: AudioStream, sfx_name: String, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if node == null or not node.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "Sfx" + sfx_name
	player.stream = stream
	player.bus = &"SFX"
	player.unit_size = UNIT_SIZE
	player.volume_db = level_db(stream) + volume_db
	player.max_db = player.volume_db + HEADROOM_DB
	player.finished.connect(player.queue_free)
	node.add_child(player)
	player.play()
	return player
