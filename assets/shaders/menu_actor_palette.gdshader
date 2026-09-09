shader_type canvas_item;
uniform bool key_neutral_background = false;
uniform bool dress_survivor = false;
uniform vec4 frame_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 frame_pivot = vec2(0.5,1.0);
uniform vec2 frame_size = vec2(1.0);
uniform vec4 jacket_color : source_color = vec4(1.0);
uniform vec4 trousers_color : source_color = vec4(1.0);
uniform vec4 shoes_color : source_color = vec4(1.0);
uniform vec4 backpack_color : source_color = vec4(1.0);
void fragment() {
	// Keep the authored palette intact and the silhouette crisp at menu scale.
	vec4 pixel = COLOR;
	vec3 source = texture(TEXTURE, UV).rgb;
	if (dress_survivor) {
		vec2 garment = ((UV-frame_region.xy)/frame_region.zw-frame_pivot)*frame_size;
		float shade = max(source.r,max(source.g,source.b));
		// Anatomical bands protect hair/faces; color families protect hands and gear.
		if (garment.y > -10.0 && source.r > source.g*1.05 && shade > 0.14) {
			pixel.rgb = shoes_color.rgb*clamp(shade/0.43,0.3,1.3);
		} else if (garment.y > -29.0 && source.b > source.r*1.08 && source.b > source.g*1.04 && shade > 0.13) {
			pixel.rgb = trousers_color.rgb*clamp(shade/0.35,0.3,1.3);
		} else if (garment.y > -56.0 && garment.y < -14.0 && abs(source.r-source.g) < 0.08 && source.g > source.b*1.35 && shade > 0.15) {
			pixel.rgb = backpack_color.rgb*clamp(shade/0.4,0.3,1.2);
		} else if (garment.y > -53.0 && garment.y < -16.0 && source.r > source.g*1.2 && source.b < source.g*0.62 && shade > 0.2) {
			pixel.rgb = jacket_color.rgb*clamp(shade/0.6,0.3,1.2);
		}
	}
	if (key_neutral_background) {
		float low = min(source.r, min(source.g, source.b));
		float high = max(source.r, max(source.g, source.b));
		if (low > 148.0/255.0 && high-low < 22.0/255.0) pixel.a = 0.0;
	}
	pixel.a = step(0.5, pixel.a);
	COLOR = pixel;
}
