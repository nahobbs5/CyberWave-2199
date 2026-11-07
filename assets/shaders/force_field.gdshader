shader_type spatial;
// Firewall shield: a glowing force field. Bright rim, a hex energy grid
// drifting over the shell, scan bands, a dissolve for fading in / out and
// a flash when it blocks a hit. Needs no UVs (works from the model-space
// direction), so any sphere-like mesh will do.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
// 0 = solid, 1 = gone.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
// 0..1 burst when an attack is blocked.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// How much the shell breathes (lower with reduced flashing).
uniform float pulse_amount : hint_range(0.0, 1.0) = 1.0;
uniform float hex_scale = 9.0;

varying vec3 local_dir;

void vertex() {
	local_dir = normalize(VERTEX);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Distance to the nearest hex cell edge (0 at the edge, ~0.5 in the middle).
float hex_edge(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 c = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - c.xy * s, p - (c.zw + 0.5) * s);
	vec2 q = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw;
	q = abs(q);
	return 0.5 - max(dot(q, s * 0.5), q.x);
}

void fragment() {
	float t = TIME;
	// Spherical coordinates of this point on the shell.
	vec2 sph = vec2(atan(local_dir.z, local_dir.x) / 6.2831853 + 0.5, acos(clamp(local_dir.y, -1.0, 1.0)) / 3.14159265);
	vec2 grid = vec2(sph.x * 2.0, sph.y) * hex_scale + vec2(t * 0.15, -t * 0.25);
	float edge = hex_edge(grid);
	float lines = 1.0 - smoothstep(0.0, 0.06, edge);
	// Cells light up one by one.
	float cell_glow = step(0.82, noise(floor(grid * 1.0) + floor(t * 1.5))) * 0.35;

	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float bands = smoothstep(0.85, 1.0, sin(local_dir.y * 14.0 - t * 3.0)) * 0.25;
	float pulse = 1.0 + pulse_amount * 0.15 * sin(t * 4.0);

	// Ring sweeping over the shell during a flash.
	float ring_pos = 1.0 - flash; // 0 -> 1 as the flash fades
	float ring = smoothstep(0.12, 0.0, abs(local_dir.y * 0.5 + 0.5 - ring_pos)) * flash;

	float energy = (fresnel * 1.4 + lines * (0.25 + fresnel) + cell_glow * fresnel + bands) * pulse;
	energy += flash * (0.6 + fresnel) + ring * 2.0;

	// Dissolve: noisy threshold with a hot edge.
	float n = noise(sph * vec2(40.0, 20.0));
	float cut = n - dissolve * 1.1 + 0.05;
	if (cut < 0.0) {
		discard;
	}
	float burn = smoothstep(0.08, 0.0, cut) * step(0.001, dissolve);

	vec3 col = color.rgb * energy + vec3(1.0, 0.85, 0.6) * (burn * 1.5 + ring * 0.8);
	ALBEDO = col;
	ALPHA = clamp(energy * 0.55 + burn, 0.0, 1.0);
}
