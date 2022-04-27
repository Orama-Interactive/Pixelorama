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
	vec4 output = texture(TEXTURE, UV);

	vec2 uv = UV * 2.0 - 1.0;
	uv -= (center * 2.0) - vec2(1.0);
	uv *= radius;
	uv /= ratio;
	float polar_uv = length(uv);
	float step_v = 1.0 / float(steps);
	float step_v_m = 1.0 / float(steps - 1);
	float uv_stepped = floor(polar_uv / step_v) * step_v_m;  // Similar to GDScript's stepify
	uv_stepped = clamp(uv_stepped, 0.0, 1.0);
	vec4 grad_color = mix(first_color, second_color, uv_stepped);
	output = grad_color;
	
	COLOR = mix(original_color, output, selection_color.a);
}
