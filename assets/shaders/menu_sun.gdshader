shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Big synthwave sun behind the start-menu skyline: a magenta disc, brighter
// at the top, with horizontal gaps across its lower half and a soft halo.

uniform vec3 top_color : source_color = vec3(1.0, 0.45, 0.85);
uniform vec3 bottom_color : source_color = vec3(0.85, 0.08, 0.6);
uniform float energy = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float disc = 1.0 - smoothstep(0.78, 0.8, d);
	float halo = (1.0 - smoothstep(0.78, 1.0, d)) * 0.35;
	float y = UV.y;
	// Bands get thicker towards the bottom, like the logo's sun.
	float bands = 1.0;
	if (y > 0.5) {
		float t = (y - 0.5) * 2.0;
		float stripe = fract(y * 18.0);
		bands = step(t * 0.6, stripe);
	}
	vec3 col = mix(top_color, bottom_color, y);
	ALBEDO = col * energy;
	ALPHA = clamp(disc * bands + halo * (1.0 - disc), 0.0, 1.0);
}
