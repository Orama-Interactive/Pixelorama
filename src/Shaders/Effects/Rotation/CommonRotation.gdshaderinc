uniform sampler2D selection_tex : filter_nearest;
uniform vec2 pivot;
uniform mat2 transformation_matrix = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));

vec2 rotate(vec2 uv, float ratio) {
	// Scale and center image
	uv.x = (uv.x - pivot.x) * ratio + pivot.x;
	uv -= pivot;

	// Rotate image
	uv *= transformation_matrix;
	uv.x /= ratio;
	uv += pivot;

	return uv;
}

vec4 mix_rotated_and_original(vec4 color, vec4 original_color, vec2 uv, vec2 rotated_uv, vec2 tex_pixel_size) {
	color.a *= texture(selection_tex, rotated_uv).a; // Combine with selection mask
	// Make a border to prevent stretching pixels on the edge
	vec2 border_uv = rotated_uv;

	// Center the border
	border_uv -= 0.5;
	border_uv *= 2.0;
	border_uv = abs(border_uv);

	float border = max(border_uv.x, border_uv.y); // This is a rectangular gradient
	border = floor(border - tex_pixel_size.x); // Turn the grad into a rectangle shape
	border = 1.0 - clamp(border, 0.0, 1.0); // Invert the rectangle

	float selection = texture(selection_tex, uv).a;
	float mask = mix(selection, 1.0, 1.0 - ceil(original_color.a)); // Combine selection mask with area outside original

	vec4 final_color;
	// Combine original and rotated image only when intersecting, otherwise just pure rotated image.
	final_color.rgb = mix(mix(original_color.rgb, color.rgb, color.a * border), color.rgb, mask);
	final_color.a = mix(original_color.a, 0.0, selection); // Remove alpha on the selected area
	final_color.a = mix(final_color.a, 1.0, color.a * border); // Combine alpha of original image and rotated
	return final_color;
}