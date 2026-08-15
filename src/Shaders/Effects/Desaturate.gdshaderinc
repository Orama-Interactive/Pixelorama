// @uniform bool red = true;
// @uniform bool green = true;
// @uniform bool blue = true;
// @uniform bool alpha = false;

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

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	bool red,
	bool green,
	bool blue,
	bool alpha
) {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(source_texture, uv);
	vec4 selection_color = texture(selection, uv);

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
	    return vec4(output.rgb, ltosChannel(lum));
	} else {
        return vec4(output.rgb, original_color.a);
	}
}