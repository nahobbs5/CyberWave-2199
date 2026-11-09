class_name Garage
extends Control
## Garage (GDD 11.4, 14.2 GarageManager / CosmeticShop), laid out after
## "reference files/Cyberwave 2199 Neon Garage.png": the neon garage room
## (VehiclePreview) fills the screen with the car on its turntable on the
## left, gold arrows and a dot per car over it; the car's name, stats and the
## license plate below; on the right COSMETICS / INFO tabs over a neon panel
## (category list + items, or the car's specs); Back and Apply at the bottom.
## Clicking an item's name tries it on in the preview; Buy spends coins
## (permanently, GDD 9.4) and equips; Equip puts an owned item on this
## vehicle; Apply equips every owned item being tried on.

const CATEGORY_ICONS := ["brush", "flags", "stripes", "layers", "rim", "plate", "burst", "exhaust"]
## Where the car sits in the full-screen room (see VehiclePreview.view_offset).
const VIEW_OFFSET := Vector2(2.95, -1.1)
const VIEW_ZOOM := 1.5

var vehicle_index: int = 0
var category: CosmeticItem.Category = CosmeticItem.Category.PAINT
## True while the INFO tab is open.
var info_open: bool = false

var showcase: CarShowcase
var cosmetics_tab: NeonMenuButton
var info_tab: NeonMenuButton
var back_button: Button
var _coin_pill: PanelContainer
## The full-screen 3D garage (kept as a field for the tests).
var _preview: VehiclePreview
var _plate: LineEdit
var _items: VBoxContainer
var _items_title: Label
var _message: Label
var _apply: Button
## The category list buttons.
var _tabs: Array[Button] = []
var _cosmetics_panel: Control
var _info_panel: Control
var _info_box: VBoxContainer
## category -> item being tried on (not equipped).
var _trying: Dictionary = {}


func _ready() -> void:
	InputSetup.ensure_actions()
	Music.play(get_tree(), Music.GARAGE)
	vehicle_index = VehicleCatalog.index_of(PlayerProfile.get_profile().selected_vehicle)
	_build()
	UIStyle.fade_in(self)
	_refresh_all()
	_tabs[0].grab_focus.call_deferred()


func back() -> void:
	GameSession.back_from_garage(get_tree())


## Opens the INFO tab (true) or COSMETICS (false).
func show_info(open: bool) -> void:
	info_open = open
	_cosmetics_panel.visible = not open
	_info_panel.visible = open
	cosmetics_tab.set_lit(not open)
	info_tab.set_lit(open)
	if open:
		_refresh_info()


## The INFO tab's text, for tests.
func info_text() -> String:
	var lines: PackedStringArray = []
	for l in _info_box.find_children("*", "Label", true, false):
		lines.append((l as Label).text)
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _plate.has_focus():
			_tabs[category].grab_focus()
		else:
			back()


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	if pad or event is InputEventKey:
		for b in [back_button, _apply]:
			(b as _ActionButton).set_gamepad(pad)


func vehicle() -> VehicleData:
	return VehicleCatalog.all()[vehicle_index]


func select_vehicle(index: int) -> void:
	vehicle_index = posmod(index, VehicleCatalog.all().size())
	PlayerProfile.get_profile().set_selected_vehicle(vehicle().id)
	_trying.clear()
	_message.text = ""
	_refresh_all()


func select_category(c: CosmeticItem.Category) -> void:
	category = c
	_refresh_items()


func try_on(item: CosmeticItem) -> void:
	_trying[item.category] = item
	_refresh_preview()
	_refresh_items()


## Returns true on success. Saves.
func buy(item: CosmeticItem) -> bool:
	var profile := PlayerProfile.get_profile()
	if profile.owns(item.id):
		_message.text = "You already own %s." % item.display_name
		return false
	if profile.coins < item.price:
		_message.text = "Not enough coins for %s (%d more needed)." % [item.display_name, item.price - profile.coins]
		return false
	profile.buy(item)
	profile.equip(vehicle().id, item)
	_trying.erase(item.category)
	_message.text = "Bought and equipped %s." % item.display_name
	_refresh_all()
	return true


func equip(item: CosmeticItem) -> bool:
	var ok := PlayerProfile.get_profile().equip(vehicle().id, item)
	if ok:
		_trying.erase(item.category)
		_message.text = "Equipped %s." % item.display_name
		_refresh_all()
	return ok


