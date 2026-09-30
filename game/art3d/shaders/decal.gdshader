// decal — the floor "decals" of the 3D view (REDESIGN §4, §5.3; R3D index §7.6): unshaded alpha quads lying on the
// floor (Godot's Decal node is not available on the Compatibility renderer), depth-tested, never writing depth, drawn
// in order of `render_priority` by kind (View3DConst.DECAL_PRIORITY). The quad's UV spans the shape's box: UV (0,0)–
// (1,1), centre (0.5, 0.5). `shape`:
//  0 TEX     `tex` × `color` (footprints, pins, glyphs)
//  1 DISC    a soft ellipse, edge `softness` (blob shadows 32 %, the spotlight pool, the tapped-spot pop)
//  2 RING    a ring between `inner` and 1.0 (radius units), soft edges (noise, squeak, destination rings, W3 ghost)
//  3 STRIP   a band along UV.x with soft ends and sides; the segment [seg_a, seg_b] (0..1) drawn in `color2`
//            (the stare strip and its darker frozen range)
//  4 DOTS    `dots` round dots along UV.x (the dotted path)
// `progress` (0..1) fades the whole decal (0 = full, 1 = gone) for pools and pops; `stage_light` dims it with its room.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform int shape = 1;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 0.32);
uniform vec4 color2 : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float softness : hint_range(0.0, 1.0) = 0.35;
uniform float inner : hint_range(0.0, 1.0) = 0.8;
uniform float seg_a : hint_range(0.0, 1.0) = 0.0;
uniform float seg_b : hint_range(0.0, 1.0) = 0.0;
uniform float dots = 6.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float stage_light : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec4 c = color;
	float a = 0.0;
	if (shape == 0) {
		vec4 t = texture(tex, UV);
		c = vec4(t.rgb * color.rgb, 1.0);
		a = t.a * color.a;
	} else if (shape == 1) {
		a = color.a * (1.0 - smoothstep(max(0.0, 1.0 - softness), 1.0, r));
	} else if (shape == 2) {
		float e = max(0.02, softness * (1.0 - inner) * 0.5 + 0.02);
		a = color.a * smoothstep(inner - e, inner, r) * (1.0 - smoothstep(1.0 - e, 1.0, r));
	} else if (shape == 3) {
		float ends = smoothstep(0.0, softness * 0.25 + 0.01, UV.x) * (1.0 - smoothstep(1.0 - softness * 0.25 - 0.01, 1.0, UV.x));
		float sides = 1.0 - smoothstep(max(0.0, 1.0 - softness), 1.0, abs(p.y));
		a = color.a * ends * sides;
		if (seg_b > seg_a && UV.x >= seg_a && UV.x <= seg_b) {
			c = color2;
			a = max(a, color2.a * sides);
		}
	} else {
		float cell = fract(UV.x * max(dots, 1.0)) * 2.0 - 1.0;
		a = color.a * (1.0 - smoothstep(0.30, 0.42, length(vec2(cell, p.y))));
	}
	ALBEDO = c.rgb * stage_light;
	ALPHA = clamp(a * (1.0 - progress), 0.0, 1.0);
}
