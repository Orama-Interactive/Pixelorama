// Authored by Variable (6 May 2022)
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D map_texture : filter_nearest;  // The map texture

// begin DESCRIPTION:
// Apply this shader to the base texture.
// The Red and Green values (0-255) of tool colors will be considered as indices instead of
// colors. These indices will then be used to recieve Colors from the "Map Texture" and displayed.
// end DESCRIPTION:
void fragment(){
	vec4 col = texture(TEXTURE, UV);
	vec2 map_size = vec2(textureSize(map_texture, 0));
	vec2 lookup_uv = vec2(round(col.x * 255.0)/(map_size.x), round(col.y * 255.0)/(map_size.y));
	vec4 index_color = texture(map_texture, lookup_uv);
	COLOR = index_color;
}
