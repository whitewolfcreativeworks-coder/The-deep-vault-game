shader_type spatial;
// Puffy cloud surface: soft wrap-around light, a bright rim where the sun
// shines through the edges, and a slow wobble so the puffs feel alive.
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade : source_color = vec3(0.72, 0.78, 0.92);
uniform float rim_power = 2.5;
uniform float rim_glow = 0.45;
uniform float wobble = 0.06;
uniform float glow = 0.0;          // storm clouds flicker with lightning

varying float v_up;
varying vec3 v_col;

void vertex() {
	float t = TIME * 0.6;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * wobble * sin(t + w.x * 0.7 + w.z * 0.5) * cos(t * 0.8 + w.y * 0.9);
	v_up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
	v_col = COLOR.rgb;
}

void fragment() {
	float up = clamp(v_up * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(shade, tint, smoothstep(0.1, 0.9, up)) * v_col;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = tint * (rim * rim_glow + glow);
	ROUGHNESS = 1.0;
}
