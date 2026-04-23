shader_type canvas_item;
render_mode unshaded;

uniform int hue : hint_range(-180, 180);
uniform int saturation : hint_range(-100, 100);
uniform int value : hint_range(-100, 100);
uniform bool wrap_overflowing = false;
uniform sampler2D selection : filter_nearest;

bool is_equal_approx(float a, float b) {
	return abs(a - b) <= 0.0001;
}

float fmod(float x, float y) {
    return x - y * trunc(x / y);
}

// Inspired from Color::get_h(), Color::get_s() and Color::get_v() in godot's color.cpp.
// All color ranges are from set [0,1].
vec3 rgb2hsv(vec3 rgb) {
	float h, s, v;
	float min_val = min(rgb.r, rgb.g);
	min_val = min(min_val, rgb.b);
	float max_val = max(rgb.r, rgb.g);
	max_val = max(max_val, rgb.b);

	float delta = max_val - min_val;

	if (is_equal_approx(delta, 0.0)) {
		h = 0.0;
	}
	else{
		if (is_equal_approx(rgb.r, max_val)) {
			h = (rgb.g - rgb.b) / delta; // between yellow & magenta
		} else if (is_equal_approx(rgb.g, max_val)) {
			h = 2.0 + (rgb.b - rgb.r) / delta; // between cyan & yellow
		} else {
			h = 4.0 + (rgb.r - rgb.g) / delta; // between magenta & cyan
		}

		h /= 6.0f;
		if (h < 0.0f) {
			h += 1.0f;
		}
	}

	s = (!is_equal_approx(max_val, 0.0)) ? (delta / max_val) : 0.0;
	v = max_val;
	return vec3(h, s, v);
}

// Inspired from Color::set_hsv in godot's color.cpp. All color ranges are from set [0,1].
vec3 hsv2rgb(vec3 hsv) {
	int i;
	float f, p, q, t;
	if (is_equal_approx(hsv.y, 0.0)) {
		// Achromatic (gray)
		return vec3(hsv.z, hsv.z, hsv.z);
	}

	hsv.x *= 6.0f;
	hsv.x = fmod(hsv.x, 6);
	i = int(floor(hsv.x));

	f = hsv.x - float(i);
	p = hsv.z * (1.0 - hsv.y);
	q = hsv.z * (1.0 - hsv.y * f);
	t = hsv.z * (1.0 - hsv.y * (1.0f - f));

	switch (i) {
		case 0: // Red is the dominant color
			return vec3(hsv.z, t, p);
		case 1: // Green is the dominant color
			return vec3(q, hsv.z, p);
		case 2:
			return vec3(p, hsv.z, t);
		case 3: // Blue is the dominant color
			return vec3(p, q, hsv.z);
		case 4:
			return vec3(t, p, hsv.z);
		default: // (5) Red is the dominant color
			return vec3(hsv.z, p, q);
	}
}

void fragment() {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec3 col = original_color.rgb;
	ivec3 hsv_8 = ivec3(round(rgb2hsv(col) * vec3(360.0, 100.0, 100.0)));

	// Apply the shifting (this is incremental, not by percentage of original).
	// If not greyscale
	if(!is_equal_approx(col[0], col[1]) || !is_equal_approx(col[1], col[2])) {
		// Shift the color by shift_amount, but rolling over ih the value goes over 1
		if (wrap_overflowing && (hsv_8.x + hue > 360 || hsv_8.x + hue < 0)){
			hsv_8.x = int(mod(float(hsv_8.x) + float(hue), 360));
		}
		else hsv_8.x = clamp(hsv_8.x + hue, 0, 360);
	}
	if (saturation != 0){
		if (wrap_overflowing && (hsv_8.y + saturation > 100 || hsv_8.y + saturation < 0)){
			hsv_8.y = int(mod(float(hsv_8.y) + float(saturation), 100));
		}
		else hsv_8.y = clamp(hsv_8.y + saturation, 0, 100);
	}
	if (value != 0){
		if (wrap_overflowing && (hsv_8.z + value > 100 || hsv_8.z + value < 0)){
			hsv_8.z = int(mod(float(hsv_8.z) + float(value), 100));
		}
		else hsv_8.z = clamp(hsv_8.z + value, 0, 100);
	}
	col = hsv2rgb(vec3(hsv_8) / vec3(360, 100, 100));
	vec3 output = mix(original_color.rgb, col, selection_color.a);
	COLOR = vec4(output.rgb, original_color.a);
}
