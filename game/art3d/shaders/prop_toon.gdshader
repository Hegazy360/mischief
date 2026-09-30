// prop_toon — live props (REDESIGN §3.7/§5.4, R3D index §7.6): look A's vinyl terms (lilac terminator, ground bounce,
// 0.10 sheen, the 66 % floor) on the palette albedo, the room's `stage_light` / `desat`, and the VERB GLOW: a pulse in
// the verb colour (`glow_color`: rig #FFC838, hide #5C9EFF, take #FFF4DB, exit cream) at 1.2 Hz between 0.6 and 1.0
// of its strength; `glow_amp` 0 = off, 1 = normal, 2 = the active spot (double amplitude). The glow is a fresnel
// rim + a small body lift, so it also reads on a wall-mounted prop whose halo shell the wall would clip (the halo
// fallback of REDESIGN §5.4). `halo_fresnel` > 0 strengthens the fresnel part when the stencil halo is not used.
// Palette alpha < 0.5 = emissive (a practical: the lamp in the lamp). Writes stencil ref 1 (the halo reads it).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled, shadows_disabled;
stencil_mode write, compare_always, 1;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform sampler2D palette : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float key_front : hint_range(0.0, 1.0) = 0.35;
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.784, 0.220, 1.0);
uniform float glow_amp : hint_range(0.0, 2.0) = 0.0;
uniform float glow_hz = 1.2;
uniform float glow_phase = 0.0;
uniform float halo_fresnel : hint_range(0.0, 1.0) = 0.0;
uniform float spent : hint_range(0.0, 1.0) = 0.0;

// The pulse: 0.6 ↔ 1.0 at glow_hz (a sine), scaled by the amplitude (the active spot swings twice as far).
float glow_pulse() {
	float s = 0.5 + 0.5 * sin(TIME * 6.2831853 * glow_hz + glow_phase);
	return (0.6 + 0.4 * s) * glow_amp;
}

void fragment() {
	vec4 p = texture(palette, UV) * albedo_color;
	vec3 base = mnd_desaturate(p.rgb, spent * 0.35) * mix(1.0, 0.88, spent);
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_view = normalize(NORMAL);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n_view, 0.0)).xyz);
	vec3 v_view = normalize(VIEW);
	vec3 key_w = mnd_key_front(INV_VIEW_MATRIX[2].xyz, key_front);
	vec3 key_view = normalize((VIEW_MATRIX * vec4(key_w, 0.0)).xyz);
	vec3 col;
	if (p.a < 0.5) {
		col = mnd_stage(base, max(stage_light, 0.5), desat * 0.5);
	} else {
		float lit;
		col = mnd_vinyl(base, n_world, mnd_band_soft, wpos, key_w, lit);
		col += vec3(mnd_sheen_term(n_view, v_view, key_view, lit));
		col = mnd_stage(col, stage_light, desat);
	}
	if (glow_amp > 0.0) {
		float g = glow_pulse();
		float fr = 1.0 - clamp(dot(n_view, v_view), 0.0, 1.0);
		float rimg = smoothstep(0.30, 0.95, fr) * (0.55 + 0.9 * halo_fresnel);
		col = mix(col, glow_color.rgb, clamp(rimg * g, 0.0, 0.85));
		col += glow_color.rgb * 0.10 * g;
	}
	ALBEDO = col;
}
