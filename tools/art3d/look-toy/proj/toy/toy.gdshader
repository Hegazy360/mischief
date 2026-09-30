// Toy Box character shader (Godot 4.7, Compatibility / GLES3). ONE material per character, one draw.
// Unshaded with its own lighting (no per-light pass: base + outline + shadow caster = 3 passes/character):
//  * soft two-tone terminator with a warm lilac shadow tint (vinyl / soft clay), ground-bounce darkening,
//  * rim light and a soft vinyl sheen,
//  * face decals: UV2 carries a planar face UV on the head's front faces (x < -1 = no face); four layers
//    (brows / eyes / mouth / extra) each sample one cell of the face atlas, alpha-composited over skin,
//  * temper: palette alpha flags skin (0.6) and nose (0.3) -> tinted toward beetroot by `temper`.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D face_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 key_dir = vec3(-0.38, 0.62, 0.69);     // world direction TOWARD the key light
uniform vec3 fill_dir = vec3(0.55, 0.25, 0.80);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float gain = 1.0;
uniform float terminator = -0.05;
uniform float softness = 0.16;
uniform float fill = 0.12;
uniform float bounce = 0.14;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float rim_amount = 0.32;
uniform float sheen = 0.10;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
// face layers: x = band v0, y = band v1 (v up, 0 = chin), z = atlas origin y (uv), w = cell height (uv)
uniform vec4 layer_brows = vec4(0.0);
uniform vec4 layer_eyes = vec4(0.0);
uniform vec4 layer_mouth = vec4(0.0);
uniform vec4 layer_extra = vec4(0.0);
uniform float cell_w = 0.33203125;   // 340 / 1024
uniform int per_row = 3;
uniform ivec4 face_idx = ivec4(0, 0, 0, 0);   // brows, eyes, mouth, extra
uniform float temper = 0.0;
uniform vec4 temper_color : source_color = vec4(0.72, 0.2, 0.29, 1.0);

vec4 layer(vec4 info, int idx, vec2 fuv) {
	float lv = (fuv.y - info.x) / max(info.y - info.x, 1e-4);
	if (lv < 0.0 || lv > 1.0 || fuv.x < 0.0 || fuv.x > 1.0 || info.w <= 0.0) {
		return vec4(0.0);
	}
	int col = idx % per_row;
	int row = idx / per_row;
	vec2 auv = vec2((float(col) + fuv.x) * cell_w, info.z + (float(row) + (1.0 - lv)) * info.w);
	return texture(face_atlas, auv);
}

void fragment() {
	vec4 p = texture(palette, UV);
	vec3 base = p.rgb;
	float skin = p.a < 0.8 ? 1.0 : 0.0;
	float nose = p.a < 0.45 ? 1.0 : 0.0;
	base = mix(base, temper_color.rgb, clamp(temper * skin * (0.72 + 0.28 * nose), 0.0, 1.0));
	if (UV2.x > -1.0) {
		vec2 fuv = vec2(UV2.x, 1.0 - UV2.y);
		vec4 e = layer(layer_extra, face_idx.w, fuv);
		base = mix(base, e.rgb, e.a);
		vec4 b = layer(layer_brows, face_idx.x, fuv);
		base = mix(base, b.rgb, b.a);
		vec4 y = layer(layer_eyes, face_idx.y, fuv);
		base = mix(base, y.rgb, y.a);
		vec4 m = layer(layer_mouth, face_idx.z, fuv);
		base = mix(base, m.rgb, m.a);
	}
	vec3 N = normalize(NORMAL);
	vec3 L = normalize((VIEW_MATRIX * vec4(normalize(key_dir), 0.0)).xyz);
	vec3 F = normalize((VIEW_MATRIX * vec4(normalize(fill_dir), 0.0)).xyz);
	vec3 V = normalize(VIEW);
	float ndl = dot(N, L);
	float lit = smoothstep(terminator - softness, terminator + softness, ndl);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	shade += fill * max(dot(N, F), 0.0) * (1.0 - lit);
	vec3 wn = (INV_VIEW_MATRIX * vec4(N, 0.0)).xyz;
	shade *= 1.0 - bounce * smoothstep(0.2, -0.8, wn.y);
	vec3 col = base * shade * gain;
	float fr = 1.0 - clamp(dot(N, V), 0.0, 1.0);
	float rim = smoothstep(0.55, 0.8, fr) * rim_amount * (0.35 + 0.65 * lit);
	col += rim_color.rgb * rim * mix(vec3(1.0), base, 0.35);
	vec3 Hh = normalize(L + V);
	float sp = smoothstep(0.86, 0.97, dot(N, Hh)) * sheen * lit;
	col += vec3(sp);
	col += flash_color.rgb * flash;
	ALBEDO = col;
}
