shader_type canvas_item;

uniform bool monochrome = false;
// Modulate doesnt seem to affect the shader when monochrome is true
uniform vec4 monchrome_color : source_color;
uniform float clamping : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	// get the greyscale based on the brightest channel
	float greyscale = max(max(color.r, color.g), color.b);
	
	if (greyscale < clamping) {
		COLOR.a = 0.0;
	}
	if (monochrome) {
		COLOR.rgb = monchrome_color.rgb;
	}
}
