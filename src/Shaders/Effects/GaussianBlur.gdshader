// https://godotshaders.com/shader/gaussian-blur-functions-for-gles2/
// Licensed under MIT.
shader_type canvas_item;
render_mode unshaded;

uniform int blur_type : hint_enum("Xor's Gaussian Blur", "Monk's Multi-Pass Gaussian Blur", "NoDev's Single-Pass Gaussian Blur", "NoDev's Multi-Pass Gaussian Blur") = 0;
uniform int blur_amount : hint_range(0, 100, 1) = 16;
uniform float blur_radius : hint_range(0.0, 100.0, 1.0) = 1.0;
uniform vec2 blur_direction = vec2(1, 1);
uniform sampler2D selection : filter_nearest;

// Xor's gaussian blur function from https://xorshaders.weebly.com/tutorials/blur-shaders-5-part-2
// Defaults from: https://www.shadertoy.com/view/Xltfzj
// BLUR BLURRINESS (Default 8.0)
// BLUR ITERATIONS (Default 16.0 - More is better but slower)
// BLUR QUALITY (Default 4.0 - More is better but slower)
//
// improved with wide Gaussian bell curve and alpha-weighted averaging for correct color
// on transparent backgrounds.
vec4 texture_xorgaussian(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, int iterations, int quality) {
	vec2 radius = blurriness / (1.0 / pixel_size).xy;
	float total_weight = 1.0;

	// Center pixel
	vec4 center = texture(tex, uv);
	vec3 blur_color_sum = center.rgb * center.a;
	float blur_alpha_sum = center.a;

	// Add up the colors of pixels around the center pixel according to their gaussian weights.
	for(float d = 0.0; d < TAU; d += TAU / float(iterations)) {
		for(float i = 1.0 / float(quality); i <= 1.0; i += 1.0 / float(quality)) {
			vec2 directions = uv + vec2(cos(d), sin(d)) * radius * i;
			// Read color located at the direction (r, theta) = (radius * i, d) relative to center.
			vec4 sample_col = texture(tex, directions);
			// Wide Gaussian: exp(-i^2 * 0.5) - gentle falloff for wider gradient spread
			float w = exp(-i * i * 0.5);
			blur_color_sum += sample_col.rgb * sample_col.a * w;
			blur_alpha_sum += sample_col.a * w;
			total_weight += w;
		}
	}

	// Average up the colors summed above to get the blurred color
	vec4 blurred_tex = vec4(0.0);
	if (blur_alpha_sum > 0.0) {
		// Unpremultiply RGB: compute alpha-weighted average color
		blurred_tex.rgb = blur_color_sum / blur_alpha_sum;
	}
	blurred_tex.a = blur_alpha_sum / total_weight;

	return blurred_tex;
}

// Monk's multi-pass gaussian blur — improved with per-iteration Gaussian decay
// and alpha-weighted averaging for correct color on transparent backgrounds.
vec4 texture_monksgaussian_multipass(sampler2D tex, vec2 uv, vec2 pixel_size, int iterations, vec2 direction) {
	vec3 blur_color_sum = vec3(0.0);
	float blur_alpha_sum = 0.0;
	float total_weight = 0.0;
	vec2 resolution = 1.0 / pixel_size;

	for (int i = 0; i < iterations; i++ ) {
		float size = float(iterations - i);
		float scale_weight = exp(-float(i * i) / max(1.0, float(iterations) * 0.8));

		vec2 off1 = vec2(1.3846153846) * (direction * size);
		vec2 off2 = vec2(3.2307692308) * (direction * size);

		vec4 s0 = texture(tex, uv);
		vec4 s1 = texture(tex, uv + (off1 / resolution));
		vec4 s2 = texture(tex, uv - (off1 / resolution));
		vec4 s3 = texture(tex, uv + (off2 / resolution));
		vec4 s4 = texture(tex, uv - (off2 / resolution));

		float w0 = 0.2270270270 * scale_weight;
		float w1 = 0.3162162162 * scale_weight;
		float w2 = 0.3162162162 * scale_weight;
		float w3 = 0.0702702703 * scale_weight;
		float w4 = 0.0702702703 * scale_weight;

		blur_color_sum += s0.rgb * s0.a * w0;
		blur_color_sum += s1.rgb * s1.a * w1;
		blur_color_sum += s2.rgb * s2.a * w2;
		blur_color_sum += s3.rgb * s3.a * w3;
		blur_color_sum += s4.rgb * s4.a * w4;

		blur_alpha_sum += s0.a * w0;
		blur_alpha_sum += s1.a * w1;
		blur_alpha_sum += s2.a * w2;
		blur_alpha_sum += s3.a * w3;
		blur_alpha_sum += s4.a * w4;

		total_weight += (w0 + w1 + w2 + w3 + w4);
	}

	vec4 blurred_tex = vec4(0.0);
	if (blur_alpha_sum > 0.0) {
		blurred_tex.rgb = blur_color_sum / blur_alpha_sum;
	}
	blurred_tex.a = blur_alpha_sum / total_weight;

	return blurred_tex;
}

// NoDev's gaussian blur functions — improved with wide Gaussian bell curve
// and alpha-weighted averaging for correct color on transparent backgrounds.
vec4 texture_nodevgaussian_singlepass(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, float radius) {
	float sigma = max(1.0, blurriness * 0.7);
	vec3 blur_color_sum = vec3(0);
	float blur_alpha_sum = 0.0;
	float total_weight = 0.0;

	for (float i = -blurriness; i <= blurriness; i++) {
		float d = i / PI;
		vec2 anchor = vec2(cos(d), sin(d)) * radius * i;
		vec2 directions = uv + pixel_size * anchor;
		vec4 sample_col = texture(tex, directions);
		float w = exp(-(i * i) / (2.0 * sigma * sigma));
		blur_color_sum += sample_col.rgb * sample_col.a * w;
		blur_alpha_sum += sample_col.a * w;
		total_weight += w;
	}

	vec4 blurred_tex = vec4(0);
	if (blur_alpha_sum > 0.0) {
		blurred_tex.rgb = blur_color_sum / blur_alpha_sum;
	}
	blurred_tex.a = blur_alpha_sum / total_weight;

	return blurred_tex;
}

vec4 texture_nodevgaussian_multipass(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, vec2 direction) {
	float sigma = max(1.0, blurriness * 0.7);
	vec3 blur_color_sum = vec3(0);
	float blur_alpha_sum = 0.0;
	float total_weight = 0.0;

	for (float i = -blurriness; i <= blurriness; i++) {
		vec2 directions = uv + pixel_size * (direction * i);
		vec4 sample_col = texture(tex, directions);
		float w = exp(-(i * i) / (2.0 * sigma * sigma));
		blur_color_sum += sample_col.rgb * sample_col.a * w;
		blur_alpha_sum += sample_col.a * w;
		total_weight += w;
	}

	vec4 blurred_tex = vec4(0);
	if (blur_alpha_sum > 0.0) {
		blurred_tex.rgb = blur_color_sum / blur_alpha_sum;
	}
	blurred_tex.a = blur_alpha_sum / total_weight;

	return blurred_tex;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col = original_color;
	if (blur_type == 0) {
		vec4 xorgaussian = texture_xorgaussian(TEXTURE, UV, TEXTURE_PIXEL_SIZE, float(blur_amount), 32, 8);
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