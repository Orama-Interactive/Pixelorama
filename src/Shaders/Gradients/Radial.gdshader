shader_type canvas_item;

uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform vec2 ratio = vec2(1.0);
uniform float size : hint_range(0.01, 2.0) = 1.0;

void fragment() {
	vec2 uv = (UV / ratio) * radius;
	float fixed_size = size + 0.5;
	float smooth_dist = smoothstep(1.0 - fixed_size, fixed_size, distance(uv, center * radius));
	COLOR = second_color * smooth_dist + (1.0 - smooth_dist) * first_color;
}
