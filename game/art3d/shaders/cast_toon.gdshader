shader_type spatial;
render_mode unshaded, cull_back, diffuse_lambert, specular_disabled;

// Cast toon shader (REDESIGN_3D §5.4, §5.6). Unshaded on purpose: the Compatibility renderer gets
// no real-time lights or shadows on a mid-range phone, so the key, fill and rim are computed here
// from a fixed world direction. One material per character, one draw call for the body.
//
// Colour comes from a 128x128 palette sampled through UV0 (every face was painted with a palette
// index at build time), never from a per-character texture. The palette's ALPHA is a flag channel:
//   1.0  = plain paint          -> never tinted
//   0.6  = skin                 -> takes the temper tint
//   0.3  = nose                 -> takes the temper tint twice as hard (GDD §1.2)
//
// The face is a 2D card composited on top (REDESIGN_3D §5.6 "2D face cards on 3D heads"): four
// layers — brows, eyes, mouth, extra — each one cell of a face atlas addressed by a uniform index,
// sampled through the planar FaceUV map (TEXCOORD_1) that only the head's front faces carry. That
// keeps the whole 2D expression vocabulary (and its named presets) without a single blend shape.

uniform sampler2D palette : filter_nearest, source_color;
uniform sampler2D face_atlas : filter_linear, source_color, hint_default_transparent;

// Per-layer atlas window: xy = cell origin (uv), zw = cell size (uv). Set from the atlas json.
uniform vec4 brows_cell = vec4(0.0);
uniform vec4 eyes_cell = vec4(0.0);
uniform vec4 mouth_cell = vec4(0.0);
uniform vec4 extra_cell = vec4(0.0);
// Where each layer's band sits inside the FaceUV square: x = v0, y = v1.
uniform vec2 brows_band = vec2(0.52, 0.67);
uniform vec2 eyes_band = vec2(0.33, 0.56);
uniform vec2 mouth_band = vec2(0.16, 0.32);
uniform vec2 extra_band = vec2(0.28, 0.60);
uniform float face_on = 1.0;
// Pupil offset in FaceUV units, so a look-at nudges the eyes without a new cell.
uniform vec2 pupil = vec2(0.0);

// Lighting.
uniform vec3 key_dir = vec3(0.45, -0.75, -0.48);
uniform vec3 key_col : source_color = vec3(1.0, 0.96, 0.88);
uniform vec3 fill_col : source_color = vec3(0.66, 0.64, 0.68);
uniform float band_soft = 0.08;
uniform float rim : hint_range(0.0, 2.0) = 0.55;
uniform vec3 rim_col : source_color = vec3(0.75, 0.88, 1.0);
uniform float stage : hint_range(0.0, 1.0) = 1.0;

// Temper: peach -> beetroot on skin-flagged paint only (GDD §1.2).
uniform float temper : hint_range(0.0, 1.0) = 0.0;
uniform vec3 temper_col : source_color = vec3(0.78, 0.16, 0.22);
// Residue tint (flour, jelly...) applied to everything, strength in w.
uniform vec4 residue : source_color = vec4(1.0, 1.0, 1.0, 0.0);

varying vec2 face_uv;

void vertex() {
	face_uv = UV2;
}

// One face layer over `base`, returning the composited colour.
vec3 layer(vec3 base, vec4 cell, vec2 band, vec2 fuv, vec2 off) {
	if (cell.z <= 0.0) {
		return base;
	}
	// Map the band of the face square onto the 0..1 height of the cell.
	float v = (fuv.y - band.x) / max(band.y - band.x, 1e-5);
	vec2 local = vec2(fuv.x, v) + off;
	if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0) {
		return base;
	}
	// The atlas is stored with v down; the face square is v up.
	vec2 uv = cell.xy + vec2(local.x, 1.0 - local.y) * cell.zw;
	vec4 c = texture(face_atlas, uv);
	return mix(base, c.rgb, c.a);
}

void fragment() {
	vec4 p = texture(palette, UV);
	vec3 c = p.rgb;

	// Alpha flags: skin takes the temper tint, the nose takes it twice as hard.
	float skin = step(0.45, p.a) * step(p.a, 0.8);   // ~0.6
	float nose = step(p.a, 0.45);                     // ~0.3
	c = mix(c, temper_col, clamp(temper, 0.0, 1.0) * (skin * 0.85 + nose * 1.0));

	// Face cards, over the paint, before the light.
	if (face_on > 0.5 && face_uv.x > 0.0 && face_uv.x < 1.0 && face_uv.y > 0.0 && face_uv.y < 1.0) {
		c = layer(c, extra_cell, extra_band, face_uv, vec2(0.0));
		c = layer(c, brows_cell, brows_band, face_uv, vec2(0.0));
		c = layer(c, eyes_cell, eyes_band, face_uv, pupil);
		c = layer(c, mouth_cell, mouth_band, face_uv, vec2(0.0));
	}

	c = mix(c, residue.rgb, clamp(residue.a, 0.0, 1.0));

	// Two soft toon bands from a fixed key direction.
	vec3 l = normalize((VIEW_MATRIX * vec4(-key_dir, 0.0)).xyz);
	float ndl = dot(NORMAL, l);
	float b1 = smoothstep(-band_soft, band_soft, ndl);
	float b2 = smoothstep(0.55 - band_soft, 0.55 + band_soft, ndl);
	vec3 light = fill_col + key_col * (0.28 * b1 + 0.08 * b2);

	vec3 outc = c * light * stage;
	// Rim: the characters are the only things in the frame that get one (§5.6).
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	outc += rim_col * fres * rim * stage;
	ALBEDO = outc;
}
