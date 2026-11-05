class_name CosmeticItem
extends Resource
## One cosmetic in the shop (GDD 9.4). Purely visual; no performance effect.

enum Category { PAINT, FINISH, STRIPES, DECAL, WHEELS, PLATE_FRAME, UNDERGLOW, EXHAUST }

const CATEGORY_NAMES: Array[String] = ["Paint", "Finish", "Stripes", "Decals", "Wheels",
		"Plate frame", "Underglow", "Exhaust"]

@export var id: String = ""
@export var category: Category = Category.PAINT
@export var display_name: String = ""
## 0 = free starter item, owned from the start.
@export var price: int = 0
@export var color: Color = Color.WHITE
## Category-specific variant: finish (gloss / matte / metallic / chrome),
## stripe layout, decal text, wheel style.
@export var style: String = ""


func is_free() -> bool:
	return price <= 0
