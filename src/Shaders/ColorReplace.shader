shader_type canvas_item;
render_mode unshaded;

uniform vec2 size;

uniform vec4 old_color;
uniform vec4 new_color;

// Must be the same size as image
// Selected pixels are 1,1,1,1 and unselected 0,0,0,0
uniform sampler2D selection;

uniform bool has_pattern;
uniform sampler2D pattern;
uniform vec2 pattern_size;
uniform vec2 pattern_uv_offset;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec4 col = original_color;

	vec4 diff = abs(original_color - old_color);
	float max_diff = max(max(diff.r, diff.g), diff.b);

	if (max_diff < 0.01)
		if (has_pattern)
			col = texture(pattern, UV * (size / pattern_size) + pattern_uv_offset);
		else
			col = new_color;

	// Mix selects original color if there is selection or col if there is none
	COLOR = mix(original_color, col, selection_color.a);
}
