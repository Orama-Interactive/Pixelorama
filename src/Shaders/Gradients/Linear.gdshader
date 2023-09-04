shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform sampler2D gradient_texture;
uniform float position : hint_range(-0.5, 0.5) = 0.0;
uniform float size : hint_range(0.01, 2.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(1.0);
uniform int shape = 0; // 0 = linear, 1 = radial
uniform int repeat = 0; // 0 = none, 1 = repeat, 2 = mirrored, 3 = truncate


float modify_uv(vec2 uv) {
	float modified_uv;
	if (shape == 0) { // Linear
		vec2 uv_offsetted = uv - 0.5;
		float angle_cos = cos(radians(angle));
		float angle_sin = sin(radians(angle));
		modified_uv = uv_offsetted.x * angle_cos - uv_offsetted.y * angle_sin;
		modified_uv /= abs(angle_cos) + abs(angle_sin);
		modified_uv /= size;
		float pivot = position / size;
		modified_uv -= pivot - 0.5;
	}
	else { // Radial
		vec2 uv_offsetted = uv * 2.0 - 1.0;
		uv_offsetted -= (center * 2.0) - vec2(1.0);
		uv_offsetted /= radius;
		modified_uv = length(uv_offsetted);
	}
	return modified_uv;
}


float mirror_fract(float uv) {
	int sign_uv = (int(sign(uv)) - 1) / 2; // returns -1 for negative sign and 0 for positive
	if (int((uv)) % 2 == sign_uv)
		uv = fract(uv);
	else
		uv = fract(1.0 - uv);

	return uv;
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = floor(UV * tex_size) / (tex_size - 1.0);
	float modified_uv = modify_uv(uv);
	if (repeat == 1)
		modified_uv = fract(modified_uv);
	else if (repeat == 2)
		modified_uv = mirror_fract(modified_uv);
	vec4 output = texture(gradient_texture, vec2(modified_uv));
	if (repeat == 3)
		output.a = min(step(modified_uv, 1.0) * step(0.0, modified_uv), output.a);
	output = mix(original_color, output, output.a);
	COLOR = mix(original_color, output, selection_color.a);
}
