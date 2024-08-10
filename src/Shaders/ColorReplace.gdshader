shader_type canvas_item;
render_mode unshaded;

uniform vec2 size;

uniform vec4 old_color;
uniform vec4 new_color;
uniform float tolerance : hint_range(0.0, 1.0);

// Must be the same size as image
// Selected pixels are 1,1,1,1 and unselected 0,0,0,0
uniform sampler2D selection : filter_nearest;

uniform bool has_pattern;
uniform sampler2D pattern: repeat_enable;
uniform vec2 pattern_size;
uniform vec2 pattern_uv_offset;


bool similar_colors(vec4 c1, vec4 c2, float tol) {
	return (
		abs(c1.r - c2.r) <= tol
		&& abs(c1.g - c2.g) <= tol
		&& abs(c1.b - c2.b) <= tol
		&& abs(c1.a - c2.a) <= tol
	);
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
	if (similar_colors(original_color, old_color, tolerance))
		if (has_pattern)
			col = textureLod(pattern, UV * (size / pattern_size) + pattern_uv_offset, 0.0);
		else
			col = new_color;

	COLOR = mix(original_color, col, selection_color.a);
}
