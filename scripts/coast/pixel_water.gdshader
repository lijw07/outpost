shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=floor(world_position.xz*16.0)/16.0;
	float x=floor(p.x/2.0)*2.0+1.0;
	float shoreline=2.0*floor((81.0-0.16*x+3.0*sin(x*.08))/2.0);
	float depth=max(0.0,p.y-shoreline);
	float grain=hash21(floor(p*vec2(8.0,12.0)));
	float patches=hash21(floor(p*1.5));
	vec3 shallow=vec3(.06,.38,.36);
	vec3 deep=vec3(.012,.20,.27);
	vec3 color=mix(shallow,deep,clamp(depth/18.0,0.0,1.0));
	color+=vec3(.015,.035,.03)*(grain-.5);
	float streak=step(.87,grain)*step(.58,patches);
	color=mix(color,vec3(.16,.49,.46),streak*.5);
	float foam=step(depth,.24+hash21(floor(p*4.0))*.75);
	foam=max(foam,step(abs(depth-1.55),.13)*step(.48,patches));
	ALBEDO=mix(color,vec3(.86,.88,.70),foam*.88);
}
