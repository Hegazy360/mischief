// outline_prop — the 2.5 px ink of a LIVE prop: outline.gdshader + a stencil write (ref 1) so the verb halo
// (halo.gdshader, stencil ≠ 1) never covers the ink. Its own instance on visual layer 3 PROP_INK. See outline.gdshader.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled;
stencil_mode write, compare_always, 1;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.106, 0.137, 0.251, 1.0);
uniform float outline_px = 2.5;
uniform bool use_color_normal = false;
uniform vec4 room_color : source_color = vec4(0.78, 0.71, 0.52, 1.0);
uniform float room_lerp : hint_range(0.0, 1.0) = 0.0;
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float max_world = 0.05;

void vertex() {
	vec3 n = use_color_normal ? normalize(COLOR.rgb * 2.0 - 1.0) : normalize(NORMAL);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(0.01, -vp.z);
	float p11 = abs(PROJECTION_MATRIX[1][1]);
	float vh = max(VIEWPORT_SIZE.y, 1.0);
	float px = outline_px * mnd_outline_scale * vh / 1080.0;
	float m_per_px = dist * 2.0 / (p11 * vh);
	float w = min(px * m_per_px, max_world);
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += n * (w / max(s, 1e-4));
}

void fragment() {
	vec3 c = mix(ink.rgb, room_color.rgb, room_lerp);
	ALBEDO = c * mix(1.0, stage_light, 0.6);
}
