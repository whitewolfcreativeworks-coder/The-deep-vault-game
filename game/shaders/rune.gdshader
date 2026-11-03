shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Procedural rune circle for floors (sanctum seal, checkpoints, telegraphs).
// `fill` > 0 draws a solid danger disc growing to the rim (boss slam warning).
uniform vec3 color : source_color = vec3(0.3, 0.8, 1.0);
uniform float intensity = 1.5;
uniform float spin = 0.15;
uniform float fill = 0.0;
uniform float rings = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * spin;
	float ring1 = smoothstep(0.025, 0.0, abs(r - 0.95));
	float ring2 = smoothstep(0.02, 0.0, abs(r - 0.72)) * rings;
	// glyph band between the rings
	float seg = floor(a / 6.2831 * 24.0);
	float g = hash(vec2(seg, 3.0));
	float band = step(0.74, r) * step(r, 0.93);
	float local = fract(a / 6.2831 * 24.0);
	float glyph = band * step(0.25, local) * step(local, 0.75) * step(0.35, g)
		* step(abs(r - 0.835), 0.03 + g * 0.05);
	// inner star
	float star = smoothstep(0.02, 0.0, abs(sin(a * 3.0) * 0.55 - r * 0.3 + 0.0) - 0.0) * step(r, 0.7) * rings * 0.0;
	float spokes = smoothstep(0.015, 0.0, abs(sin(a * 3.0)) * r) * step(r, 0.72) * rings * 0.6;
	float disc = fill > 0.0 ? step(r, fill) * (0.25 + 0.75 * smoothstep(fill - 0.06, fill, r)) : 0.0;
	float v = ring1 + ring2 + glyph + spokes + star + disc;
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = color * v * intensity * pulse * step(r, 1.0);
}
