class_name CosmeticCatalog
extends RefCounted
## Every cosmetic in the shop, by category (GDD 9.4). Prices follow the GDD
## targets: basic paint 100, plate frame 250, wheel design 500, premium
## finish 1,000; the GDD leaves the other categories unpriced, so they sit in
## between. One free starter item per category is owned from the start.
## Add items here; ids must stay stable because saves refer to them.


## [id, category, name, price, color, style]
const DATA := [
	["paint_factory", CosmeticItem.Category.PAINT, "Factory", 0, Color(0, 0, 0, 0), "factory"],
	["paint_crimson", CosmeticItem.Category.PAINT, "Crimson", 100, Color(0.75, 0.05, 0.12), ""],
	["paint_ultraviolet", CosmeticItem.Category.PAINT, "Ultraviolet", 100, Color(0.42, 0.1, 0.85), ""],
	["paint_acid", CosmeticItem.Category.PAINT, "Acid Green", 100, Color(0.45, 0.9, 0.1), ""],
	["paint_arctic", CosmeticItem.Category.PAINT, "Arctic White", 100, Color(0.9, 0.92, 0.95), ""],
	["paint_sunset", CosmeticItem.Category.PAINT, "Sunset Orange", 100, Color(1.0, 0.42, 0.08), ""],
	["paint_midnight", CosmeticItem.Category.PAINT, "Midnight Black", 100, Color(0.03, 0.03, 0.05), ""],
	["finish_gloss", CosmeticItem.Category.FINISH, "Gloss", 0, Color.WHITE, "gloss"],
	["finish_matte", CosmeticItem.Category.FINISH, "Matte", 500, Color.WHITE, "matte"],
	["finish_metallic", CosmeticItem.Category.FINISH, "Metallic Flake", 750, Color.WHITE, "metallic"],
	["finish_chrome", CosmeticItem.Category.FINISH, "Chrome", 1000, Color.WHITE, "chrome"],
	["stripes_none", CosmeticItem.Category.STRIPES, "None", 0, Color.WHITE, "none"],
	["stripes_twin_white", CosmeticItem.Category.STRIPES, "Twin Racing (White)", 300, Color(0.95, 0.95, 0.95), "twin"],
	["stripes_center_cyan", CosmeticItem.Category.STRIPES, "Centre Line (Cyan)", 300, Color(0.0, 0.95, 1.0), "center"],
	["stripes_side_magenta", CosmeticItem.Category.STRIPES, "Side Flash (Magenta)", 300, Color(1.0, 0.2, 0.85), "side"],
	["decal_none", CosmeticItem.Category.DECAL, "None", 0, Color.WHITE, ""],
	["decal_2199", CosmeticItem.Category.DECAL, "2199", 200, Color(0.0, 0.95, 1.0), "2199"],
	["decal_wave", CosmeticItem.Category.DECAL, "Cyberwave", 300, Color(1.0, 0.2, 0.85), "CYBERWAVE"],
	["decal_88", CosmeticItem.Category.DECAL, "Number 88", 200, Color(1.0, 0.85, 0.2), "88"],
	["wheels_standard", CosmeticItem.Category.WHEELS, "Standard", 0, Color(0.25, 0.25, 0.28), "standard"],
	["wheels_chrome", CosmeticItem.Category.WHEELS, "Chrome Mesh", 500, Color(0.85, 0.87, 0.9), "chrome"],
	["wheels_gold", CosmeticItem.Category.WHEELS, "Gold Spoke", 500, Color(0.95, 0.72, 0.2), "chrome"],
	["wheels_neon", CosmeticItem.Category.WHEELS, "Neon Rim", 500, Color(0.0, 0.95, 1.0), "neon"],
	["frame_basic", CosmeticItem.Category.PLATE_FRAME, "Basic", 0, Color(0.05, 0.05, 0.06), "basic"],
	["frame_chrome", CosmeticItem.Category.PLATE_FRAME, "Chrome", 250, Color(0.85, 0.87, 0.9), "chrome"],
	["frame_gold", CosmeticItem.Category.PLATE_FRAME, "Gold", 250, Color(0.95, 0.72, 0.2), "chrome"],
	["frame_neon", CosmeticItem.Category.PLATE_FRAME, "Neon Magenta", 250, Color(1.0, 0.2, 0.85), "neon"],
	["glow_none", CosmeticItem.Category.UNDERGLOW, "None", 0, Color(0.0, 0.95, 1.0), "none"],
	["glow_cyan", CosmeticItem.Category.UNDERGLOW, "Cyan", 400, Color(0.0, 0.95, 1.0), ""],
	["glow_magenta", CosmeticItem.Category.UNDERGLOW, "Magenta", 400, Color(1.0, 0.2, 0.85), ""],
	["glow_lime", CosmeticItem.Category.UNDERGLOW, "Lime", 400, Color(0.5, 1.0, 0.15), ""],
	["exhaust_standard", CosmeticItem.Category.EXHAUST, "Standard", 0, Color(0.35, 0.35, 0.38), "metal"],
	["exhaust_plasma", CosmeticItem.Category.EXHAUST, "Plasma Blue", 350, Color(0.25, 0.55, 1.0), ""],
	["exhaust_toxic", CosmeticItem.Category.EXHAUST, "Toxic Green", 350, Color(0.4, 1.0, 0.2), ""],
	["exhaust_violet", CosmeticItem.Category.EXHAUST, "Violet", 350, Color(0.7, 0.25, 1.0), ""],
]

