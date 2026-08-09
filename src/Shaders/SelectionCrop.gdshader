// This shader erases all content at positions that do not have a value in selection texture.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	// Crop text rendered outside selection
	COLOR = mix(vec4(0.0), original_color, selection_color.a);
}