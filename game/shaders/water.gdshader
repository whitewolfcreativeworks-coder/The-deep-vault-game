shader_type spatial;
render_mode cull_disabled;
// Forest stream: clear green-blue water flowing along UV.y, with moving glints.
uniform vec3 shallow : source_color = vec3(0.35, 0.62, 0.58);
uniform vec3 deep : source_color = vec3(0.12, 0.36, 0.42);
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float flow = 0.35;
void fragment() {
	vec2 uv = UV;
	float a = texture(noise, vec2(uv.x * 0.6, uv.y * 0.08 - TIME * flow * 0.08)).r;
	float b = texture(noise, vec2(uv.x * 1.3 + 0.37, uv.y * 0.2 - TIME * flow * 0.2)).r;
	float edge = smoothstep(0.0, 0.35, uv.x) * smoothstep(1.0, 0.65, uv.x);
	vec3 col = mix(shallow, deep, edge * 0.8);
	float glint = smoothstep(0.62, 0.8, a * b * 1.9);
	col += vec3(0.55, 0.7, 0.7) * glint * 0.35;
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	ALPHA = 0.88;
}
