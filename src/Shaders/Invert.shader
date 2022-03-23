shader_type canvas_item;
render_mode unshaded;

uniform bool red;
uniform bool blue;
uniform bool green;
uniform bool alpha;
uniform sampler2D selection;
uniform bool affect_selection;
uniform bool has_selection;


void fragment() {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
    if (red)
        col.r = 1f - col.r;
    if (green)
        col.g = 1f - col.g;
    if (blue)
        col.b = 1f - col.b;
    if (alpha)
        col.a = 1f - col.a;

	vec4 output;
	if(affect_selection && has_selection)
		output = mix(original_color.rgba, col, selection_color.a);
	else
		output = col;

	COLOR = output;
}