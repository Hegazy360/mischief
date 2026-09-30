// stage_light.gdshaderinc — the ONE lighting model of the 3D view (REDESIGN §5.3, R3D index §7.6, ruling R8).
// Every 3D material is `unshaded` and lights itself here from the `mnd_*` globals (registered in project.godot
// [shader_globals]; StageLighting3D sets them at runtime). No Light3D, no shadows, no PBR, no normal maps: the
// Compatibility, Mobile and Forward+ renderers look identical and cost the same.
//
//  * one warm key from the upper left front (`mnd_key_dir` points TOWARD the key): +28 % on the lit band, +8 % on a
//    top band, two soft bands (`mnd_band_soft`);
//  * the shadow band is the neutral `mnd_fill_color` for the set (set_toon), look A's lilac `mnd_shadow_tint` for vinyl
//    (char_toon, prop_toon — the owner's pick), plus A's ground bounce and matte sheen for vinyl;
//  * THE FLOOR: no surface below `mnd_fill` (66 %) of its albedo's luminance, applied last (after tint and bounce),
//    so nothing crushes at 30–50 % phone brightness; room dimming (`stage`) and desaturation apply after the floor;
//  * the footlight: an additive warm gradient from the stage lip, `mnd_foot_strength` at the floor fading to 0 by
//    `mnd_foot_fade_m` up (per floor, 3.5 m pitch), stronger toward the lip.

global uniform vec3 mnd_key_dir;
global uniform vec4 mnd_key_color;
global uniform float mnd_key_lit;
global uniform float mnd_key_top;
global uniform float mnd_fill;
global uniform vec4 mnd_fill_color;
global uniform float mnd_band_soft;
global uniform vec4 mnd_rim_color;
global uniform float mnd_rim_power;
global uniform float mnd_foot_strength;
global uniform float mnd_foot_fade_m;
global uniform float mnd_lip_z;
global uniform float mnd_outline_scale;
global uniform vec4 mnd_shadow_tint;
global uniform float mnd_bounce;
global uniform float mnd_sheen;

const float MND_FLOOR_PITCH = 3.5;
const float MND_BACK_WALL_Z = -2.4;
const float MND_TOP_BAND = 0.55;

float mnd_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 mnd_desaturate(vec3 c, float amount) {
	return mix(c, vec3(mnd_luma(c)), clamp(amount, 0.0, 1.0));
}

// The key's world direction (normalised; the global is already a unit vector toward the key).
vec3 mnd_key() {
	return normalize(mnd_key_dir);
}

// The vinyl key: the stage key bent `front` toward the camera (`cam_back` = the camera's +Z in world space). Look A
// lit its characters from a more frontal key (−0.38, 0.62, 0.69); `front` 0.35 on REDESIGN's (−0.45, 0.75, 0.48)
// lands on it, so faces stay in the lit band (the faces are the comedy). The set keeps the pure stage key.
vec3 mnd_key_front(vec3 cam_back, float front) {
	vec3 b = vec3(cam_back.x, 0.0, cam_back.z);
	float bl = length(b);
	b = bl > 1e-4 ? b / bl : vec3(0.0, 0.0, 1.0);
	return normalize(normalize(mnd_key_dir) + b * front);
}

// The footlight term (added to the shade): strongest at the floor next to the lip.
float mnd_footlight(vec3 wpos) {
	float h = mod(wpos.y + 0.001, MND_FLOOR_PITCH);
	float up = 1.0 - smoothstep(0.0, max(mnd_foot_fade_m, 0.01), h);
	float front = mix(0.5, 1.0, smoothstep(MND_BACK_WALL_Z, mnd_lip_z, wpos.z));
	return mnd_foot_strength * up * front;
}

// Clamp a shade so the lit colour keeps >= mnd_fill of the albedo's luminance (the readability floor).
vec3 mnd_floor(vec3 albedo, vec3 col) {
	float want = mnd_fill * mnd_luma(albedo);
	float have = mnd_luma(col);
	if (have < want && have > 1e-5) {
		col *= want / have;
	} else if (have <= 1e-5) {
		col = albedo * mnd_fill;
	}
	return col;
}

// Neutral set lighting (architecture, furniture, dressing): fill band + key bands + footlight, floored.
// Returns the final colour (stage light and desaturation applied).
vec3 mnd_light(vec3 albedo, vec3 n_world, float band_soft, float stage, float desat, vec3 wpos) {
	float ndl = dot(normalize(n_world), mnd_key());
	float band = smoothstep(-band_soft, band_soft, ndl);
	float band2 = smoothstep(MND_TOP_BAND - band_soft, MND_TOP_BAND + band_soft, ndl);
	vec3 shade = mnd_fill_color.rgb + mnd_key_color.rgb * (mnd_key_lit * band + mnd_key_top * band2);
	shade += mnd_key_color.rgb * mnd_footlight(wpos);
	vec3 col = mnd_floor(albedo, albedo * shade);
	return mnd_desaturate(col, desat) * stage;
}

// Look A's vinyl lighting (characters, live props): A's soft lilac terminator and ground bounce on REDESIGN's key
// bands, floored. `lit_out` returns the lit-band factor (rim and sheen use it). No stage/desat here (the caller adds
// rim and sheen first, then calls mnd_stage()).
vec3 mnd_vinyl(vec3 albedo, vec3 n_world, float band_soft, vec3 wpos, vec3 key, out float lit_out) {
	vec3 n = normalize(n_world);
	float ndl = dot(n, key);
	// A's terminator sits slightly past the equator (-0.05) with its softer 0.16 edge (2 × band_soft).
	float lit = smoothstep(-0.05 - 2.0 * band_soft, -0.05 + 2.0 * band_soft, ndl);
	float band2 = smoothstep(MND_TOP_BAND - band_soft, MND_TOP_BAND + band_soft, ndl);
	vec3 lit_shade = vec3(mnd_fill) + mnd_key_color.rgb * mnd_key_lit;
	vec3 shade = mix(mnd_shadow_tint.rgb, lit_shade, lit) + mnd_key_color.rgb * mnd_key_top * band2;
	shade *= 1.0 - mnd_bounce * smoothstep(0.2, -0.8, n.y);
	shade += mnd_key_color.rgb * mnd_footlight(wpos);
	lit_out = lit;
	return mnd_floor(albedo, albedo * shade);
}

// A's matte vinyl sheen: a smoothstep on N·H, lit band only. n_view / v_view in view space.
float mnd_sheen_term(vec3 n_view, vec3 v_view, vec3 key_view, float lit) {
	vec3 h = normalize(key_view + v_view);
	return smoothstep(0.86, 0.97, dot(n_view, h)) * mnd_sheen * lit;
}

// The character rim (fresnel `mnd_rim_power`, cool `mnd_rim_color`), shaped into A's crisp vinyl band.
vec3 mnd_rim(vec3 n_view, vec3 v_view, float strength, float lit, vec3 albedo) {
	float fr = 1.0 - clamp(dot(n_view, v_view), 0.0, 1.0);
	float f = smoothstep(0.10, 0.42, pow(fr, mnd_rim_power));
	return mnd_rim_color.rgb * f * strength * (0.35 + 0.65 * lit) * mix(vec3(1.0), albedo, 0.35);
}

vec3 mnd_stage(vec3 col, float stage, float desat) {
	return mnd_desaturate(col, desat) * stage;
}
