shader_type spatial;
// Holographic recovery overlay (docs/Recovery System.md): drawn on top of a
// car's meshes as material_overlay while it dissolves and re-forms. Additive
// cyan light: Fresnel edge glow, scrolling scan lines, a grid "wireframe",
// digital flicker, and a bright band at the dissolve / build front. Heights
// are world-space, measured from base_y over height, so every mesh of the
// car sweeps together.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.2, 0.45, 1.0, 1.0);
uniform vec4 glitch_tint : source_color = vec4(1.0, 0.2, 0.85, 1.0);
// Overall brightness (0 = invisible).
uniform float strength = 0.0;
// Shown only where height >= dissolve (sweeps away bottom to top) ...
uniform float dissolve = 0.0;
// ... and where height <= build (forms bottom to top).
uniform float build = 1.0;
uniform float wire = 0.0;
uniform float flicker = 0.0;
uniform float base_y = 0.0;
uniform float height = 2.0;

varying vec3 world_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((world_pos.y - base_y) / height, 0.0, 1.0);
	// Blocky digital noise so the fronts break up into fragments.
	float n = hash(floor(world_pos * 9.0)) - 0.5;
	float hn = h + n * 0.12;
	if (hn < dissolve || hn > build) {
		discard;
	}
	float front = 0.0;
	if (dissolve > 0.001) {
		front = max(front, 1.0 - smoothstep(0.0, 0.07, hn - dissolve));
	}
	if (build < 0.999) {
		front = max(front, 1.0 - smoothstep(0.0, 0.07, build - hn));
	}
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float scan = pow(0.5 + 0.5 * sin((world_pos.y - TIME * 1.6) * 55.0), 6.0);
	vec3 g = abs(fract(world_pos * 2.5) - 0.5);
	float grid = 1.0 - smoothstep(0.0, 0.05, min(min(g.x, g.y), g.z));
	float blink = 1.0 - flicker * 0.7 * step(0.6, hash(vec3(floor(TIME * 24.0), 1.0, 2.0)));
	vec3 col = tint.rgb * (0.18 + 0.75 * fres + 0.45 * scan) + edge_tint.rgb * grid * wire;
	col += vec3(1.0) * front * 1.4;
	col = mix(col, glitch_tint.rgb * 0.8, flicker * 0.25 * step(0.85, hash(vec3(floor(TIME * 30.0), floor(world_pos.y * 6.0), 0.0))));
	ALBEDO = col * strength * blink;
}
