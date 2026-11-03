shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Luminous arcane river: scrolling flow noise, bright current streaks,
// shoreline foam from scene depth, travelling vertex waves and expanding
// ripple rings where the player wades. `corruption` blends toward a second
// palette (used when the river reacts to the player / the Warden).

uniform vec3 deep_color : source_color = vec3(0.0, 0.12, 0.22);
uniform vec3 glow_color : source_color = vec3(0.15, 0.85, 1.0);
uniform vec3 foam_color : source_color = vec3(0.75, 1.0, 1.0);
uniform vec3 alt_glow : source_color = vec3(0.35, 1.0, 0.55);
uniform float corruption = 0.0;
uniform vec2 flow_dir = vec2(1.0, 0.0);
uniform float flow_speed = 0.6;
uniform float glow_strength = 2.2;
uniform float wave_height = 0.06;
uniform float shore_fade = 0.9;
uniform vec3 ripple_pos = vec3(0.0, -999.0, 0.0);
uniform float ripple_strength = 0.0;
uniform float pulse = 0.0;          // brief flash on splash
uniform bool use_depth = true;     // off on the web renderer
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x),
	           mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + 9.3; a *= 0.5; }
	return s;
}
vec2 rot_flow(vec2 p) {
	vec2 d = normalize(flow_dir);
	return vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
}

float ripple(vec3 p) {
	float d = length(p.xz - ripple_pos.xz);
	return sin(d * 9.0 - TIME * 7.0) * exp(-d * 0.9) * ripple_strength;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 f = rot_flow(wpos.xz);
	float w = sin(f.x * 1.3 - TIME * 2.1) * 0.5 + sin(f.x * 0.7 + f.y * 1.1 - TIME * 1.3) * 0.5;
	w += (vnoise(f * 0.8 - vec2(TIME * flow_speed, 0.0)) - 0.5) * 1.2;
	VERTEX.y += w * wave_height + ripple(wpos) * 0.05;
}

void fragment() {
	vec2 f = rot_flow(wpos.xz);
	float t = TIME * flow_speed;
	// two flow layers sliding at different speeds give a convincing current
	float n1 = fbm(vec2(f.x * 0.35 - t, f.y * 0.9));
	float n2 = fbm(vec2(f.x * 0.8 - t * 1.7, f.y * 1.6) + n1 * 1.5);
	float streak = smoothstep(0.55, 0.85, fbm(vec2(f.x * 0.25 - t * 1.3, f.y * 3.5)));
	float sparkle = pow(vnoise(vec2(f.x * 6.0 - t * 4.0, f.y * 6.0)), 12.0) * 3.0;

	// shoreline / object intersection foam from scene depth
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float scene_z = -view.z / view.w;
	float water_z = -VERTEX.z;
	float thickness = use_depth ? clamp((scene_z - water_z) / shore_fade, 0.0, 1.0) : 0.75;
	float foam = (1.0 - smoothstep(0.0, 0.35, thickness)) * (0.6 + n2 * 0.8);

	float r = ripple(wpos);
	vec3 glow = mix(glow_color, alt_glow, corruption);
	float energy = n2 * 0.9 + streak * 0.9 + sparkle + abs(r) * 1.5 + pulse;
	vec3 col = mix(deep_color, glow * 0.5, n1 * 0.6);

	ALBEDO = col;
	EMISSION = glow * energy * glow_strength * (0.35 + thickness * 0.65) + foam_color * foam * 1.4;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(0.55 + thickness * 0.35 + fres * 0.2 + foam * 0.4, 0.0, 0.97);
}
