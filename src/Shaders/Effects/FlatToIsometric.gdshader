shader_type canvas_item;

uniform int origin : hint_range(0, 64, 1) = 32;
uniform int iso_step : hint_range(0, 16, 1) = 2;
uniform int deadzone : hint_range(0, 16, 1);
uniform sampler2D selection : filter_nearest;

void fragment() {
	if (iso_step != 0) {
		vec4 original_color = texture(TEXTURE, UV);
		vec4 selection_color = texture(selection, UV);
		vec2 uv = UV;
		float normalized_origin = float(origin) * TEXTURE_PIXEL_SIZE.x;
		float normalized_deadzone = float(deadzone) * TEXTURE_PIXEL_SIZE.x;
		float dist = distance(uv.x, normalized_origin);
		float shifted_dist = max(0.0, dist - normalized_deadzone);
		vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
		float ratio = tex_size.x / tex_size.y;
		uv.y += shifted_dist / float(iso_step) * ratio;
		vec4 final_color = texture(TEXTURE, uv);
		COLOR = mix(original_color.rgba, final_color, selection_color.a);
	}
}
