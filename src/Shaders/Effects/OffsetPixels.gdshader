shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;
uniform ivec2 offset = ivec2(0); // In pixels
uniform float zoom_amount: hint_range(0.02, 100.0) = 1.0;
uniform bool wrap_around = false;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 uv = UV - (vec2(offset) * TEXTURE_PIXEL_SIZE); // Offset the uv by an amount of pixels
	vec2 zoomed_uv = (uv - vec2(0.5)) * zoom_amount + vec2(0.5);
	if (wrap_around) {
		zoomed_uv = fract(zoomed_uv);
	}

	vec4 output = texture(TEXTURE, zoomed_uv);
	// Cut original selected content
	original_color.a = 0.0 * step(0.5, selection_color.a) + original_color.a * step(selection_color.a, 0.5);
	output.a = min(step(zoomed_uv.x, 1.0) * step(0.0, zoomed_uv.x), output.a); // Remove left and right edges
	output.a = min(step(zoomed_uv.y, 1.0) * step(0.0, zoomed_uv.y), output.a); // Remove up and bottom edges

	selection_color = texture(selection, uv);
	COLOR = mix(original_color, output, selection_color.a);
}
