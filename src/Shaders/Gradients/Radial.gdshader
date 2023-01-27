shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform sampler2D gradient_texture;
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = floor(UV * tex_size) / (tex_size - 1.0);
	uv /= radius;
	float smooth_dist = smoothstep(0.0, 1.0, distance(uv, center / radius));
	vec4 output = texture(gradient_texture, vec2(smooth_dist));
	output = mix(original_color, output, output.a);
	COLOR = mix(original_color, output, selection_color.a);
}
