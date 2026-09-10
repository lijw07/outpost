shader_type spatial;
render_mode unshaded, cull_front;
void vertex() {
	VERTEX += sign(VERTEX)*0.035;
}
void fragment() {
	ALBEDO = vec3(0.075,0.105,0.085);
}
