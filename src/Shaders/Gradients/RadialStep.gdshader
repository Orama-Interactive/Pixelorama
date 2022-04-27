shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform vec2 ratio = vec2(1.0);
uniform int steps : hint_range(2, 257) = 2;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = vec4(0.0);
	vec2 uv = UV * 2.0 - 1.0;
	uv -= (center * 2.0) - vec2(1.0);
	uv *= radius;
	uv /= ratio;
	float polar_uv = length(uv);
	for(int i = 0; i < steps; i++)
	{
		float percentage = float(i) / float(steps);
		float color_percentage = float(i) / float(steps - 1);
		vec4 grad_color = mix(first_color, second_color, color_percentage);
		float pos = step(percentage, polar_uv) - step(percentage + (1.0 / float(steps)), polar_uv);
		output += grad_color * pos;
	}
	
	COLOR = mix(original_color, output, selection_color.a);
}
