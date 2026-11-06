class_name Garage
extends Control
## Garage (GDD 11.4, 14.2 GarageManager / CosmeticShop), laid out after
## "reference files/Neon Cyberwave Garage Interface.png": the rotating car
## on its platform with arrows and dots, stats and the license plate on the
## left; the cosmetics panel (category list + items) on the right; Back and
## Apply at the bottom. Clicking an item's name tries it on in the preview;
## Buy spends coins (permanently, GDD 9.4) and equips; Equip puts an owned
## item on this vehicle; Apply equips every owned item being tried on.

var vehicle_index: int = 0
var category: CosmeticItem.Category = CosmeticItem.Category.PAINT

var showcase: CarShowcase
var _coins: Label
## The showcase's 3D preview (kept as a field for the tests).
var _preview: VehiclePreview
var _plate: LineEdit
var _items: VBoxContainer
var _items_title: Label
var _message: Label
var _apply: Button
var _tabs: Array[Button] = []
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
	_coins.text = str(PlayerProfile.get_profile().coins)
	showcase.set_vehicle(vehicle_index, _loadout(), PlayerProfile.get_profile().plate_text)
	_refresh_apply()
	_refresh_items()


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
	_apply.text = "APPLY" if count <= 1 else "APPLY (%d)" % count


func _refresh_items() -> void:
	for i in _tabs.size():
		UIStyle.style_list_tab(_tabs[i], i == category)
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
		var highlight := item == trying
		var row_style := UIStyle.box_style(Color(1, 1, 1, 0.035) if not highlight else Color(UIStyle.MAGENTA, 0.12),
				Color(1, 1, 1, 0.08) if not highlight else UIStyle.MAGENTA, 6, 1)
		row.add_theme_stylebox_override("panel", row_style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		row.add_child(line)
		var swatch_frame := PanelContainer.new()
		swatch_frame.add_theme_stylebox_override("panel", UIStyle.box_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.3), 1, 1))
		swatch_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch_frame)
		var swatch := ColorRect.new()
		swatch.color = vehicle().factory_color if item.style == "factory" else item.color
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_frame.add_child(swatch)
		var name_button := Button.new()
		name_button.text = item.display_name
		name_button.flat = true
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.custom_minimum_size = Vector2(120, 34)
		name_button.add_theme_font_size_override("font_size", 18)
		name_button.add_theme_color_override("font_color", Color.WHITE)
		name_button.add_theme_color_override("font_hover_color", UIStyle.MAGENTA.lightened(0.3))
		name_button.add_theme_color_override("font_focus_color", UIStyle.MAGENTA.lightened(0.3))
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
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(action)
		var status := UIStyle.label("Owned" if profile.owns(item.id) else "", 14, UIStyle.MUTED)
		status.custom_minimum_size = Vector2(52, 0)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(status)
		_items.add_child(row)
		if first == null:
			first = name_button
		name_button.focus_neighbor_left = name_button.get_path_to(_tabs[category])
	if first != null:
		for tab in _tabs:
			tab.focus_neighbor_right = tab.get_path_to(first)


# --- layout ------------------------------------------------------------------

