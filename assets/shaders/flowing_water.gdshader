shader_type spatial;
// Moving river water for Vale da Lua: ripples, streaks and foam scroll
// downstream. UV.x runs across the river (0..1), UV.y along it in metres /
// 4, so the flow follows the mesh. Steep parts of the ribbon (waterfalls)
// switch to fast, white falling streaks; COLOR.r adds foam (rapids, the
// churn at the foot of a fall). Banks get a ring of foam too.
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.2, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.5, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
// Metres per second, roughly: river and waterfall speeds.
uniform float speed = 1.4;
uniform float fall_speed = 5.0;

varying float steep;
varying float foam_in;

void vertex() {
	// COLOR.g marks falling water explicitly (smoothed normals soften the drop).
	steep = max(1.0 - abs(NORMAL.y), COLOR.g);
	foam_in = COLOR.r;
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

void fragment() {
	float fall = smoothstep(0.45, 0.8, steep);
	float flow = mix(speed, fall_speed, fall) * 0.25;
	vec2 uv = UV;
	vec2 p = vec2(uv.x * 4.0, uv.y * 1.0 - TIME * flow);
	float ripples = noise(p * vec2(1.0, 2.0)) * 0.6 + noise(p * vec2(2.7, 4.3) + 7.0) * 0.4;
	float streaks = noise(vec2(uv.x * mix(10.0, 26.0, fall), uv.y * mix(1.2, 0.4, fall) - TIME * flow * 1.6));
	float bank = smoothstep(0.78, 1.0, abs(uv.x - 0.5) * 2.0);
	float foam = smoothstep(0.62, 0.85, streaks * 0.6 + ripples * 0.4 + foam_in * 0.55 + bank * 0.3);
	foam = max(foam, fall * smoothstep(0.25, 0.6, streaks));
	foam = clamp(foam + foam_in * 0.35 * ripples, 0.0, 1.0);

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, ripples * 0.7 + bank * 0.3);
	col = mix(col, foam_color.rgb, foam);
	ALBEDO = col;
	ALPHA = mix(0.82, 0.97, max(foam, fall));
	ROUGHNESS = mix(0.04, 0.45, foam);
	SPECULAR = 0.7;
	EMISSION = foam_color.rgb * (foam * 0.12 + fall * 0.25);
	// Gentle wobble in the surface normal so the sky reflection moves.
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4((ripples - 0.5) * 0.25, 0.0, (streaks - 0.5) * 0.25, 0.0)).xyz * (1.0 - fall));
}
