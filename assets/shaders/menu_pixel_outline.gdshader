shader_type canvas_item;
// One logical pixel at the menu's 2x presentation scale. No blur or glow.
uniform vec4 outline_color : source_color = vec4(0.055, 0.085, 0.07, 1.0);
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
	float edge = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = max(edge, texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a);
		}
	}
	COLOR = vec4(mix(outline_color.rgb, base.rgb, base.a), max(base.a, edge));
}
