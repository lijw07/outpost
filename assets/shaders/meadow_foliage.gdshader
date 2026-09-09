shader_type canvas_item;
render_mode unshaded;
// Sample the rest drawing with subpixel filtering only on moving foliage.
// This avoids the old per-row integer jumps; the lowest eight pixels stay fixed.
uniform sampler2D rest_texture : source_color, filter_linear, repeat_disable;
uniform vec2 sprite_size = vec2(64.0);
uniform vec2 sprite_origin = vec2(-32.0, -60.0);
uniform float bend = 0.0;
varying vec2 local_uv;
varying vec4 tint;

void vertex() {
	vec2 base_uv = (VERTEX - sprite_origin) / sprite_size;
	float margin = max(12.0, abs(bend) + 2.0);
	VERTEX.x += (base_uv.x < 0.5 ? -margin : margin);
	local_uv = (VERTEX - sprite_origin) / sprite_size;
	tint = COLOR;
}

void fragment() {
	float root = 1.0 - 8.0 / sprite_size.y;
	float weight = clamp((root - local_uv.y) / root, 0.0, 1.0);
	vec2 sample_uv = local_uv;
	sample_uv.x -= bend * weight * weight / sprite_size.x;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		// Keep enlarged pixel interiors sharp; blend only the moving screen-pixel edge.
		vec2 pixel = sample_uv * sprite_size - 0.5;
		vec2 footprint = clamp(fwidth(pixel), vec2(0.0001), vec2(1.0));
		vec2 edge = smoothstep(vec2(0.5)-footprint*0.5, vec2(0.5)+footprint*0.5, fract(pixel));
		vec2 sharp_uv = (floor(pixel)+0.5+edge) / sprite_size;
		COLOR = texture(rest_texture, sharp_uv) * tint;
	}
}
