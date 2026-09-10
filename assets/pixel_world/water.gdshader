shader_type spatial;
uniform float phase = 0.0;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 cell = floor(world_position.xz*16.0);
	float row = mod(cell.y+floor(phase),13.0);
	float stripe = step(row,0.5)*step(mod(cell.x+floor(cell.y/13.0)*7.0,23.0),5.0);
	ALBEDO = mix(vec3(0.13,0.29,0.33),vec3(0.23,0.40,0.42),stripe);
	ROUGHNESS = 1.0;
}
