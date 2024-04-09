// Maps the color of the input to the nearest color in the selected palette.
// Similar to Krita's Palettize filter
shader_type canvas_item;

uniform sampler2D palette_texture : filter_nearest;
uniform sampler2D selection;

vec4 swap_color(vec4 color) {
	if (color.a <= 0.01) {
		return color;
	}
	int color_index = 0;
	int n_of_colors = textureSize(palette_texture, 0).x;
	float smaller_distance = distance(color, texture(palette_texture, vec2(0.0)));
	for (int i = 0; i <= n_of_colors; i++) {
		vec2 uv = vec2(float(i) / float(n_of_colors), 0.0);
		vec4 palette_color = texture(palette_texture, uv);
		float dist = distance(color, palette_color);
		if (dist < smaller_distance) {
			smaller_distance = dist;
			color_index = i;
		}
	}
	return texture(palette_texture, vec2(float(color_index) / float(n_of_colors), 0.0));
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 color = swap_color(original_color);
	COLOR = mix(original_color.rgba, color, selection_color.a);
}

