shader_type spatial;
// Nyiragongo's lava lake (GDD 8.6h), after the reference photos: plates of
// black, cooling crust drifting slowly, split by a web of glowing orange
// cracks, with yellow-white hot spots that boil up and fade, and the crust
// thinning (glowing through) toward the vents. Also used for the lava
// channel and the pools on the crater floor. Unshaded emission, so it lights
// the scene through glow/bloom in every renderer. Model space = track-local
// metres for scenery meshes.
render_mode unshaded, cull_disabled;

uniform vec4 crust_color : source_color = vec4(0.03, 0.02, 0.02, 1.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.3, 0.03, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
// Metres -> crust plates (bigger = smaller plates).
uniform float plate_scale = 0.045;
uniform float crack_width = 0.06;
uniform float glow = 4.0;
// Drift of the crust (m/s along x and z).
uniform vec2 drift = vec2(0.35, 0.15);
// Vents: xz (track-local) and radius; the crust breaks up near them.
uniform vec4 vents[4];
uniform int vent_count = 0;
// Fraction of the surface that's open, bright lava (channel = high).
uniform float openness : hint_range(0.0, 1.0) = 0.15;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
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
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.45 * sin(TIME * 0.05 + 6.2831 * hash2(i + g));
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
	vec2 xz = local_pos.xz - drift * TIME;
	vec2 warp = vec2(fbm(xz * 0.02), fbm(xz * 0.02 + 5.3)) * 6.0;
	float edge = cell_edge((xz + warp) * plate_scale);
	float fine = cell_edge((xz + warp) * plate_scale * 3.1 + 7.0);
	float crack = 1.0 - smoothstep(0.0, crack_width, edge);
	crack = max(crack, (1.0 - smoothstep(0.0, crack_width * 0.6, fine)) * 0.6);
	// Near vents the crust breaks up and glows through.
	float vent = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= vent_count) {
			break;
		}
		float d = length(local_pos.xz - vents[i].xy) / max(vents[i].z, 0.01);
		vent = max(vent, 1.0 - smoothstep(0.2, 1.0, d));
	}
	float open_field = smoothstep(1.0 - openness - 0.1, 1.0 - openness + 0.1, fbm(xz * 0.015 + 2.0));
	float boil = smoothstep(0.55, 0.9, fbm(xz * 0.06 + vec2(TIME * 0.12, -TIME * 0.09)));
	float heat = clamp(crack + vent * 0.9 + open_field * 0.85, 0.0, 1.0);
	float hot = clamp(boil * (vent + open_field) + crack * 0.25 * boil, 0.0, 1.0);
	vec3 lava = mix(crack_color.rgb, hot_color.rgb, hot);
	// Crust is not quite black: faint glow seeps through thin plates.
	float seep = fbm(xz * 0.08) * 0.08;
	vec3 color = mix(crust_color.rgb + crack_color.rgb * seep, lava * glow, heat);
	ALBEDO = color;
}
