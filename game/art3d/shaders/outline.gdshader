// outline — inverted-hull ink (REDESIGN §5.4, R3D index §7.6), used as a material's next_pass.
// Constant SCREEN width: `outline_px` logical px at the 1080-tall base (characters 3.5, live props 2.5), × the global
// `mnd_outline_scale` (Settings "Outline +50 %" = 1.5), × vertex COLOR.a on characters (their outline-scale channel).
// Ink #1B2340, lerped `room_lerp` (0.5 in a dimmed room) toward `room_color`, and dimmed with the room's stage light.
// Godot 4.7.2 Compatibility gotchas (tools/art3d/diorama/README.md): grow VERTEX in model space — never write
// POSITION (the depth test breaks and the hull covers the object); PROJECTION_MATRIX[1][1] is negative in the vertex
// stage — use abs(). `use_color_normal` grows along a smoothed normal baked in COLOR.rgb (0..1, object space) for
// hard-edged props (box props otherwise split at the corners); skinned characters use NORMAL (COLOR is not skinned).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.106, 0.137, 0.251, 1.0);
uniform float outline_px = 3.5;
uniform bool use_color_normal = false;
uniform bool width_from_alpha = true;
uniform vec4 room_color : source_color = vec4(0.78, 0.71, 0.52, 1.0);
uniform float room_lerp : hint_range(0.0, 1.0) = 0.0;
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float max_world = 0.05;

void vertex() {
	vec3 n = use_color_normal ? normalize(COLOR.rgb * 2.0 - 1.0) : normalize(NORMAL);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(0.01, -vp.z);
	float p11 = abs(PROJECTION_MATRIX[1][1]);
	bool ortho = abs(PROJECTION_MATRIX[3][3]) > 0.5;
	float vh = max(VIEWPORT_SIZE.y, 1.0);
	float px = outline_px * mnd_outline_scale * vh / 1080.0;
	if (width_from_alpha && !use_color_normal) {
		px *= COLOR.a;
	}
	float m_per_px = (ortho ? 2.0 : dist * 2.0) / (p11 * vh);
	float w = min(px * m_per_px, max_world);
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += n * (w / max(s, 1e-4));
}

void fragment() {
	vec3 c = mix(ink.rgb, room_color.rgb, room_lerp);
	ALBEDO = c * mix(1.0, stage_light, 0.6);
}
