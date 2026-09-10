shader_type canvas_item;
uniform vec2 sprite_recoil_offset = vec2(0.0);
uniform float sprite_recoil_height = 1.0;
void vertex() {
	// Small upper-body recoil, with the ground-contact edge held still.
	VERTEX += sprite_recoil_offset * clamp(-VERTEX.y / sprite_recoil_height, 0.0, 1.0);
}
uniform bool key_neutral_background = false;
uniform bool zombie_attack = false;
uniform bool dress_survivor = false;
uniform bool carry_pose = false;
uniform bool replace_arms = false;
uniform int facing_direction = 0;
uniform vec4 frame_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 frame_pivot = vec2(0.5,1.0);
uniform vec2 frame_size = vec2(1.0);
uniform bool frame_flipped = false;
uniform vec2 torso_socket = vec2(0.0,-36.0);
uniform vec2 head_socket = vec2(0.0,-61.0);
uniform float head_width = 24.0;
uniform bool cover_hair = false;
uniform vec4 jacket_color : source_color = vec4(1.0);
uniform vec4 shirt_color : source_color = vec4(1.0);
uniform vec4 trousers_color : source_color = vec4(1.0);
uniform vec4 shoes_color : source_color = vec4(1.0);
uniform vec4 backpack_color : source_color = vec4(1.0);
uniform bool replace_backpack = false;
uniform bool armor_enabled = false;
uniform sampler2D armor_texture : filter_nearest;
uniform vec4 armor_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 armor_bounds = vec4(-9.0,-52.0,18.0,28.0);
void fragment() {
	// Keep the authored palette intact and the silhouette crisp at menu scale.
	vec4 pixel = COLOR;
	vec3 source = texture(TEXTURE, UV).rgb;
	if (dress_survivor) {
		vec2 garment = ((UV-frame_region.xy)/frame_region.zw-frame_pivot)*frame_size;
		if (frame_flipped) garment.x = -garment.x;
		vec2 anatomy = garment-torso_socket+vec2(0.0,-36.0);
		float shade = max(source.r,max(source.g,source.b));
		bool timber = carry_pose && anatomy.y > -43.0 && anatomy.y < -24.0 && (facing_direction == 0 || (facing_direction == 1 && anatomy.x > 7.0) || (facing_direction == 3 && anatomy.x < -7.0) || (facing_direction == 2 && abs(anatomy.x) > 19.0));
		// Anatomical bands protect hair/faces; color families protect hands and gear.
		if (anatomy.y > -10.0 && source.r > source.g*1.05 && shade > 0.14) {
			pixel.rgb = shoes_color.rgb*clamp(shade/0.43,0.3,1.3);
		} else if (anatomy.y > -29.0 && source.b > source.r*1.08 && source.b > source.g*1.04 && shade > 0.13) {
			pixel.rgb = trousers_color.rgb*clamp(shade/0.35,0.3,1.3);
		} else if (anatomy.y > -47.0 && anatomy.y < -14.0 && abs(source.r-source.g) < 0.08 && source.g > source.b*1.35 && shade > 0.15) {
			pixel.rgb = backpack_color.rgb*clamp(shade/0.4,0.3,1.2);
			if (replace_backpack) pixel.a = 0.0;
		} else if (anatomy.y > -46.0 && anatomy.y < -18.0 && (anatomy.y < -27.0 || abs(anatomy.x) < 10.0) && !timber && source.r > source.g*1.2 && source.b < source.g*0.62 && shade > 0.2) {
			pixel.rgb = jacket_color.rgb*clamp(shade/0.6,0.3,1.2);
		}
		bool inner_shirt = abs(anatomy.x) < 5.0 && anatomy.y > -39.0 && anatomy.y < -21.0 && shade > 0.08 && shade < 0.25 && abs(source.r-source.b) < 0.08 && !carry_pose;
		if (inner_shirt && !key_neutral_background) pixel.rgb = shirt_color.rgb*clamp(shade/0.2,0.3,1.0);
		vec2 armor_uv = (garment-armor_bounds.xy)/armor_bounds.zw;
		bool cloth = ((source.r > source.g*1.2 && source.b < source.g*0.62) || inner_shirt) && !timber;
		if (armor_enabled && cloth && all(greaterThanEqual(armor_uv,vec2(0.0))) && all(lessThanEqual(armor_uv,vec2(1.0)))) {
			vec4 armor = texture(armor_texture,armor_region.xy+armor_uv*armor_region.zw);
			if (armor.a > 0.5) pixel.rgb = armor.rgb;
		}
		bool arm_side = facing_direction == 1 ? anatomy.x > 8.0 : facing_direction == 3 ? anatomy.x < -8.0 : abs(anatomy.x) > 10.0;

		// Faces share warm colors with the source jacket; protect the animated head.
		if (abs(garment.x-head_socket.x) < head_width*0.52 && garment.y < head_socket.y+head_width*0.78) pixel = COLOR;
		if (replace_arms && arm_side && anatomy.y > -49.0 && anatomy.y < -14.0) pixel.a = 0.0;
		// Remove the baked-in crown under a hat, including stray outlined spikes.
		// Bound the cut to the head so raised tools remain intact above it.
		if (cover_hair && abs(garment.x-head_socket.x) < head_width*0.72 && garment.y > head_socket.y-head_width*0.9 && garment.y < head_socket.y+head_width*0.22) pixel.a = 0.0;
	}
	if (zombie_attack) {
		vec2 point = ((UV-frame_region.xy)/frame_region.zw-frame_pivot)*frame_size;
		bool near_arm = facing_direction == 1 ? point.x > 8.0 : facing_direction == 3 ? point.x < -8.0 : abs(point.x) > 9.0;
		if (near_arm && point.y > -49.0 && point.y < -16.0) pixel.a = 0.0;
	}
	if (key_neutral_background) {
		float low = min(source.r, min(source.g, source.b));
		float high = max(source.r, max(source.g, source.b));
		if (low > 148.0/255.0 && high-low < 22.0/255.0) pixel.a = 0.0;
	}
	pixel.a = step(0.5, pixel.a);
	COLOR = pixel;
}
