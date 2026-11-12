shader_type spatial;
// Electrified puddle (TrackFeature EMP_PUDDLE): dark oily water with
// crackling arcs that jump rather than flow, ringed by a yellow/black
// hazard band. Meant to read as "don't drive here", unlike the cyan pads.
// mode 0 = the water disc (rim band drawn on its outer edge), mode 1 = the
// raised lip around it (stripes all over).
render_mode cull_disabled, blend_mix;

#include "res://assets/shaders/water_common.gdshaderinc"

uniform int mode = 0;
// Disc radius in local units (before the node's scale).
uniform float radius = 2.5;
uniform vec4 water_color : source_color = vec4(0.03, 0.025, 0.05, 1.0);
uniform vec4 arc_color : source_color = vec4(0.72, 0.45, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.95, 0.92, 1.0, 1.0);
uniform vec4 hazard_yellow : source_color = vec4(1.0, 0.78, 0.05, 1.0);
uniform vec4 hazard_black : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform float arc_energy = 5.0;
// 1 = jumpy flicker; 0 = reduced flashing (slow, steady arcs).
uniform float flicker : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
}

float stripes(vec2 local) {
	float ang = atan(local.y, local.x);
	// Diagonal stripes around the ring (angle + radius gives the slant).
	float s = fract(ang / TAU * 28.0 + length(local) * 0.6 + TIME * 0.15);
	return step(0.5, s);
}

float arc_layer(vec2 p, float step_t, float seed) {
	vec2 jitter = vec2(w_hash(vec2(step_t, seed)), w_hash(vec2(seed, step_t + 3.0))) * 40.0;
	float n = w_noise(p * 1.7 + jitter) * 0.65 + w_noise(p * 4.3 + jitter * 1.3) * 0.35;
	float ridge = 1.0 - abs(n - 0.5) * 2.0;
	return pow(ridge, 28.0);
}

void fragment() {
	vec2 lp = local_pos.xz;
	float r = length(lp) / max(radius, 0.01);

	if (mode == 1) {
		vec3 c = mix(hazard_black.rgb, hazard_yellow.rgb, stripes(lp));
		ALBEDO = c;
		ROUGHNESS = 0.5;
		EMISSION = hazard_yellow.rgb * stripes(lp) * 0.35;
	} else {
		vec2 xz = world_pos.xz;
		float t = TIME;
		vec2 slope = w_slope(xz, t, 1.8, 0.7, 0.0);
		// Oily sheen: a faint rainbow film drifting on the dark water.
		float film = w_fbm(xz * 0.5 + t * 0.05);
		vec3 sheen = 0.5 + 0.5 * cos(6.2831 * (film * 1.5 + vec3(0.0, 0.33, 0.67)));
		vec3 col = water_color.rgb + sheen * 0.05;

		// Arcs: re-seeded several times a second so they snap to new paths.
		float rate = mix(0.6, 9.0, flicker);
		float a1 = arc_layer(xz, floor(t * rate), 1.0);
		float a2 = arc_layer(xz * 1.3, floor(t * rate * 0.7 + 0.5), 2.0);
		// Random surges where the whole puddle flares.
		float surge_seed = w_hash(vec2(floor(t * 4.0), 5.0));
		float surge = mix(0.7, step(0.75, surge_seed) * 1.6 + 0.6, flicker);
		float arcs = clamp((a1 + a2 * 0.8) * surge, 0.0, 1.5);
		float glow = clamp((a1 + a2) * 0.5, 0.0, 1.0);
		// Arcs fade into the hazard band.
		float inner = 1.0 - smoothstep(0.78, 0.86, r);
		// Thin out with distance: far away the lines would alias into a solid fill.
		float footprint = length(fwidth(xz));
		float thin = clamp(0.03 / max(footprint, 0.0001), 0.2, 1.0);
		arcs *= inner * thin;
		glow *= thin;

		// Hazard band on the outer edge of the disc.
		float band = smoothstep(0.86, 0.88, r);
		vec3 stripe = mix(hazard_black.rgb, hazard_yellow.rgb, stripes(lp));

		vec3 arc_col = mix(arc_color.rgb, core_color.rgb, smoothstep(0.4, 1.0, arcs));
		ALBEDO = mix(col + arc_col * arcs * 0.3, stripe, band);
		ROUGHNESS = mix(0.04, 0.5, band);
		METALLIC = mix(0.3, 0.0, band);
		SPECULAR = 0.8;
		EMISSION = arc_col * (arcs * arc_energy + glow * inner * 0.4)
				+ hazard_yellow.rgb * stripes(lp) * band * 0.35;
		vec3 tilt = (VIEW_MATRIX * vec4(-slope.x, 0.0, -slope.y, 0.0)).xyz * 0.05 * (1.0 - band);
		NORMAL = normalize(NORMAL + tilt);
	}
}
