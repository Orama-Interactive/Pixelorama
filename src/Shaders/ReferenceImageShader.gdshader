shader_type canvas_item;

// This shader gets applied to every single reference image.


uniform bool monochrome = false;
// Used because modulate does not work when monochrome is true
uniform vec4 monchrome_color : source_color;
// Clamp the color by using the greyscale of the image to identify the brightness of each pixel
uniform float clamping : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	// The original color
	vec4 color = texture(TEXTURE, UV);
	// Get the greyscale based on the brightest channel
	float greyscale = max(max(color.r, color.g), color.b);
	// Dont Use Alpha Channel past this statement!
	if (greyscale < clamping) COLOR.a = 0.0;
	// If we want the image to be onochrome we just set that pixels rgb color.
	if (monochrome) COLOR.rgb = monchrome_color.rgb;
}
