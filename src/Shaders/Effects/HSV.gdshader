shader_type canvas_item;
render_mode unshaded;

uniform float hue : hint_range(-1, 1);
uniform float saturation : hint_range(-1, 1);
uniform float value : hint_range(-1, 1);
uniform bool wrap_overflowing = false;
uniform sampler2D selection : filter_nearest;

bool is_equal_approx(float a, float b) {
	return abs(a - b) <= 0.0001;
}

vec3 rgb2hsb(vec3 c){
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz),
				vec4(c.gb, K.xy),
				step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r),
				vec4(c.r, p.yzx),
				step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
				d / (q.x + e),
				q.x);
}

vec3 hsb2rgb(vec3 c){
	vec3 rgb = clamp(abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),
					6.0)-3.0)-1.0,
					0.0,
					1.0 );
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec3 col = original_color.rgb;
	vec3 hsb = rgb2hsb(col);

	// Apply the shifting (this is incremental, not by percentage of original).
	// If not greyscale
	if(!is_equal_approx(col[0], col[1]) || !is_equal_approx(col[1], col[2])) {
		// Shift the color by shift_amount, but rolling over the value goes over 1
		if (wrap_overflowing && (hsb.x + hue > 1.0 || hsb.x + hue < 0.0)){
			hsb.x = mod(hsb.x + hue, 1.0);
		}
		else hsb.x = clamp(hsb.x + hue, 0.0, 1.0);
	}
	if (!is_equal_approx(saturation, 0)){
		if (wrap_overflowing && (hsb.y + saturation > 1.0 || hsb.y + saturation < 0.0)){
			hsb.y = mod(hsb.y + saturation, 1.0);
		}
		else hsb.y = clamp(hsb.x + saturation, 0.0, 1.0);
	}
	if (!is_equal_approx(value, 0)){
		if (wrap_overflowing && (hsb.z + value > 1.0 || hsb.z + value < 0.0)){
			hsb.z = mod(hsb.z + value, 1.0);
		}
		else hsb.z = clamp(hsb.x + value, 0.0, 1.0);
	}
	// Minimize uncertanities by scaling up to the standardized values, round and then scale down.
	// I don't think removing this will will cause problems, but it's better to place it here.
	hsb.x = round(hsb.x * 360.0) / 360.0;
	hsb.y = round(hsb.y * 100.0) / 100.0;
	hsb.z = round(hsb.z * 100.0) / 100.0;

	col = hsb2rgb(hsb);
	vec3 output = mix(original_color.rgb, col, selection_color.a);
	COLOR = vec4(output.rgb, original_color.a);
}
