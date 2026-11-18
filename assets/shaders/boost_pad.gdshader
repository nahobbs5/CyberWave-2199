shader_type spatial;
// Boost pad centre plate (TrackFeature BOOST_PAD), after
// 'reference files/New Boost Pads.png': dark ribbed graphite with three
// segmented cyan chevrons pointing the way to drive (local -Z). A soft
// pulse runs through the chevrons from back to front; `flash` washes the
// whole plate once when a car crosses it. The beveled frame and amber
// corner lights are separate meshes (TrackFeature._pad_visual).
render_mode cull_disabled;

// Plate size in metres (x = across the road, y = along it).
uniform vec2 plate_size = vec2(4.3, 5.3);
uniform vec4 glow_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 plate_color : source_color = vec4(0.035, 0.038, 0.045, 1.0);
uniform vec4 rib_color : source_color = vec4(0.11, 0.115, 0.125, 1.0);
uniform float chevron_energy = 3.5;
// 0..1: set by TrackFeature for one short flash per crossing.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// 1 = reduced flashing: slow, shallow pulse.
uniform float calm : hint_range(0.0, 1.0) = 0.0;

const float RIB_PITCH = 0.12;
const float CHEVRON_THICK = 0.4;
const float CHEVRON_SLOPE = 0.55; // metres back per metre out from the centre
const float SEGMENT = 0.3;       // segment pitch along an arm (metres across)
const float GAP = 0.22;           // share of each segment left dark

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Signed coverage of one chevron (1 inside, 0 outside, soft edge), and its
// distance outside the band for the glow bleed.
vec2 chevron(vec2 p, float apex, float half_span) {
	float ax = abs(p.x);
	// Distance from the arm's centre line, measured square to the arm.
	float d = abs(p.y - (apex - CHEVRON_SLOPE * ax)) * inversesqrt(1.0 + CHEVRON_SLOPE * CHEVRON_SLOPE);
	float edge = d - CHEVRON_THICK * 0.5;
	float aa = max(fwidth(edge), 0.004);
	float band = 1.0 - smoothstep(-aa, aa, edge);
	float span = 1.0 - smoothstep(half_span - aa, half_span + aa, ax);
	// Segments, measured along the arm; the apex stays solid.
	float s = fract((ax - 0.12) / SEGMENT);
	float sa = max(fwidth(s), 0.01);
	float seg = smoothstep(GAP - sa, GAP + sa, s);
	seg = max(seg, 1.0 - step(0.12, ax));
	return vec2(band * span * seg, max(edge, 0.0) + max(ax - half_span, 0.0));
}

void fragment() {
	// x across, y forward (driving direction is local -Z).
	vec2 p = vec2(local_pos.x, -local_pos.z);
	float half_len = plate_size.y * 0.5;
	float half_span = plate_size.x * 0.5 - 0.45;

	// Ribs across the road.
	float r = fract(p.y / RIB_PITCH);
	float ridge = smoothstep(0.05, 0.22, r) * (1.0 - smoothstep(0.55, 0.72, r));
	vec3 albedo = mix(plate_color.rgb, rib_color.rgb, ridge);
	// Tilt the normal on the rib flanks so they catch the sun.
	float flank = smoothstep(0.0, 0.22, r) - smoothstep(0.55, 0.8, r);
	NORMAL_MAP = normalize(vec3(0.5, 0.5 - flank * 0.18, 1.0));
	ROUGHNESS = mix(0.55, 0.32, ridge);
	METALLIC = 0.55;

	// Pulse: a soft wave travelling from the back of the pad to the front.
	float speed = mix(1.1, 0.35, calm);
	float travel = fract(TIME * speed);
	float wave_pos = mix(-half_len - 0.8, half_len + 0.8, travel);
	float wave = exp(-pow((p.y - wave_pos) / 0.9, 2.0));
	float pulse = mix(0.62, 0.85, calm) + mix(0.38, 0.12, calm) * wave;

	// Three chevrons, front apex near the front edge.
	float cover = 0.0;
	float near = 10.0;
	for (int i = 0; i < 3; i++) {
		float apex = half_len * 0.78 - float(i) * half_len * 0.52;
		vec2 c = chevron(p, apex, half_span);
		cover = max(cover, c.x);
		near = min(near, c.y);
	}
	float bleed = exp(-near / 0.18) * (1.0 - cover);

	vec3 glow = glow_color.rgb;
	vec3 core = mix(glow, vec3(1.0), 0.35);
	ALBEDO = mix(albedo, core, cover);
	ROUGHNESS = mix(ROUGHNESS, 0.2, cover);
	METALLIC = mix(METALLIC, 0.0, cover);
	float lit = pulse + flash * 0.9;
	EMISSION = core * cover * chevron_energy * lit
		+ glow * bleed * 0.35 * lit
		+ glow * flash * 0.8 * (1.0 - cover);
}
