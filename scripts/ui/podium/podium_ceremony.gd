class_name PodiumCeremony
extends CanvasLayer
## The victory podium (GDD 11.7a), after "reference files/Neon Grand Prix
## Victory Podium.png". Shown at the end of a Grand Prix, at the end of a
## Versus set, and after a single Versus race, before the results screen.
##
## A full-screen PodiumStage (the top three's cars driving onto neon
## platforms that rise, a crown over the winner, spotlights) under a 2D
## layer: the "GRAND PRIX / CONGRATULATIONS!" banner, a place tag on each
## platform, the cup's trophy (Grand Prix), confetti, a fanfare and an
## "A Continue" prompt. Grand Prix places come from the cup standings, a
## Versus set's from its points, a single race's from the finishing order.
## The Grand Prix ceremony is longer and bigger.
##
## Accept / click skips to the end; accept again emits `finished` (the
## results open) and the ceremony fades out.

signal finished

## Tests: skip the ceremony and open the results straight away.
static var instant: bool = false

## Optional real fanfare clip; a synthesized one is used without it.
const FANFARE_PATHS: Array[String] = ["res://sounds/victory_fanfare.ogg", "res://sounds/victory_fanfare.mp3", "res://sounds/victory_fanfare.wav"]
const PLACE_NAMES: Array[String] = ["1ST", "2ND", "3RD"]
## Ignore accept this long after it appears (A is also the weapon button).
const INPUT_GRACE := 0.6
const FADE := 0.4

## {id, name, color, is_human, look} per podium place, best first.
var entries: Array = []
var grand: bool = false
## "GRAND PRIX  /  AMERICAN CUP", "VERSUS SET  /  4 RACES", "VERSUS  /  VEGAS OVERDRIVE"
var mode_text: String = ""
## "CONGRATULATIONS!" when a human made the top three, else "FINAL PODIUM".
var title_text: String = ""
## Under the winner's tag: "CUP CHAMPION", "SET WINNER" or "RACE WINNER".
var winner_text: String = ""
var emblem: String = ""

var stage: PodiumStage
var root: Control
var banner: Control
var title_label: Label
var mode_label: Label
var tags: Array[Control] = []
var prompt: Control
var trophy: TrophyIcon
var confetti: Array[CPUParticles2D] = []
var fanfare: AudioStreamPlayer

## Seconds into the ceremony; negative while waiting to start.
var time: float = 0.0
var _done: bool = false
var _played_fanfare: bool = false
var _since_shown: float = 0.0


## Should this race end with a podium? The last race of a Grand Prix or a
## Versus set, or a single Versus race.
static func wants_podium(race: RaceManager) -> bool:
	if race == null or race.config == null:
		return false
	if race.championship != null:
		return race.championship.is_complete()
	return race.config.mode == RaceConfig.Mode.VERSUS


## Ids of the top three: cup / set standings, else this race's order.
static func podium_ids(race: RaceManager) -> Array[int]:
	var ids: Array[int] = []
	if race.championship != null:
		ids = race.championship.standings()
	else:
		for racer in race.get_standings():
			ids.append(racer.racer_id)
	return ids.slice(0, 3)


static func entries_for(race: RaceManager) -> Array:
	var out: Array = []
	for id in podium_ids(race):
		var racer: RaceProgress = null
		for r in race.racers:
			if r.racer_id == id:
				racer = r
		if racer == null:
			continue
		var human := RaceConfig.is_human_id(id)
		var tag_color := Color.WHITE
		if human:
			tag_color = SplitScreen.PLAYER_COLORS[RaceConfig.human_slot(id)] if race.is_multiplayer() else UIStyle.MAGENTA
		out.append({
			"id": id,
			"name": racer.display_name.to_upper(),
			"color": tag_color,
			"is_human": human,
			"look": race.racer_look(id, racer.color),
		})
	return out


## Shows the podium when the race wants one, then opens `results`;
## otherwise opens `results` now. `delay` lets "FINISH!" show first.
static func open_then(race: RaceManager, results: ResultsScreen, delay: float = 0.0) -> PodiumCeremony:
	if instant or not wants_podium(race):
		results.open(race)
		return null
	var ceremony := PodiumCeremony.new()
	ceremony.setup_from_race(race)
	ceremony.time = -delay
	ceremony.finished.connect(func() -> void:
		if is_instance_valid(results):
			results.open(race))
	race.add_child(ceremony)
	return ceremony


