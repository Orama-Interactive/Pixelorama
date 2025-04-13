shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;
group_uniforms gradient_textures;
// The gradient texture itself, with interpolation.
uniform sampler2D gradient_texture : filter_nearest;
// A Nx1 image, where N is the amount of the different colors of gradient_texture,
// without interpolating between them. Used in dithering.
uniform sampler2D gradient_texture_no_interpolation : filter_nearest;
// A Nx1 grayscale image, where N is the amount of the different colors of gradient_texture,
// where each pixel contains the offset, ranging from 0-1 of each color. Used in dithering.
uniform sampler2D gradient_offset_texture : filter_nearest;

group_uniforms gradient_options;
// uniform_data shape type:: OptionButton [Linear||Radial]
uniform int shape = 0;
// uniform_data repeat type:: OptionButton [None||Repeat||Mirrored||Truncate]
uniform int repeat = 0;
uniform bool use_dithering = false;
uniform sampler2D dither_texture : filter_nearest, repeat_enable;
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);


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
		uv_offsetted /= radius;
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
float dither(vec2 uv, float modified_uv, ivec2 image_size) {
	float uv_lower = floor(modified_uv);
	float uv_upper = floor(modified_uv) + 1.0;
	ivec2 pixel_size = textureSize(dither_texture, 0);
	float threshold = texture(dither_texture, uv * vec2(image_size / pixel_size.x)).r;
	float ramp_val = modified_uv < threshold ? 0.0 : 1.0;
	// sample at the lower bound colour if ramp_val is 0.0, upper bound color if 1.0
	float col_sample = mix(uv_lower, uv_upper, ramp_val);
	return col_sample;
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = floor(UV * tex_size) / (tex_size - 1.0);
	float modified_uv = modify_uv(uv);
	if (repeat == 1)
		modified_uv = fract(modified_uv);
	else if (repeat == 2)
		modified_uv = mirror_fract(modified_uv);

	vec4 output;
	if (use_dithering) {
		int n_of_colors = textureSize(gradient_offset_texture, 0).x;
		float colors_minus = float(n_of_colors - 1);
		for (int i = 1; i <= n_of_colors; i++) {
			float off = texture(gradient_offset_texture, vec2(float(i) / colors_minus)).r;
			float off_prev = texture(gradient_offset_texture, vec2(float(i - 1) / colors_minus)).r;
			vec4 first = texture(gradient_texture_no_interpolation, vec2(float((i - 1)) / colors_minus));
			vec4 second = texture(gradient_texture_no_interpolation, vec2(float(i) / colors_minus));
			if (modified_uv < off_prev) {
				if (i == 1) {
					output = first;
				}
				continue;
			}
			if (modified_uv >= off) {
				if (i == n_of_colors) {
					output = second;
				}
				continue;
			}
			float uvt = (modified_uv - off_prev) / (off - off_prev);
			float col_sample = dither(UV, uvt, textureSize(TEXTURE, 0));
			output = mix(first, second, col_sample);
		}
	}
	else
		output = texture(gradient_texture, vec2(modified_uv));
	if (repeat == 3)
		output.a = min(step(modified_uv, 1.0) * step(0.0, modified_uv), output.a);
	output = mix(original_color, output, output.a);
	COLOR = mix(original_color, output, selection_color.a);
}
