// fx_toon — vinyl FX and particles (the CHOO puff, dazed stars, pepper, notes, drops, roses, onions, steam, dust;
// R3D index §7.6): look A's matte vinyl on `albedo_color` × `tex` × the particle/vertex COLOR, floored at 66 %, with
// alpha. `billboard` turns quads to the camera (CPUParticles3D quads); meshes keep their own orientation.
// `emissive` 1 = unlit (sparkles, the spotlight's motes). Visual layer 5 MAIN_ONLY unless the window must show it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, fog_disabled, shadows_disabled;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform bool billboard = false;
uniform float emissive : hint_range(0.0, 1.0) = 0.0;
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float key_front : hint_range(0.0, 1.0) = 0.35;
uniform float alpha_scissor = 0.02;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 t = texture(tex, UV) * albedo_color * COLOR;
	if (t.a < alpha_scissor) {
		discard;
	}
	vec3 col = t.rgb;
	if (emissive < 1.0) {
		vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz);
		float lit;
		vec3 shaded = mnd_vinyl(t.rgb, n_world, mnd_band_soft, wpos, mnd_key_front(INV_VIEW_MATRIX[2].xyz, key_front), lit);
		col = mix(shaded, t.rgb, emissive);
	}
	ALBEDO = col * stage_light;
	ALPHA = t.a;
}
