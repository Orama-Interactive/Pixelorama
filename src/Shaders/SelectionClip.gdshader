shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;

void fragment() {
	vec4 selection_color = texture(selection, UV);
	// Not using equality here because this alternative was recommended in Godot warning instead.
	if (abs(selection_color.a) < 0.00001){
		COLOR = vec4(0.0);
	}
}