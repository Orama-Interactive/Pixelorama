// https://godotshaders.com/shader/gaussian-blur-functions-for-gles2/
// Licensed under MIT.
shader_type canvas_item;

// uniform_data blur_type type:: OptionButton [Xor's Gaussian Blur||Monk's Multi-Pass Gaussian Blur||NoDev's Single-Pass Gaussian Blur||NoDev's Multi-Pass Gaussian Blur]
uniform int blur_type : hint_range(0, 3, 1) = 0;
uniform int blur_amount = 16;
uniform float blur_radius = 1.0;
uniform vec2 blur_direction = vec2(1, 1);
uniform sampler2D selection : filter_nearest;

// Xor's gaussian blur function
// Link: https://xorshaders.weebly.com/tutorials/blur-shaders-5-part-2
// Defaults from: https://www.shadertoy.com/view/Xltfzj
//
// BLUR BLURRINESS (Default 8.0)
// BLUR ITERATIONS (Default 16.0 - More is better but slower)
// BLUR QUALITY (Default 4.0 - More is better but slower)
//
// Desc.: Don't have the best performance but will run on almost
// anything, although, if developing for mobile, is better to use
// 'texture_nodevgaussian(...) instead'.
vec4 texture_xorgaussian(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, int iterations, int quality) {
	vec2 radius = blurriness / (1.0 / pixel_size).xy;
	vec4 blurred_tex = texture(tex, uv);

	for(float d = 0.0; d < TAU; d += TAU / float(iterations)) {
		for(float i = 1.0 / float(quality); i <= 1.0; i += 1.0 / float(quality)) {
			vec2 directions = uv + vec2(cos(d), sin(d)) * radius * i;
			blurred_tex += texture(tex, directions);
		}
	}
	blurred_tex /= float(quality) * float(iterations) + 1.0;

	return blurred_tex;
}

// Experience-Monks' fast gaussian blur function
// Link: https://github.com/Experience-Monks/glsl-fast-gaussian-blur/
//
// BLUR ITERATIONS (Default 16.0 - More is better but slower)
// BLUR DIRECTION (Direction in which the blur is applied, use vec2(1, 0) for first pass and vec2(0, 1) for second pass)
//
// Desc.: ACTUALLY PRETTY SLOW but still pretty good for custom cinematic
// bloom effects, since this needs render 2 passes
vec4 texture_monksgaussian_multipass(sampler2D tex, vec2 uv, vec2 pixel_size, int iterations, vec2 direction) {
	vec4 blurred_tex = vec4(0.0);
	vec2 resolution = 1.0 / pixel_size;

	for (int i = 0; i < iterations; i++ ) {
		float size = float(iterations - i);

		vec2 off1 = vec2(1.3846153846) * (direction * size);
		vec2 off2 = vec2(3.2307692308) * (direction * size);

		blurred_tex += texture(tex, uv) * 0.2270270270;
		blurred_tex += texture(tex, uv + (off1 / resolution)) * 0.3162162162;
		blurred_tex += texture(tex, uv - (off1 / resolution)) * 0.3162162162;
		blurred_tex += texture(tex, uv + (off2 / resolution)) * 0.0702702703;
		blurred_tex += texture(tex, uv - (off2 / resolution)) * 0.0702702703;
	}

	blurred_tex /= float(iterations) + 1.0;

	return blurred_tex;
}

// u/_NoDev_'s gaussian blur function
// Discussion Link: https://www.reddit.com/r/godot/comments/klgfo9/help_with_shaders_in_gles2/
// Code Link: https://postimg.cc/7JDJw80d
//
// BLUR BLURRINESS (Default 8.0 - More is better but slower)
// BLUR RADIUS (Default 1.5)
// BLUR DIRECTION (Direction in which the blur is applied, use vec2(1, 0) for first pass and vec2(0, 1) for second pass)
//
// Desc.: Really fast and GOOD FOR MOST CASES, but might NOT RUN IN THE WEB!
// use 'texture_xorgaussian' instead if you found any issues.
vec4 texture_nodevgaussian_singlepass(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, float radius) {
	float n = 0.0015;
	vec4 blurred_tex = vec4(0);
	float weight;

	for (float i = -blurriness; i <= blurriness; i++) {
		float d = i / PI;
		vec2 anchor = vec2(cos(d), sin(d)) * radius * i;
		vec2 directions = uv + pixel_size * anchor;
		blurred_tex += texture(tex, directions) * n;
		if (i <= 0.0) {n += 0.0015; }
		if (i > 0.0) {n -= 0.0015; }
		weight += n;
	}

	float norm = 1.0 / weight;
	blurred_tex *= norm;
	return blurred_tex;
}

vec4 texture_nodevgaussian_multipass(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, vec2 direction) {
	float n = 0.0015;
	vec4 blurred_tex = vec4(0);
	float weight;

	for (float i = -blurriness; i <= blurriness; i++) {
		vec2 directions = uv + pixel_size * (direction * i);
		blurred_tex += texture(tex, directions) * n;
		if (i <= 0.0) {n += 0.0015; }
		if (i > 0.0) {n -= 0.0015; }
		weight += n;
	}

	float norm = 1.0 / weight;
	blurred_tex *= norm;
	return blurred_tex;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
	if (blur_type == 0) {
		vec4 xorgaussian = texture_xorgaussian(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(blur_amount), 16, 4);
		col = xorgaussian;
	}
	else if (blur_type == 1) {
		vec4 monksgaussian_multipass = texture_monksgaussian_multipass(TEXTURE, UV, TEXTURE_PIXEL_SIZE, blur_amount, blur_direction);
		col = monksgaussian_multipass;
	}
	else if (blur_type == 2) {
		vec4 nodevgaussian_singlepass = texture_nodevgaussian_singlepass(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(blur_amount), blur_radius);
		col = nodevgaussian_singlepass;
	}
	else if (blur_type == 3) {
		vec4 nodevgaussian_multipass = texture_nodevgaussian_multipass(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(blur_amount), blur_direction);
		col = nodevgaussian_multipass;
	}
	else {
		col = texture(TEXTURE, UV);
	}
	vec4 output = mix(original_color.rgba, col, selection_color.a);
	COLOR = output;
}
