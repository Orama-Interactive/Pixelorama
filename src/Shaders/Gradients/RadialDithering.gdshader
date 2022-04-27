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
uniform int dither_steps : hint_range(2, 100) = 5;
uniform int pixel_size : hint_range(2, 16) = 2;

const float PI = 3.1415926535;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = vec4(0.0);
	vec2 uv = UV * 2.0 - 1.0;
	uv -= (center * 2.0) - vec2(1.0);
	uv *= radius;
	uv /= ratio;
	vec2 polar_uv = vec2(atan(uv.x, uv.y), length(uv));
	vec4 dither_value = texture(dither_texture, UV * (image_size / float(pixel_size)));

	for(int i = 0; i < dither_steps; i++) {
		float percentage = float(i) / float(dither_steps);
		float pos = step(percentage, polar_uv.y) - step(percentage + (1.0 / float(dither_steps)), polar_uv.y);
		float dithered = step(percentage, dither_value.r);
		if (i == dither_steps - 1) {
			dithered = 0.0;
		}
		vec4 grad_color = first_color * (dithered) + second_color * (1.0 - dithered);
		output += grad_color * pos;
	}
	
	COLOR = mix(original_color, output, selection_color.a);
}
