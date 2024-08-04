uniform float width : hint_range(0, 2) = 0.05;

bool is_zero_approx(float num) {
	return num < 0.0001;
}


bool has_contrary_neighbour(vec2 uv, vec2 texture_pixel_size, sampler2D tex) {
	float i = -ceil(width);
	float j = ceil(width);
	float x1 = abs(i) > width ? width * sign(i) : i;
	float x2 = abs(j) > width ? width * sign(j) : j;
	float y1 = abs(i) > width ? width * sign(i) : i;
	float y2 = abs(j) > width ? width * sign(j) : j;

	vec2 xy1 = uv + texture_pixel_size * vec2(x1, y1);
	vec2 xy2 = uv + texture_pixel_size * vec2(x2, y2);

	if (xy1 != clamp(xy1, vec2(0.0), vec2(1.0)) || is_zero_approx(texture(tex, xy1).a) || xy2 != clamp(xy2, vec2(0.0), vec2(1.0)) || is_zero_approx(texture(tex, xy2).a)) {
		return true;
	}

	return false;
}
