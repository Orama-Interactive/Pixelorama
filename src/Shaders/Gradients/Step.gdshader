shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform int steps : hint_range(2, 100) = 2;


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = vec4(0.0);

	float pivot = (position / size) + 0.5;
	vec2 uv = UV - 0.5;
	float angle_cos = cos(radians(angle));
	float angle_sin = sin(radians(angle));
	float rotated = uv.x * angle_cos - uv.y * angle_sin; 
	rotated /= abs(angle_cos) + abs(angle_sin);
	rotated /= size;
	for(int i = -1; i <= steps; i++)
	{
		float percentage = float(i) / float(steps) - pivot;
		float color_percentage = float(i) / float(steps - 1);
		color_percentage = clamp(color_percentage, 0.0, 1.0);
		vec4 grad_color = mix(first_color, second_color, color_percentage);
		float unit_perc = (1.0 / float(steps));
		float pos = step(percentage, rotated) - step(percentage + unit_perc, rotated);
		if (i == -1) {
			pos = 1.0 - step(percentage + unit_perc, rotated);
		}
		else if (i == steps) {
			pos = step(percentage, rotated);
		}
		output += grad_color * pos;
	}
	COLOR = mix(original_color, output, selection_color.a);
}
