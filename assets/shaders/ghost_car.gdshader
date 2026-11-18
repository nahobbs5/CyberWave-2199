shader_type spatial;
// Time Trial ghost car (GDD 2.4): a see-through hologram of the car in one
// tint, brighter at the silhouette, with slow scan lines. Additive and
// unshaded, so it reads at night and never hides the road behind it.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.2, 0.9, 1.0, 1.0);
// 0..1: faded near the camera and when the run is over.
uniform float fade = 1.0;
uniform float body_alpha = 0.16;
uniform float rim_alpha = 0.75;
uniform float scan_speed = 1.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	float scan = 0.75 + 0.25 * sin(world_pos.y * 22.0 - TIME * scan_speed * 6.0);
	float a = (body_alpha + rim * rim_alpha) * scan * fade;
	ALBEDO = tint.rgb * a;
}
