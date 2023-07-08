shader_type canvas_item;


void fragment() {
	vec4 color = texture(TEXTURE, UV);
	COLOR = color;
	vec3 inverted = vec3(1.0) - color.rgb;
	vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	float screen_avg = (screen_color.r + screen_color.g + screen_color.b) / 3.0;
	
	COLOR.rgb = inverted * step(0.5, screen_avg) + color.rgb * step(screen_avg, 0.5);
}
