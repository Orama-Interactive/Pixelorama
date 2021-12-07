shader_type canvas_item;
render_mode unshaded;

uniform vec4 old_color : hint_color;
uniform vec4 new_color : hint_color;
uniform sampler2D selection;
uniform bool has_selection;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;

	if (original_color == old_color)
		col = new_color;

	vec4 output;
	if (has_selection)
		output = mix(original_color.rgba, col, selection_color.a);
	else
		output = col;

	COLOR = output;
}