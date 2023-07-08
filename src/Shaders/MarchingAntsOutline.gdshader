// Taken and modified from https://godotshaders.com/shader/2d-outline-inline/
// Also thanks to https://andreashackel.de/tech-art/stripes-shader-1/ for the stripe tutorial
shader_type canvas_item;

uniform vec4 first_color : source_color = vec4(1.0);
uniform vec4 second_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool animated = true;
uniform float width : hint_range(0, 2) = 0.05;
uniform float frequency = 50.0;
uniform float stripe_direction : hint_range(0, 1) = 0.5;


bool has_contrary_neighbour(vec2 uv, vec2 texture_pixel_size, sampler2D tex) {
	float i = -ceil(width);
	float j = ceil(width);
	float x1 = abs(i) > width ? width * sign(i) : i;
	float x2 = abs(j) > width ? width * sign(j) : j;
	float y1 = abs(i) > width ? width * sign(i) : i;
	float y2 = abs(j) > width ? width * sign(j) : j;

	vec2 xy1 = uv + texture_pixel_size * vec2(x1, y1);
	vec2 xy2 = uv + texture_pixel_size * vec2(x2, y2);

	if (xy1 != clamp(xy1, vec2(0.0), vec2(1.0)) || texture(tex, xy1).a == 0.0 || xy2 != clamp(xy2, vec2(0.0), vec2(1.0)) || texture(tex, xy2).a == 0.0) {
		return true;
	}

	return false;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE;

	if (COLOR.a > 0.0 && has_contrary_neighbour(UV, ts, TEXTURE)) {
		vec2 ratio = (ts.x > ts.y) ? vec2(ts.y / ts.x, 1) : vec2(1, ts.x / ts.y);
		vec2 uv = UV * ratio;
		if(animated)
			uv -= TIME / frequency;
		// Generate diagonal stripes
		float pos = mix(uv.x, uv.y, stripe_direction) * frequency;
		float value = floor(fract(pos) + 0.5);
		COLOR = mix(first_color, second_color, step(1.0, mod(value, 2.0)));
	}
	else {
		// Erase the texture's pixels in order to only keep the outline visible
		COLOR.a = 0.0;
	}
}
