shader_type spatial;
// The start-light board (Racing Start Light Assembly.png). Lamps at index
// lit_count and above are shown switched off: dark and desaturated, with
// their glow dimmed. Lit lamps are pushed a little brighter so they bloom.
render_mode unshaded, cull_disabled;

uniform sampler2D board : source_color, filter_linear_mipmap;
uniform int lit_count = 0;
uniform float lit_boost = 1.6;

const float ASPECT = 3.0;
const float LAMP_RADIUS = 0.19;
const float GLOW_RADIUS = 0.34;

void fragment() {
	vec4 c = texture(board, UV);
	float off = 0.0;
	float glow_off = 0.0;
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 centre = vec2(0.2675 + float(i) * 0.155, 0.487);
		float d = length((UV - centre) * vec2(ASPECT, 1.0));
		float inside = 1.0 - smoothstep(LAMP_RADIUS - 0.02, LAMP_RADIUS + 0.01, d);
		float halo = 1.0 - smoothstep(LAMP_RADIUS, GLOW_RADIUS, d);
		if (i >= lit_count) {
			off = max(off, inside);
			glow_off = max(glow_off, halo);
		} else {
			lit = max(lit, inside);
		}
	}
	float luma = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 dark = vec3(luma * 0.16);
	vec3 col = mix(c.rgb, dark, off);
	col = mix(col, col * 0.45, glow_off * (1.0 - off));
	col *= mix(1.0, lit_boost, lit);
	ALBEDO = col;
	ALPHA = c.a;
}
