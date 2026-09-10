shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform vec2 pixel_size;
uniform float phase = 0.0;
uniform bool flame = false;
void fragment() {
	vec2 uv = UV;
	if (uv.y < 0.6) {
		uv.x += floor(sin(phase)*1.1)*pixel_size.x;
		if (flame) uv.y += floor(sin(phase*2.0)*1.5)*pixel_size.y;
	}
	vec4 color = texture(sprite_texture,uv);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (flame) EMISSION = color.rgb*0.35;
	ROUGHNESS = 1.0;
}
