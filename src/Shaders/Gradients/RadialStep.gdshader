shader_type canvas_item;

uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform vec2 ratio = vec2(1.0);
uniform int steps : hint_range(2, 257) = 2;

const float PI = 3.1415926535;

void fragment() {
	COLOR = vec4(0.0);
	vec2 uv = UV * 2.0 - 1.0;
	uv -= center - vec2(0.5);
	uv *= radius;
	uv /= ratio;
	vec2 polar_uv = vec2(atan(uv.x, uv.y), length(uv));
	for(int i = 0; i < steps; i++)
	{
		float percentage = float(i) / float(steps);
		float color_percentage = float(i) / float(steps - 1);
		vec4 grad_color = mix(first_color, second_color, color_percentage);
		float pos = step(percentage, polar_uv.y) - step(percentage + (1.0 / float(steps)), polar_uv.y);
		COLOR += grad_color * pos;
	}
}
