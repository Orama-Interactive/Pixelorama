shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;
uniform sampler2D pattern : filter_nearest, repeat_enable;
uniform vec2 size;
uniform vec2 pattern_size;
uniform vec2 pattern_uv_offset;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
	col = textureLod(pattern, UV * (size / pattern_size) + pattern_uv_offset, 0.0);

	COLOR = mix(original_color, col, selection_color.a);
}
