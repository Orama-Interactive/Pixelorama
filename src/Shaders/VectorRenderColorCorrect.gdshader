shader_type canvas_item;
render_mode unshaded;
//render_mode unshaded, blend_premul_alpha;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb = clamp(COLOR.rgb / COLOR.a, 0, 1);
}