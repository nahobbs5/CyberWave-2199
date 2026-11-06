class_name Garage
extends Control
## Garage (GDD 11.4, 14.2 GarageManager / CosmeticShop): rotating vehicle
## preview, vehicle stats, license plate editor, paint and the other
## cosmetics, the player's cosmetic inventory, the shop and the coin
## balance. Clicking an item's name tries it on in the preview; Buy spends
## coins (permanently, GDD 9.4); Equip puts an owned item on this vehicle.

var vehicle_index: int = 0
var category: CosmeticItem.Category = CosmeticItem.Category.PAINT

var _coins: Label
var _preview: VehiclePreview
var _vehicle_info: VBoxContainer
var _plate: LineEdit
var _items: VBoxContainer
var _message: Label
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
	_refresh_all()


func select_category(c: CosmeticItem.Category) -> void:
	category = c
	_refresh_items()


func try_on(item: CosmeticItem) -> void:
	_trying[item.category] = item
	_refresh_preview()


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
	_coins.text = "%d coins" % PlayerProfile.get_profile().coins
	UIStyle.fill_vehicle_info(_vehicle_info, vehicle())
	_refresh_preview()
	_refresh_items()


func _refresh_preview() -> void:
	var profile := PlayerProfile.get_profile()
	var loadout := profile.loadout_for(vehicle().id)
	for c in _trying:
		loadout[c] = _trying[c]
	_preview.show_vehicle(vehicle(), loadout, profile.plate_text)


func _refresh_items() -> void:
	for i in _tabs.size():
		_tabs[i].add_theme_color_override("font_color", UIStyle.MAGENTA if i == category else Color.WHITE)
	for child in _items.get_children():
		child.queue_free()
	var profile := PlayerProfile.get_profile()
	var equipped := profile.equipped_item(vehicle().id, category)
	for item in CosmeticCatalog.in_category(category):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = vehicle().factory_color if item.style == "factory" else item.color
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_button := UIStyle.button(item.display_name, try_on.bind(item))
		name_button.custom_minimum_size = Vector2(230, 34)
		name_button.add_theme_font_size_override("font_size", 15)
		name_button.tooltip_text = "Try it on"
		row.add_child(name_button)
		var action: Button
		if item == equipped:
			action = UIStyle.button("Equipped", func() -> void: pass)
			action.disabled = true
		elif profile.owns(item.id):
			action = UIStyle.button("Equip", equip.bind(item))
		else:
			action = UIStyle.button("Buy  %d" % item.price, buy.bind(item))
			action.disabled = profile.coins < item.price
		action.custom_minimum_size = Vector2(120, 34)
		action.add_theme_font_size_override("font_size", 15)
		row.add_child(action)
		var status := "owned" if profile.owns(item.id) else ""
		row.add_child(UIStyle.label(status, 13, Color(1, 1, 1, 0.45)))
		_items.add_child(row)


# --- layout ------------------------------------------------------------------

func _build() -> void:
	UIStyle.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	_coins = UIStyle.header(page, "GARAGE")

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 10)
	left.add_child(picker)
	var prev := UIStyle.button("<  Previous", func() -> void: select_vehicle(vehicle_index - 1))
	var next := UIStyle.button("Next  >", func() -> void: select_vehicle(vehicle_index + 1))
	prev.custom_minimum_size = Vector2(200, 40)
	next.custom_minimum_size = Vector2(200, 40)
	picker.add_child(prev)
	picker.add_child(next)
	_preview = VehiclePreview.new()
	_preview.custom_minimum_size = Vector2(460, 260)
	left.add_child(_preview)
	_vehicle_info = VBoxContainer.new()
	left.add_child(_vehicle_info)
	var plate_row := HBoxContainer.new()
	plate_row.add_theme_constant_override("separation", 10)
	left.add_child(plate_row)
	plate_row.add_child(UIStyle.label("License plate", 17))
	_plate = LineEdit.new()
	_plate.max_length = PlayerProfile.PLATE_MAX
	_plate.text = PlayerProfile.get_profile().plate_text
	_plate.custom_minimum_size = Vector2(180, 36)
	_plate.add_theme_font_size_override("font_size", 18)
	_plate.text_changed.connect(set_plate)
	plate_row.add_child(_plate)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UIStyle.label("COSMETICS", 18, UIStyle.CYAN))
	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	right.add_child(tabs)
	for c in CosmeticItem.Category.values():
		var tab := UIStyle.button(CosmeticItem.CATEGORY_NAMES[c], select_category.bind(c))
		tab.custom_minimum_size = Vector2(128, 32)
		tab.add_theme_font_size_override("font_size", 15)
		tabs.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 6)
	scroll.add_child(_items)
	_message = UIStyle.label("", 15, Color(1.0, 0.82, 0.3))
	right.add_child(_message)
	right.add_child(UIStyle.button("Back", func() -> void: GameSession.to_main_menu(get_tree())))