func setup_from_race(race: RaceManager) -> void:
	var c := race.championship
	var any_human := false
	var e := entries_for(race)
	for entry in e:
		any_human = any_human or bool(entry.is_human)
	var mode := ""
	var winner := ""
	var p_grand := false
	if c != null and not c.is_series():
		p_grand = true
		mode = "GRAND PRIX  /  %s" % c.gp.display_name.to_upper()
		winner = "CUP CHAMPION"
		emblem = c.gp.emblem
	elif c != null:
		mode = "%s SET  /  %d RACES" % [RaceConfig.MODE_NAMES[c.series_mode].to_upper(), c.race_count()]
		winner = "SET WINNER"
	else:
		mode = "VERSUS  /  %s" % race.config.track_name.to_upper()
		winner = "RACE WINNER"
	setup(e, p_grand, mode, "CONGRATULATIONS!" if any_human else "FINAL PODIUM", winner)


func setup(p_entries: Array, p_grand: bool, p_mode: String, p_title: String, p_winner: String) -> void:
	entries = p_entries
	grand = p_grand
	mode_text = p_mode
	title_text = p_title
	winner_text = p_winner


func _init() -> void:
	name = "PodiumCeremony"
	layer = 15


func _ready() -> void:
	_build()
	stage.setup(entries, grand)
	stage.set_progress(maxf(time, 0.0))
	root.visible = time >= 0.0
	_update_overlay()


func duration() -> float:
	return PodiumStage.timeline(grand)[3]


func is_prompt_shown() -> bool:
	return prompt != null and prompt.visible and prompt.modulate.a > 0.5


func is_finished() -> bool:
	return _done


## Jumps to the end of the ceremony (prompt showing).
func skip() -> void:
	time = maxf(time, duration())
	_since_shown = maxf(_since_shown, INPUT_GRACE)
	root.visible = true
	root.modulate.a = 1.0
	_advance(0.0)


## Closes the ceremony: emits `finished` and fades out.
func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	for p in confetti:
		p.emitting = false
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _done:
		return
	_advance(delta)


func _advance(delta: float) -> void:
	time += delta
	if time < 0.0:
		return
	if not root.visible:
		root.visible = true
		root.modulate.a = 0.0
	_since_shown += delta
	root.modulate.a = minf(1.0, root.modulate.a + delta / FADE) if delta > 0.0 else root.modulate.a
	stage.set_progress(minf(time, duration()))
	var tl := PodiumStage.timeline(grand)
	if time >= tl[1] and not _played_fanfare:
		_celebrate()
	_update_overlay()


## Confetti, flashes and the fanfare as the crown drops.
func _celebrate() -> void:
	if _played_fanfare:
		return
	_played_fanfare = true
	for p in confetti:
		p.emitting = true
	if fanfare != null:
		fanfare.play()


func _update_overlay() -> void:
	var tl := PodiumStage.timeline(grand)
	var t := maxf(time, 0.0)
	for i in tags.size():
		var tag := tags[i]
		var k := 1.0 if stage.is_risen(i, t) else 0.0
		if k > 0.0 and tag.modulate.a < 1.0:
			tag.modulate.a = minf(1.0, tag.modulate.a + get_process_delta_time() / 0.25) if t < duration() else 1.0
		elif k == 0.0:
			tag.modulate.a = 0.0
		if i < stage.platforms.size():
			var at := stage.screen_point(stage.tag_anchor(i))
			tag.position = at - Vector2(tag.size.x * 0.5, 0.0)
	var b := clampf(t / 0.6, 0.0, 1.0)
	banner.modulate.a = b
	banner.position.x = lerpf(-60.0, 0.0, b) + 36.0
	if trophy != null:
		trophy.modulate.a = clampf((t - tl[1]) / 0.5, 0.0, 1.0)
	_place_confetti()
	var pk := clampf((t - tl[2]) / 0.5, 0.0, 1.0)
	prompt.visible = pk > 0.0
	prompt.modulate.a = pk


## Keeps the confetti spanning the screen (wide windows are wider than 1280).
func _place_confetti() -> void:
	var w := root.size.x
	for p in confetti:
		if p.one_shot:
			p.position = Vector2(w * 0.5 + signf(p.position.x - w * 0.5) * (w * 0.5 + 20.0), root.size.y + 20.0)
		else:
			p.position = Vector2(w * 0.5, -20.0)
			p.emission_rect_extents = Vector2(w * 0.5 + 60.0, 10.0)


