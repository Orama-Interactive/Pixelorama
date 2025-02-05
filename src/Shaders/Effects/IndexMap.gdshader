// Authored by Variable (6 May 2022)
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D map_texture : filter_nearest;  // The map texture
uniform bool include_alpha = false;

// (begin DESCRIPTION)
// The Red and Green values (0-255) of tool color will be treated as an x and y position
// respectively instead of color components.
// When you draw, color will be taken from the x-y position in the "Map Texture".
// (end DESCRIPTION)
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 map_size = vec2(textureSize(map_texture, 0));
	vec2 lookup_uv = vec2(round(col.x * 255.0)/(map_size.x), round(col.y * 255.0)/(map_size.y));
	vec4 index_color = texture(map_texture, lookup_uv);
	COLOR.rgb = index_color.rgb;
	if (include_alpha) {
		COLOR.a = index_color.a;
	}
}
