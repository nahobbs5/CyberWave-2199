shader_type spatial;
// Crazy House walls: the inside of a hollow tree as Hang Nga built it.
// Procedural, with optional Poly Haven bark grain (detail_common.gdshaderinc,
// softer on the plaster): grey and dark-brown "melted" bark with knotty
// grooves, cream plaster drips running down it, and (lava_amount) the
// orange-red pitted walls. Glows softly near window light (glow_points), so
// it reads in the Compatibility renderer too. Model space = track-local.
render_mode cull_disabled;

uniform vec4 bark_dark : source_color = vec4(0.17, 0.12, 0.1, 1.0);
uniform vec4 bark_grey : source_color = vec4(0.46, 0.43, 0.4, 1.0);
uniform vec4 cream : source_color = vec4(0.93, 0.88, 0.76, 1.0);
uniform vec4 lava_color : source_color = vec4(0.72, 0.28, 0.13, 1.0);
uniform float lava_amount : hint_range(0.0, 1.0) = 0.0;
// How much of the wall the cream drips cover.
uniform float drip_amount : hint_range(0.0, 1.0) = 0.45;
uniform float scale = 0.12;
uniform float base_glow = 0.1;
uniform float source_glow = 1.2;
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.6, 1.0);
// xyz = track-local position, w = reach (m).
uniform vec4 glow_points[12];
uniform int glow_count = 0;

#include "res://assets/shaders/detail_common.gdshaderinc"

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 p = local_pos * scale;
	// Bark: blotchy grey and dark brown with knotty grooves.
	float blotch = fbm(p * 0.6 + vec3(3.0, 0.0, 7.0));
	vec3 col = mix(bark_dark.rgb, bark_grey.rgb, smoothstep(0.35, 0.7, blotch));
	float grain = fbm(vec3(p.x * 2.5, p.y * 0.5, p.z * 2.5) + blotch);
	float groove = smoothstep(0.08, 0.0, abs(fract(grain * 5.0) - 0.5) - 0.42);
	col *= 1.0 - groove * 0.45;
	// Cream drips: vertical streaks (noise stretched up and down) that run
	// down the walls from the plaster above.
	float streak = fbm(vec3(p.x * 1.6, p.y * 0.18, p.z * 1.6) + vec3(11.0));
	float drip = smoothstep(0.55 - drip_amount * 0.25, 0.6 - drip_amount * 0.25, streak + local_pos.y * 0.004);
	col = mix(col, cream.rgb * (0.85 + 0.15 * blotch), drip);
	// Lava walls: orange-red with dark pits.
	float pits = smoothstep(0.68, 0.74, vnoise(p * 26.0)) * 0.8;
	vec3 lava = mix(lava_color.rgb * (0.75 + 0.5 * blotch), vec3(0.18, 0.05, 0.02), pits);
	col = mix(col, lava, lava_amount * (1.0 - drip * 0.6));

	vec3 dn = normalize(local_normal);
	vec3 dw = detail_weights(dn);
	col *= mix(detail_shade(local_pos, dw), 1.0, drip * 0.6);
	if (detail_normal_strength > 0.0) {
		NORMAL = detail_view_normal(local_pos, dn, dw, MODEL_MATRIX, VIEW_MATRIX, FRONT_FACING);
	}

	float glow = base_glow;
	for (int i = 0; i < glow_count; i++) {
		float r = glow_points[i].w;
		float d = distance(local_pos, glow_points[i].xyz);
		glow += source_glow / (1.0 + (d * d) / (r * r));
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.75, 0.5, drip);
	EMISSION = col * glow_color.rgb * glow * 0.35 + lava * lava_amount * 0.12;
}
