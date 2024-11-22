shader_type canvas_item;
render_mode unshaded;

const float EPSILON = 0.0001;

uniform sampler2D palette_texture : filter_nearest;
uniform sampler2D indices_texture : filter_nearest;

void fragment() {
	float index = texture(indices_texture, UV).r * 255.0;
	if (index <= EPSILON) { // If index is zero, make it transparent
		COLOR = vec4(0.0);
	}
	else {
		float n_of_colors = float(textureSize(palette_texture, 0).x);
		index -= 1.0;
		float index_normalized = index / n_of_colors;
		if (index < n_of_colors) {
			COLOR = texelFetch(palette_texture, ivec2(int(index), 0), 0);
		}
		else {
			// If index is bigger than the size of the palette, make it transparent.
			// This happens when switching to a palette, where the previous palette was bigger
			// than the newer one, and the current index is out of bounds of the new one.
			COLOR = vec4(0.0);
		}
	}
}
