// Taken and modified from https://godotshaders.com/shader/2d-outline-inline/
// Also thanks to https://andreashackel.de/tech-art/stripes-shader-1/ for the stripe tutorial
shader_type canvas_item;

uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool animated = true;
uniform float width : hint_range(0, 2) = 0.2;
uniform float frequency = 50.0;
uniform float stripe_direction : hint_range(0, 1) = 0.5;


bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float x = abs(i) > width ? width * sign(i) : i;
		float offset = width;
		
		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);
			
			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(texture, xy).a == 0.0) == true) {
				return true;
			}
		}
	}
	
	return false;
}

void fragment() {
	vec2 uv = UV;
	COLOR = texture(TEXTURE, uv);
	
	if ((COLOR.a > 0.0) == true && hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE)) {
		vec4 final_color = first_color;
		// Generate diagonal stripes
		if(animated)
			uv -= TIME / frequency;
		float pos = mix(uv.x, uv.y, stripe_direction) * frequency;
		float value = floor(fract(pos) + 0.5);
		if (mod(value, 2.0) == 0.0)
			final_color = second_color;

		COLOR.rgb = mix(COLOR.rgb, final_color.rgb, final_color.a);
		COLOR.a += (1.0 - COLOR.a) * final_color.a;
	}
	else {
		// Erase the texture's pixels in order to only keep the outline visible
		COLOR.a = 0.0;
	}
}