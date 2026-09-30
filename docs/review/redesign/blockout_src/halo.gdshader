shader_type spatial;
render_mode unshaded, cull_front;
// Verb halo for interactive props (spec §2.4): a soft coloured shell outside the ink outline, pulsing 0.6<->1.0.
uniform vec4 col : source_color = vec4(1.0, 0.78, 0.2, 0.6);
uniform float width_1080 = 8.0;
uniform float pos_dir = 0.0;
void vertex() {
	vec3 dir = mix(NORMAL, normalize(VERTEX), pos_dir);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz);
	vec2 off = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(off);
	if (len > 0.0001) { off /= len; }
	float px = width_1080 * VIEWPORT_SIZE.y / 1080.0;
	clip.xy += off * px * 2.0 / VIEWPORT_SIZE * clip.w;
	clip.z -= 0.0002 * clip.w; // reverse-z: push the shell behind the ink outline
	POSITION = clip;
}
void fragment() { ALBEDO = mix(vec3(0.95, 0.92, 0.85), col.rgb, col.a); }
