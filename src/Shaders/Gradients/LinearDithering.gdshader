shader_type canvas_item;
render_mode unshaded;

uniform sampler2D gradient_texture;
uniform sampler2D dither_texture;
uniform sampler2D offset_texture;
uniform sampler2D selection;
uniform vec2 image_size = vec2(64.0);
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform int shape = 0; // 0 = linear, 1 = radial
uniform int repeat = 0; // 0 = none, 1 = repeat, 2 = mirrored, 3 = truncate
uniform int pixel_size : hint_range(2, 16) = 2;
uniform int n_of_colors = 2;


float modify_uv(vec2 uv) {
	float modified_uv;
	if (shape == 0) { // Linear
		vec2 uv_offsetted = uv - 0.5;
		float angle_cos = cos(radians(angle));
		float angle_sin = sin(radians(angle));
		modified_uv = uv_offsetted.x * angle_cos - uv_offsetted.y * angle_sin; 
		modified_uv /= abs(angle_cos) + abs(angle_sin);
		modified_uv /= size;
		float pivot = position / size;
		modified_uv -= pivot - 0.5;
	}
	else { // Radial
		vec2 uv_offsetted = uv * 2.0 - 1.0;
		uv_offsetted -= (center * 2.0) - vec2(1.0);
		uv_offsetted *= radius;
		modified_uv = length(uv_offsetted);
	}
	return modified_uv;
}


float mirror_fract(float uv) {
	int sign_uv = (int(sign(uv)) - 1) / 2; // returns -1 for negative sign and 0 for positive
	if (int((uv)) % 2 == sign_uv)
		uv = fract(uv);
	else
		uv = fract(1.0 - uv);
	
	return uv;
}

// Logic taken from https://godotshaders.com/shader/dither-gradient-shader/
float dither(vec2 uv, float modified_uv) {
	float uv_lower = floor(modified_uv);
	float uv_upper = floor(modified_uv) + 1.0;
	float threshold = texture(dither_texture, uv * (image_size / float(pixel_size))).r;
	float ramp_val = modified_uv < threshold ? 0.0 : 1.0;
	// sample at the lower bound colour if ramp_val is 0.0, upper bound color if 1.0
	float col_sample = mix(uv_lower, uv_upper, ramp_val);
	return col_sample;
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	float modified_uv = modify_uv(UV);
	if (repeat == 1)
		modified_uv = fract(modified_uv);
	else if (repeat == 2)
		modified_uv = mirror_fract(modified_uv);

	vec4 output;
	// Note for the future, please remember to change 100 to n_of_colors when we
	// use GLES3 for the Web version. A constant number is used to make it work in WebGL 1.0.
	for (int i = 1; i <= 100; i++) {
		if(i > n_of_colors) {
			break;
		}
		float colors_minus = float(n_of_colors - 1);
		float off = texture(offset_texture, vec2(float(i) / colors_minus)).r;
		float off_prev = texture(offset_texture, vec2(float(i - 1) / colors_minus)).r;
		vec4 first = texture(gradient_texture, vec2(float((i - 1)) / colors_minus));
		vec4 second = texture(gradient_texture, vec2(float(i) / colors_minus));
		if (modified_uv < off_prev) {
			if (i == 1) {
				output = first;
			}
			continue;
		}
		if (modified_uv > off) {
			if (i == n_of_colors) {
				output = second;
			}
			continue;
		}
		float uvt = (modified_uv - off_prev) / (off - off_prev);
		float col_sample = dither(UV, uvt);
		output = mix(first, second, col_sample);
	}
	if (repeat == 3)
		output.a = min(step(modified_uv, 1.0) * step(0.0, modified_uv), output.a);
	output = mix(original_color, output, output.a);
	COLOR = mix(original_color, output, selection_color.a);
}
