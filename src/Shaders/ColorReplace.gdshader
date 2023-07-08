shader_type canvas_item;
render_mode unshaded;

uniform vec2 size;

uniform vec4 old_color;
uniform vec4 new_color;
uniform float similarity_percent : hint_range(0.0, 100.0);

// Must be the same size as image
// Selected pixels are 1,1,1,1 and unselected 0,0,0,0
uniform sampler2D selection;

uniform bool has_pattern;
uniform sampler2D pattern;
uniform vec2 pattern_size;
uniform vec2 pattern_uv_offset;

void fragment() { // applies on each pixel separately
	vec4 original_color = texture(TEXTURE, UV);  // The drawing we have to use on
	vec4 selection_color = texture(selection, UV);  // use its alpha to get portion we can ignore

	vec4 col = original_color;  // Innocent till proven guilty

	float max_diff = distance(original_color, old_color);  // How much this pixel matches our description

	float similarity = abs(2.0 - ((similarity_percent/100.0) * 2.0));

	if (max_diff <= similarity)  // We found our match and pixel is proven guilty (small is precise)
		if (has_pattern)
			col = textureLod(pattern, UV * (size / pattern_size) + pattern_uv_offset, 0.0);
		else
			col = new_color;

	// Mix selects original color if there is selection or col if there is none
	COLOR = mix(original_color, col, selection_color.a);
}
