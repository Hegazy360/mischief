// char_toon — the characters' material (Hush, Bellows): look A's Toy Box vinyl (the owner's pick, R3D index §7.6)
// on the one lighting model (stage_light.gdshaderinc). ONE material per character + the outline next_pass.
//
//  albedo   palette texture (UV; nearest), then:
//  tint     temper tint toward `tint_color` (alpha = amount) on the skin mask
//  stone    the marble freeze: every part toward `stone_color` except the keep mask (eyes, beret, braces)
//  face     2D face cards from one atlas (`face_atlas`, a `face_grid` of cells) composited on the head's planar face
//           UV (UV2: u right, v up from the chin; UV2.x < -0.5 = not face). Layers and their rects (`face_rect[i]`
//           = [u0, v0, u1, v1] in face UV): 0 brows, 1 eyes, 2 pupils, 3 mouth, 4 extra_a, 5 extra_b; lids use the
//           eyes rect. Cells: `face_cell_a` = (brows, eyes, pupils, mouth), `face_cell_b` = (extra_a, extra_b, lids,
//           spare); -1 = off. Pupils slide by `pupil_offset` (-1..1) × `pupil_range` (face-UV units).
//           Order: extra_a, brows, eyes, pupils, lids, mouth, extra_b.
//  masks    vertex colour (R3D index §7.3): R skin-tint mask, G stone-keep mask, B rim damp, A outline scale.
//           `vc_masks = false` (a mesh without vertex colours, e.g. a look-dev stand-in) takes the skin mask from
//           the palette alpha (look A: alpha < 0.8 = skin) and keeps nothing out of the stone.
//  light    look A's lilac terminator + ground bounce + 0.10 vinyl sheen, REDESIGN's key bands, the 66 % floor, the
//           cool rim (0.35–0.55), then `stage_light` (the room's level; Bellows' never below 0.9) and `desat`.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled, shadows_disabled;

#include "res://art3d/shaders/stage_light.gdshaderinc"

uniform sampler2D palette : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D face_atlas : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform ivec2 face_grid = ivec2(8, 8);
uniform ivec4 face_cell_a = ivec4(-1, -1, -1, -1);
uniform ivec4 face_cell_b = ivec4(-1, -1, -1, -1);
uniform vec4 face_rect[6];
uniform vec2 pupil_offset = vec2(0.0);
uniform vec2 pupil_range = vec2(0.05, 0.03);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float stone : hint_range(0.0, 1.0) = 0.0;
uniform vec4 stone_color : source_color = vec4(0.910, 0.902, 0.882, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float rim : hint_range(0.0, 1.0) = 0.45;
uniform float rim_damp = 0.6;
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;
uniform float key_front : hint_range(0.0, 1.0) = 0.35;
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform bool vc_masks = true;

vec4 face_layer(vec4 r, int idx, vec2 fuv) {
	if (idx < 0) {
		return vec4(0.0);
	}
	vec2 size = r.zw - r.xy;
	if (size.x <= 1e-5 || size.y <= 1e-5) {
		return vec4(0.0);
	}
	vec2 l = (fuv - r.xy) / size;
	if (l.x < 0.0 || l.x > 1.0 || l.y < 0.0 || l.y > 1.0) {
		return vec4(0.0);
	}
	int gx = max(face_grid.x, 1);
	int gy = max(face_grid.y, 1);
	int col = idx % gx;
	int row = idx / gx;
	vec2 auv = vec2((float(col) + l.x) / float(gx), (float(row) + 1.0 - l.y) / float(gy));
	return texture(face_atlas, auv);
}

vec3 over(vec3 base, vec4 layer, float stone_k) {
	vec3 c = mix(layer.rgb, stone_color.rgb * mix(0.55, 1.0, mnd_luma(layer.rgb)), stone_k);
	return mix(base, c, layer.a);
}

void fragment() {
	vec4 p = texture(palette, UV) * albedo_color;
	vec3 base = p.rgb;
	float skin = vc_masks ? COLOR.r : (p.a < 0.8 ? 1.0 : 0.0);
	float keep = vc_masks ? COLOR.g : 0.0;
	float damp = vc_masks ? COLOR.b : 0.0;
	base = mix(base, tint_color.rgb, clamp(tint_color.a * skin, 0.0, 1.0));
	float st = clamp(stone * (1.0 - keep), 0.0, 1.0);
	base = mix(base, stone_color.rgb * mix(0.82, 1.0, mnd_luma(base)), st);
	if (UV2.x > -0.5) {
		vec2 fuv = vec2(UV2.x, 1.0 - UV2.y);
		base = over(base, face_layer(face_rect[4], face_cell_b.x, fuv), st);
		base = over(base, face_layer(face_rect[0], face_cell_a.x, fuv), st);
		base = over(base, face_layer(face_rect[1], face_cell_a.y, fuv), 0.0);
		vec4 pr = face_rect[2];
		vec2 po = clamp(pupil_offset, vec2(-1.0), vec2(1.0)) * pupil_range;
		base = over(base, face_layer(vec4(pr.xy + po, pr.zw + po), face_cell_a.z, fuv), 0.0);
		base = over(base, face_layer(face_rect[1], face_cell_b.z, fuv), 0.0);
		base = over(base, face_layer(face_rect[3], face_cell_a.w, fuv), st);
		base = over(base, face_layer(face_rect[5], face_cell_b.y, fuv), st);
	}
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_view = normalize(NORMAL);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n_view, 0.0)).xyz);
	vec3 v_view = normalize(VIEW);
	vec3 key_w = mnd_key_front(INV_VIEW_MATRIX[2].xyz, key_front);
	vec3 key_view = normalize((VIEW_MATRIX * vec4(key_w, 0.0)).xyz);
	float lit;
	vec3 col = mnd_vinyl(base, n_world, mnd_band_soft, wpos, key_w, lit);
	col += mnd_rim(n_view, v_view, rim * (1.0 - rim_damp * damp), lit, base);
	col += vec3(mnd_sheen_term(n_view, v_view, key_view, lit));
	col = mnd_stage(col, stage_light, desat);
	col += flash_color.rgb * flash;
	ALBEDO = col;
}
