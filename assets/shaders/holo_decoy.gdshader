shader_type spatial;
// Holo Decoy: a see-through hologram of the car. Cyan body, bright fresnel
// rim, scanlines crawling up it in world space, and an occasional glitch
// band that slides the image sideways. `steady` (reduced flashing) stops the
// flicker and the band jumps.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
// 0..1 fade (in when deployed, out when it expires or pops).
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float steady : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Glitch band: a thin slice of the car jumps sideways now and then.
	float tick = floor(TIME * 9.0);
	float band_y = hash(tick) * 1.6;
	float in_band = step(abs(VERTEX.y - band_y), 0.12) * step(0.6, hash(tick + 7.0));
	VERTEX.x += in_band * (hash(tick + 3.0) - 0.5) * 0.5 * (1.0 - steady);
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float scan = 0.55 + 0.45 * sin(world_pos.y * 40.0 - TIME * 6.0);
	float sweep = smoothstep(0.92, 1.0, fract(world_pos.y * 0.6 - TIME * 0.7));
	float flicker = mix(0.75 + 0.25 * step(0.15, hash(floor(TIME * 24.0))), 0.9, steady);
	vec3 col = color.rgb * (0.18 + 0.35 * scan) + color.rgb * fresnel * 1.6 + vec3(0.8, 1.0, 1.0) * sweep * 0.5;
	ALBEDO = col * flicker * alpha;
}
