shader_type spatial;
// Glacier ice for the Vatnajokull cave walls. Procedural, with an optional
// Poly Haven normal map for surface roughness (detail_common.gdshaderinc):
// swirling flow bands from deep blue through cyan to white, dark volcanic
// ash streaks, a glassy surface and a glow that is strongest near daylight
// (the cave mouth, skylights, the crystal tube's far end). Works in model
// space, which for track scenery is track-local metres.
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.4, 1.0);
uniform vec4 mid_color : source_color = vec4(0.12, 0.55, 0.88, 1.0);
uniform vec4 pale_color : source_color = vec4(0.78, 0.94, 1.0, 1.0);
uniform vec4 ash_color : source_color = vec4(0.04, 0.05, 0.07, 1.0);
// Metres -> noise units (bigger = finer swirls).
uniform float scale = 0.06;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.45;
// Glow everywhere, and extra glow per light source.
uniform float base_glow = 0.35;
uniform float source_glow = 2.2;
// xyz = track-local position, w = reach (m). glow_count are used.
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
	// Domain warp for the swirling, flowing look of glacier ice.
	vec3 w = vec3(fbm(p + vec3(0.0, 3.1, 7.7)), fbm(p + vec3(5.2, 1.3, 2.8)), fbm(p + vec3(8.3, 2.8, 4.1)));
	vec3 q = p + w * 2.2;
	float f = fbm(q);
	float bands = 0.5 + 0.5 * sin(q.y * 9.0 + q.x * 2.0 + f * 10.0);
	float streak = smoothstep(0.6, 0.7, fbm(q * vec3(1.0, 4.0, 1.0) + 11.0)) * ash_amount;

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.25, 0.75, f));
	col = mix(col, pale_color.rgb, smoothstep(0.55, 1.0, bands * f * 1.6));
	// Fine detail: crisp white crests and dark veins in the flow.
	float fine = fbm(q * 3.5 + vec3(f * 2.0));
	col = mix(col, pale_color.rgb, smoothstep(0.6, 0.78, fine) * 0.55);
	col = mix(col, deep_color.rgb * 0.45, smoothstep(0.38, 0.22, fine) * 0.6);
	col = mix(col, ash_color.rgb, streak);

	vec3 dn = normalize(local_normal);
	vec3 dw = detail_weights(dn);
	col *= detail_shade(local_pos, dw);
	if (detail_normal_strength > 0.0) {
		NORMAL = detail_view_normal(local_pos, dn, dw, MODEL_MATRIX, VIEW_MATRIX, FRONT_FACING);
	}

	float glow = base_glow;
	for (int i = 0; i < glow_count; i++) {
		float r = glow_points[i].w;
		float d = distance(local_pos, glow_points[i].xyz);
		glow += source_glow / (1.0 + (d * d) / (r * r));
	}
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);

	ALBEDO = col * 0.55;
	ROUGHNESS = mix(0.06, 0.3, f);
	SPECULAR = 0.8;
	EMISSION = (col * glow + pale_color.rgb * fres * 0.25 * glow) * (1.0 - streak * 0.85);
}
