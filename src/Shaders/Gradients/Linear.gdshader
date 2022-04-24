shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.5, 2.5) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 output = texture(TEXTURE, UV);

	float pivot = position + 0.5;
	vec2 uv = UV - pivot;
	float rotated = uv.x * cos(radians(angle)) - uv.y * sin(radians(angle)); 
	float fixed_size = size + 0.5;
	float pos = smoothstep((1.0 - fixed_size) + position, fixed_size + 0.0001 + position, rotated + pivot);
	output = mix(first_color, second_color, pos); 
	COLOR = mix(original_color, output, selection_color.a);
}
