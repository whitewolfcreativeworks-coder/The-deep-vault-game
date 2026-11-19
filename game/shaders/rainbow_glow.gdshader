shader_type canvas_item;
render_mode blend_add;
// "Rainbow vision", part 2 of 2: a soft rainbow glow round the edges of the
// view and a few drifting colour blobs, added on top (it only brightens).

uniform float amount = 0.0;
uniform float t = 0.0;

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	float k = clamp(amount / 5.0, 0.0, 1.0);
	float on = smoothstep(0.0, 0.6, amount);
	vec2 c = UV - 0.5;
	float r = length(c * vec2(1.4, 1.0));
	float ang = atan(c.y, c.x);
	// a rainbow halo round the edges, turning slowly, breathing in and out
	float edge = smoothstep(0.38 - 0.06 * sin(t * 1.1), 0.78, r);
	vec3 col = rainbow(ang / 6.2831 + t * 0.08 + r * 0.9) * edge * (0.12 + 0.22 * k);
	// soft blobs of colour floating about
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 p = vec2(0.5 + 0.32 * sin(t * (0.21 + fi * 0.07) + fi * 2.1), 0.5 + 0.28 * cos(t * (0.17 + fi * 0.05) + fi * 1.3));
		float d = length((UV - p) * vec2(1.6, 1.0));
		col += rainbow(fi * 0.33 + t * 0.05) * smoothstep(0.3, 0.0, d) * (0.025 + 0.07 * k);
	}
	COLOR = vec4(col * on, 1.0);
}
