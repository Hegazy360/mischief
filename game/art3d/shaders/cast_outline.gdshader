shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

// Inverted-hull outline for the cast (REDESIGN_3D §5.4: characters are the only things in the frame
// with a 3.5 px outline, which is what separates them from the set).
//
// The width is specified in SCREEN pixels at a 1080 px tall viewport and converted here, so the
// outline stays 3.5 px whether the camera is in close on a gag or pulled back to the overview —
// a world-space offset would vanish at the overview and swallow the character in a punch-in.
//
// `skin_outline` must stay on for a skinned mesh: the hull has to be expanded along the SKINNED
// normal, after the bone transform, or the outline tears away from a bent elbow.

uniform vec4 ink : source_color = vec4(0.106, 0.137, 0.251, 1.0);
uniform float width_1080 : hint_range(0.0, 12.0) = 3.5;
uniform float stage : hint_range(0.0, 1.0) = 1.0;
// Outlines thin out as the character gets small on screen, so a PiP copy keeps its shape instead of
// turning into a blob of ink.
uniform float min_width_px = 1.25;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 off = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(off);
	if (len > 0.0001) {
		off /= len;
	}
	float px = max(min_width_px, width_1080 * VIEWPORT_SIZE.y / 1080.0);
	clip.xy += off * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb * mix(1.0, stage, 0.5);
}
