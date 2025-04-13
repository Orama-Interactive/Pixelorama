// Maps the color of the input to the nearest color in the selected palette.
// Similar to Krita's Palettize filter
shader_type canvas_item;
render_mode unshaded;

#include "res://src/Shaders/FindPaletteColorIndex.gdshaderinc"
uniform sampler2D palette_texture : filter_nearest;
uniform sampler2D selection : filter_nearest;

vec4 swap_color(vec4 color) {
	if (color.a <= 0.01) {
		return color;
	}

	int n_of_colors = textureSize(palette_texture, 0).x;
	int color_index = find_index(color, n_of_colors, palette_texture);
	return texelFetch(palette_texture, ivec2(color_index, 0), 0);
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 color = swap_color(original_color);
	COLOR = mix(original_color.rgba, color, selection_color.a);
}
