shader_type canvas_item;
render_mode unshaded;

uniform sampler2D dither_texture;
uniform sampler2D selection;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 image_size = vec2(64.0);
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform vec2 ratio = vec2(1.0);
uniform float size : hint_range(0.01, 2) = 1.0;
uniform int dither_steps : hint_range(2, 100) = 5;
uniform int pixel_size : hint_range(2, 16) = 2;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 uv = UV * 2.0 - 1.0;
	uv -= (center * 2.0) - vec2(1.0);
	uv *= radius;
	uv /= ratio;
	vec4 dither_value = texture(dither_texture, UV * (image_size / float(pixel_size)));

	float polar_uv = length(uv);
	float step_v = 1.0 / float(dither_steps);
	float step_v_m = 1.0 / float(dither_steps - 1);
	float uv_stepped = floor(polar_uv / step_v) * step_v_m;  // Similar to GDScript's stepify
	if (uv_stepped > 0.0) {
		// Size should not affect the center, only the steps
		polar_uv /= size;
		uv_stepped = floor(polar_uv / step_v) * step_v_m;
		uv_stepped += step_v_m * step(1.0, (1.0 - uv_stepped));
	}
	float dithered = step(uv_stepped, dither_value.r);
	vec4 output = first_color * dithered + second_color * (1.0 - dithered);
	
	COLOR = mix(original_color, output, selection_color.a);
}
