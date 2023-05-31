shader_type canvas_item;
render_mode unshaded;

uniform sampler2D lut;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float index = 0.0;
	if (color.a > 0.0) {
		for (int i = 0; i < 256; i++) {
			vec4 c = texture(lut, vec2((float(i) + 0.5) / 256.0, 0.5));
			if (c.rgb == color.rgb) {
				index = float(i) / 255.0;
				break;
			}
		}
	}
	COLOR = vec4(vec3(index), 1.0);
}