## The owned items being tried on that aren't equipped yet.
func pending_items() -> Array[CosmeticItem]:
	var profile := PlayerProfile.get_profile()
	var out: Array[CosmeticItem] = []
	for c in _trying:
		var item := _trying[c] as CosmeticItem
		if profile.owns(item.id) and profile.equipped_item(vehicle().id, c) != item:
			out.append(item)
	return out


## Equips every owned item being tried on; unowned ones stay previews.
## Returns how many were equipped. Saves.
func apply() -> int:
	var profile := PlayerProfile.get_profile()
	var items := pending_items()
	for item in items:
		profile.equip(vehicle().id, item)
		_trying.erase(item.category)
	if items.is_empty():
		_message.text = "Nothing to apply. Buy an item first, or pick one you own."
	else:
		_message.text = "Applied %d item%s." % [items.size(), "" if items.size() == 1 else "s"]
	_refresh_all()
	return items.size()


func set_plate(text: String) -> void:
	var clean := PlayerProfile.sanitize_plate(text)
	PlayerProfile.get_profile().set_plate(clean)
	if _plate.text != clean:
		var caret := _plate.caret_column
		_plate.text = clean
		_plate.caret_column = mini(caret, clean.length())
	_refresh_preview()



# --- refresh -----------------------------------------------------------------

func _refresh_all() -> void:
	(_coin_pill.find_child("Count", true, false) as Label).text = str(PlayerProfile.get_profile().coins)
	showcase.set_vehicle(vehicle_index, _loadout(), PlayerProfile.get_profile().plate_text)
	_refresh_apply()
	_refresh_items()
	if info_open:
		_refresh_info()


func _loadout() -> Dictionary:
	var loadout := PlayerProfile.get_profile().loadout_for(vehicle().id)
	for c in _trying:
		loadout[c] = _trying[c]
	return loadout


func _refresh_preview() -> void:
	showcase.show_loadout(_loadout(), PlayerProfile.get_profile().plate_text)
	_refresh_apply()


func _refresh_apply() -> void:
	var count := pending_items().size()
	_apply.disabled = count == 0
	_apply.text = "Apply" if count <= 1 else "Apply (%d)" % count
	_apply.queue_redraw()


func _refresh_items() -> void:
	for i in _tabs.size():
		_style_category(_tabs[i], i == category)
	_items_title.text = CosmeticItem.CATEGORY_NAMES[category].to_upper()
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	var profile := PlayerProfile.get_profile()
	var equipped := profile.equipped_item(vehicle().id, category)
	var trying := _trying.get(category) as CosmeticItem
	var first: Control = null
	for item in CosmeticCatalog.in_category(category):
		var row := PanelContainer.new()
		var border := Color(0.38, 0.4, 0.9, 0.45)
		var fill := Color(0.06, 0.04, 0.15, 0.85)
		if item == equipped:
			border = Color(0.35, 0.6, 1.0, 0.9)
		if item == trying:
			border = UIStyle.MAGENTA
			fill = Color(0.3, 0.05, 0.3, 0.8)
		var row_style := UIStyle.box_style(fill, border, 0, 2)
		row_style.set_corner_radius_all(10)
		row_style.content_margin_left = 10
		row_style.content_margin_right = 10
		row_style.content_margin_top = 3
		row_style.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", row_style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		row.add_child(line)
		var swatch := Panel.new()
		var swatch_style := UIStyle.box_style(vehicle().factory_color if item.style == "factory" else item.color,
				Color(1, 1, 1, 0.35), 0, 1)
		swatch_style.set_corner_radius_all(6)
		swatch.add_theme_stylebox_override("panel", swatch_style)
		swatch.custom_minimum_size = Vector2(32, 32)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
		var name_button := Button.new()
		name_button.text = item.display_name
		name_button.flat = true
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.custom_minimum_size = Vector2(90, 36)
		name_button.add_theme_font_size_override("font_size", 20)
		var bold := UIStyle.bold_font()
		if bold != null:
			name_button.add_theme_font_override("font", bold)
		name_button.add_theme_color_override("font_color", Color.WHITE)
		name_button.add_theme_color_override("font_hover_color", UIStyle.MAGENTA.lightened(0.35))
		name_button.add_theme_color_override("font_focus_color", UIStyle.MAGENTA.lightened(0.35))
		name_button.tooltip_text = "Preview it on the car"
		name_button.pressed.connect(try_on.bind(item))
		line.add_child(name_button)
		var action: Button
		if item == equipped:
			action = UIStyle.row_action("Equipped", "equipped", func() -> void: pass)
			action.disabled = true
			action.icon = UIStyle.icon_texture("check", 16, UIStyle.CYAN)
		elif profile.owns(item.id):
			action = UIStyle.row_action("Equip", "equip", equip.bind(item))
		else:
			action = UIStyle.row_action("Buy  %d" % item.price, "buy", buy.bind(item))
			action.disabled = profile.coins < item.price
		action.custom_minimum_size = Vector2(118, 34)
		action.add_theme_font_size_override("font_size", 18)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(action)
		var status := UIStyle.label("Owned" if profile.owns(item.id) else "", 15, UIStyle.MUTED)
		status.custom_minimum_size = Vector2(46, 0)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(status)
		_items.add_child(row)
		if first == null:
			first = name_button
		name_button.focus_neighbor_left = name_button.get_path_to(_tabs[category])
	if first != null:
		for tab in _tabs:
			tab.focus_neighbor_right = tab.get_path_to(first)


