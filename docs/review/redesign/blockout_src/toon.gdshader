shader_type spatial;
render_mode unshaded, cull_back;
// Fake-light toon: one key (world dir), flat ambient fill, 2 soft bands, optional rim + stage dimmer.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 key_dir = vec3(0.45, -0.75, -0.48); // direction the light travels: it comes from the upper left front
uniform vec3 key_col = vec3(1.0, 0.96, 0.88);
uniform vec3 fill_col = vec3(0.66, 0.64, 0.68);
uniform float band_soft = 0.08;
uniform float rim = 0.0;
uniform vec3 rim_col = vec3(0.75, 0.88, 1.0);
uniform float stage = 1.0;   // room light 0..1
uniform float desat = 0.0;   // room desaturation 0..1
uniform float glow = 0.0;    // additive pulse for live props
uniform vec3 glow_col = vec3(1.0, 0.8, 0.3);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 l = normalize((VIEW_MATRIX * vec4(-key_dir, 0.0)).xyz);
	float ndl = dot(NORMAL, l);
	float band = smoothstep(-band_soft, band_soft, ndl);
	float band2 = smoothstep(0.55 - band_soft, 0.55 + band_soft, ndl);
	vec3 light = fill_col + key_col * (0.28 * band + 0.08 * band2);
	vec3 c = albedo.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desat);
	vec3 outc = c * light * stage;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	outc += rim_col * fres * rim * stage;
	outc += glow_col * glow * smoothstep(0.35, 1.0, fres) * 2.2;
	ALBEDO = outc;
}
