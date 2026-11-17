shader_type canvas_item;
// System Glitch: scrambles the middle of a racer's view (GDD 6.3), like an
// ink splat over the screen but digital. Only an elliptical centre region is
// touched; the corners (where every HUD panel lives) stay clean, and the HUD
// draws on top anyway. Inside: blocky horizontal tearing, RGB split, chunky
// cyan / magenta noise blocks and dark scan bars.
//   intensity  0..1 overall strength (ramps in/out; bursts above 0.7)
//   burst      0..1 extra heavy moment (Inky-style splats)
//   calm       1 = reduced flashing: slow, smooth, no strobing

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
// Half-size of the affected ellipse, as a fraction of the view.
uniform vec2 extent = vec2(0.36, 0.33);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - 0.5) / extent;
	// Ragged edge: the splat outline wobbles with noise.
	float edge = 1.0 + 0.18 * (vnoise(uv * 9.0 + TIME * mix(1.5, 0.3, calm)) - 0.5);
	float mask = 1.0 - smoothstep(0.65 * edge, 1.0 * edge, length(d));
	float k = mask * intensity;
	if (k <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Time steps: fast jumps normally, slow smooth drift when calm.
		float rate = mix(14.0, 2.0, calm);
		float tick = calm > 0.5 ? TIME * rate : floor(TIME * rate);
		// Horizontal tear: rows of blocks slide sideways.
		float rows = mix(28.0, 14.0, calm);
		float row = floor(uv.y * rows);
		float tear = (hash(vec2(row, floor(tick))) - 0.5) * step(0.55 - burst * 0.3, hash(vec2(row * 1.7, floor(tick) + 3.0)));
		tear = mix(tear, (vnoise(vec2(row * 0.4, tick)) - 0.5) * 0.6, calm);
		float shift = tear * 0.09 * k * (1.0 + burst);
		// RGB split.
		float split = 0.012 * k * (1.0 + 2.0 * burst);
		vec2 suv = vec2(uv.x + shift, uv.y);
		vec3 scene;
		scene.r = texture(screen_tex, suv + vec2(split, 0.0)).r;
		scene.g = texture(screen_tex, suv).g;
		scene.b = texture(screen_tex, suv - vec2(split, 0.0)).b;
		// Chunky noise blocks in cyan / magenta / static.
		vec2 cell = floor(uv * vec2(48.0, 27.0) * mix(1.0, 0.5, calm));
		float n = hash(cell + floor(tick) * 1.31);
		n = mix(n, vnoise(cell * 0.35 + tick * 0.5), calm);
		float block_on = smoothstep(0.62 - 0.35 * k - 0.2 * burst, 0.68 - 0.35 * k - 0.2 * burst, n);
		vec3 tint = mix(vec3(0.2, 1.0, 0.95), vec3(1.0, 0.25, 0.8), step(0.5, hash(cell + 9.0)));
		float grain = hash(uv * 900.0 + floor(TIME * mix(60.0, 4.0, calm)));
		vec3 stat = mix(vec3(grain), tint, 0.65);
		// Dark scan bars rolling down.
		float bars = 0.75 + 0.25 * sin(uv.y * 380.0 + TIME * mix(30.0, 3.0, calm));
		vec3 col = mix(scene, stat, block_on * k * 0.9) * bars;
		// The heaviest moments nearly black out the middle (the splat).
		col = mix(col, tint * 0.15 + vec3(grain) * 0.15, burst * mask * 0.55);
		COLOR = vec4(col, clamp(k * 1.2, 0.0, 1.0));
	}
}
