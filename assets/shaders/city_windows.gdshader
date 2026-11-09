shader_type spatial;
// Night-city towers for the start menu (MenuStreetScene): a dark facade with
// a grid of lit windows. Works on MultiMesh boxes; INSTANCE_CUSTOM.x seeds
// which windows are lit, INSTANCE_CUSTOM.y is the share of magenta windows
// (the rest are cyan). Windows are laid out in world space so every tower
// gets the same window size whatever its scale.

uniform vec3 facade : source_color = vec3(0.025, 0.018, 0.06);
uniform vec3 window_cyan : source_color = vec3(0.1, 0.85, 1.0);
uniform vec3 window_magenta : source_color = vec3(1.0, 0.25, 0.85);
uniform vec2 window_size = vec2(1.5, 2.1);
uniform float lit_share = 0.24;
uniform float energy = 1.5;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 custom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	custom = INSTANCE_CUSTOM;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.x > n.z ? world_pos.zy : world_pos.xy;
	vec2 cell = p / window_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float pane = step(0.22, f.x) * step(f.x, 0.78) * step(0.28, f.y) * step(f.y, 0.78);
	float r = hash(id + vec2(custom.x * 31.0, custom.x * 17.0));
	float lit = step(1.0 - lit_share, r);
	// A few windows blink slowly.
	float blink = step(0.97, hash(id + floor(TIME * 0.4 + r * 7.0)));
	lit *= 1.0 - blink;
	vec3 col = mix(window_cyan, window_magenta, step(hash(id * 1.73 + custom.x), custom.y));
	float wall = 1.0 - step(0.5, n.y);
	ALBEDO = facade;
	ROUGHNESS = 0.55;
	METALLIC = 0.3;
	EMISSION = col * pane * lit * wall * energy * (0.6 + r * 0.8);
}
