// Shared bits for still water (standing_water, emp_puddle). Everything is
// built from world XZ in metres so it tiles the same on any mesh.

float w_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float w_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(w_hash(i), w_hash(i + vec2(1.0, 0.0)), f.x),
			mix(w_hash(i + vec2(0.0, 1.0)), w_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float w_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += w_noise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Rain-drop rings: one drop per cell on its own phase, each an expanding,
// fading ring. Returns a signed height (crest minus trough).
float w_rings(vec2 p, float t) {
	float h = 0.0;
	vec2 cell = floor(p);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			float r = w_hash(c);
			float period = 1.2 + r * 1.6;
			float age = fract(t / period + r * 7.0) * period;
			vec2 centre = c + vec2(w_hash(c + 3.1), w_hash(c + 8.7));
			float d = length(p - centre);
			float radius = age * 0.55;
			float ring = d - radius;
			float fade = (1.0 - smoothstep(0.0, 1.0, age / period)) * smoothstep(0.75, 0.0, radius);
			h += sin(ring * 40.0) * exp(-ring * ring * 60.0) * fade;
		}
	}
	return h;
}

// Ripple height at world XZ (metres): two drifting noise layers plus rings.
float w_height(vec2 xz, float t, float scale, float speed, float rings) {
	vec2 p = xz * scale;
	float h = w_noise(p * 1.3 + vec2(t * 0.31, t * 0.17) * speed) * 0.6
			+ w_noise(p * 3.1 - vec2(t * 0.23, -t * 0.29) * speed + 11.0) * 0.4;
	if (rings > 0.0) {
		h += w_rings(xz * 0.67, t) * 0.35 * rings;
	}
	return h;
}

// Surface slope (d/dx, d/dz) from finite differences of w_height.
vec2 w_slope(vec2 xz, float t, float scale, float speed, float rings) {
	float e = 0.04;
	float h0 = w_height(xz, t, scale, speed, rings);
	return vec2(w_height(xz + vec2(e, 0.0), t, scale, speed, rings) - h0,
			w_height(xz + vec2(0.0, e), t, scale, speed, rings) - h0) / e;
}
