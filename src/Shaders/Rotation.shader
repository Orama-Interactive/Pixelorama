shader_type canvas_item;

uniform float angle;

vec2 rotate(vec2 uv) {
	uv -= 0.5;
	uv = vec2(cos(angle) * uv.x + sin(angle) * uv.y,
				-sin(angle) * uv.x + cos(angle) * uv.y);
	uv += 0.5;
	return uv;
}


void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pixelated_uv = floor(UV * tex_size) / (tex_size - 1.0);
	
	vec2 border_uv = abs(rotate(pixelated_uv) * 2.0 - 1.0);
	float border = max(border_uv.x, border_uv.y);
	border = 1.0 - floor(border - TEXTURE_PIXEL_SIZE.x);
	
	COLOR = texture(TEXTURE, rotate(pixelated_uv));
	COLOR.a *= border;
}