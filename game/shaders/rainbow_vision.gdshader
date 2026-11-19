shader_type canvas_item;
render_mode blend_mul;
// "Rainbow vision" after eating glowing mushrooms, part 1 of 2: slow waves of
// rainbow colour drift across the view, multiplied onto the game, so you still
// see everything, just in shifting colours. `amount` is how many mushrooms'
// worth (0..5). It never reads the screen, so it looks the same on every device.

uniform float amount = 0.0;
uniform float t = 0.0;

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	float k = clamp(amount / 5.0, 0.0, 1.0);
	float on = smoothstep(0.0, 0.6, amount);
	vec2 uv = UV;
	float h = uv.x * 0.55 + uv.y * 0.35 + t * 0.06
		+ 0.12 * sin(uv.y * 7.0 + t * 0.9) + 0.12 * sin(uv.x * 5.0 - t * 0.7);
	vec3 c = rainbow(h);
	// gentle at one mushroom, strong (but never hiding anything) at five
	float s = (0.24 + 0.3 * k) * on;
	COLOR = vec4(mix(vec3(1.0), c, s), 1.0);
}
