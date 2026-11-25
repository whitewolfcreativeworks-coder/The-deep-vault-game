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
// Wardrobe outfits (Outfits.gd): 1 stripes, 2 dots, 3 checks, 4 stars, in stripe_color.
uniform int pattern = 0;
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
	int pt = pattern;
	if (pt == 0 && stripes > 0.5) {
		pt = 1;
	}
	float pm = 0.0;
	vec2 pp = vec2(lpos.x + lpos.z * 0.8, lpos.y);
	if (pt == 1) {
		pm = step(0.5, fract(lpos.y * stripe_freq));
	} else if (pt == 2) {
		vec2 g = fract(pp * 7.0 + vec2(0.5 * mod(floor(pp.y * 7.0), 2.0), 0.0)) - 0.5;
		pm = 1.0 - smoothstep(0.17, 0.2, length(g));
	} else if (pt == 3) {
		vec2 g = floor(pp * 5.5);
		pm = mod(g.x + g.y, 2.0);
	} else if (pt == 4) {
		vec2 q = pp * 5.0;
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 g = fract(q) - 0.5;
		float a = atan(g.y, g.x);
		float sr = 0.2 * (0.55 + 0.45 * cos(5.0 * a + 1.5708));
		pm = 1.0 - smoothstep(sr - 0.02, sr, length(g));
	}
	vec3 band = mix(tint, stripe_color, pm);
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
