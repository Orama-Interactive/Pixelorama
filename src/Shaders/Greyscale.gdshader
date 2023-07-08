shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    COLOR = texture(screen_texture, SCREEN_UV);
	// formula from "https://stackoverflow.com/a/596241"
    float avg = ((0.2126 * COLOR.r) + (0.7152 * COLOR.g) + (0.0722 * COLOR.b));
    COLOR.rgb = vec3(avg);
}