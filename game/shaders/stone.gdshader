shader_type spatial;
// Procedural world-space masonry for axis-aligned dungeon geometry.
//   mode 0 = ashlar wall blocks, 1 = floor flagstones, 2 = rough natural rock,
//   mode 3 = a carved frieze band (rosettes between raised lips).
// Walls and floors are "chiselled": every block has crisp bevelled edges, deep
// mortar joints and a few flat facets on its face, like a hand-cut stone. The
// facets and bevels are worked out per pixel (no textures), so the look stays
// crisp at any distance. Trim boxes (frieze, base course) are unit boxes scaled
// into place, so their local height runs exactly from bottom to top.

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
uniform float facet = 0.28;       // how strongly the chiselled facets tilt
uniform float bevel_w = 0.075;    // width of the bevel round each block (m)
uniform float mortar_w = 0.028;   // half the width of a joint (m)
uniform bool local_v = false;     // trims: one row of blocks exactly fills the box
uniform float band_h = 0.55;      // frieze: the band's height in metres
uniform float motif_period = 1.1; // frieze: one rosette every this many metres

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;

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

// Rough rock: height in x, random in y, crack mask in z (the old look).
vec3 rock(vec2 uv) {
	float n = fbm(uv * 0.9) * 0.8 + fbm(uv * 3.1) * 0.35;
	float cracks = smoothstep(0.03, 0.0, abs(fbm(uv * 1.7 + 4.0) - 0.5));
	return vec3(n - cracks * 0.5, hash12(floor(uv * 0.5)), cracks);
}

// The carved frieze: x along the wall (m), y up the band (0..1).
float frieze_h(vec2 p) {
	float v = p.y;
	float lip = smoothstep(0.17, 0.13, v) + smoothstep(0.83, 0.87, v);
	float h = mix(0.35, 1.0, clamp(lip, 0.0, 1.0));
	// a fine bead just inside each lip
	h += 0.25 * (smoothstep(0.035, 0.0, abs(v - 0.21)) + smoothstep(0.035, 0.0, abs(v - 0.79)));
	// rosettes, with a little diamond between each pair
	float px = (fract(p.x / motif_period) - 0.5) * motif_period;
	vec2 q = vec2(px, (v - 0.5) * band_h);
	float r = length(q);
	float ang = atan(q.y, q.x);
	float petal = 0.5 + 0.5 * cos(ang * 8.0);
	float ros = smoothstep(0.012, 0.0, r - (0.1 + 0.055 * petal));
	h = max(h, 0.35 + ros * (0.6 - r * 1.6));
	h = max(h, smoothstep(0.035, 0.025, r) * 1.05);             // the centre boss
	h = max(h, smoothstep(0.012, 0.0, abs(r - 0.19) - 0.012) * 0.8);   // a ring round it
	float dx = abs(abs(px) - motif_period * 0.5);
	float dia = dx + abs(q.y) * 1.2;
	h = max(h, smoothstep(0.012, 0.0, dia - 0.075) * (0.85 - dia * 2.0));
	return h;
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
	lpos = VERTEX;
}

