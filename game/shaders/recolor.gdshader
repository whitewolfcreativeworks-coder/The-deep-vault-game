shader_type spatial;
// Recolours a KayKit atlas texture: clothing/armour to a chosen colour (keeping
// its shading) and skin to a chosen skin tone. Used by the character creator.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 0.0;        // outfit recolour amount
uniform float skin_protect = 1.0;    // keep warm (skin/hair/leather) texels out of the outfit recolour
uniform vec3 skin_tone : source_color = vec3(0.97, 0.8, 0.67);
uniform float skin_on = 0.0;         // 1 = replace the light-peach skin with skin_tone
uniform vec3 hair_tone : source_color = vec3(0.3, 0.2, 0.1);
uniform float hair_on = 0.0;
// Modelled-hair heads (KayKit 2.0): the hair lives in one swatch of the atlas, given as a UV rect.
uniform vec4 hair_rect = vec4(0.0);  // x0, y0, x1, y1
uniform float hair_rect_on = 0.0;
// The web/iPad (Compatibility) renderer hands the texture back in sRGB already.
uniform bool tex_is_srgb = false;         // head meshes only: recolour the hero's own hair and brows
// Pajama stripes: alternate the outfit colour with stripe_color in horizontal bands.
uniform float stripes = 0.0;
uniform vec3 stripe_color : source_color = vec3(1.0);
uniform float stripe_freq = 9.0;
varying vec3 lpos;
uniform float roughness_v = 0.8;
uniform float metallic_v = 0.0;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float warm = clamp((c.r - c.g) * 5.0, 0.0, 1.0) * clamp((c.g - c.b) * 5.0, 0.0, 1.0) * step(0.45, c.r) * skin_protect;
	vec3 band = mix(tint, stripe_color, step(0.5, fract(lpos.y * stripe_freq)) * stripes);
	vec3 rec = band * (0.3 + l * 1.2);
	c = mix(c, rec, strength * (1.0 - warm));
	// Masks work on the texture's sRGB values (the sampler hands back linear).
	// KayKit skin is a light peach (r > 0.8, g > 0.55): hair and leather are darker
	vec3 s = tex_is_srgb ? t.rgb : pow(max(t.rgb, vec3(0.0)), vec3(1.0 / 2.2));
	float ls = dot(s, vec3(0.299, 0.587, 0.114));
	float skin = smoothstep(0.80, 0.88, s.r) * smoothstep(0.62, 0.72, s.g)
		* clamp((s.r - s.b) * 6.0 - 0.6, 0.0, 1.0) * clamp((s.g - s.b) * 8.0, 0.0, 1.0);
	vec3 toned = skin_tone * clamp(ls / 0.83, 0.0, 1.3);
	c = mix(c, toned, skin * skin_on);
	float hair = (1.0 - skin) * smoothstep(0.18, 0.3, s.r) * clamp((s.r - s.b) * 6.0, 0.0, 1.0);
	vec3 htoned = hair_tone * clamp(ls / 0.45, 0.3, 1.6);
	c = mix(c, htoned, hair * hair_on);
	if (hair_rect_on > 0.5) {
		float inr = step(hair_rect.x, UV.x) * step(UV.x, hair_rect.z) * step(hair_rect.y, UV.y) * step(UV.y, hair_rect.w);
		vec3 kc = texture(tex, (hair_rect.xy + hair_rect.zw) * 0.5).rgb;
		vec3 ks = tex_is_srgb ? kc : pow(max(kc, vec3(0.0)), vec3(1.0 / 2.2));
		float kl = max(dot(ks, vec3(0.299, 0.587, 0.114)), 0.05);
		vec3 rt = hair_tone * clamp(pow(ls / kl, 1.4), 0.35, 1.7);
		c = mix(c, rt, inr);
	}
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