## Signature items (GDD 2.5), never sold: won by beating a Time Trial expert
## ghost (TimeTrialCatalog), worn only by their own car. Paint style = the
## finish it always has; animated underglow pulses between colour and colour2.
## [id, category, name, vehicle id, color, style, color2]
const SIGNATURE := [
	["sig_paint_empyrean_s", CosmeticItem.Category.PAINT, "High Roller Gold", "empyrean_s",
			Color(0.86, 0.64, 0.16), "metallic", Color.WHITE],
	["sig_paint_nexus_x", CosmeticItem.Category.PAINT, "Nexus Volt", "nexus_x",
			Color(0.02, 0.62, 0.86), "metallic", Color.WHITE],
	["sig_paint_orbiter", CosmeticItem.Category.PAINT, "Orbiter Nebula", "orbiter",
			Color(0.32, 0.08, 0.6), "metallic", Color.WHITE],
	["sig_paint_valkyrie_r", CosmeticItem.Category.PAINT, "Valkyrie Crimson Steel", "valkyrie_r",
			Color(0.62, 0.03, 0.08), "chrome", Color.WHITE],
	["sig_paint_cipher_evo", CosmeticItem.Category.PAINT, "Cipher Blackout", "cipher_evo",
			Color(0.05, 0.09, 0.07), "matte", Color.WHITE],
	["sig_glow_empyrean_s", CosmeticItem.Category.UNDERGLOW, "Jackpot Pulse", "empyrean_s",
			Color(1.0, 0.75, 0.15), "animated", Color(1.0, 0.15, 0.6)],
	["sig_glow_nexus_x", CosmeticItem.Category.UNDERGLOW, "Circuit Surge", "nexus_x",
			Color(0.0, 0.9, 1.0), "animated", Color(0.45, 1.0, 0.15)],
	["sig_glow_orbiter", CosmeticItem.Category.UNDERGLOW, "Orbit Wave", "orbiter",
			Color(0.6, 0.2, 1.0), "animated", Color(0.0, 0.85, 1.0)],
	["sig_glow_valkyrie_r", CosmeticItem.Category.UNDERGLOW, "Valkyrie Flare", "valkyrie_r",
			Color(1.0, 0.1, 0.15), "animated", Color(1.0, 0.55, 0.05)],
	["sig_glow_cipher_evo", CosmeticItem.Category.UNDERGLOW, "Cipher Code", "cipher_evo",
			Color(0.3, 1.0, 0.3), "animated", Color(0.9, 1.0, 0.95)],
	["sig_paint_switchback", CosmeticItem.Category.PAINT, "Rally Stage Red", "switchback",
			Color(0.78, 0.1, 0.08), "metallic", Color.WHITE],
	["sig_paint_afterimage", CosmeticItem.Category.PAINT, "Afterimage Phantom", "afterimage",
			Color(0.12, 0.08, 0.24), "chrome", Color.WHITE],
	["sig_paint_high_roller", CosmeticItem.Category.PAINT, "Champagne Stakes", "high_roller",
			Color(0.9, 0.8, 0.6), "metallic", Color.WHITE],
	["sig_paint_revenant", CosmeticItem.Category.PAINT, "Revenant Ash", "revenant",
			Color(0.3, 0.3, 0.32), "matte", Color.WHITE],
	["sig_paint_interceptor", CosmeticItem.Category.PAINT, "Interceptor Cobalt", "interceptor",
			Color(0.08, 0.2, 0.7), "metallic", Color.WHITE],
]

