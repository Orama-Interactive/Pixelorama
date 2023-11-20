shader_type canvas_item;
render_mode unshaded;

uniform sampler2D map;  // GradientTexture
uniform sampler2D selection;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = original_color;
	float value = (0.2126 * original_color.r) + (0.7152 * original_color.g) + (0.0722 * original_color.b);
	vec4 gradient_color = texture(map, vec2(value, 0.0));
	output.rgb = gradient_color.rgb;
	output.a *= gradient_color.a;

	COLOR = mix(original_color, output, selection_color.a);
}
