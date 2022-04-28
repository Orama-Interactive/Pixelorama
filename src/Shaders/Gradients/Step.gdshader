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

	float pivot = position / size;
	vec2 uv = UV - 0.5;
	float angle_cos = cos(radians(angle));
	float angle_sin = sin(radians(angle));
	float rotated = uv.x * angle_cos - uv.y * angle_sin; 
	rotated /= abs(angle_cos) + abs(angle_sin);
	rotated /= size;
	rotated -= pivot - 0.5;
	float step_v = 1.0 / float(steps);
	float step_v_m = 1.0 / float(steps - 1);
	float rotated_stepped = floor(rotated / step_v) * step_v_m;  // Similar to GDScript's stepify
	rotated_stepped = clamp(rotated_stepped, 0.0, 1.0);
	vec4 output = mix(first_color, second_color, rotated_stepped);

	COLOR = mix(original_color, output, selection_color.a);
}
