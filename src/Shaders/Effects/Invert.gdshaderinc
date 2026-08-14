// @uniform bool red = true;
// @uniform bool green = true;
// @uniform bool blue = true;
// @uniform bool alpha = false;


vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	bool red,
	bool green,
	bool blue,
	bool alpha
) {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec4 col = original_color;
    if (red)
        col.r = 1.0 - col.r;
    if (green)
        col.g = 1.0 - col.g;
    if (blue)
        col.b = 1.0 - col.b;
    if (alpha)
        col.a = 1.0 - col.a;

	vec4 output = mix(original_color, col, selection_color.a);
	return output;
}
