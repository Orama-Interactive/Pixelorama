shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform vec4 first_color : hint_color = vec4(1.0);
uniform vec4 second_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = floor(UV * tex_size) / (tex_size - 1.0);
	uv -= 0.5;
	float rotated = uv.x * cos(radians(angle)) - uv.y * sin(radians(angle)); 
	float fixed_position = position - 0.5;
	float fixed_size = (size / 2.0) + 0.5;
	
	float pos = smoothstep((1.0 - fixed_size) + fixed_position, fixed_size + fixed_position, rotated);
	vec4 output = mix(first_color, second_color, pos); 
	COLOR = mix(original_color, output, selection_color.a);
}
