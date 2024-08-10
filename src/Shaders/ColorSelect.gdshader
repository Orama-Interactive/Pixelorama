shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest, hint_default_black;
uniform vec4 color;
uniform float tolerance : hint_range(0.0, 1.0);
uniform int operation = 0; // 0 = add, 1 = subtract, 2 = intersect

bool similar_colors(vec4 c1, vec4 c2, float tol) {
	return (
		abs(c1.r - c2.r) <= tol
		&& abs(c1.g - c2.g) <= tol
		&& abs(c1.b - c2.b) <= tol
		&& abs(c1.a - c2.a) <= tol
	);
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);

	vec4 col = texture(selection, UV);
	if (col.rgb == vec3(0.0))
		col.a = 0.0;

	if (similar_colors(original_color, color, tolerance))
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
