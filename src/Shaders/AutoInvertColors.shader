shader_type canvas_item;


void fragment() {
	vec3 inverted = vec3(1.0) - COLOR.rgb;
	vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	float avg = (screen_color.r + screen_color.g + screen_color.b) / 3.0;
	COLOR.rgb = inverted * step(avg, 0.5);
}