func _refresh_info() -> void:
	for child in _info_box.get_children():
		_info_box.remove_child(child)
		child.queue_free()
	var v := vehicle()
	var st := v.stats
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_info_box.add_child(title_row)
	var title := UIStyle.stat(v.display_name.to_upper(), 30, UIStyle.CYAN)
	title.add_theme_font_override("font", UIStyle.slanted_font(true))
	title_row.add_child(title)
	var kind := UIStyle.label(v.vehicle_type, 20, UIStyle.MUTED)
	kind.add_theme_font_override("font", UIStyle.slanted_font(false))
	kind.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(kind)
	_info_box.add_child(NeonWidgets.Divider.new())
	_info_box.add_child(_info_heading("HOW IT DRIVES"))
	var character := UIStyle.label(v.character, 19, Color(1, 1, 1, 0.9))
	character.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(character)
	_info_box.add_child(_info_heading("SPECS"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	_info_box.add_child(grid)
	var gold := st.boost_extra_speed.size() - 1
	var specs := [
		["Top speed", "%d km/h" % roundi(st.top_speed * 3.6)],
		["0-100 km/h", "%.1f s" % (100.0 / 3.6 / st.acceleration)],
		["Braking", "%d m from 100" % roundi(pow(100.0 / 3.6, 2.0) / (2.0 * st.brake_deceleration))],
		["Reverse", "%d km/h" % roundi(st.reverse_top_speed * 3.6)],
		["Handling", "%d / 10" % VehicleCatalog.rating("Handling", st.handling)],
		["Drift", "%d / 10" % VehicleCatalog.rating("Drift", st.drift)],
		["Gold boost", "+%d km/h, %.1f s" % [roundi(st.boost_extra_speed[gold] * 3.6), st.boost_duration[gold]]],
		["Grip", "%.0f" % st.grip],
	]
	for spec in specs:
		var l := UIStyle.label(spec[0], 18, UIStyle.MUTED)
		l.custom_minimum_size = Vector2(96, 0)
		grid.add_child(l)
		var value := UIStyle.stat(spec[1], 19, Color.WHITE)
		value.custom_minimum_size = Vector2(150, 0)
		grid.add_child(value)
	_info_box.add_child(_info_heading("EQUIPPED ON THIS CAR"))
	var equipped := GridContainer.new()
	equipped.columns = 4
	equipped.add_theme_constant_override("h_separation", 18)
	equipped.add_theme_constant_override("v_separation", 2)
	_info_box.add_child(equipped)
	var profile := PlayerProfile.get_profile()
	for c in CosmeticItem.Category.values():
		var item := profile.equipped_item(v.id, c)
		var l := UIStyle.label(CosmeticItem.CATEGORY_NAMES[c], 18, UIStyle.MUTED)
		l.custom_minimum_size = Vector2(96, 0)
		equipped.add_child(l)
		equipped.add_child(UIStyle.label(item.display_name if item != null else "Stock", 18, Color.WHITE))


func _info_heading(text: String) -> Control:
	var l := UIStyle.stat(text, 18, UIStyle.GOLD)
	l.add_theme_font_override("font", UIStyle.slanted_font(true))
	return l


# --- layout ------------------------------------------------------------------

func _build() -> void:
	UIStyle.background(self)
	_preview = VehiclePreview.new()
	_preview.detail = VehiclePreview.Detail.FULL
	_preview.view_offset = VIEW_OFFSET
	_preview.zoom = VIEW_ZOOM
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)
	add_child(_Shade.new())
	add_child(_TopLine.new())

	# Title and coins.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.position = Vector2(28, 4)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_row)
	title_row.add_child(UIStyle.logo(Vector2(210, 66)))
	for text in ["/", "GARAGE"]:
		var l := UIStyle.stat(text, 50 if text != "/" else 52, Color.WHITE if text != "/" else Color(1, 1, 1, 0.75))
		l.add_theme_font_override("font", UIStyle.slanted_font(true))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(l)
	_coin_pill = UIStyle.coin_pill(26)
	_coin_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_coin_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_coin_pill.offset_right = -28
	_coin_pill.offset_top = 14
	add_child(_coin_pill)

	# Left: arrows and dots over the car, then name, stats and the plate.
	showcase = CarShowcase.new(0.0, true, false)
	showcase.vehicle_changed.connect(select_vehicle)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.position = Vector2(20, 96)
	stage.size = Vector2(630, 300)
	add_child(stage)
	showcase.build_stage_in(stage, _preview)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.position = Vector2(28, 398)
	left.size = Vector2(620, 310)
	add_child(left)
	showcase.add_theme_constant_override("separation", 4)
	left.add_child(showcase)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gap)
	left.add_child(_plate_strip())

	# Right: tabs, the panel, Back / Apply.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right.offset_left = 664
	right.offset_right = -26
	right.offset_top = 80
	right.offset_bottom = -14
	add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	right.add_child(tabs)
	cosmetics_tab = _page_tab(tabs, "Cosmetics", "brush", false)
	info_tab = _page_tab(tabs, "Info", "info", true)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(holder)
	_cosmetics_panel = _build_cosmetics()
	holder.add_child(_cosmetics_panel)
	_info_panel = _build_info()
	holder.add_child(_info_panel)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	back_button = _ActionButton.new("Back", "B", "Esc", false)
	back_button.pressed.connect(back)
	buttons.add_child(back_button)
	_apply = _ActionButton.new("Apply", "A", "Enter", true)
	_apply.tooltip_text = "Equip the owned items you're previewing"
	_apply.pressed.connect(apply)
	buttons.add_child(_apply)
	(back_button as _ActionButton).set_gamepad(not Input.get_connected_joypads().is_empty())
	(_apply as _ActionButton).set_gamepad(not Input.get_connected_joypads().is_empty())
	_link_focus()
	show_info(false)


