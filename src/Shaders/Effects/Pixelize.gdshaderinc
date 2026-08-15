/*
Shader from Godot Shaders - the free shader library.
https://godotshaders.com/shader/pixelate-2/

This shader is under MIT license
*/
// @uniform uvec2 pixel_size = uvec2(4);

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	uvec2 pixel_size
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	ivec2 size = textureSize(source_texture, 0);
	int xRes = size.x;
	int yRes = size.y;
	float xFactor = float(xRes) / float(pixel_size.x);
	float yFactor = float(yRes) / float(pixel_size.y);
	float grid_uv_x = round(uv.x * xFactor) / xFactor;
	float grid_uv_y = round(uv.y * yFactor) / yFactor;
	vec4 pixelated_color = texture(source_texture, vec2(grid_uv_x, grid_uv_y));

	return mix(original_color.rgba, pixelated_color, selection_color.a);
}
