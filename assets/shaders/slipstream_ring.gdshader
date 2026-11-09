shader_type spatial;
// Slipstream ring: a glowing neon arch standing around the car while it
// drafts. The mesh is a flat half-circle band: UV.x runs along the arc
// (0 and 1 at the road), UV.y across the band (0.5 = the core line).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
// Overall brightness 0..1 (eased toward the slipstream meter).
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// 0..1 burst when the slipstream boost fires.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// How fast light streaks run along the arc (0 = still).
uniform float flow_speed = 1.6;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0; // 0 at the core, 1 at the edge
	float core = 1.0 - smoothstep(0.0, 0.16, across);
	float glow = pow(1.0 - across, 2.2);
	// Fade where the arch meets the road so it never cuts into the asphalt.
	float ends = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	// Streaks running up both sides toward the roof.
	float side = min(UV.x, 1.0 - UV.x);
	float streak = smoothstep(0.7, 1.0, sin(side * 40.0 - TIME * flow_speed * 6.2831853));
	float bright = strength * (1.0 + flash * 1.5);
	vec3 col = color.rgb * (glow * 0.9 + streak * glow * 0.6) + vec3(0.85, 1.0, 1.0) * core * 1.2;
	ALBEDO = col * bright * ends;
}
