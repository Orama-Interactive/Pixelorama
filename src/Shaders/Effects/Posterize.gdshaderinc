// https://godotshaders.com/shader/color-reduction-and-dither/

// @uniform float colors : hint_range(1.0, 255.0) = 2.0;
// @uniform float dither_intensity : hint_range(0.0, 0.5) = 0.0;

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	float colors,
	float dither_intensity
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec2 pixel_size = 1.0 / vec2(textureSize(source_texture, 0));

	float a = floor(mod(uv.x / pixel_size.x, 2.0));
	float b = floor(mod(uv.y / pixel_size.y, 2.0));
	float c = mod(a + b, 2.0);
	vec4 col;
	col.r = (round(original_color.r * colors + dither_intensity) / colors) * c;
	col.g = (round(original_color.g * colors + dither_intensity) / colors) * c;
	col.b = (round(original_color.b * colors + dither_intensity) / colors) * c;
	c = 1.0 - c;
	col.r += (round(original_color.r * colors - dither_intensity) / colors) * c;
	col.g += (round(original_color.g * colors - dither_intensity) / colors) * c;
	col.b += (round(original_color.b * colors - dither_intensity) / colors) * c;
	col.a = original_color.a;
	vec4 output = mix(original_color.rgba, col, selection_color.a);
	return output;
}
