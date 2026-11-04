shader_type spatial;
// Forest ground: per-vertex colours (grass / dirt road / rock / stream bed)
// broken up with world-space noise so it never looks flat or tiled.
uniform sampler2D detail : repeat_enable, filter_linear_mipmap;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = COLOR.rgb;
	float n1 = texture(detail, wpos.xz * 0.045).r;
	float n2 = texture(detail, wpos.xz * 0.37).r;
	float n3 = texture(detail, wpos.xz * 1.9).r;
	c *= 0.78 + n1 * 0.36 + (n2 - 0.5) * 0.18 + (n3 - 0.5) * 0.10;
	ALBEDO = c;
	ROUGHNESS = 0.96;
	SPECULAR = 0.25;
}
