shader_type canvas_item;
render_mode unshaded;

uniform float size = 10.0;
uniform float alpha = 1.0;
uniform vec4 color1 : hint_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 color2 : hint_color = vec4(1.0);
uniform vec2 offset = vec2(0.0);
uniform vec2 scale = vec2(0.0);
uniform vec2 rect_size = vec2(0.0);
uniform bool follow_movement = false;
uniform bool follow_scale = false;

void fragment() {
	vec2 ref_pos = FRAGCOORD.xy;
	if (follow_scale) {
		if (!follow_movement)
			ref_pos /= scale;
		else
			ref_pos = UV * rect_size;
	}
	else if (follow_movement)
		ref_pos -= mod(offset, size * 2.0);
	
	vec2 pos = mod(ref_pos, size * 2.0);
	bool c1 = any(lessThan(pos, vec2(size)));
	bool c2 = any(greaterThanEqual(pos, vec2(size)));
	float c = c1 && c2 ? 1.0: 0.0;
	COLOR = mix(color1, color2, c);
	COLOR.a = alpha;
}