## Signature underglows sold in the shop (GDD 9.4): worn only by their own
## car, and only buyable once that car is unlocked. (The five cars added
## last have one rival track each, so their expert ghost gives the paint
## and the glow is bought.)
## [id, category, name, vehicle id, price, color, style, color2]
const SHOP_SIGNATURE := [
	["sig_glow_switchback", CosmeticItem.Category.UNDERGLOW, "Rally Lights", "switchback", 600,
			Color(1.0, 0.85, 0.5), "animated", Color(0.0, 0.9, 0.8)],
	["sig_glow_afterimage", CosmeticItem.Category.UNDERGLOW, "Ghost Trail", "afterimage", 600,
			Color(0.7, 0.3, 1.0), "animated", Color(1.0, 0.2, 0.7)],
	["sig_glow_high_roller", CosmeticItem.Category.UNDERGLOW, "Full House", "high_roller", 600,
			Color(1.0, 0.8, 0.3), "animated", Color(0.9, 0.05, 0.2)],
	["sig_glow_revenant", CosmeticItem.Category.UNDERGLOW, "Afterburn", "revenant", 600,
			Color(1.0, 0.45, 0.05), "animated", Color(1.0, 0.1, 0.05)],
	["sig_glow_interceptor", CosmeticItem.Category.UNDERGLOW, "Pursuit Strobe", "interceptor", 600,
			Color(0.15, 0.4, 1.0), "animated", Color(0.85, 0.9, 1.0)],
]

static var _items: Array[CosmeticItem] = []
static var _by_id: Dictionary = {}


static func items() -> Array[CosmeticItem]:
	if _items.is_empty():
		for row in DATA:
			var item := CosmeticItem.new()
			item.id = row[0]
			item.category = row[1]
			item.display_name = row[2]
			item.price = row[3]
			item.color = row[4]
			item.style = row[5]
			_items.append(item)
			_by_id[item.id] = item
		for row in SIGNATURE:
			var item := CosmeticItem.new()
			item.id = row[0]
			item.category = row[1]
			item.display_name = row[2]
			item.vehicle_id = row[3]
			item.color = row[4]
			item.style = row[5]
			item.color2 = row[6]
			item.unlock_only = true
			_items.append(item)
			_by_id[item.id] = item
		for row in SHOP_SIGNATURE:
			var item := CosmeticItem.new()
			item.id = row[0]
			item.category = row[1]
			item.display_name = row[2]
			item.vehicle_id = row[3]
			item.price = row[4]
			item.color = row[5]
			item.style = row[6]
			item.color2 = row[7]
			_items.append(item)
			_by_id[item.id] = item
	return _items


static func by_id(id: String) -> CosmeticItem:
	items()
	return _by_id.get(id)


static func in_category(category: CosmeticItem.Category) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for item in items():
		if item.category == category:
			out.append(item)
	return out


## The free starter item of a category.
static func default_for(category: CosmeticItem.Category) -> CosmeticItem:
	for item in in_category(category):
		if item.is_free():
			return item
	return null


static func free_ids() -> Array[String]:
	var out: Array[String] = []
	for item in items():
		if item.is_free():
			out.append(item.id)
	return out
