shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 ink : source_color = vec4(0.106, 0.137, 0.251, 1.0);
uniform float width_1080 = 3.5; // outline width in px at a 1080 px tall screen
uniform float pos_dir = 0.0;    // 1 = push along the vertex position (boxes), 0 = along the normal
uniform float stage = 1.0;
void vertex() {
	vec3 dir = mix(NORMAL, normalize(VERTEX), pos_dir);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz);
	vec2 off = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(off);
	if (len > 0.0001) { off /= len; }
	float px = width_1080 * VIEWPORT_SIZE.y / 1080.0;
	clip.xy += off * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}
void fragment() { ALBEDO = ink.rgb * mix(1.0, stage, 0.5); }
