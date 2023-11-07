// Original shader written by Azagaya
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection_tex;
uniform float initial_angle = 0.0;
uniform float ending_angle = 0.0;
uniform float tolerance : hint_range(0.0, 255.0) = 100.0;
uniform vec2 origin = vec2(0.0, 0.0);
uniform vec2 position = vec2(0.0, 0.0);

bool similarColors(vec4 c1, vec4 c2) {
	return (distance(c1 * 255.0, c2 * 255.0) < tolerance);
}


vec4 rotate(sampler2D tex, vec2 uv, vec2 tex_pixel_size) {
	vec4 color = vec4(0.0);
	vec2 center = origin / tex_pixel_size;
	vec2 size = 1.0 / tex_pixel_size;
	vec2 coord = uv / tex_pixel_size + position;
	int dx = 3 * (int(coord.x) - int(center.x));
	int dy = 3 * (int(coord.y) - int(center.y));
	int k = 0;
	int ox, oy;
	float dir;
	float mag;
	float init_angle = initial_angle < ending_angle ? initial_angle : ending_angle;
	for (float angle = ending_angle; angle >= init_angle && color.a == 0.0; angle -= 1.0) {
		float ang = angle*3.1416/180.0;

		for (int k = 0; k < 9; k++) {
			int i = -1 + int(k % 3);
			int j = -1 + k / 3;
			dir = atan(float(dy + j), float(dx + i));
			mag = sqrt(pow(float(dx + i), 2.0) + pow(float(dy + j), 2.0));
			dir -= ang;
			ox = int(round(3.0 * center.x + 1.0 + mag * cos(dir)));
			oy = int(round(3.0 * center.y + 1.0 + mag * sin(dir)));

			if (int(size.x) % 2 != 0) {
				ox += 1;
			}
			if (int(size.y) % 2 != 0) {
				oy += 1;
			}

			if (ox >= 0 && ox < 3 * int(size.x) && oy >= 0 && oy < 3 * int(size.y)) {
				break;
			}
		}
		if (k == 9){
			continue;
		}

		int row = int(oy % 3);
		int col = int(ox % 3);
		int index = col + 3 * row;
		ox = int(round(float(ox - 1) / 3.0));
		oy = int(round(float(oy - 1) / 3.0));

		if (ox == 0 || ox == int(size.x) - 1 || oy == 0 || oy == int(size.y) - 1) {
			color = texture(tex, vec2(float(ox), float(oy)) * tex_pixel_size);
		}
		else {
			vec4 a = texture(tex, vec2(float(ox - 1), float(oy - 1)) * tex_pixel_size);
			vec4 b = texture(tex, vec2(float(ox), float(oy - 1)) * tex_pixel_size);
			vec4 c = texture(tex, vec2(float(ox + 1), float(oy - 1)) * tex_pixel_size);
			vec4 d = texture(tex, vec2(float(ox - 1), float(oy)) * tex_pixel_size);
			vec4 e = texture(tex, vec2(float(ox), float(oy)) * tex_pixel_size);
			vec4 f = texture(tex, vec2(float(ox + 1), float(oy)) * tex_pixel_size);
			vec4 g = texture(tex, vec2(float(ox - 1), float(oy + 1)) * tex_pixel_size);
			vec4 h = texture(tex, vec2(float(ox), float(oy + 1)) * tex_pixel_size);
			vec4 l = texture(tex, vec2(float(ox + 1), float(oy + 1)) * tex_pixel_size);

			if (index == 0) {
				color = similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) ? d : e;
			}
			else if (index == 1) {
				color = (similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) && !similarColors(e,c))
				|| (similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) && !similarColors(e,a)) ? b : e;
			}
			else if (index == 2) {
				color = similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) ? f : e;
			}
			else if (index == 3) {
				color = (similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) && !similarColors(e,a))
				|| (similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) && !similarColors(e,g)) ? d : e;
			}
			else if (index == 4) {
				color = e;
			}
			else if (index == 5) {
				color = (similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) && !similarColors(e,l))
				|| (similarColors(f,h) && !similarColors(b,f) && !similarColors(d,h) && !similarColors(e,c)) ? f : e;
			}
			else if (index == 6) {
				color = similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) ? d : e;
			}
			else if (index == 7) {
				color = (similarColors(f,h) && !similarColors(f,b)&& !similarColors(d,h) && !similarColors(e,g))
				|| (similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) && !similarColors(e,l)) ? h : e;
			}
			else if (index == 8) {
				color = similarColors(f,h) && !similarColors(f,b) && !similarColors(d,h)? f : e;
			}
		}
		color.a *= step(ending_angle, initial_angle) +
		step(initial_angle ,ending_angle) * (angle - initial_angle) / (ending_angle - initial_angle + 0.01);
	}

	return color;
}

