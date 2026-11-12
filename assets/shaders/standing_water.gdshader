shader_type spatial;
// Still water: puddles, flooded road, pools and ponds. Drifting ripples,
// optional rain-drop rings, murky silt patches and glints on the crests.
// Patterns use world XZ so it works on any mesh (batched scenery boxes and
// cylinders included). No screen/depth textures: fine in Compatibility.
render_mode cull_disabled, blend_mix, depth_draw_opaque;

#include "res://assets/shaders/water_common.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.03, 0.12, 0.16, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.42, 0.52, 1.0);
uniform vec4 glint_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
// Ripples per metre (higher = finer) and how fast they drift.
uniform float ripple_scale = 1.6;
uniform float ripple_speed = 1.0;
// How much the ripples tilt the reflection.
uniform float ripple_strength = 0.35;
uniform float rain_rings : hint_range(0.0, 1.0) = 0.0;
uniform float murk : hint_range(0.0, 1.0) = 0.35;
uniform float glint : hint_range(0.0, 2.0) = 0.6;
uniform float emission_strength = 0.0;
// Feather the edges of a PlaneMesh (uses UV). 0 = off; else the feather
// width in metres, with plane_size the mesh's size in metres.
uniform float edge_fade = 0.0;
uniform vec2 plane_size = vec2(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = world_pos.xz;
	float t = TIME;
	float h = w_height(xz, t, ripple_scale, ripple_speed, rain_rings);
	vec2 slope = w_slope(xz, t, ripple_scale, ripple_speed, rain_rings);
	float silt = smoothstep(0.35, 0.8, w_fbm(xz * 0.35 + 4.0)) * murk;

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(h * 0.8 + 0.1, 0.0, 1.0));
	col = mix(col, col * vec3(0.55, 0.5, 0.42), silt);
	// Sparkles where ripple crests catch the light.
	float crest = smoothstep(0.78, 0.95, h) * (0.6 + 0.4 * w_noise(xz * 9.0 + t * 2.0));
	col += glint_color.rgb * crest * glint * 0.25;

	ALBEDO = col;
	ROUGHNESS = mix(0.03, 0.3, silt);
	METALLIC = 0.1;
	SPECULAR = 0.8;
	EMISSION = (shallow_color.rgb * (0.6 + 0.4 * sin(t * 1.7)) + glint_color.rgb * crest * glint) * emission_strength;

	vec3 tilt = (VIEW_MATRIX * vec4(-slope.x, 0.0, -slope.y, 0.0)).xyz * ripple_strength * 0.15;
	NORMAL = normalize(NORMAL + tilt);

	// More opaque at grazing angles (fresnel-ish), less in the glare-free middle.
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float a = mix(1.0, opacity, facing) + silt * 0.2;
	if (edge_fade > 0.0) {
		vec2 e = min(UV, 1.0 - UV) * plane_size;
		float edge = min(e.x, e.y);
		// Wobbly shoreline so it isn't a clean rectangle.
		float wob = (w_noise(xz * 0.8) - 0.5) * edge_fade * 1.2;
		a *= smoothstep(0.0, edge_fade, edge + wob);
	}
	ALPHA = clamp(a, 0.0, 1.0);
}
