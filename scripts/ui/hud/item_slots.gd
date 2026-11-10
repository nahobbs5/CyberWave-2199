class_name ItemSlots
extends VBoxContainer
## Held items: two neon squares with a number badge in the corner (after
## the slipstream art). Bottom right in single player (bottom_anchored: the
## notices stack above the squares), top right in split screen. The active
## slot is larger with a bright cyan edge and an ACTIVE caption; the other
## is smaller and dim, STORED. Switching
## slots resizes them briefly; picking an item up flashes the slot and pops
## the icon in; using one (or losing a charge) puffs the icon out. Under the
## slots: target lock, active effects and combat notices.

const ACTIVE_SIZE := 88.0
const STORED_SIZE := 72.0
const ACTIVE_BORDER := Color(0.25, 0.9, 1.0)
const STORED_BORDER := Color(0.5, 0.35, 0.75, 0.8)

var panels: Array[PanelContainer] = []
var icons: Array[TextureRect] = []
## Weapon-name fallback when a weapon has no picture.
var names: Array[Label] = []
var keys: Array[Label] = []
var counts: Array[Label] = []
var captions: Array[Label] = []
var empties: Array[Label] = []
var lock_label: Label
var status_label: Label
var notice: Label
## Notices above the squares (bottom-right placement).
var bottom_anchored: bool = false
## "1  Firewall", "2  EMPTY", "1  Triple Nitro  x3"
var slot_text: Array[String] = ["1  EMPTY", "2  EMPTY"]

## Animations started (tests).
var pickup_anims: int = 0
var use_anims: int = 0

var _last_weapon: Array = [null, null]
var _last_charges: Array[int] = [0, 0]
var _last_selected: int = -1
var _notice_time: float = 0.0


func _init() -> void:
	name = "ItemSlots"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -20.0
	offset_top = 16.0
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for i in ItemInventory.SLOT_COUNT:
		row.add_child(_build_slot(i))
	lock_label = _right(UIStyle.stat("", 17, UIStyle.MAGENTA))
	status_label = _right(UIStyle.stat("", 15, UIStyle.GOLD))
	lock_label.visible = false
	status_label.visible = false
	notice = _right(UIStyle.stat("", 20, Color.WHITE))
	notice.visible = false


