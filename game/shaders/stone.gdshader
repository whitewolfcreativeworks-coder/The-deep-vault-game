shader_type spatial;
// Procedural world-space masonry for axis-aligned dungeon geometry.
// mode 0 = ashlar wall blocks, 1 = floor flagstones, 2 = rough natural rock.
// Picks the dominant world axis (geometry is box-built) and builds a
// height field from mortar lines + fbm noise, then perturbs the normal from
// its finite-difference gradient. No textures required.

uniform vec3 base_color : source_color = vec3(0.34, 0.31, 0.28);
uniform vec3 mortar_color : source_color = vec3(0.13, 0.12, 0.11);
uniform vec3 moss_color : source_color = vec3(0.16, 0.22, 0.12);
uniform float block_w = 1.3;
uniform float block_h = 0.55;
uniform int mode = 0;
uniform float bump = 1.0;
uniform float moss = 0.25;
uniform float tint_var = 0.18;
uniform float floor_y = 0.0;      // moss gathers near this height on walls
uniform float wet = 0.0;         // darkens and smooths (near the river)
uniform vec3 glow_color : source_color = vec3(0.2, 0.8, 1.0);
uniform vec3 glow_origin = vec3(0.0, -100.0, 0.0);  // reflected river light
uniform float glow_radius = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

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
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; }
	return s;
}

// Returns height in x, per-block random in y, mortar mask in z.
vec3 masonry(vec2 uv) {
	if (mode == 2) {
		float n = fbm(uv * 0.9) * 0.8 + fbm(uv * 3.1) * 0.35;
		float cracks = smoothstep(0.03, 0.0, abs(fbm(uv * 1.7 + 4.0) - 0.5));
		return vec3(n - cracks * 0.5, hash12(floor(uv * 0.5)), cracks);
	}
	vec2 bs = mode == 1 ? vec2(1.25, 1.25) : vec2(block_w, block_h);
	vec2 g = uv / bs;
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5 + (mode == 1 ? hash12(vec2(row, 3.0)) * 0.3 : 0.0);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	vec2 edge = min(f, 1.0 - f) * bs;               // distance to joint in metres
	float d = min(edge.x, edge.y);
	float jitter = (fbm(uv * 6.0) - 0.5) * 0.025;
	float m = smoothstep(0.035 + jitter, 0.012 + jitter, d); // 1 in mortar
	float bevel = smoothstep(0.0, 0.09, d);
	float rnd = hash12(cell);
	float surf = fbm(uv * 2.2 + rnd * 9.0) * 0.35 + fbm(uv * 9.0) * 0.12;
	float h = bevel * 0.9 + surf - m * 0.6 + rnd * 0.05;
	return vec3(h, rnd, m);
}

vec2 plane_uv(vec3 p, vec3 n, out int axis) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) { axis = 1; return p.xz; }
	if (a.x >= a.z) { axis = 0; return vec2(p.z, p.y); }
	axis = 2; return vec2(p.x, p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	int axis;
	vec2 uv = plane_uv(wpos, wnorm, axis);
	vec3 m0 = masonry(uv);
	float e = 0.02;
	float hx = masonry(uv + vec2(e, 0.0)).x;
	float hy = masonry(uv + vec2(0.0, e)).x;
	vec2 grad = vec2(hx - m0.x, hy - m0.x) / e * 0.045 * bump;

	vec3 n = wnorm;
	float s = 1.0;
	if (axis == 1) { s = sign(n.y); n = normalize(n - vec3(grad.x, 0.0, grad.y) * s); }
	else if (axis == 0) { s = sign(n.x); n = normalize(n - vec3(0.0, grad.y, grad.x) * s); }
	else { s = sign(n.z); n = normalize(n - vec3(grad.x, grad.y, 0.0) * s); }
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float tint = 1.0 + (m0.y - 0.5) * tint_var * 2.0;
	vec3 col = base_color * tint * (0.78 + 0.35 * fbm(uv * 1.3));
	col = mix(col, mortar_color, m0.z);
	// moss creeps into joints and low on walls
	float mossy = moss * smoothstep(0.55, 0.75, fbm(uv * 0.7 + 11.0));
	mossy *= (axis == 1 ? 0.6 : smoothstep(2.2, 0.0, wpos.y - floor_y));
	col = mix(col, moss_color, clamp(mossy + m0.z * moss * 0.8, 0.0, 1.0));
	col *= 1.0 - wet * 0.35;

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.45, wet) - m0.x * 0.1;
	SPECULAR = 0.3 + wet * 0.3;
	// faint caustic shimmer on stone near the glowing river
	if (glow_radius > 0.0) {
		float dist = length(wpos - glow_origin);
		float fall = smoothstep(glow_radius, 0.0, dist);
		float caust = pow(vnoise(uv * 2.5 + TIME * vec2(0.4, 0.25)) * vnoise(uv * 3.1 - TIME * 0.3), 1.6) * 2.0;
		EMISSION = glow_color * fall * (0.05 + caust * 0.35) * (1.0 - m0.z * 0.6);
	}
}
