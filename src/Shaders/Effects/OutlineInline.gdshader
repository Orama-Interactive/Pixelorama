// Based on https://godotshaders.com/shader/2d-outline-inline/
shader_type canvas_item;
render_mode unshaded;

uniform vec4 color : source_color = vec4(1.0);
uniform float width : hint_range(0, 10) = 1.0;
uniform int pattern : hint_range(0, 2) = 0; // diamond, circle, square
uniform bool inside = false;
uniform sampler2D selection;


bool has_contrary_neighbour(vec2 uv, vec2 texture_pixel_size, sampler2D tex) {
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float offset;

		if (pattern == 0) {
			offset = width - abs(i);
		} else if (pattern == 1) {
			offset = floor(sqrt(pow(width + 0.5, 2) - i * i));
		} else if (pattern == 2) {
			offset = width;
		}

		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			vec2 xy = uv + texture_pixel_size * vec2(i, j);

			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(tex, xy).a == 0.0) == inside) {
				return true;
			}
		}
	}

	return false;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = texture(TEXTURE, UV);

	if ((output.a > 0.0) == inside && has_contrary_neighbour(UV, TEXTURE_PIXEL_SIZE, TEXTURE)) {
		output.rgb = inside ? mix(output.rgb, color.rgb, color.a) : color.rgb;
		output.a += (1.0 - output.a) * color.a;
	}

	COLOR = mix(original_color, output, selection_color.a);
}