func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	_coins = UIStyle.top_bar(page, "GARAGE")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# Left: the car and the license plate.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.05
	body.add_child(left)
	showcase = CarShowcase.new(260.0)
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase.vehicle_changed.connect(select_vehicle)
	left.add_child(showcase)
	_preview = showcase.preview
	left.add_child(_plate_strip())

	# Right: the cosmetics panel, then Back / Apply.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var tab_row := HBoxContainer.new()
	right.add_child(tab_row)
	var tab := PanelContainer.new()
	var tab_style := UIStyle.box_style(Color(UIStyle.MAGENTA.darkened(0.55), 0.95), UIStyle.MAGENTA, 0, 2)
	tab_style.content_margin_left = 22
	tab_style.content_margin_right = 26
	tab_style.content_margin_top = 6
	tab_style.content_margin_bottom = 6
	tab_style.corner_radius_bottom_left = 0
	tab_style.corner_radius_bottom_right = 0
	tab_style.shadow_color = Color(UIStyle.MAGENTA, 0.3)
	tab_style.shadow_size = 6
	tab.add_theme_stylebox_override("panel", tab_style)
	tab_row.add_child(tab)
	tab.add_child(UIStyle.heading("COSMETICS", 20))

	var panel := UIStyle.section_panel(12)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(panel)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	panel.add_child(split)
	var categories := VBoxContainer.new()
	categories.add_theme_constant_override("separation", 6)
	split.add_child(categories)
	for c in CosmeticItem.Category.values():
		var b := Button.new()
		b.text = CosmeticItem.CATEGORY_NAMES[c]
		b.custom_minimum_size = Vector2(168, 38)
		b.add_theme_font_size_override("font_size", 18)
		var font := UIStyle.bold_font()
		if font != null:
			b.add_theme_font_override("font", font)
		b.pressed.connect(select_category.bind(c))
		b.focus_entered.connect(select_category.bind(c))
		categories.add_child(b)
		_tabs.append(b)
	UIStyle.chain_focus(_tabs)
	var divider := VSeparator.new()
	divider.add_theme_stylebox_override("separator", UIStyle.box_style(Color(0.6, 0.3, 0.9, 0.35), Color(0, 0, 0, 0), 0, 0))
	divider.add_theme_constant_override("separation", 1)
	split.add_child(divider)
	var items_col := VBoxContainer.new()
	items_col.add_theme_constant_override("separation", 8)
	items_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(items_col)
	_items_title = UIStyle.heading("", 22, UIStyle.CYAN)
	items_col.add_child(_items_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_col.add_child(scroll)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 5)
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	items_col.add_child(hint_row)
	var info := TextureRect.new()
	info.texture = UIStyle.icon_texture("info", 18, UIStyle.GOLD)
	info.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_row.add_child(info)
	hint_row.add_child(UIStyle.label("Click a name to preview it on the car.", 15, UIStyle.GOLD))
	_message = UIStyle.label("", 15, UIStyle.CYAN)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_col.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(Control.new()) # gap
	right.get_child(right.get_child_count() - 1).custom_minimum_size = Vector2(0, 12)
	right.add_child(buttons)
	var back := UIStyle.secondary_button("<  BACK", func() -> void: GameSession.to_main_menu(get_tree()))
	back.custom_minimum_size = Vector2(200, 50)
	back.add_theme_font_size_override("font_size", 22)
	buttons.add_child(back)
	_apply = UIStyle.primary_button("APPLY", apply)
	_apply.icon = UIStyle.icon_texture("check", 22, Color.WHITE)
	_apply.custom_minimum_size = Vector2(240, 50)
	_apply.add_theme_font_size_override("font_size", 22)
	_apply.tooltip_text = "Equip the owned items you're previewing"
	buttons.add_child(_apply)


func _plate_strip() -> Control:
	var strip := UIStyle.hud_panel(Color(0.6, 0.4, 0.9, 0.4), 10)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	strip.add_child(row)
	var title := UIStyle.stat("LICENSE PLATE", 19)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	_plate = LineEdit.new()
	_plate.max_length = PlayerProfile.PLATE_MAX
	_plate.text = PlayerProfile.get_profile().plate_text
	_plate.custom_minimum_size = Vector2(200, 40)
	_plate.add_theme_font_size_override("font_size", 22)
	var font := UIStyle.heading_font()
	if font != null:
		_plate.add_theme_font_override("font", font)
	for state in ["normal", "focus"]:
		var style := UIStyle.box_style(Color(0.02, 0.01, 0.05, 0.95),
				UIStyle.MAGENTA if state == "focus" else Color(1, 1, 1, 0.75), 8, 2)
		style.content_margin_left = 12
		_plate.add_theme_stylebox_override(state, style)
	_plate.right_icon = _pencil_texture()
	_plate.text_changed.connect(set_plate)
	row.add_child(_plate)
	var note := UIStyle.label("Shared by every car\n(%d character max)" % PlayerProfile.PLATE_MAX, 14, UIStyle.MUTED)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	return strip


## A small pencil for the plate field, drawn into an image.
static func _pencil_texture() -> Texture2D:
	var n := 20
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			# Distance from the diagonal running bottom-left to top-right.
			var along := (x + (n - 1 - y)) * 0.5
			var across := absf(x - (n - 1 - y)) * 0.7
			var col := Color(0, 0, 0, 0)
			if along > 2.0 and along < 17.5 and across < 2.4:
				col = Color.WHITE
				if along < 5.0:
					col = Color(1, 1, 1, 0.65) if across < 1.3 + (along - 2.0) * 0.4 else Color(0, 0, 0, 0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
