shader_type canvas_item;

uniform vec4 silhouette_color;
uniform bool show_silhouette;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (show_silhouette && color.a > 0.0) {
		color.rgb = silhouette_color.rgb;
		COLOR.rgb = color.rgb;
	} else {
		COLOR = color;
	}
}