void fragment() {
	int axis;
	vec2 uv = plane_uv(wpos, wnorm, axis);
	vec3 tan_u = axis == 0 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tan_v = axis == 1 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 n = wnorm;
	vec3 col;
	float rough = 0.9;
	float mortar = 0.0;
	float height01 = 0.5;

	if (mode == 2) {
		// --- natural rock: fbm height field, finite differences
		vec3 m0 = rock(uv);
		float e = 0.02;
		vec2 grad = vec2(rock(uv + vec2(e, 0.0)).x - m0.x, rock(uv + vec2(0.0, e)).x - m0.x) / e * 0.045 * bump;
		n = normalize(n - tan_u * grad.x - tan_v * grad.y);
		col = base_color * (1.0 + (m0.y - 0.5) * tint_var * 2.0) * (0.78 + 0.35 * fbm(uv * 1.3));
		col = mix(col, mortar_color, m0.z);
		mortar = m0.z;
		height01 = m0.x;
	} else if (mode == 3) {
		// --- the carved frieze (plain top, bottom and ends)
		float v = lpos.y + 0.5;
		if (axis == 1 || abs(dot(wnorm, vec3(0.0, 1.0, 0.0))) > 0.5) {
			col = base_color * 1.08;
		} else {
			vec2 p = vec2(uv.x, v);
			float h0 = frieze_h(p);
			float e = 0.006;
			float hx = frieze_h(p + vec2(e, 0.0));
			float hy = frieze_h(p + vec2(0.0, e / band_h));
			vec2 grad = vec2(hx - h0, hy - h0) / e * 0.05 * bump;
			n = normalize(n - tan_u * grad.x - tan_v * grad.y);
			col = base_color * (1.12 + (vnoise(uv * 5.0) - 0.5) * 0.08) * (0.4 + 0.6 * h0);
			height01 = h0;
		}
		rough = 0.85;
	} else {
		// --- chiselled blocks (walls) and flagstones (floors)
		vec2 bs = mode == 1 ? vec2(1.25, 1.25) : vec2(block_w, block_h);
		vec2 c = uv;
		if (local_v && axis != 1) {
			c.y = (lpos.y + 0.5) * block_h;           // one row exactly fills a trim
		}
		vec2 g = c / bs;
		float row = floor(g.y);
		g.x += mod(row, 2.0) * 0.5 + (mode == 1 ? hash12(vec2(row, 3.0)) * 0.3 : 0.0);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		vec2 dm = f * bs;
		vec2 dp = (1.0 - f) * bs;
		float dx = min(dm.x, dp.x);
		float dy = min(dm.y, dp.y);
		// a slightly wobbly joint, so it reads as cut stone and not a grid
		float wob = (vnoise(c * 7.0) - 0.5) * 0.012;
		float d = min(dx, dy) + wob;
		vec2 edir = dx < dy ? vec2(dm.x < dp.x ? -1.0 : 1.0, 0.0) : vec2(0.0, dm.y < dp.y ? -1.0 : 1.0);
		float rnd = hash12(cell);
		mortar = 1.0 - smoothstep(mortar_w - 0.005, mortar_w + 0.005, d);
		float bev = (1.0 - smoothstep(mortar_w + bevel_w - 0.004, mortar_w + bevel_w + 0.004, d)) * (1.0 - mortar);
		// the face: the lowest of a few planes, so it breaks into flat facets
		vec2 fc = f - 0.5;
		float best = 0.18 + rnd * 0.04;
		vec2 tilt = vec2(hash12(cell + 5.1) - 0.5, hash12(cell + 9.7) - 0.5) * 0.25;
		float fid = 0.0;
		for (int k = 0; k < 4; k++) {
			float a = (float(k) + hash12(cell + float(k) * 3.3)) * 1.5708;
			vec2 t = vec2(cos(a), sin(a));
			float off = 0.33 + hash12(cell + float(k) * 7.7) * 0.12;
			float pk = off - dot(t, fc * vec2(bs.x / bs.y, 1.0)) * 0.9;
			if (pk < best) { best = pk; tilt = t; fid = float(k) + 1.0; }
		}
		vec2 slope = fid > 0.0 ? tilt * facet : tilt * facet * 0.5;
		slope = mix(slope, edir * 0.85, bev);
		slope *= (1.0 - mortar) * bump * (mode == 1 ? 0.6 : 1.0);
		n = normalize(n + tan_u * slope.x + tan_v * slope.y);
		// colour: each block its own shade, each facet a touch different, worn bright edges
		float tint = 1.0 + (rnd - 0.5) * tint_var * 2.0;
		col = base_color * tint;
		col *= 1.0 + (hash12(cell + fid * 13.1) - 0.5) * 0.09;
		col *= 0.9 + 0.2 * vnoise(c * 3.0 + rnd * 11.0);
		col = mix(col, col * 1.22 + vec3(0.015), bev * 0.6);
		col = mix(col, mortar_color, mortar);
		height01 = 1.0 - mortar;
		rough = 0.88 - bev * 0.12;
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// moss creeps into joints and low on walls
	float mossy = moss * smoothstep(0.55, 0.75, fbm(uv * 0.7 + 11.0));
	mossy *= (axis == 1 ? 0.6 : smoothstep(2.2, 0.0, wpos.y - floor_y));
	col = mix(col, moss_color, clamp(mossy + mortar * moss * 0.8, 0.0, 1.0));
	col *= 1.0 - wet * 0.35;

	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.45, wet) - height01 * 0.05;
	SPECULAR = 0.3 + wet * 0.3;
	// faint caustic shimmer on stone near the glowing river
	if (glow_radius > 0.0) {
		float dist = length(wpos - glow_origin);
		float fall = smoothstep(glow_radius, 0.0, dist);
		float caust = pow(vnoise(uv * 2.5 + TIME * vec2(0.4, 0.25)) * vnoise(uv * 3.1 - TIME * 0.3), 1.6) * 2.0;
		EMISSION = glow_color * fall * (0.05 + caust * 0.35) * (1.0 - mortar * 0.6);
	}
}
