// Authored by Variable (6 May 2022)
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D map_texture : filter_nearest;  // The map texture
uniform bool wrap_around = false;  // Wraps the coordinates if offset causes them out of area.
uniform bool include_alpha = false;  // If true, the alpha from the map colors are used as well.
uniform bool use_pixel_position_by_default = false;
// When true shows the indices as colors.
uniform bool show_intermediate_texture = false;
uniform ivec2 offset = ivec2(0);  // Offset value for the lookup coordinates in pixels
// Scale value for the lookup coordinates in multiples of map_texture size.
uniform vec2 scale = vec2(1.0);

// (begin DESCRIPTION)
// The Red and Green values (0-255) of your tool's color will be treated as coordinates X and Y
// instead of as regular R and G color components.
// When you draw, the X and Y components are looked up in the "Map Texture", and color at that
// position in the Map Texture is displayed
//
// If "Use pixel position by default" is enabled, then for transparent colors,
// their "Canvas position" will be looked up in the "Map Texture" instead of the color.
//
// Optionally you can also set some offset to the returned color i-e (X, Y) + Offset
//
// If "Include alpha" is enabled, the alpha from the "Map Texture's" color is used as well.
//
// "Show intermediate texture" returns the image with R and G components equal to the X and Y
// coordinates of the color to be used for lookup (After applying all the offset/wrap/zoom
// calculations). Note that This can currently only show X and Y coordinates that are less than 255.
// (end DESCRIPTION)
void fragment() {
	vec4 coordinate = texture(TEXTURE, UV);
	vec2 image_size = vec2(textureSize(TEXTURE, 0));
	bool should_import_alpha = include_alpha;
	vec2 anti_normalize_vector = vec2(255.0, 255.0);
	if (use_pixel_position_by_default && COLOR.a < 0.0001) {
		should_import_alpha = true;
		coordinate = vec4(UV.r, UV.g, 0, 1);
		anti_normalize_vector = image_size;
	}

	vec2 map_size = vec2(textureSize(map_texture, 0));
	vec2 offset_lookup_uv = ((coordinate.rg * anti_normalize_vector) - vec2(offset)) / map_size;

	vec2 zoom_center = (vec2(0.5) * (image_size / map_size)) - (vec2(offset) / map_size);
	vec2 zoomed_lookup_uv = ((offset_lookup_uv - zoom_center) / scale) + zoom_center;
	if (wrap_around) {
		zoomed_lookup_uv = fract(zoomed_lookup_uv);
	}
	if (show_intermediate_texture) {
		// While we can still do computations for numbers greater than 255 like when
		// use_pixel_position_by_default is true, But for previewing, using
		// Color as X, Y places a limitation that we can not display indices greater than 255.
		vec2 lookup_coord_normalized = (zoomed_lookup_uv * map_size) / vec2(255.0, 255.0);
		COLOR.rgb = vec3(lookup_coord_normalized.x, lookup_coord_normalized.y, 0.0);
		if (use_pixel_position_by_default && COLOR.a < 0.0001) {
			COLOR.a = 1.0;
		}
		if (
			lookup_coord_normalized.x < 0.0
			|| lookup_coord_normalized.x > 1.0
			|| lookup_coord_normalized.y < 0.0
			|| lookup_coord_normalized.y > 1.0
		) {
			COLOR.rgba = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
	else {
		vec4 index_color = texture(map_texture, zoomed_lookup_uv);
		COLOR.rgb = index_color.rgb;
		if (should_import_alpha) {
			COLOR.a = index_color.a;
		}
	}
}
