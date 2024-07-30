/*
Shader from Godot Shaders - the free shader library.
https://godotshaders.com/shader/pixelate-2/

This shader is under MIT license
*/
shader_type canvas_item;
render_mode unshaded;

uniform uvec2 pixel_size = uvec2(4);
uniform sampler2D selection : filter_nearest;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	ivec2 size = textureSize(TEXTURE, 0);
	int xRes = size.x;
	int yRes = size.y;
	float xFactor = float(xRes) / float(pixel_size.x);
	float yFactor = float(yRes) / float(pixel_size.y);
	float grid_uv_x = round(UV.x * xFactor) / xFactor;
	float grid_uv_y = round(UV.y * yFactor) / yFactor;
	vec4 pixelated_color = texture(TEXTURE, vec2(grid_uv_x, grid_uv_y));

	COLOR = mix(original_color.rgba, pixelated_color, selection_color.a);
}
