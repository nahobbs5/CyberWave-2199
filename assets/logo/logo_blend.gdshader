shader_type canvas_item;
render_mode blend_add;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float fx = smoothstep(0.0, 0.06, UV.x) * smoothstep(0.0, 0.06, 1.0 - UV.x);
	float fy = smoothstep(0.0, 0.15, UV.y) * smoothstep(0.0, 0.15, 1.0 - UV.y);
	COLOR = vec4(c.rgb * fx * fy, 1.0);
}
