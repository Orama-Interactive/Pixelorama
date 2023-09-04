shader_type canvas_item;

uniform sampler2D selection;
uniform vec2 offset = vec2(0.0); // In pixels
uniform bool wrap_around = false;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 uv = UV - (offset * TEXTURE_PIXEL_SIZE); // Offset the uv by an amount of pixels
	if (wrap_around) {
		uv = fract(uv);
	}

	vec4 output = texture(TEXTURE, uv);
	// Cut original selected content
	original_color.a = 0.0 * step(0.5, selection_color.a) + original_color.a * step(selection_color.a, 0.5);
	output.a = min(step(uv.x, 1.0) * step(0.0, uv.x), output.a); // Remove left and right edges
	output.a = min(step(uv.y, 1.0) * step(0.0, uv.y), output.a); // Remove up and bottom edges

	selection_color = texture(selection, uv);
	COLOR = mix(original_color, output, selection_color.a);
}
