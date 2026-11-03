shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Glowing cascade: vertically scrolling streaks on a quad, soft edges.
uniform vec3 color : source_color = vec3(0.2, 0.85, 1.0);
uniform float speed = 1.6;
uniform float intensity = 1.6;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f)); }

void fragment() {
	vec2 uv = UV;
	float cols = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float lane = n1(uv.x * (14.0 + fk * 9.0) + fk * 7.0);
		float flow = fract(uv.y * (1.5 + fk * 0.7) - TIME * speed * (1.0 + fk * 0.35) + lane * 3.0);
		cols += smoothstep(0.6, 1.0, lane) * (0.4 + 0.6 * smoothstep(0.0, 0.9, flow));
	}
	float edge = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
	float fade = smoothstep(0.0, 0.08, uv.y) * smoothstep(1.0, 0.85, uv.y);
	vec3 c = color * (0.35 + cols) * intensity * edge * fade;
	ALBEDO = c;
}