func _page_tab(parent: Container, text: String, icon_kind: String, info: bool) -> NeonMenuButton:
	var tab := NeonMenuButton.new(text, icon_kind)
	tab.chevrons = false
	tab.font_size = 26
	tab.custom_minimum_size = Vector2(262, 48)
	tab.pressed.connect(show_info.bind(info))
	tab.focus_entered.connect(show_info.bind(info))
	parent.add_child(tab)
	return tab


func _build_cosmetics() -> Control:
	var panel := NeonPanel.new(14, Color(0.3, 0.55, 1.0), UIStyle.MAGENTA)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	panel.add_child(split)
	var categories := VBoxContainer.new()
	categories.add_theme_constant_override("separation", 7)
	split.add_child(categories)
	for c in CosmeticItem.Category.values():
		var b := Button.new()
		b.text = CosmeticItem.CATEGORY_NAMES[c]
		b.icon = UIStyle.cached_icon(CATEGORY_ICONS[c], 26)
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 14)
		b.custom_minimum_size = Vector2(168, 42)
		b.add_theme_font_size_override("font_size", 20)
		var font := UIStyle.bold_font()
		if font != null:
			b.add_theme_font_override("font", font)
		b.pressed.connect(select_category.bind(c))
		b.focus_entered.connect(select_category.bind(c))
		categories.add_child(b)
		_tabs.append(b)
	var divider := ColorRect.new()
	divider.color = Color(0.55, 0.4, 1.0, 0.35)
	divider.custom_minimum_size = Vector2(2, 0)
	split.add_child(divider)
	var items_col := VBoxContainer.new()
	items_col.add_theme_constant_override("separation", 8)
	items_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(items_col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	items_col.add_child(head)
	var mark := NeonWidgets.Checker.new(UIStyle.CYAN, 2, true)
	mark.custom_minimum_size = Vector2(22, 18)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	_items_title = UIStyle.stat("", 30, UIStyle.CYAN)
	_items_title.add_theme_font_override("font", UIStyle.slanted_font(true))
	head.add_child(_items_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var corner := NeonWidgets.Checker.new(Color(0.55, 0.3, 0.95, 0.5), 2, true)
	corner.custom_minimum_size = Vector2(110, 30)
	head.add_child(corner)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_col.add_child(scroll)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 6)
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items)
	var hint := NeonWidgets.note("Click a name to preview it on the car.", UIStyle.GOLD, false)
	items_col.add_child(hint)
	_message = UIStyle.label("", 16, UIStyle.CYAN)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_col.add_child(_message)
	return panel


