// halo — the verb halo of a live prop (REDESIGN §3.7/§5.4, R3D index §7.6): an 8 px shell in the verb colour
// OUTSIDE the prop's 2.5 px ink, pulsing 0.6 ↔ 1.0 at 1.2 Hz. It MUST stay visible against the back wall, where a
// plain hull behind a wall-mounted prop is clipped by the wall, so:
//  * STENCIL: the prop (prop_toon) and its ink (outline_prop) write ref 1; the halo draws only where the stencil is
//    not 1, so it never covers the prop or its ink;
//  * DEPTH: the shell's depth is pulled `pull_m` toward the camera (reverse-Z: clip.z += k·clip.w toward the viewer),
//    so the wall behind the prop cannot clip it, while a character standing in the lane (≥ 0.6 m in front of any
//    set-band prop) still covers it — "depth-tested only against characters".
// Its own instance on visual layer 3 PROP_INK (the Bellows window culls it). `glow_amp` 0 hides it, 2 = the active spot.
shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0, 0.784, 0.220, 1.0);
uniform float glow_amp : hint_range(0.0, 2.0) = 1.0;
uniform float glow_hz = 1.2;
uniform float glow_phase = 0.0;
uniform float halo_px = 8.0;
uniform float ink_px = 2.5;
uniform float pull_m = 0.30;
uniform bool use_color_normal = false;
uniform float max_world = 0.12;

void vertex() {
	vec3 n = use_color_normal ? normalize(COLOR.rgb * 2.0 - 1.0) : normalize(NORMAL);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(0.01, -vp.z);
	float p11 = abs(PROJECTION_MATRIX[1][1]);
	float vh = max(VIEWPORT_SIZE.y, 1.0);
	float px = (ink_px * mnd_outline_scale + halo_px) * vh / 1080.0;
	float m_per_px = dist * 2.0 / (p11 * vh);
	float w = min(px * m_per_px, max_world);
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += n * (w / max(s, 1e-4));
	vec4 grown = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Pull toward the camera along the view ray without changing the projected position: scale the view-space point.
	float d = max(0.05, -grown.z);
	float k = max(0.05, d - pull_m) / d;
	VERTEX = (inverse(MODELVIEW_MATRIX) * vec4(grown.xyz * k, 1.0)).xyz;
}

void fragment() {
	float s = 0.5 + 0.5 * sin(TIME * 6.2831853 * glow_hz + glow_phase);
	float a = clamp((0.6 + 0.4 * s) * 0.5 * glow_amp, 0.0, 1.0);
	ALBEDO = glow_color.rgb;
	ALPHA = a * glow_color.a;
}
