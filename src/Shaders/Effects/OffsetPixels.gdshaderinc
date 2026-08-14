// @uniform ivec2 offset = ivec2(0); // In pixels
// @uniform float scale_amount: hint_range(0.0, 100.0, 0.01) = 1.0;
// @uniform bool wrap_around = false;

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	ivec2 offset,
	float scale_amount,
	bool wrap_around,
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec2 pixel_size = 1.0 / vec2(textureSize(source_texture, 0));

	uv = uv - (vec2(offset) * pixel_size); // Offset the uv by an amount of pixels
	vec2 zoomed_uv = ((uv - vec2(0.5)) / scale_amount) + vec2(0.5);
	if (wrap_around) {
		zoomed_uv = fract(zoomed_uv);
	}

	vec4 output = texture(source_texture, zoomed_uv);
	// Cut original selected content
	original_color.a = original_color.a * step(selection_color.a, 0.5);
	output.a = min(step(zoomed_uv.x, 1.0) * step(0.0, zoomed_uv.x), output.a); // Remove left and right edges
	output.a = min(step(zoomed_uv.y, 1.0) * step(0.0, zoomed_uv.y), output.a); // Remove up and bottom edges

	selection_color = texture(selection, uv);
	return mix(original_color, output, selection_color.a);
}
