// Optional Poly Haven detail for the procedural shaders (moon rock, glacier
// ice, Crazy House walls): an albedo set's grain multiplies the procedural
// colour and its normal map roughens the lighting. Mapped triplanar in model
// space (track-local metres for scenery), so meshes need no UVs. Both
// strengths default to 0, so a material without detail looks as before
// (the web build has no normal maps; the default normal is flat).
// TrackScenery.shader_textures(m, "detail", name) sets the two textures.

uniform sampler2D detail_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres per texture tile.
uniform float detail_tile = 3.0;
// How strongly the texture's light / dark grain shows in the colour.
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
// The texture's average brightness, so the grain neither darkens nor
// brightens the colour overall.
uniform float detail_mean = 0.45;
uniform float detail_normal_strength : hint_range(0.0, 2.0) = 0.0;

vec3 detail_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

// Colour multiplier (about 1 on average) from the albedo grain.
float detail_shade(vec3 p, vec3 w) {
	vec3 c = texture(detail_albedo, p.zy / detail_tile).rgb * w.x
			+ texture(detail_albedo, p.xz / detail_tile).rgb * w.y
			+ texture(detail_albedo, p.xy / detail_tile).rgb * w.z;
	float l = dot(c, vec3(0.299, 0.587, 0.114)) / max(detail_mean, 0.01);
	return mix(1.0, clamp(l, 0.35, 1.8), detail_strength);
}

// Whiteout-blended triplanar normal in model space.
vec3 detail_model_normal(vec3 p, vec3 n, vec3 w) {
	vec3 tx = texture(detail_normal, p.zy / detail_tile).rgb * 2.0 - 1.0;
	vec3 ty = texture(detail_normal, p.xz / detail_tile).rgb * 2.0 - 1.0;
	vec3 tz = texture(detail_normal, p.xy / detail_tile).rgb * 2.0 - 1.0;
	tx.xy *= detail_normal_strength;
	ty.xy *= detail_normal_strength;
	tz.xy *= detail_normal_strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

// The detailed normal in view space, for NORMAL (flipped on back faces).
vec3 detail_view_normal(vec3 p, vec3 n, vec3 w, mat4 model, mat4 view, bool front) {
	vec3 v = normalize((view * model * vec4(detail_model_normal(p, n, w), 0.0)).xyz);
	return front ? v : -v;
}
