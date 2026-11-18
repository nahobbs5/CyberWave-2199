shader_type spatial;
// Boost ring inner rim (TrackFeature BOOST_RING), after
// 'reference files/Cyberwave New Boost Ring.png': a segmented magenta band
// round the inside of the slim graphite frame, dark under the four amber
// marker pods. UV.x = angle round the ring (0..1, counter-clockwise seen
// from the approach side), UV.y = 0 at the inner edge, 1 at the outer edge
// of the band. `sweep` (1 -> 0) runs two light pulses one lap clockwise as a
// car approaches; `flash` lights the inner edge once as it passes through.
// The frame, pods and lamps are separate meshes (TrackFeature._ring_visual).
render_mode cull_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.85, 1.0);
uniform vec4 gap_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float energy = 2.2;
// 1 when a car starts its approach, runs down to 0 (TrackFeature).
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
// 0..1: one flash per pass-through.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// 1 = reduced flashing: shallow pulses.
uniform float calm : hint_range(0.0, 1.0) = 0.0;

const float SEGMENTS = 28.0;
const float GAP = 0.3;        // share of each segment left dark
const float POD_HALF = 0.028; // turns either side of a marker pod left dark
const float TAIL = 0.07;      // pulse tail length (turns)

void fragment() {
	float a = UV.x;
	float rad = clamp(UV.y, 0.0, 1.0);

	// Segments with dark gaps. The seam at a = 0 / 1 lands on a gap.
	float s = fract(a * SEGMENTS);
	float aa = clamp(fwidth(s), 0.01, 0.1);
	float d = abs(s - 0.5);
	float seg = 1.0 - smoothstep(0.5 - GAP * 0.5 - aa, 0.5 - GAP * 0.5 + aa, d);
	// Dark under the pods at the top, bottom and sides.
	float dq = abs(fract(a * 4.0 + 0.5) - 0.5) * 0.25;
	seg *= smoothstep(POD_HALF, POD_HALF + 0.008, dq);

	// Two pulses, half a turn apart (top and bottom), one lap clockwise
	// (decreasing a) over the sweep. The tail trails at larger angles.
	float prog = 1.0 - sweep;
	float pulse = 0.0;
	if (sweep > 0.0) {
		for (int i = 0; i < 2; i++) {
			float head = fract(0.25 + 0.5 * float(i) - prog);
			float behind = fract(a - head);
			pulse += exp(-behind / TAIL) + exp(-pow((1.0 - behind) / 0.012, 2.0));
		}
		pulse *= smoothstep(0.0, 0.15, sweep) * mix(1.0, 0.35, calm);
	}
	pulse = min(pulse, 1.4);

	float edge = 1.0 - smoothstep(0.0, 0.65, rad);
	float base = mix(0.5, 0.65, calm);
	float lit = base + pulse * 3.0 + flash * (0.3 + edge * 1.5);

	vec3 glow = glow_color.rgb;
	vec3 core = mix(glow, vec3(1.0), 0.06 + 0.5 * min(pulse + flash * edge, 1.0));
	ALBEDO = mix(gap_color.rgb, core, seg);
	ROUGHNESS = mix(0.4, 0.2, seg);
	METALLIC = mix(0.6, 0.0, seg);
	EMISSION = core * seg * energy * lit
		+ glow * (1.0 - seg) * (0.08 * pulse + 0.6 * flash * edge);
}
