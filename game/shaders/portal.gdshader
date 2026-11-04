shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
// Swirling portal surface: spiral arms turning into the centre.
uniform vec3 color_a : source_color = vec3(0.35, 0.95, 0.75);
uniform vec3 color_b : source_color = vec3(0.45, 0.35, 1.0);
uniform float intensity = 2.2;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float swirl = sin(ang * 3.0 + r * 9.0 - TIME * 3.0) * 0.5 + 0.5;
	float rings = sin(r * 22.0 - TIME * 5.0) * 0.5 + 0.5;
	float body = smoothstep(1.0, 0.75, r);
	vec3 col = mix(color_b, color_a, swirl) * (0.6 + 0.6 * rings * swirl);
	col += vec3(1.0) * smoothstep(0.35, 0.0, r) * 0.8;
	ALBEDO = col * intensity * body;
	ALPHA = body;
}
