// Based on https://godotshaders.com/shader/2d-outline-inline/
// @uniform vec4 color : source_color = vec4(1.0);
// @uniform float width : hint_range(0, 10, 1) = 1.0;
// @uniform int brush : hint_enum("Diamond", "Circle", "Square") = 0;
// @uniform bool inside = false;
// @uniform bool keep_border_only = false;

bool is_zero_approx(float num) {
	return num < 0.0001;
}

bool has_contrary_neighbour(
	vec2 uv, sampler2D tex, float width, int brush, bool inside
) {
	vec2 pixel_size = 1.0 / vec2(textureSize(tex, 0));
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float offset;

		if (brush == 0) {
			offset = width - abs(i);
		} else if (brush == 1) {
			offset = floor(sqrt(pow(width + 0.5, 2) - i * i));
		} else if (brush == 2) {
			offset = width;
		}

		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			vec2 xy = uv + pixel_size * vec2(i, j);

			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || is_zero_approx(texture(tex, xy).a)) == inside) {
				return true;
			}
		}
	}

	return false;
}

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	vec4 color,
	float width,
	int brush,
	bool inside,
	bool keep_border_only,
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec4 output = original_color;

	bool contrary_neighbour = has_contrary_neighbour(uv, source_texture, width, brush, inside);
	if ((output.a > 0.0) == inside && contrary_neighbour) {
		output.rgb = inside ? mix(output.rgb, color.rgb, color.a) : color.rgb;
		if (is_zero_approx(color.a)) {
			output.a = color.a;
		}
		else {
			output.a += (1.0 - output.a) * color.a;
		}
	}
	else if (keep_border_only) {
		output.a = 0.0;
	}

	return mix(original_color, output, selection_color.a);
}
