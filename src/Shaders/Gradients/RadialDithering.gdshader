shader_type canvas_item;
render_mode unshaded;

uniform sampler2D gradient_texture;
uniform sampler2D dither_texture;
uniform sampler2D offset_texture;
uniform sampler2D selection;
uniform vec2 image_size = vec2(64.0);
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform float size : hint_range(0.01, 2) = 1.0;
uniform int pixel_size : hint_range(2, 16) = 2;
uniform int n_of_colors = 2;

// Logic taken from https://godotshaders.com/shader/dither-gradient-shader/
float dither(vec2 uv, float modified_uv) {
	float uv_lower = floor(modified_uv);
	float uv_upper = (floor(modified_uv) + 1.0);
	float threshold = texture(dither_texture, uv * (image_size / float(pixel_size))).r;
	float ramp_val = modified_uv < threshold ? 0.0 : 1.0;
	// sample at the lower bound colour if ramp_val is 0.0, upper bound color if 1.0
	float col_sample = mix(uv_lower, uv_upper, ramp_val);
	return col_sample;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 uv = UV * 2.0 - 1.0;
	uv -= (center * 2.0) - vec2(1.0);
	uv /= radius;
	float polar_uv = length(uv);

	vec4 dither_value = texture(dither_texture, uv * (image_size / float(pixel_size)));

	vec4 output;
	for (int i = 1; i <= n_of_colors; i++) {
		float colors_minus = float(n_of_colors - 1);
		float off = texture(offset_texture, vec2(float(i) / colors_minus)).r;
		float off_prev = texture(offset_texture, vec2(float(i - 1) / colors_minus)).r;
		vec4 first = texture(gradient_texture, vec2(float((i - 1)) / colors_minus));
		vec4 second = texture(gradient_texture, vec2(float(i) / colors_minus));
		if (polar_uv < off_prev) {
			if (i == 1) {
				output = first;
			}
			continue;
		}
		if (polar_uv > off) {
			if (i == n_of_colors) {
				output = second;
			}
			continue;
		}
		float uvt = (polar_uv - off_prev) / (off - off_prev);
		float col_sample = dither(UV, uvt);
		output = mix(first, second, col_sample);
}

	COLOR = mix(original_color, output, selection_color.a);
}
