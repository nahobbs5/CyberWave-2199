shader_type spatial;
// Vale da Lua rock: smooth, river-sculpted stone, pale to dark grey, with
// rippled erosion lines, round dimples and potholes, and a darker, glossier
// wet band with a faint green-brown stain toward the water. Procedural, in
// model space (track-local metres for scenery), with optional Poly Haven
// rock grain on top (detail_common.gdshaderinc).

uniform vec4 pale : source_color = vec4(0.58, 0.57, 0.55, 1.0);
uniform vec4 dark : source_color = vec4(0.24, 0.24, 0.25, 1.0);
uniform vec4 stain : source_color = vec4(0.36, 0.33, 0.24, 1.0);
uniform float scale = 0.18;
// Below this height the rock starts to look wet; fully wet at wet_bottom.
uniform float wet_top = -2.0;
uniform float wet_bottom = -6.0;

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
		p = p * 2.1 + vec3(5.2, 1.3, 7.7);
		a *= 0.5;
	}
	return v;
}

// Distance to the nearest scattered pothole centre (cell noise).
float potholes(vec3 p) {
	vec3 c = floor(p);
	float best = 9.0;
	for (int x = -1; x <= 1; x++) {
		for (int z = -1; z <= 1; z++) {
			vec3 cell = c + vec3(float(x), 0.0, float(z));
			vec3 o = vec3(hash(cell), 0.0, hash(cell + 3.7));
			float keep = step(0.55, hash(cell + 9.1));
			float d = length((p - cell - o) * vec3(1.0, 0.0, 1.0)) / mix(0.35, 0.6, hash(cell + 1.3));
			best = min(best, mix(9.0, d, keep));
		}
	}
	return best;
}

void fragment() {
	vec3 p = local_pos * scale;
	float blotch = fbm(p * 0.5);
	vec3 col = mix(dark.rgb, pale.rgb, smoothstep(0.3, 0.72, blotch));
	// Rippled erosion lines that wrap round the rock.
	float warp = fbm(p * 0.8 + 4.0) * 3.0;
	float ripple = sin((p.y * 6.0 + p.x * 0.8 + warp) * 3.14159);
	col *= 0.72 + 0.28 * smoothstep(-0.3, 0.9, ripple);
	// Pothole rims and dark hollows on the flatter tops.
	float flat_top = smoothstep(0.55, 0.85, local_normal.y);
	float ph = potholes(local_pos * 0.35);
	float hollow = (1.0 - smoothstep(0.55, 1.0, ph)) * flat_top;
	float rim = smoothstep(0.75, 1.0, ph) * (1.0 - smoothstep(1.0, 1.2, ph)) * flat_top;
	col = mix(col, dark.rgb * 0.55, hollow * 0.8);
	col += vec3(0.06) * rim;
	// Wet and stained toward the water.
	float wet = smoothstep(wet_top, wet_bottom, local_pos.y);
	col = mix(col, mix(col * 0.55, stain.rgb * 0.7, 0.35), wet);
	vec3 dn = normalize(local_normal);
	vec3 dw = detail_weights(dn);
	col *= detail_shade(local_pos, dw);
	if (detail_normal_strength > 0.0) {
		NORMAL = detail_view_normal(local_pos, dn, dw, MODEL_MATRIX, VIEW_MATRIX, FRONT_FACING);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.7, 0.18, max(wet, hollow * 0.6));
	SPECULAR = 0.5;
}
