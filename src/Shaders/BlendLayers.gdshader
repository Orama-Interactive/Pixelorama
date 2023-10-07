shader_type canvas_item;
render_mode unshaded;

uniform sampler2DArray layers : filter_nearest;
uniform float[1024] opacities;
uniform int[1024] blend_modes;


vec4 blend(int blend_type, vec4 current_color, vec4 prev_color, float opacity) {
	vec4 result;
	if (current_color.a <= 0.01) {
		return prev_color;
	}
	current_color.rgb = current_color.rgb * opacity; // Premultiply with the layer texture's alpha to prevent semi transparent pixels from being too bright (ALL LAYER TYPES!)
	current_color.a = current_color.a * opacity;  // Combine the layer opacity
	switch(blend_type) {
		case 1: // Add
			result.rgb = prev_color.rgb + current_color.rgb;
			break;
		case 2: // Subtract
			result.rgb = prev_color.rgb - current_color.rgb;
			break;
		case 3: // Multiply
			result.rgb = prev_color.rgb * current_color.rgb;
			break;
		case 4: // Screen
			result.rgb = mix(prev_color.rgb, 1.0 - (1.0 - prev_color.rgb) * (1.0 - current_color.rgb), current_color.a);
			break;
		case 5: // Difference
			result.rgb = abs(prev_color.rgb - current_color.rgb);
			break;
		case 6: // Burn
			result.rgb = 1.0 - (1.0 - prev_color.rgb) / current_color.rgb;
			break;
		case 7: // Dodge
			result.rgb = prev_color.rgb / (1.0 - current_color.rgb);
			break;
		case 8: // Overlay
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(prev_color.rgb));
			break;
		case 9: // Soft light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb + prev_color.rgb * prev_color.rgb * (1.0 - 2.0 * current_color.rgb), sqrt(prev_color.rgb) * (2.0 * current_color.rgb - 1.0) + (2.0 * prev_color.rgb) * (1.0 - current_color.rgb), round(prev_color.rgb));
			break;
		case 10: // Hard light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(current_color.rgb));
			break;
		default: // Normal (case 0)
			result.rgb = prev_color.rgb * (1.0 - current_color.a) + current_color.rgb;
			break;
	}
	result.a = prev_color.a * (1.0 - current_color.a) + current_color.a;
	result = clamp(result, 0.0, 1.0);
	return mix(current_color, result, prev_color.a);
}


void fragment() {
	vec4 col = texture(layers, vec3(UV, 0.0));
	col.a *= opacities[0];
	for(int i = 1; i < textureSize(layers, 0).z; i++) // Loops through every layer
	{
		col = blend(blend_modes[i], texture(layers, vec3(UV, float(i))), col, opacities[i]);
	}
	COLOR = col;
}
