// @uniform int origin : hint_range(0, 64, 1) = 32;
// @uniform int iso_step : hint_range(0, 16, 1) = 2;
// @uniform int deadzone : hint_range(0, 16, 1);

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	int origin,
	int iso_step,
	int deadzone,
) {
	if (iso_step == 0) {
		return texture(source_texture, uv);
	}
	vec2 pixel_size = 1.0 / vec2(textureSize(source_texture, 0));
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);
	float normalized_origin = float(origin) * pixel_size.x;
	float normalized_deadzone = float(deadzone) * pixel_size.x;
	float dist = distance(uv.x, normalized_origin);
	float shifted_dist = max(0.0, dist - normalized_deadzone);
	vec2 tex_size = 1.0 / pixel_size;
	float ratio = tex_size.x / tex_size.y;
	uv.y += shifted_dist / float(iso_step) * ratio;

	vec4 output = texture(source_texture, uv);
	output.a = min(step(uv.x, 1.0) * step(0.0, uv.x), output.a); // Remove left and right edges
	output.a = min(step(uv.y, 1.0) * step(0.0, uv.y), output.a); // Remove up and bottom edges
	return mix(original_color.rgba, output, selection_color.a);
}
