shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Drifting ground mist sheet. Soft-intersects the floor using scene depth and
// fades out when the camera is close, so it reads as volume, not a plane.
uniform vec3 color : source_color = vec3(0.55, 0.75, 0.85);
uniform float density = 0.35;
uniform vec2 drift = vec2(0.08, 0.03);
uniform float scale = 0.18;
uniform float glow = 0.0;
uniform bool use_depth = true;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
varying vec3 wpos;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.02 + 5.7; a *= 0.5; } return s; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz * scale;
	float n = fbm(p + TIME * drift + fbm(p * 1.7 - TIME * drift * 1.3) * 0.8);
	float m = smoothstep(0.35, 0.8, n);
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float scene_z = -view.z / view.w;
	float soft = use_depth ? clamp((scene_z + VERTEX.z) / 1.2, 0.0, 1.0) : 1.0;
	float near = smoothstep(0.5, 3.0, -VERTEX.z);
	vec2 e = abs(UV - 0.5) * 2.0;
	float edge = (1.0 - smoothstep(0.6, 1.0, e.x)) * (1.0 - smoothstep(0.6, 1.0, e.y));
	ALBEDO = color * (1.0 + glow * (0.5 + n));
	ALPHA = m * density * soft * near * edge;
}
