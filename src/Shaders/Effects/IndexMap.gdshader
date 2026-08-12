// Authored by Variable (6 May 2022)
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D map_texture : filter_nearest;  // The map texture
uniform ivec2 offset = ivec2(0); // Offset value for the lookup coordinates in pixels
// If true, the aplha from the map colors are used as well.
uniform bool use_pixel_position_for_transparent_colors = false;
// If true, the aplha from the map colors are used as well.
uniform bool import_alpha_values = false;

// (begin DESCRIPTION)
// The Red and Green values (0-255) of your tool's color will be treated as coordinates X and Y
// instead of as regular R and G color components.
// When you draw, the X and Y components are looked up in the "Map Texture", and color at that
// position in the Map Texture is displayed
// If "Use pixel position for transparent colors" is enabled, then for transparent colors,
// their "Canvas position" will be looked up in the "Map Texture" instead of the color.
// Optionally you can also set some offset to the returned color i-e (X, Y) + Offset
// If "Import alpha values" is enabled, the aplha from the "Map Texture's" color is used as well.
// (end DESCRIPTION)
void fragment() {
	vec4 coordinate = texture(TEXTURE, UV);
	vec2 image_size = vec2(textureSize(TEXTURE, 0));
	bool should_import_alpha = import_alpha_values;
	vec2 max_coordinate_vector = vec2(255.0, 255.0);
	if (use_pixel_position_for_transparent_colors && COLOR.a < 0.0001) {
		should_import_alpha = true;
		coordinate = vec4(UV.r, UV.g, 0, 1);
		max_coordinate_vector = image_size;
	}

	vec2 map_size = vec2(textureSize(map_texture, 0));
	vec2 lookup_uv = (coordinate.xy * max_coordinate_vector) / (map_size);
	vec2 offset_uv = vec2(offset) / map_size;

	vec4 index_color = texture(map_texture, lookup_uv + offset_uv);
	COLOR.rgb = index_color.rgb;
	if (should_import_alpha) {
		COLOR.a = index_color.a;
	}
}
