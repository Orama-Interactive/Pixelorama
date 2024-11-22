int find_index(vec4 color, int n_of_colors, sampler2D palette_texture) {
	int color_index = 0;
	float smaller_distance = distance(color, texture(palette_texture, vec2(0.0)));
	for (int i = 0; i <= n_of_colors; i++) {
		vec4 palette_color = texelFetch(palette_texture, ivec2(i, 0), 0);
		float dist = distance(color, palette_color);
		if (dist < smaller_distance) {
			smaller_distance = dist;
			color_index = i;
		}
	}
	return color_index;
}
