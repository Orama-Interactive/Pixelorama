shader_type canvas_item;
render_mode unshaded;

#include "res://src/Shaders/Effects/Rotation/CommonRotation.gdshaderinc"


void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE; // Texture size in real pixel coordinates
	vec2 pixelated_uv = floor(UV * tex_size) / (tex_size - 1.0); // Pixelate UV to fit resolution
	float ratio = tex_size.x / tex_size.y; // Resolution ratio

	vec2 rotated_uv = rotate(pixelated_uv, ratio);
	vec4 rotated_color = texture(TEXTURE, rotated_uv); // Rotated image
	COLOR = mix_rotated_and_original(rotated_color, original, UV, rotated_uv, TEXTURE_PIXEL_SIZE);
}
