shader_type canvas_item;

uniform sampler2D dither_texture;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 image_size = vec2(64.0);
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform int dither_steps : hint_range(2, 257) = 5;
uniform int pixel_size : hint_range(2, 16) = 2;


void fragment() {
	float pivot = (position / size) + 0.5;
	vec2 uv = UV - 0.5;
	float angle_cos = cos(radians(angle));
	float angle_sin = sin(radians(angle));
	float rotated = uv.x * angle_cos - uv.y * angle_sin; 
	rotated /= abs(angle_cos) + abs(angle_sin);
	rotated /= size;
	COLOR = vec4(0.0);
	vec4 dither_value = texture(dither_texture, uv * (image_size / float(pixel_size)));

	for(int i = -1; i <= dither_steps; i++) {
		float percentage = float(i) / float(dither_steps) - pivot;
		float unit_perc = (1.0 / float(dither_steps));
		float pos = step(percentage, rotated) - step(percentage + unit_perc, rotated);
		float dithered = step(percentage, dither_value.r - pivot);
		if (i == dither_steps - 1) {
			dithered = 0.0;
		}
		else if (i == -1) {
			pos = 1.0 - step(percentage + unit_perc, rotated);
		}
		else if (i == dither_steps) {
			pos = step(percentage, rotated);
		}
		vec4 grad_color = first_color * (dithered) + second_color * (1.0 - dithered);
		COLOR += grad_color * pos;
	}
}