func _build_info() -> Control:
	var panel := NeonPanel.new(18, Color(0.3, 0.55, 1.0), UIStyle.MAGENTA)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 8)
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_info_box)
	return panel


## Tabs on top; categories go up to the open tab and right to the items;
## the last category and the items go down to Back / Apply.
func _link_focus() -> void:
	cosmetics_tab.focus_neighbor_right = cosmetics_tab.get_path_to(info_tab)
	info_tab.focus_neighbor_left = info_tab.get_path_to(cosmetics_tab)
	cosmetics_tab.focus_neighbor_bottom = cosmetics_tab.get_path_to(_tabs[0])
	info_tab.focus_neighbor_bottom = info_tab.get_path_to(back_button)
	for i in _tabs.size():
		var b := _tabs[i]
		b.focus_neighbor_top = b.get_path_to(_tabs[i - 1] if i > 0 else cosmetics_tab)
		b.focus_neighbor_bottom = b.get_path_to(_tabs[i + 1] if i < _tabs.size() - 1 else back_button)
		b.focus_neighbor_left = b.get_path_to(_plate)
	_plate.focus_neighbor_right = _plate.get_path_to(_tabs[0])
	for b in [back_button, _apply]:
		b.focus_neighbor_top = b.get_path_to(_tabs[_tabs.size() - 1])
	back_button.focus_neighbor_left = back_button.get_path_to(_plate)
	back_button.focus_neighbor_right = back_button.get_path_to(_apply)
	_apply.focus_neighbor_left = _apply.get_path_to(back_button)


## Category list entry: bright magenta when selected, dark otherwise.
func _style_category(b: Button, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(9)
		style.content_margin_left = 14
		style.content_margin_right = 10
		if selected:
			style.bg_color = Color(0.82, 0.16, 0.72) if state != "hover" else Color(0.9, 0.3, 0.8)
			style.border_color = Color(1.0, 0.75, 0.98)
			style.set_border_width_all(2)
			style.shadow_color = Color(UIStyle.MAGENTA, 0.45)
			style.shadow_size = 7
		else:
			style.bg_color = Color(0.07, 0.05, 0.16, 0.92) if state != "hover" else Color(0.14, 0.08, 0.28, 0.95)
			style.border_color = Color(0.45, 0.45, 0.9, 0.4)
			style.set_border_width_all(1)
		if state == "focus":
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
		b.add_theme_stylebox_override(state, style)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("icon_normal_color", Color.WHITE)


func _plate_strip() -> Control:
	var strip := NeonPanel.new(0, Color(0.3, 0.55, 1.0), UIStyle.MAGENTA)
	strip.radius = 10.0
	strip.glow = 6.0
	strip.edge_width = 2.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_child(row)
	strip.add_child(pad)
	var title := UIStyle.stat("LICENSE PLATE", 21)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	_plate = LineEdit.new()
	_plate.max_length = PlayerProfile.PLATE_MAX
	_plate.text = PlayerProfile.get_profile().plate_text
	_plate.custom_minimum_size = Vector2(210, 42)
	_plate.add_theme_font_size_override("font_size", 26)
	_plate.add_theme_font_override("font", UIStyle.slanted_font(true))
	for state in ["normal", "focus"]:
		var style := UIStyle.box_style(Color(0.02, 0.01, 0.05, 0.95),
				UIStyle.MAGENTA if state == "focus" else Color(1, 1, 1, 0.85), 8, 2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		_plate.add_theme_stylebox_override(state, style)
	_plate.right_icon = RaceIcons.texture("pencil", 22)
	_plate.text_changed.connect(set_plate)
	row.add_child(_plate)
	var note := UIStyle.label("Shared by every car\n(%d character max)" % PlayerProfile.PLATE_MAX, 16, Color(1, 1, 1, 0.75))
	note.add_theme_font_override("font", UIStyle.slanted_font(false))
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	return strip


## Darkens the right side (under the panels) and the bottom left (under the
## stats) so text reads over the garage.
class _Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var dark := Color(0.03, 0.01, 0.08)
		var x0 := size.x * 0.47
		var x1 := size.x * 0.56
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
				PackedColorArray([Color(dark, 0.0), Color(dark, 0.72), Color(dark, 0.72), Color(dark, 0.0)]))
		draw_rect(Rect2(x1, 0, size.x - x1, size.y), Color(dark, 0.72))
		var y0 := size.y * 0.5
		var y1 := size.y * 0.62
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(x0, y0), Vector2(x0, y1), Vector2(0, y1)]),
				PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), Color(dark, 0.7), Color(dark, 0.7)]))
		draw_rect(Rect2(0, y1, x0, size.y - y1), Color(dark, 0.7))
		draw_rect(Rect2(0, 0, size.x, 80), Color(dark, 0.45))


