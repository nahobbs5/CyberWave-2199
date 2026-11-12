shader_type spatial;
// Warning sign for hazards: yellow triangle, black border, black lightning
// bolt. Procedural, drawn on a QuadMesh (UV 0..1, y down).
render_mode unshaded, cull_disabled;

uniform vec4 sign_color : source_color = vec4(1.0, 0.78, 0.05, 1.0);
uniform vec4 ink_color : source_color = vec4(0.03, 0.03, 0.03, 1.0);
uniform float glow = 1.4;

// Signed distance to a triangle (Inigo Quilez).
float sd_triangle(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
			vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
			vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);
	float tri = sd_triangle(p, vec2(0.5, 0.95), vec2(0.04, 0.12), vec2(0.96, 0.12));
	if (tri > 0.0) {
		discard;
	}
	// Bolt: two slanted triangles meeting in the middle.
	float b1 = sd_triangle(p, vec2(0.56, 0.78), vec2(0.38, 0.44), vec2(0.53, 0.47));
	float b2 = sd_triangle(p, vec2(0.47, 0.50), vec2(0.62, 0.53), vec2(0.43, 0.2));
	float bolt = min(b1, b2);
	bool ink = tri > -0.05 || bolt < 0.0;
	vec3 c = ink ? ink_color.rgb : sign_color.rgb * glow;
	ALBEDO = c;
}
