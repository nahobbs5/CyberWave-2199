class_name HallBuilder
extends RefCounted
## Builds an interior hall along a stretch of track (Library of Congress
## style): marble wainscot, plaster walls, marble pilasters, tall arched
## window bays (real openings, so a low sun throws shafts of light across
## the floor) or bookshelf bays, a coffered ceiling with painted panels and
## gilded ribs, and chandeliers. Corner-aware: anything that would stand on
## a road (junctions, other halls) is skipped. Visual only; the track
## barriers do the colliding.
##
## Materials expected on the scenery (keys): marble, plaster, gold, ceiling,
## glass (no shadow), books, wood, and paint0..paint3.

## Options: width (wall lateral from centre), height, bay (m), windows_left,
## windows_right, shelves_left, shelves_right, ceiling (bool),
## chandelier_every (m, 0 = none).
static func build(scenery: TrackScenery, from_offset: float, to_offset: float, opts: Dictionary = {}) -> void:
	var track := scenery.track
	var wall := float(opts.get("width", track.road_width * 0.5 + 6.0))
	var height := float(opts.get("height", 16.0))
	var bay := float(opts.get("bay", 12.0))
	var step := 3.0
	var d := from_offset
	var span := fposmod(to_offset - from_offset, track.length)
	var travelled := 0.0
	var light_every := float(opts.get("chandelier_every", 36.0))
	var next_light := light_every * 0.5
	while travelled < span:
		var center := scenery.at(d)
		var in_bay := fmod(travelled, bay)
		for side in [-1.0, 1.0]:
			var key_win := "windows_left" if side < 0.0 else "windows_right"
			var key_shelf := "shelves_left" if side < 0.0 else "shelves_right"
			var p := scenery.at(d, side * wall)
			if not scenery.clear(p.origin, 1.0):
				continue
			var face := p
			# Marble wainscot (0-3 m) and cornice band.
			scenery.add_box("marble", Vector3(1.0, 3.0, step + 0.05), face.translated_local(Vector3(0, 1.5, 0)))
			scenery.add_box("gold", Vector3(1.1, 0.25, step + 0.05), face.translated_local(Vector3(0, 3.1, 0)))
			var pier := in_bay < 3.0 # solid pier every bay
			if opts.get(key_win, false) and not pier:
				# Window bay: wall below the sill and above the arch, open between.
				scenery.add_box("plaster", Vector3(0.8, 2.0, step + 0.05), face.translated_local(Vector3(0, 4.2, 0)))
				scenery.add_box("plaster", Vector3(0.8, height - 13.0, step + 0.05), face.translated_local(Vector3(0, 13.0 + (height - 13.0) * 0.5, 0)))
				# Arch top (stepped) and the leaded glass, set outside the opening.
				var arch := absf(in_bay - (3.0 + (bay - 3.0) * 0.5)) / ((bay - 3.0) * 0.5)
				scenery.add_box("plaster", Vector3(0.8, 1.6 * arch * arch, step + 0.05), face.translated_local(Vector3(0, 13.0 - 0.8 * arch * arch, 0)))
				scenery.add_box("glass", Vector3(0.1, 7.8, step + 0.05), face.translated_local(Vector3(side * 0.9, 9.1, 0)))
			elif opts.get(key_shelf, false) and not pier:
				# Floor-to-cornice bookshelves.
				scenery.add_box("plaster", Vector3(0.8, height - 3.2, step + 0.05), face.translated_local(Vector3(side * 0.4, 3.2 + (height - 3.2) * 0.5, 0)))
				scenery.add_box("books", Vector3(0.6, 9.0, step + 0.05), face.translated_local(Vector3(-side * 0.05, 7.8, 0)))
				scenery.add_box("wood", Vector3(0.9, 0.2, step + 0.05), face.translated_local(Vector3(-side * 0.1, 12.4, 0)))
			else:
				scenery.add_box("plaster", Vector3(0.8, height - 3.2, step + 0.05), face.translated_local(Vector3(0, 3.2 + (height - 3.2) * 0.5, 0)))
			if pier and in_bay < step:
				# Marble pilaster with a gilded capital.
				scenery.add_box("marble", Vector3(1.6, height, 1.6), face.translated_local(Vector3(-side * 0.6, height * 0.5, 0)))
				scenery.add_box("gold", Vector3(2.0, 0.6, 2.0), face.translated_local(Vector3(-side * 0.6, height - 1.2, 0)))
		if opts.get("ceiling", true):
			scenery.add_box("ceiling", Vector3(wall * 2.0 + 2.0, 1.0, step + 0.05), center.translated_local(Vector3(0, height + 0.5, 0)))
			# Coffers: gilded ribs across and along, painted panels between.
			if in_bay < step:
				scenery.add_box("gold", Vector3(wall * 2.0, 0.5, 0.6), center.translated_local(Vector3(0, height - 0.25, 0)))
			for k in [-0.5, 0.0, 0.5]:
				scenery.add_box("gold", Vector3(0.4, 0.4, step + 0.05), center.translated_local(Vector3(k * wall * 1.6, height - 0.2, 0)))
			if fmod(travelled, bay * 2.0) > bay * 0.5 and fmod(travelled, bay * 2.0) < bay * 1.5:
				scenery.add_box("paint%d" % (int(travelled / (bay * 2.0)) % 4), Vector3(wall * 0.7, 0.1, step + 0.05),
						center.translated_local(Vector3(0, height - 0.1, 0)))
		if light_every > 0.0 and travelled >= next_light:
			_chandelier(scenery, center.translated_local(Vector3(0, height - 4.5, 0)))
			next_light += light_every
		d = track.wrap_offset(d + step)
		travelled += step


static func _chandelier(scenery: TrackScenery, xf: Transform3D) -> void:
	scenery.add_box("gold", Vector3(0.12, 3.0, 0.12), xf.translated_local(Vector3(0, 2.8, 0)))
	scenery.add_cyl("gold", 2.2, 0.3, xf, 12)
	scenery.add_cyl("gold", 1.3, 0.3, xf.translated_local(Vector3(0, 0.8, 0)), 10)
	for k in 8:
		var ang := TAU * k / 8.0
		scenery.add_sphere("candle", 0.18, xf.translated_local(Vector3(cos(ang) * 2.1, 0.45, sin(ang) * 2.1)), 3, 5)
	scenery.add_light(xf * Vector3(0, -0.5, 0), Color(1.0, 0.78, 0.5), 3.2, 26.0)


## A tall bookcase unit (stand-alone; for stacks and alcoves).
static func bookcase(scenery: TrackScenery, xf: Transform3D, width: float, height: float) -> void:
	scenery.add_box("wood", Vector3(width + 0.3, height + 0.3, 1.2), xf.translated_local(Vector3(0, (height + 0.3) * 0.5, -0.1)))
	scenery.add_box("books", Vector3(width, height, 1.25), xf.translated_local(Vector3(0, height * 0.5 + 0.15, 0)))
	scenery.add_box("wood", Vector3(width + 0.5, 0.3, 1.4), xf.translated_local(Vector3(0, height + 0.3, 0)))
