// set_toon — architecture, furniture and set dressing (REDESIGN §5.3/§5.4, R3D index §7.6): palette albedo (one palette
// per room set, so a room is one material), REDESIGN's neutral shadow band (`mnd_fill_color`), the key bands, the
// footlight and the 66 % floor, then the room's `stage_light` (1.0 / 0.9 / 0.78 / 0.3) and `desat` (0 / 0.4).
// Palette alpha < 0.5 marks a practical (fire, lamp, window): emissive, unlit, only dimmed by the room light.
// No outline, no glow, no rim (only characters get a rim; only live props get ink).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled, shadows_disabled;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform sampler2D palette : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform float emissive_gain = 1.0;

void fragment() {
	vec4 p = texture(palette, UV) * albedo_color;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz);
	vec3 col;
	if (p.a < 0.5) {
		col = mnd_stage(p.rgb * emissive_gain, max(stage_light, 0.5), desat * 0.5);
	} else {
		col = mnd_light(p.rgb, n_world, mnd_band_soft, stage_light, desat, wpos);
	}
	ALBEDO = col;
}
