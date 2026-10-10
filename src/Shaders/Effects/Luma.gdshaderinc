// formula from "https://stackoverflow.com/a/596241"
// see "https://en.wikipedia.org/wiki/Luma_(video)" for detailed information.
vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection
) {
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	float avg = (
		(0.2126 * original_color.r) + (0.7152 * original_color.g) + (0.0722 * original_color.b)
	);
	vec4 luma = vec4(vec3(avg), 1.0);
	if (original_color.a < 0.0001) {
		luma.a = 0.0;
	}
	return mix(original_color.rgba, luma, selection_color.a);
}