func _input(event: InputEvent) -> void:
	if _done or time < 0.0 or not root.visible:
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (click or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	if _since_shown < INPUT_GRACE:
		return
	# Once the Continue prompt is coming up, accept continues; before that
	# it skips to the end of the ceremony.
	if time < PodiumStage.timeline(grand)[2]:
		skip()
	else:
		finish()


# --- layout -------------------------------------------------------------------

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.0, 0.05)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	stage = PodiumStage.new()
	root.add_child(stage)
	root.add_child(NeonSwoosh.new())

	for i in mini(entries.size(), 3):
		var tag := _place_tag(i, entries[i])
		tag.modulate.a = 0.0
		root.add_child(tag)
		tags.append(tag)

	_build_banner()
	if grand:
		trophy = TrophyIcon.new(emblem, false, 120.0)
		trophy.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		trophy.position = Vector2(-160, 24)
		trophy.modulate.a = 0.0
		root.add_child(trophy)
	_build_confetti()
	_build_prompt()
	_build_fanfare()


func _build_banner() -> void:
	banner = VBoxContainer.new()
	banner.name = "Banner"
	banner.position = Vector2(36, 22)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 0)
	root.add_child(banner)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	banner.add_child(chip_row)
	var chip := PanelContainer.new()
	var chip_style := UIStyle.box_style(Color(0.35, 0.05, 0.55, 0.9), UIStyle.MAGENTA, 8, 2)
	chip_style.skew = Vector2(0.3, 0.0)
	chip_style.content_margin_left = 18
	chip_style.content_margin_right = 18
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)
	chip_row.add_child(chip)
	mode_label = Label.new()
	mode_label.text = mode_text
	mode_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	mode_label.add_theme_font_size_override("font_size", 26)
	mode_label.add_theme_color_override("font_color", Color.WHITE)
	chip.add_child(mode_label)
	var checker := NeonWidgets.Checker.new(Color(UIStyle.MAGENTA, 0.85), 2, false)
	checker.custom_minimum_size = Vector2(110, 26)
	checker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(checker)
	title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_override("font", UIStyle.slanted_font(true))
	title_label.add_theme_font_size_override("font_size", 84 if grand else 72)
	title_label.add_theme_color_override("font_color", UIStyle.GOLD)
	title_label.add_theme_color_override("font_outline_color", Color(0.75, 0.05, 0.6))
	title_label.add_theme_constant_override("outline_size", 16)
	title_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.0, 0.3, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 5)
	title_label.add_theme_constant_override("shadow_offset_y", 6)
	banner.add_child(title_label)


