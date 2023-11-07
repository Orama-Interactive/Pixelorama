shader_type canvas_item;
render_mode unshaded;

uniform bool red;
uniform bool blue;
uniform bool green;
uniform bool alpha;
uniform sampler2D selection;

float stolChannel(float x) {
	return (x < 0.04045) ? (x / 12.92) : pow((x + 0.055) / 1.055, 2.4);
}

vec3 standardToLinear(vec3 c) {
	return vec3(
		stolChannel(c.r),
		stolChannel(c.g),
		stolChannel(c.b));
}

float ltosChannel(float x) {
	return (x > 0.0031308) ? (pow(x, 1.0 / 2.4) * 1.055 - 0.055) : (x * 12.92);
}

vec3 linearToStandard(vec3 c) {
	return vec3(
		ltosChannel(c.r),
		ltosChannel(c.g),
		ltosChannel(c.b));
}

float luminance(vec3 lin) {
	return 0.21264935 * lin.r
	     + 0.71516913 * lin.g
		 + 0.07218152 * lin.b;
}

void fragment() {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	// Transform from standard RGB to linear RGB.
	vec3 std = original_color.rgb;
	vec3 lin = standardToLinear(std);

	// Find the y component of linear RGB to XYZ transformation.
	float lum = luminance(lin);
	vec3 des = vec3(
		red ? lum : lin.r,
		green ? lum : lin.g,
		blue ? lum : lin.b);
	vec3 stdPrime = linearToStandard(des);

	vec3 output = mix(original_color.rgb, stdPrime, selection_color.a);

    if (alpha) {
	    COLOR = vec4(output.rgb, ltosChannel(lum));
	} else {
        COLOR = vec4(output.rgb, original_color.a);
	}
}