class_name SpeedBlur
extends CanvasLayer
## Optional motion blur (GDD 11.9 toggle, off by default). Godot has no
## built-in motion blur, so this is a screen-space radial blur that grows
## with speed and boosts. The centre of the screen stays sharp so the road
## ahead is always readable.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float edge = smoothstep(0.12, 0.5, length(dir));
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		sum += texture(screen_tex, uv - dir * strength * edge * float(i) / 8.0);
	}
	COLOR = sum / 8.0;
}
"""

var vehicle: VehicleController
var strength: float = 0.0

var _rect: ColorRect
var _material: ShaderMaterial


func _init() -> void:
	layer = 0


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)


func _process(delta: float) -> void:
	var target := 0.0
	if vehicle != null and is_instance_valid(vehicle) and vehicle.stats != null:
		var ratio := clampf(absf(vehicle.forward_speed) / vehicle.stats.top_speed, 0.0, 1.4)
		target = clampf((ratio - 0.6) * 0.05, 0.0, 0.03)
		if vehicle.is_boosting():
			target += 0.02
	strength = lerpf(strength, target, 1.0 - exp(-6.0 * delta))
	_material.set_shader_parameter("strength", strength)
	_rect.visible = strength > 0.001