func _right(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	return label


func _build_slot(i: int) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % (i + 1)
	var style := UIStyle.box_style(UIStyle.PANEL_BG, STORED_BORDER, 3, 2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2.ONE * STORED_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	column.add_child(panel)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.resized.connect(func() -> void: icon.pivot_offset = icon.size * 0.5)
	stack.add_child(icon)
	var fallback := UIStyle.stat("", 13, Color.WHITE)
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback.visible = false
	stack.add_child(fallback)
	var empty := UIStyle.stat("EMPTY", 13, Color(1, 1, 1, 0.25))
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(empty)
	# Number badge in the bottom-right corner.
	var key := UIStyle.heading(str(i + 1), 20, Color(1, 1, 1, 0.3))
	key.add_theme_font_override("font", UIStyle.slanted_font(true))
	var badge := UIStyle.box_style(Color(0.02, 0.01, 0.06, 0.9), Color(1, 1, 1, 0.0), 0, 0)
	badge.set_corner_radius_all(6)
	badge.content_margin_left = 6
	badge.content_margin_right = 5
	key.add_theme_stylebox_override("normal", badge)
	key.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	key.grow_vertical = Control.GROW_DIRECTION_BEGIN
	key.offset_right = 2
	key.offset_bottom = 2
	stack.add_child(key)
	var count := UIStyle.heading("", 16, UIStyle.GOLD)
	count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.offset_right = -3
	stack.add_child(count)
	var caption := UIStyle.stat("STORED", 13, UIStyle.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	panels.append(panel)
	icons.append(icon)
	names.append(fallback)
	empties.append(empty)
	keys.append(key)
	counts.append(count)
	captions.append(caption)
	return column


## Bottom-right placement: the notices go above the squares, which sit at
## the bottom of this column (the owner positions the column).
func set_bottom_anchored() -> void:
	bottom_anchored = true
	alignment = BoxContainer.ALIGNMENT_END
	move_child(get_child(0), get_child_count() - 1)


func show_notice(text: String, color: Color) -> void:
	notice.text = text
	notice.add_theme_color_override("font_color", color)
	notice.visible = true
	_notice_time = 1.6


## Whose items (split screen: this view's player); null = player 1.
var racer: RaceProgress


func refresh(race: RaceManager, delta: float) -> void:
	var car := (racer if racer != null else race.player).vehicle
	var inventory := car.inventory
	for i in ItemInventory.SLOT_COUNT:
		var weapon := inventory.slots[i]
		var charges := inventory.charges[i]
		var selected := i == inventory.selected
		var weapon_text := "EMPTY"
		if weapon != null:
			weapon_text = weapon.display_name
			if weapon.charges > 1:
				weapon_text += "  x%d" % charges
		slot_text[i] = "%d  %s" % [i + 1, weapon_text]
		# The picture from the Weapon Arsenal art; the name only as a fallback.
		var icon: Texture2D = weapon.icon if weapon != null else null
		if weapon != _last_weapon[i] and weapon != null:
			_pickup(i, weapon)
		elif _last_weapon[i] != null and (weapon == null or (weapon == _last_weapon[i] and charges < _last_charges[i])):
			_used(i, _last_weapon[i] as WeaponData)
		_last_weapon[i] = weapon
		_last_charges[i] = charges
		icons[i].texture = icon
		names[i].visible = weapon != null and icon == null
		names[i].text = weapon.display_name if weapon != null else ""
		empties[i].visible = weapon == null
		panels[i].tooltip_text = weapon.display_name if weapon != null else ""
		keys[i].add_theme_color_override("font_color", Color.WHITE if weapon != null else Color(1, 1, 1, 0.3))
		counts[i].text = "x%d" % charges if weapon != null and weapon.charges > 1 else ""
		var style := panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if selected:
			style.border_color = ACTIVE_BORDER
			style.bg_color = Color(0.06, 0.04, 0.2, 0.88) if weapon != null else Color(0.05, 0.02, 0.14, 0.55)
			style.shadow_color = Color(ACTIVE_BORDER, 0.35)
			style.shadow_size = 8
		else:
			style.border_color = STORED_BORDER if weapon != null else Color(1, 1, 1, 0.12)
			style.bg_color = Color(0.04, 0.02, 0.12, 0.75 if weapon != null else 0.35)
			style.shadow_size = 0
		style.set_border_width_all(3 if selected else 2)
		captions[i].text = "ACTIVE" if selected else "STORED"
		captions[i].add_theme_color_override("font_color", ACTIVE_BORDER if selected else UIStyle.MUTED)
	if inventory.selected != _last_selected:
		_resize_slots(inventory.selected, _last_selected != -1)
		_last_selected = inventory.selected

	var targeting := car.targeting
	var current := inventory.current()
	if current != null and current.targeted and targeting != null and targeting.candidate != null:
		var progress := race.progress_of(targeting.candidate)
		var who := progress.display_name if progress != null else "?"
		lock_label.text = ("LOCKED  %s" % who) if targeting.locked else ("locking %s..." % who)
		lock_label.add_theme_color_override("font_color", UIStyle.MAGENTA if targeting.locked else Color(1, 1, 1, 0.7))
	elif current != null and current.targeted:
		lock_label.text = "no target"
		lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	else:
		lock_label.text = ""
	lock_label.visible = lock_label.text != ""

	var effects: PackedStringArray = []
	if car.status != null:
		for effect in car.status.active_effects():
			effects.append("%s %.1fs" % [String(effect).to_upper(), car.status.time_left(effect)])
		if car.status.is_protected():
			effects.append("PROTECTED")
	status_label.text = "  ".join(effects)
	status_label.visible = status_label.text != ""

	if _notice_time > 0.0:
		_notice_time -= delta
		notice.visible = _notice_time > 0.0


func _resize_slots(selected: int, animate: bool) -> void:
	for i in panels.size():
		var target := Vector2.ONE * (ACTIVE_SIZE if i == selected else STORED_SIZE)
		if animate:
			var t := panels[i].create_tween()
			t.tween_property(panels[i], "custom_minimum_size", target, 0.15).set_ease(Tween.EASE_OUT)
		else:
			panels[i].custom_minimum_size = target


## Flash the slot in the item's colour and pop the icon in.
func _pickup(i: int, weapon: WeaponData) -> void:
	pickup_anims += 1
	var panel := panels[i]
	var icon := icons[i]
	panel.modulate = Color(1.0, 1.0, 1.0) + Color(weapon.color, 0.0) * 0.8
	icon.scale = Vector2.ONE * 1.4
	var t := panel.create_tween().set_parallel()
	t.tween_property(panel, "modulate", Color.WHITE, 0.35)
	t.tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A ghost of the icon grows and fades where the item was.
func _used(i: int, weapon: WeaponData) -> void:
	use_anims += 1
	if weapon.icon == null:
		return
	var ghost := TextureRect.new()
	ghost.texture = weapon.icon
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := icons[i].get_parent() as Control
	ghost.size = stack.size
	ghost.pivot_offset = stack.size * 0.5
	stack.add_child(ghost)
	var t := ghost.create_tween().set_parallel()
	t.tween_property(ghost, "scale", Vector2.ONE * 1.5, 0.3)
	t.tween_property(ghost, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(ghost.queue_free)
