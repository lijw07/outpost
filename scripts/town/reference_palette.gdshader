shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D source_texture : source_color, filter_nearest, repeat_enable;
uniform bool foliage = false;
void fragment() {
	vec4 texel = texture(source_texture, UV);
	float value = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = texel.rgb;
	if (foliage) {
		if (color.g > color.r * 1.025 && color.g > color.b * 1.2) {
			float tone = clamp((value - 0.015) / 0.28, 0.0, 1.0);
			vec3 shade = vec3(0.024, 0.078, 0.009);
			vec3 mid = vec3(0.08, 0.18, 0.022);
			vec3 light = vec3(0.30, 0.40, 0.06);
			color = tone < 0.5 ? mix(shade, mid, tone * 2.0) : mix(mid, light, (tone - 0.5) * 2.0);
		}
	} else {
		color = vec3(value * 0.78 + 0.018) * vec3(0.94, 0.98, 1.0);
	}
	ALBEDO = color;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ROUGHNESS = 1.0;
}
