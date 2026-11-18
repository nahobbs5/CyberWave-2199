class_name UnderglowPulse
extends Node
## Animated underglow (signature item, GDD 2.5): the neon strips and the
## underglow light ease back and forth between the item's two colours.
## With Reduced Flashing on it holds a steady mix of the two.

const PERIOD := 1.6

var item: CosmeticItem
var material: StandardMaterial3D
var light: OmniLight3D
var _t: float = 0.0


func setup(p_item: CosmeticItem, p_material: StandardMaterial3D, p_light: OmniLight3D) -> void:
	item = p_item
	material = p_material
	light = p_light
	apply_mix(0.0)


## 0 = colour, 1 = colour2.
func mix_at(t: float) -> float:
	if GameSettings.reduced_flashing:
		return 0.5
	return 0.5 - 0.5 * cos(TAU * t / PERIOD)


func apply_mix(m: float) -> void:
	if item == null:
		return
	var c := item.color.lerp(item.color2, m)
	if material != null:
		material.albedo_color = c
		material.emission = c
	if is_instance_valid(light):
		light.light_color = c


## The colour now (tests).
func current_color() -> Color:
	return material.emission if material != null else item.color


func _process(delta: float) -> void:
	_t += delta
	apply_mix(mix_at(_t))
