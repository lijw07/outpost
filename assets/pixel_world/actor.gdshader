shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform vec2 pixel_size = vec2(0.0625,0.04166667);
uniform float stride = 0.0;
uniform bool moving = false;
uniform bool modular_body = false;
uniform bool replace_arms = false;
uniform int facing = 0;
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	vec2 uv = UV;
	// One native-pixel step per leg: clothes and boots move as the same pixels.
	if (moving && uv.y > 0.76) {
		float leg = uv.x < 0.5 ? 1.0 : -1.0;
		uv.y += round(sin(stride)*leg)*pixel_size.y;
	}
	vec4 tex = texture(sprite_texture,uv);
	if (uv.y > 1.0 || uv.y < 0.0) tex.a = 0.0;
	float edge = modular_body ? 0.37 : 0.20;
	float shoulder = modular_body ? 0.54 : 0.48;
	if (replace_arms && UV.y > shoulder && UV.y < 0.79 && (UV.x < edge || UV.x > 1.0-edge)) tex.a = 0.0;
	ALBEDO = tex.rgb*tint;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