## The magenta-to-cyan line sweeping up under the title, like the mockup.
class _TopLine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := PackedVector2Array()
		var a := Vector2(-10, 102)
		var c := Vector2(size.x * 0.44, 70)
		var b := Vector2(size.x + 10, 0)
		for i in 33:
			var t := i / 32.0
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		var cols := PackedColorArray()
		var glow := PackedColorArray()
		for p in pts:
			var col := UIStyle.MAGENTA.lerp(UIStyle.CYAN, p.x / size.x)
			cols.append(col)
			glow.append(Color(col, 0.25))
		draw_polyline_colors(pts, glow, 8.0, true)
		draw_polyline_colors(pts, cols, 2.5, true)


## Back / Apply: a slanted bar with a pad glyph (B / A) or keycap, and slanted
## lettering. primary: gold (dimmed while disabled).
class _ActionButton extends Button:
	var primary: bool
	var _glyph: Control
	var _font: Font

	func _init(label_text: String, pad: String, key: String, is_primary: bool) -> void:
		text = label_text
		primary = is_primary
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(240 if not is_primary else 280, 56)
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		_font = UIStyle.slanted_font(true)
		_glyph = MenuHints._Glyph.new(pad, key)
		add_child(_glyph)
		mouse_entered.connect(func() -> void:
			if not disabled:
				grab_focus())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		resized.connect(_place_glyph)

	func set_gamepad(on: bool) -> void:
		_glyph.gamepad = on
		_glyph.update_minimum_size()
		_place_glyph()
		queue_redraw()

	func _place_glyph() -> void:
		var gs := _glyph.get_combined_minimum_size()
		_glyph.size = gs
		_glyph.position = Vector2(size.y * 0.35 + 18.0, (size.y - gs.y) * 0.5)

	func _draw() -> void:
		var h := size.y
		var s := h * 0.35
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(size.x, 0), Vector2(size.x - s, h), Vector2(0, h)])
		var top := Color(0.12, 0.06, 0.26, 0.92)
		var bottom := Color(0.06, 0.03, 0.14, 0.92)
		if primary:
			top = NeonMenuButton.GOLD_TOP if not disabled else Color(0.45, 0.4, 0.28)
			bottom = NeonMenuButton.GOLD_BOTTOM if not disabled else Color(0.36, 0.3, 0.2)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, p.y / h))
		draw_polygon(pts, cols)
		var outline := pts.duplicate()
		outline.append(pts[0])
		var edge := Color(1.0, 0.95, 0.7) if primary else Color(0.45, 0.6, 1.0)
		if has_focus():
			draw_polyline(outline, Color(1, 1, 1, 0.3), 10.0, true)
			edge = Color.WHITE
		draw_polyline(outline, Color(edge, 0.3), 6.0, true)
		draw_polyline(outline, edge, 2.5, true)
		var size_px := 30
		var ink := NeonMenuButton.DARK_TEXT if primary else Color.WHITE
		if disabled:
			ink = Color(ink, 0.55)
		var tx := _glyph.position.x + _glyph.size.x + 16.0
		var baseline := (h + _font.get_ascent(size_px) - _font.get_descent(size_px)) * 0.5
		draw_string(_font, Vector2(tx, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)
