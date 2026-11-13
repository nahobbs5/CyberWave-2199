shader_type spatial;
// Nyiragongo crater ground (GDD 8.6h). Procedural, no textures: dark basalt
// with a rough mottle, lighter ashy dust on the flats, banded cliff faces,
// and molten fissures (cellular cracks) that glow orange. The fissures are
// everywhere but get denser and hotter toward the lava lake, and the whole
// crater takes a warm under-glow from the lake. All of it is emission, so it
// reads the same in Compatibility (no light limits). Works in model space,
// which for track scenery is track-local metres.
render_mode cull_disabled;

uniform vec4 rock_dark : source_color = vec4(0.035, 0.032, 0.034, 1.0);
uniform vec4 rock_light : source_color = vec4(0.13, 0.115, 0.11, 1.0);
uniform vec4 ash_color : source_color = vec4(0.24, 0.22, 0.21, 1.0);
uniform vec4 molten_color : source_color = vec4(1.0, 0.32, 0.04, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.78, 0.25, 1.0);
// Lava lake: xz centre (track-local) and radius (m).
uniform vec3 lake_centre = vec3(0.0, -68.0, -20.0);
uniform float lake_radius = 165.0;
// How far from the lake edge the fissures fade to their background level (m).
uniform float molten_reach = 260.0;
// Fissure density far from the lake (0-1) and its glow strength.
uniform float background_molten = 0.25;
uniform float glow = 3.2;
// Warm light thrown up by the lake onto nearby rock.
uniform float lake_glow = 0.35;
uniform float lake_glow_reach = 220.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash1(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash1(p), hash1(p + 17.31));
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x),
			mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

// Distance to the nearest cell edge (F2 - F1) of a jittered grid.
float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void fragment() {
	vec2 xz = local_pos.xz;
	float steep = 1.0 - clamp(local_normal.y, 0.0, 1.0);
	// Rock: mottled basalt; ash settles on the flats; cliffs show strata.
	float m = fbm(xz * 0.08);
	float grain = vnoise(xz * 1.3);
	vec3 rock = mix(rock_dark.rgb, rock_light.rgb, m * 0.8 + grain * 0.25);
	float strata = smoothstep(0.35, 0.65, vnoise(vec2(local_pos.y * 0.6, (xz.x + xz.y) * 0.02)));
	rock = mix(rock, rock_light.rgb * mix(0.7, 1.15, strata), smoothstep(0.35, 0.8, steep) * 0.6);
	float ash = smoothstep(0.45, 0.75, fbm(xz * 0.03 + 11.0)) * (1.0 - smoothstep(0.15, 0.45, steep));
	rock = mix(rock, ash_color.rgb, ash * 0.55);

	// Molten fissures: two scales of cracks, masked into patches.
	float to_lake = length(xz - lake_centre.xz) - lake_radius;
	float near_lake = 1.0 - smoothstep(0.0, molten_reach, to_lake);
	float amount = mix(background_molten, 1.0, near_lake);
	float patch = smoothstep(0.62 - amount * 0.45, 0.78 - amount * 0.3, fbm(xz * 0.012 + vec2(4.0, 1.0)));
	float big = cell_edge(xz * 0.07 + fbm(xz * 0.05) * 0.8);
	float small = cell_edge(xz * 0.22 + fbm(xz * 0.11 + 3.0) * 0.6);
	float crack = (1.0 - smoothstep(0.02, 0.09, big)) + (1.0 - smoothstep(0.015, 0.06, small)) * 0.55;
	crack *= patch * (1.0 - smoothstep(0.5, 0.95, steep) * 0.5);
	// A slow pulse, out of step from place to place.
	float pulse = 0.75 + 0.25 * sin(TIME * 0.9 + fbm(xz * 0.02) * 12.0);
	float heat = clamp(crack, 0.0, 1.0);
	vec3 molten = mix(molten_color.rgb, hot_color.rgb, smoothstep(0.75, 1.0, heat) * near_lake);

	ALBEDO = mix(rock, molten * 0.4, heat * 0.6);
	ROUGHNESS = mix(0.92, 0.6, heat);
	SPECULAR = 0.25;
	vec3 emission = molten * heat * glow * pulse;
	// Warm under-glow from the lake, strongest low down and facing it.
	float lit = 1.0 - smoothstep(0.0, lake_glow_reach, to_lake);
	float low = 1.0 - smoothstep(-70.0, 10.0, local_pos.y);
	emission += molten_color.rgb * lake_glow * lit * (0.35 + 0.65 * low) * (0.4 + m * 0.6);
	EMISSION = emission;
}
