class_name TrackCatalog
extends RefCounted
## Every raceable track (GDD 8). Tracks still to be built in Phase 6 race on
## the test circuit under their own name until their scene exists.

const TEST_CIRCUIT := "res://scenes/tracks/test_circuit.tscn"

## [name, scene path or "" (not built yet), location, race music or "" (none)]
const TRACKS := [
	["The Stacks", "res://scenes/tracks/the_stacks.tscn", "Library of Congress, Washington, DC",
			"res://music/lilex-cyber-dreams-314323.mp3"],
	["Six Flags New Orleans", "res://scenes/tracks/six_flags_new_orleans.tscn", "Louisiana",
			"res://music/theboysbeats-the-boy-s-beats-race-winner-282390.mp3"],
	["Vegas Overdrive", "res://scenes/tracks/vegas_overdrive.tscn", "Las Vegas, Nevada",
			"res://music/spmusic-heavy-racing-151129.mp3"],
	["Hoia Baciu Run", "res://scenes/tracks/hoia_baciu.tscn", "Romania",
			"res://music/kulakovka-cyberpunk-music-624631.mp3"],
	["Catacombs Descent", "res://scenes/tracks/catacombs_descent.tscn", "Paris, France",
			"res://music/kulakovka-hard-cyberpunk-281149.mp3"],
	["Arashiyama Circuit", "res://scenes/tracks/arashiyama_circuit.tscn", "Kyoto, Japan",
			"res://music/ob-lix-the-cyber-geisha-world-ethnic-amp-fantasy-background-music-110365.mp3"],
	["Vatnajökull Glacier", "res://scenes/tracks/vatnajokull_glacier.tscn", "Vatnajökull, Iceland",
			"res://music/ed-musicproductions-besieged-castle-397025.mp3"],
	["Crazy House", "res://scenes/tracks/crazy_house.tscn", "Hang Nga Villa, Da Lat, Vietnam",
			"res://music/sonican-spooky-halloween-strange-house-420678.mp3"],
	["Gardens by the Bay", "res://scenes/tracks/gardens_by_the_bay.tscn", "Marina Bay, Singapore",
			"res://music/elisaveta_stoycheva-garden-fairytale-368607.mp3"],
	["Parque Quinta Normal", "res://scenes/tracks/quinta_normal.tscn", "Santiago, Chile",
			"res://music/theorienvibes-to-the-moon-and-back-232892.mp3"],
	["Vale da Lua", "res://scenes/tracks/vale_da_lua.tscn", "Chapada dos Veadeiros, Brazil",
			"res://music/restum-anoush-rise-of-the-phoenix-265090.mp3"],
	["Choquequirao", "res://scenes/tracks/choquequirao.tscn", "Cusco Region, Peru",
			"res://music/desifreemusic-epic-victory-march-for-heroes-triumph-amp-celebration-462007.mp3"],
	["Kilwa Kisiwani Ruins", "res://scenes/tracks/kilwa_kisiwani.tscn", "Kilwa Kisiwani, Tanzania",
			"res://music/vishiv-the-dragons-lair-351312.mp3"],
	["Fires of Nyiragongo", "res://scenes/tracks/nyiragongo.tscn", "Nyiragongo, D.R. Congo",
			"res://music/jean-paul-v-danger-imminent-317370.mp3"],
	["Chefchaouen", "res://scenes/tracks/chefchaouen.tscn", "Chefchaouen, Morocco", ""],
	["Test Circuit", TEST_CIRCUIT, "Graybox",
			"res://music/stageechoesmusic-the-garden-wakes-628640.mp3"],
]


static func names() -> Array[String]:
	var out: Array[String] = []
	for t in TRACKS:
		out.append(t[0])
	return out


static func scene_path(track_name: String) -> String:
	for t in TRACKS:
		if t[0] == track_name and t[1] != "":
			return t[1]
	return TEST_CIRCUIT


static func scene(track_name: String) -> PackedScene:
	return load(scene_path(track_name)) as PackedScene


## Location line for a track ("" if unknown).
static func location(track_name: String) -> String:
	for t in TRACKS:
		if t[0] == track_name:
			return t[2]
	return ""


## Race music for a track ("" for none).
static func music(track_name: String) -> String:
	for t in TRACKS:
		if t[0] == track_name:
			return t[3]
	return ""


static func is_built(track_name: String) -> bool:
	for t in TRACKS:
		if t[0] == track_name:
			return t[1] != ""
	return false
