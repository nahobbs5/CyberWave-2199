shader_type spatial;
render_mode cull_disabled;
// Garden Rhapsody light show for the Supertrees (Gardens by the Bay). The
// steel frames glow in a slow cycle of purple, cyan, green and magenta. The
// phase comes from world position, so the colour change rolls across the
// grove as a wave. Batched meshes need no per-tree data.

uniform vec3 color_a : source_color = vec3(0.75, 0.2, 1.0);
uniform vec3 color_b : source_color = vec3(0.1, 0.85, 1.0);
uniform vec3 color_c : source_color = vec3(0.45, 1.0, 0.3);
uniform vec3 color_d : source_color = vec3(1.0, 0.2, 0.7);
uniform vec3 base_color : source_color = vec3(0.22, 0.08, 0.26);
uniform float energy = 2.4;
// Colours per second (one full cycle is 4 / speed seconds).
uniform float speed = 0.07;
// Phase change per metre across the grove.
uniform float wave = 0.004;
// Glow ramps up with height in the tree (the canopy is brightest).
uniform float height_ramp = 0.0;
uniform float ramp_from = -20.0;
uniform float ramp_to = 10.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 palette(float t) {
	float f = fract(t) * 4.0;
	float k = smoothstep(0.0, 1.0, fract(f));
	int i = int(floor(f));
	vec3 a = i == 0 ? color_a : i == 1 ? color_b : i == 2 ? color_c : color_d;
	vec3 b = i == 0 ? color_b : i == 1 ? color_c : i == 2 ? color_d : color_a;
	return mix(a, b, k);
}

void fragment() {
	float t = TIME * speed + (world_pos.x + world_pos.z) * wave;
	vec3 glow = palette(t);
	float ramp = mix(1.0, smoothstep(ramp_from, ramp_to, world_pos.y), height_ramp);
	ALBEDO = base_color;
	ROUGHNESS = 0.45;
	METALLIC = 0.6;
	EMISSION = glow * energy * (0.35 + 0.65 * ramp);
}
