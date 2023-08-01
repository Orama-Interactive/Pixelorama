shader_type canvas_item;
render_mode unshaded;

uniform float angle;
uniform sampler2D selection_tex;
uniform vec2 pivot_pixel;


vec2 rotate(vec2 uv, vec2 pivot, float ratio) {
	// Scale and center image
	uv.x -= pivot.x;
	uv.x *= ratio;
	uv.x += pivot.x;

	// Rotate image
	uv -= pivot;
	uv = vec2(cos(angle) * uv.x + sin(angle) * uv.y,
				-sin(angle) * uv.x + cos(angle) * uv.y);
	uv.x /= ratio;
	uv += pivot;

	return uv;
}


void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float selection = texture(selection_tex, UV).a;

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE; // Texture size in real pixel coordinates
	vec2 pixelated_uv = floor(UV * tex_size) / (tex_size - 1.0); // Pixelate UV to fit resolution
	vec2 pivot = pivot_pixel / tex_size; // Normalize pivot position
	float ratio = tex_size.x / tex_size.y; // Resolution ratio

	// Make a border to prevent stretching pixels on the edge
	vec2 border_uv = rotate(pixelated_uv, pivot, ratio);

	// Center the border
	border_uv -= 0.5;
	border_uv *= 2.0;
	border_uv = abs(border_uv);

	float border = max(border_uv.x, border_uv.y); // This is a rectangular gradient
	border = floor(border - TEXTURE_PIXEL_SIZE.x); // Turn the grad into a rectangle shape
	border = 1.0 - clamp(border, 0.0, 1.0); // Invert the rectangle

	// Mixing
	vec4 rotated = texture(TEXTURE, rotate(pixelated_uv, pivot, ratio)); // Rotated image
	rotated.a *= texture(selection_tex, rotate(pixelated_uv, pivot, ratio)).a; // Combine with selection mask
	float mask = mix(selection, 1.0, 1.0 - ceil(original.a)); // Combine selection mask with area outside original

	// Combine original and rotated image only when intersecting, otherwise just pure rotated image.
	COLOR.rgb = mix(mix(original.rgb, rotated.rgb, rotated.a * border), rotated.rgb, mask);
	COLOR.a = mix(original.a, 0.0, selection); // Remove alpha on the selected area
	COLOR.a = mix(COLOR.a, 1.0, rotated.a * border); // Combine alpha of original image and rotated
}
