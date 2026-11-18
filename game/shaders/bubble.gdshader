shader_type spatial;
// A soap bubble: almost clear in the middle, a swirl of rainbow colours round the
// edge (thin-film colours), and a bright highlight.
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx, unshaded;

uniform float edge_alpha = 0.8;
uniform float centre_alpha = 0.08;
uniform float swirl = 1.0;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(f, 1.6);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float h = rim * 1.3 + wn.y * 0.35 + sin(TIME * 0.8 * swirl + wn.x * 3.0) * 0.15;
	vec3 film = mix(vec3(1.0), hue(fract(h)), 0.75);
	float spec = pow(clamp(dot(reflect(-VIEW, NORMAL), normalize(vec3(0.3, 0.8, 0.5))), 0.0, 1.0), 40.0);
	ALBEDO = film + vec3(spec * 2.0);
	ALPHA = clamp(mix(centre_alpha, edge_alpha, rim) + spec, 0.0, 1.0);
}