// The exact same as rotate, but had to be re-defined due to https://github.com/godotengine/godot/issues/75935
vec4 rotate_uniform(sampler2D tex, vec2 uv, vec2 tex_pixel_size) {
	vec4 color = vec4(0.0);
	vec2 center = origin / tex_pixel_size;
	vec2 size = 1.0 / tex_pixel_size;
	vec2 coord = uv / tex_pixel_size + position;
	int dx = 3 * (int(coord.x) - int(center.x));
	int dy = 3 * (int(coord.y) - int(center.y));
	int k = 0;
	int ox, oy;
	float dir;
	float mag;
	float init_angle = initial_angle < ending_angle ? initial_angle : ending_angle;
	for (float angle = ending_angle; angle >= init_angle && color.a == 0.0; angle -= 1.0) {
		float ang = angle*3.1416/180.0;

		for (int k = 0; k < 9; k++) {
			int i = -1 + int(k % 3);
			int j = -1 + k / 3;
			dir = atan(float(dy + j), float(dx + i));
			mag = sqrt(pow(float(dx + i), 2.0) + pow(float(dy + j), 2.0));
			dir -= ang;
			ox = int(round(3.0 * center.x + 1.0 + mag * cos(dir)));
			oy = int(round(3.0 * center.y + 1.0 + mag * sin(dir)));

			if (int(size.x) % 2 != 0) {
				ox += 1;
			}
			if (int(size.y) % 2 != 0) {
				oy += 1;
			}

			if (ox >= 0 && ox < 3 * int(size.x) && oy >= 0 && oy < 3 * int(size.y)) {
				break;
			}
		}
		if (k == 9){
			continue;
		}

		int row = int(oy % 3);
		int col = int(ox % 3);
		int index = col + 3 * row;
		ox = int(round(float(ox - 1) / 3.0));
		oy = int(round(float(oy - 1) / 3.0));

		if (ox == 0 || ox == int(size.x) - 1 || oy == 0 || oy == int(size.y) - 1) {
			color = texture(tex, vec2(float(ox), float(oy)) * tex_pixel_size);
		}
		else {
			vec4 a = texture(tex, vec2(float(ox - 1), float(oy - 1)) * tex_pixel_size);
			vec4 b = texture(tex, vec2(float(ox), float(oy - 1)) * tex_pixel_size);
			vec4 c = texture(tex, vec2(float(ox + 1), float(oy - 1)) * tex_pixel_size);
			vec4 d = texture(tex, vec2(float(ox - 1), float(oy)) * tex_pixel_size);
			vec4 e = texture(tex, vec2(float(ox), float(oy)) * tex_pixel_size);
			vec4 f = texture(tex, vec2(float(ox + 1), float(oy)) * tex_pixel_size);
			vec4 g = texture(tex, vec2(float(ox - 1), float(oy + 1)) * tex_pixel_size);
			vec4 h = texture(tex, vec2(float(ox), float(oy + 1)) * tex_pixel_size);
			vec4 l = texture(tex, vec2(float(ox + 1), float(oy + 1)) * tex_pixel_size);

			if (index == 0) {
				color = similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) ? d : e;
			}
			else if (index == 1) {
				color = (similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) && !similarColors(e,c))
				|| (similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) && !similarColors(e,a)) ? b : e;
			}
			else if (index == 2) {
				color = similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) ? f : e;
			}
			else if (index == 3) {
				color = (similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) && !similarColors(e,a))
				|| (similarColors(d,b) && !similarColors(d,h) && !similarColors(b,f) && !similarColors(e,g)) ? d : e;
			}
			else if (index == 4) {
				color = e;
			}
			else if (index == 5) {
				color = (similarColors(b,f) && !similarColors(d,b) && !similarColors(f,h) && !similarColors(e,l))
				|| (similarColors(f,h) && !similarColors(b,f) && !similarColors(d,h) && !similarColors(e,c)) ? f : e;
			}
			else if (index == 6) {
				color = similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) ? d : e;
			}
			else if (index == 7) {
				color = (similarColors(f,h) && !similarColors(f,b)&& !similarColors(d,h) && !similarColors(e,g))
				|| (similarColors(d,h) && !similarColors(f,h) && !similarColors(d,b) && !similarColors(e,l)) ? h : e;
			}
			else if (index == 8) {
				color = similarColors(f,h) && !similarColors(f,b) && !similarColors(d,h)? f : e;
			}
		}
		color.a *= step(ending_angle, initial_angle) +
		step(initial_angle ,ending_angle) * (angle - initial_angle) / (ending_angle - initial_angle + 0.01);
	}

	return color;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 selection = texture(selection_tex, UV);
	vec4 rotated_selection = rotate_uniform(selection_tex, UV, TEXTURE_PIXEL_SIZE);
	vec4 rotated = rotate(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
	rotated = mix(vec4(0.0), rotated, rotated_selection.a);
	rotated.a *= rotated_selection.a; // Combine with selection mask
	float mask = mix(selection.a, 1.0, 1.0 - ceil(original.a)); // Combine selection mask with area outside original

	// Combine original and rotated image only when intersecting, otherwise just pure rotated image.
	COLOR.rgb = mix(mix(original.rgb, rotated.rgb, rotated.a), rotated.rgb, mask);
	COLOR.a = mix(original.a, 0.0, selection.a); // Remove alpha on the selected area
	COLOR.a = mix(COLOR.a, 1.0, rotated.a); // Combine alpha of original image and rotated
}
