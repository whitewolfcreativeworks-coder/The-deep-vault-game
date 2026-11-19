shader_type canvas_item;
// "Rainbow vision" after eating glowing mushrooms: the screen shimmers, swims and
// turns rainbow. `amount` is how many mushrooms' worth (0..5): one is a gentle
// colour shimmer; five is swirling, doubled, rainbow-banded chaos.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float t = 0.0;

vec3 hue_rotate(vec3 c, float a) {
	// rotate around the grey axis
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	float a = clamp(amount / 5.0, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	// the world wobbles like it's under water
	vec2 w = vec2(sin(uv.y * 11.0 + t * 2.1), cos(uv.x * 9.0 + t * 1.6)) * 0.005 * amount;
	// and from three mushrooms on, it slowly swirls round the middle
	vec2 c = uv - 0.5;
	float r = length(c);
	float sw = smoothstep(2.0, 5.0, amount) * 0.9 * sin(t * 0.6) * (0.8 - r);
	c = mat2(vec2(cos(sw), sin(sw)), vec2(-sin(sw), cos(sw))) * c;
	vec2 uv2 = c + 0.5 + w;
	// seeing double: the colours slide apart
	vec2 split = vec2(0.003 + 0.004 * sin(t * 1.3), 0.002 * cos(t)) * amount;
	vec3 col;
	col.r = texture(screen_tex, uv2 + split).r;
	col.g = texture(screen_tex, uv2).g;
	col.b = texture(screen_tex, uv2 - split).b;
	// colours drift round the rainbow
	col = hue_rotate(col, a * (t * 0.8 + uv.y * 3.0 + uv.x * 2.0) * 0.9);
	// big rainbow arcs sweeping over everything
	float d = length((uv - vec2(0.5, 1.35)) * vec2(1.0, 1.25));
	float band = fract(d * 2.6 - t * 0.12);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (band + vec3(0.0, 0.33, 0.67)));
	float arc = smoothstep(0.5, 0.7, d) * smoothstep(1.45, 1.15, d);
	col = mix(col, rainbow, clamp(a * 0.32 * arc + a * a * 0.12, 0.0, 0.6));
	// everything gets extra colourful
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.0 + a * 0.9);
	COLOR = vec4(col, smoothstep(0.0, 0.35, amount));
}
