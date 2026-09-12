shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 pixel = floor(world_position.xz * vec2(8.0, 12.0));
	float grain = fract(sin(dot(pixel, vec2(127.1, 311.7))) * 43758.5453);
	ALBEDO = vec3(0.012, 0.20, 0.27) + vec3(0.008, 0.018, 0.02) * (grain - 0.5);
}