## "1ST | NAME" bar for a platform (plus the winner's ribbon).
func _place_tag(i: int, entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "Tag%d" % (i + 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	var bar := PanelContainer.new()
	var style := UIStyle.box_style(Color(0.03, 0.01, 0.08, 0.88), PodiumStage.PLACE_COLORS[i], 6, 2)
	style.skew = Vector2(0.3, 0.0)
	style.content_margin_left = 6
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", style)
	box.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var chip := PanelContainer.new()
	var chip_style := UIStyle.box_style(PodiumStage.PLACE_COLORS[i], Color(0, 0, 0, 0), 4, 0)
	chip_style.skew = Vector2(0.3, 0.0)
	chip_style.content_margin_left = 12
	chip_style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", chip_style)
	row.add_child(chip)
	var place := Label.new()
	place.text = PLACE_NAMES[i]
	place.add_theme_font_override("font", UIStyle.slanted_font(true))
	place.add_theme_font_size_override("font_size", 30 if i == 0 else 26)
	place.add_theme_color_override("font_color", Color(0.05, 0.02, 0.12))
	chip.add_child(place)
	var who := Label.new()
	who.name = "Name"
	who.text = str(entry.get("name", "?"))
	who.add_theme_font_override("font", UIStyle.slanted_font(true))
	who.add_theme_font_size_override("font_size", 30 if i == 0 else 26)
	who.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
	who.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	who.add_theme_constant_override("outline_size", 4)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	if i == 0 and winner_text != "":
		var ribbon := Label.new()
		ribbon.name = "Ribbon"
		ribbon.text = winner_text
		ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ribbon.add_theme_font_override("font", UIStyle.slanted_font(false))
		ribbon.add_theme_font_size_override("font_size", 22)
		ribbon.add_theme_color_override("font_color", UIStyle.GOLD)
		ribbon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		ribbon.add_theme_constant_override("outline_size", 5)
		box.add_child(ribbon)
	return box


func _build_prompt() -> void:
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	var pill := PanelContainer.new()
	pill.name = "Prompt"
	var style := UIStyle.box_style(Color(0.05, 0.01, 0.12, 0.85), UIStyle.MAGENTA, 10, 2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 26
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(MenuHints.new([["A", "Enter", "Continue"]]))
	pill.position = Vector2(-260, -86)
	pill.visible = false
	anchor.add_child(pill)
	prompt = pill


## Neon confetti from the top edge; a Grand Prix adds two corner cannons.
func _build_confetti() -> void:
	var calm := GameSettings.reduced_flashing
	var rain := _confetti_emitter((220 if grand else 120) / (2 if calm else 1))
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(700, 10)
	rain.position = Vector2(640, -20)
	rain.direction = Vector2(0, 1)
	rain.spread = 25.0
	rain.initial_velocity_min = 60.0
	rain.initial_velocity_max = 180.0
	rain.gravity = Vector2(0, 160)
	rain.lifetime = 5.0
	if not grand or calm:
		return
	for side in [-1.0, 1.0]:
		var cannon := _confetti_emitter(90)
		cannon.one_shot = true
		cannon.explosiveness = 0.85
		cannon.position = Vector2(640.0 + side * 660.0, 740.0)
		cannon.direction = Vector2(-side * 0.45, -1.0)
		cannon.spread = 18.0
		cannon.initial_velocity_min = 650.0
		cannon.initial_velocity_max = 950.0
		cannon.gravity = Vector2(0, 520)
		cannon.lifetime = 3.0


func _confetti_emitter(amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(amount, 1)
	p.emitting = false
	p.texture = _confetti_texture()
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.damping_min = 10.0
	p.damping_max = 30.0
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	ramp.colors = PackedColorArray([UIStyle.GOLD, UIStyle.MAGENTA, UIStyle.CYAN, Color(1.0, 0.95, 0.7), Color(0.6, 0.4, 1.0)])
	p.color_initial_ramp = ramp
	root.add_child(p)
	confetti.append(p)
	return p


static var _confetti_tex: Texture2D


static func _confetti_texture() -> Texture2D:
	if _confetti_tex == null:
		var img := Image.create(10, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_confetti_tex = ImageTexture.create_from_image(img)
	return _confetti_tex


func _build_fanfare() -> void:
	fanfare = AudioStreamPlayer.new()
	fanfare.bus = &"SFX"
	fanfare.volume_db = -4.0
	fanfare.stream = fanfare_stream(grand)
	add_child(fanfare)


## A real clip when one is in sounds/, else a short synthesized brass call:
## C-E-G and a held high C (Grand Prix: a longer call ending on a chord).
static func fanfare_stream(p_grand: bool) -> AudioStream:
	for path in FANFARE_PATHS:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	# [start s, length s, frequencies]
	var notes: Array = [[0.0, 0.16, [523.25]], [0.17, 0.16, [659.25]], [0.34, 0.16, [783.99]], [0.51, 0.9, [1046.5]]]
	if p_grand:
		notes = [[0.0, 0.14, [392.0]], [0.15, 0.14, [523.25]], [0.30, 0.14, [659.25]], [0.45, 0.32, [783.99]],
				[0.80, 0.14, [659.25]], [0.95, 1.4, [523.25, 659.25, 783.99, 1046.5]]]
	var rate := 22050
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[0]) + float(n[1]) + 0.1)
	var count := int(rate * total)
	var mix := PackedFloat32Array()
	mix.resize(count)
	for n in notes:
		var start := int(float(n[0]) * rate)
		var length := int(float(n[1]) * rate)
		var freqs: Array = n[2]
		for i in length:
			var t := float(i) / rate
			var env := minf(1.0, t / 0.015) * (1.0 - 0.35 * float(i) / length)
			if i > length - int(0.05 * rate):
				env *= float(length - i) / (0.05 * rate)
			var s := 0.0
			for f in freqs:
				# A few odd and even harmonics for a brassy tone.
				var ph := TAU * float(f) * t
				s += sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph) + 0.15 * sin(4.0 * ph)
			mix[start + i] += s * env / (1.95 * freqs.size())
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(mix[i] * 0.45, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
