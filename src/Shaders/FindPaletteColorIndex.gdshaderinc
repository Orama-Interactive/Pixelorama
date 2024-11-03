int find_index(vec4 color, int n_of_colors, sampler2D palette_texture) {
	int color_index = 0;
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
	return color_index;
}
