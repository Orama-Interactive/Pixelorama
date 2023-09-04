shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : hint_default_black;
uniform vec4 color;
uniform float similarity_percent : hint_range(0.0, 100.0);
uniform int operation = 0; // 0 = add, 1 = subtract, 2 = intersect

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	float diff = distance(original_color, color);
	float similarity = abs(2.0 - ((similarity_percent/100.0) * 2.0));
	vec4 col = texture(selection, UV);
	if (col.rgb == vec3(0.0))
		col.a = 0.0;

	if (diff <= similarity)
	{
		if (operation == 0)
			col = vec4(1.0);
		else if (operation == 1)
			col = vec4(0.0);
	}
	else
		if (operation == 2)
			col = vec4(0.0);

	COLOR = col;
}
