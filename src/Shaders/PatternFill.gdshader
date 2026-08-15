shader_type texture_blit;
render_mode blend_disabled;

uniform sampler2D source_texture0 : hint_blit_source0, filter_nearest;

uniform sampler2D selection : filter_nearest, repeat_disable;
uniform sampler2D pattern : filter_nearest, repeat_enable;
uniform vec2 size;
uniform vec2 pattern_size;
uniform vec2 pattern_uv_offset;

void blit() {
	vec4 original_color = texture(source_texture0, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
	col = textureLod(pattern, UV * (size / pattern_size) + pattern_uv_offset, 0.0);

	COLOR0 = mix(original_color, col, selection_color.a);
}
