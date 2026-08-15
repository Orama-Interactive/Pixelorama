// Maps the color of the input to the nearest color in the selected palette.
// Similar to Krita's Palettize filter
#include "res://src/Shaders/FindPaletteColorIndex.gdshaderinc"
// @uniform sampler2D palette_texture : filter_nearest, repeat_disable;

vec4 swap_color(vec4 color, sampler2D palette_texture) {
	if (color.a <= 0.01) {
		return color;
	}

	int n_of_colors = textureSize(palette_texture, 0).x;
	int color_index = find_index(color, n_of_colors, palette_texture);
	return texelFetch(palette_texture, ivec2(color_index, 0), 0);
}

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	sampler2D palette_texture
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec4 color = swap_color(original_color, palette_texture);
	return mix(original_color.rgba, color, selection_color.a);
}
