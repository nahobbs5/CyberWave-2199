shader_type spatial;
// Nyiragongo crater rock (GDD 8.6h). Two Poly Haven rock sets mapped
// triplanar in world space (track-local metres; tracks sit at the origin):
// stratified, fractured basalt on steep faces, broken rock and grit on the
// flats, darkened toward black. Ash settles in hollows. Fine molten
// fissures glow on the flats, denser and hotter toward the lava lake, and
// the lake throws a warm glow up the walls. Emission carries the glow, so
// it reads in Compatibility too (no light limits). Normal and roughness
// maps are optional (the web build leaves them out).
render_mode cull_disabled;

uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres per texture tile.
uniform float cliff_tile = 7.0;
uniform float ground_tile = 4.0;
// Multiplies the textures toward basalt black.
uniform vec4 cliff_tint : source_color = vec4(0.42, 0.4, 0.42, 1.0);
uniform vec4 ground_tint : source_color = vec4(0.3, 0.28, 0.28, 1.0);
uniform vec4 ash_color : source_color = vec4(0.36, 0.34, 0.33, 1.0);
uniform float ash_amount = 0.45;
uniform float normal_strength = 1.0;
uniform vec4 molten_color : source_color = vec4(1.0, 0.32, 0.04, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.78, 0.25, 1.0);
// Lava lake: centre (track-local) and radius (m).
uniform vec3 lake_centre = vec3(0.0, -68.0, -20.0);
uniform float lake_radius = 165.0;
// How far from the lake edge the fissures fade to their background level (m).
uniform float molten_reach = 240.0;
uniform float background_molten = 0.18;
uniform float glow = 3.0;
// Warm light thrown up by the lake onto nearby rock.
uniform float lake_glow = 0.3;
uniform float lake_glow_reach = 220.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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

vec3 triplanar(sampler2D tex, vec3 p, vec3 w, float tile) {
	return texture(tex, p.zy / tile).rgb * w.x + texture(tex, p.xz / tile).rgb * w.y + texture(tex, p.xy / tile).rgb * w.z;
}

// Whiteout-blended triplanar normal (world space).
vec3 triplanar_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float tile) {
	vec3 tx = texture(tex, p.zy / tile).rgb * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz / tile).rgb * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy / tile).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float steep = 1.0 - clamp(n.y, 0.0, 1.0);
	float cliffness = smoothstep(0.25, 0.6, steep);
	vec2 xz = world_pos.xz;

	vec3 cliff = triplanar(cliff_albedo, world_pos, w, cliff_tile) * cliff_tint.rgb;
	vec3 ground = triplanar(ground_albedo, world_pos, w, ground_tile) * ground_tint.rgb;
	// Large-scale variation so tiling doesn't show.
	float m = fbm(xz * 0.015);
	ground *= 0.75 + m * 0.5;
	cliff *= 0.8 + fbm(vec2(world_pos.y * 0.15, (xz.x + xz.y) * 0.01)) * 0.4;
	vec3 rock = mix(ground, cliff, cliffness);
	// Ash drifts in the hollows and on ledges.
	float ash = smoothstep(0.5, 0.8, fbm(xz * 0.04 + 11.0)) * (1.0 - cliffness) * ash_amount;
	rock = mix(rock, ash_color.rgb, ash);

	vec3 nc = triplanar_normal(cliff_normal, world_pos, n, w, cliff_tile);
	vec3 ng = triplanar_normal(ground_normal, world_pos, n, w, ground_tile);
	vec3 nw = normalize(mix(ng, nc, cliffness));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// Molten fissures: fine cracks on the flats, in patches, more near the lake.
	float to_lake = length(xz - lake_centre.xz) - lake_radius;
	float near_lake = 1.0 - smoothstep(0.0, molten_reach, to_lake);
	float amount = mix(background_molten, 1.0, near_lake);
	float patch = smoothstep(0.66 - amount * 0.4, 0.8 - amount * 0.25, fbm(xz * 0.02 + vec2(4.0, 1.0)));
	float big = cell_edge(xz * 0.22 + fbm(xz * 0.1) * 0.9);
	float small = cell_edge(xz * 0.6 + fbm(xz * 0.3 + 3.0) * 0.7);
	float crack = (1.0 - smoothstep(0.015, 0.05, big)) + (1.0 - smoothstep(0.01, 0.04, small)) * 0.5;
	crack *= patch * (1.0 - cliffness);
	float pulse = 0.75 + 0.25 * sin(TIME * 0.9 + fbm(xz * 0.02) * 12.0);
	float heat = clamp(crack, 0.0, 1.0);
	vec3 molten = mix(molten_color.rgb, hot_color.rgb, smoothstep(0.7, 1.0, heat) * near_lake);

	ALBEDO = mix(rock, molten * 0.3, heat * 0.7);
	ROUGHNESS = mix(0.9, 0.55, heat);
	SPECULAR = 0.3;
	vec3 emission = molten * heat * glow * pulse;
	float lit = 1.0 - smoothstep(0.0, lake_glow_reach, to_lake);
	float low = 1.0 - smoothstep(-70.0, 20.0, world_pos.y);
	emission += molten_color.rgb * lake_glow * lit * (0.3 + 0.7 * low) * (0.5 + m * 0.5);
	EMISSION = emission;
}
