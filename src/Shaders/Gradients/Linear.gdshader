shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform sampler2D gradient_texture;
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = UV - 0.5;
	uv = floor(uv * tex_size) / (tex_size - 1.0);
	float angle_cos = cos(radians(angle));
	float angle_sin = sin(radians(angle));
	float rotated_uv = uv.x * angle_cos - uv.y * angle_sin; 
	rotated_uv /= abs(angle_cos) + abs(angle_sin);
	rotated_uv -= position - 0.5;
	vec4 output = texture(gradient_texture, vec2(rotated_uv));
	output = mix(original_color, output, output.a);
	COLOR = mix(original_color, output, selection_color.a);
}
