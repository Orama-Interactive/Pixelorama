// @uniform sampler2D gradient_map : source_color, filter_nearest, repeat_disable;  // GradientTexture


vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	sampler2D gradient_map
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	vec4 output = original_color;
	float value = (0.2126 * original_color.r) + (0.7152 * original_color.g) + (0.0722 * original_color.b);
	vec4 gradient_color = texture(gradient_map, vec2(value, 0.5));
	output.rgb = gradient_color.rgb;
	output.a *= gradient_color.a;

	return mix(original_color, output, selection_color.a);
}
