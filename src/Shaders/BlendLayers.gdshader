shader_type canvas_item;
render_mode unshaded;

const float HCV_EPSILON = 1e-10;
const float HSL_EPSILON = 1e-10;

uniform sampler2DArray layers : filter_nearest;
uniform float[1024] opacities;
uniform int[1024] blend_modes;
uniform vec2[1024] origins;

// Conversion functions from
// https://gist.github.com/unitycoder/aaf94ddfe040ec2da93b58d3c65ab9d9
// licensed under MIT

// Converts from pure Hue to linear RGB
vec3 hue_to_rgb(float hue)
{
    float R = abs(hue * 6.0 - 3.0) - 1.0;
    float G = 2.0 - abs(hue * 6.0 - 2.0);
    float B = 2.0 - abs(hue * 6.0 - 4.0);
    return clamp(vec3(R, G, B), 0.0, 1.0);
}

// Converts from HSL to linear RGB
vec3 hsl_to_rgb(vec3 hsl)
{
    vec3 rgb = hue_to_rgb(hsl.x);
    float C = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
    return (rgb - 0.5) * C + hsl.z;
}


// Converts a value from linear RGB to HCV (Hue, Chroma, Value)
vec3 rgb_to_hcv(vec3 rgb)
{
    // Based on work by Sam Hocevar and Emil Persson
    vec4 P = (rgb.g < rgb.b) ? vec4(rgb.bg, -1.0, 2.0/3.0) : vec4(rgb.gb, 0.0, -1.0/3.0);
    vec4 Q = (rgb.r < P.x) ? vec4(P.xyw, rgb.r) : vec4(rgb.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6.0 * C + HCV_EPSILON) + Q.z);
    return vec3(H, C, Q.x);
}

// Converts from linear rgb to HSL
vec3 rgb_to_hsl(vec3 rgb)
{
    vec3 HCV = rgb_to_hcv(rgb);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1.0 - abs(L * 2.0 - 1.0) + HSL_EPSILON);
    return vec3(HCV.x, S, L);
}


vec4 blend(int blend_type, vec4 current_color, vec4 prev_color, float opacity) {
	vec4 result;
	if (current_color.a <= 0.01) {
		return prev_color;
	}
	current_color.rgb = current_color.rgb * opacity; // Premultiply with the layer texture's alpha to prevent semi transparent pixels from being too bright (ALL LAYER TYPES!)
	current_color.a = current_color.a * opacity;  // Combine the layer opacity
	switch(blend_type) {
		case 1: // Darken
			result.rgb = min(prev_color.rgb, current_color.rgb);
			break;
		case 2: // Multiply
			result.rgb = prev_color.rgb * current_color.rgb;
			break;
		case 3: // Color burn
			result.rgb = 1.0 - (1.0 - prev_color.rgb) / current_color.rgb;
			break;
		case 4: // Linear burn
			result.rgb = prev_color.rgb + current_color.rgb - 1.0;
			break;
		case 5: // Lighten
			result.rgb = max(prev_color.rgb, current_color.rgb);
			break;
		case 6: // Screen
			result.rgb = mix(prev_color.rgb, 1.0 - (1.0 - prev_color.rgb) * (1.0 - current_color.rgb), current_color.a);
			break;
		case 7: // Color dodge
			result.rgb = prev_color.rgb / (1.0 - current_color.rgb);
			break;
		case 8: // Add (linear dodge)
			result.rgb = prev_color.rgb + current_color.rgb;
			break;
		case 9: // Overlay
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(prev_color.rgb));
			break;
		case 10: // Soft light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb + prev_color.rgb * prev_color.rgb * (1.0 - 2.0 * current_color.rgb), sqrt(prev_color.rgb) * (2.0 * current_color.rgb - 1.0) + (2.0 * prev_color.rgb) * (1.0 - current_color.rgb), round(prev_color.rgb));
			break;
		case 11: // Hard light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(current_color.rgb));
			break;
		case 12: // Difference
			result.rgb = abs(prev_color.rgb - current_color.rgb);
			break;
		case 13: // Exclusion
			result.rgb = prev_color.rgb + current_color.rgb - 2.0 * prev_color.rgb * current_color.rgb;
			break;
		case 14: // Subtract
			result.rgb = prev_color.rgb - current_color.rgb;
			break;
		case 15: // Divide
			result.rgb = prev_color.rgb / current_color.rgb;
			break;
		case 16: // Hue
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(current_hsl.r, prev_hsl.g, prev_hsl.b));
			break;
		case 17: // Saturation
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(prev_hsl.r, current_hsl.g, prev_hsl.b));
			break;
		case 18: // Color
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(current_hsl.r, current_hsl.g, prev_hsl.b));
			break;
		case 19: // Luminosity
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(prev_hsl.r, prev_hsl.g, current_hsl.b));
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
	vec4 col = texture(layers, vec3(UV - origins[0], 0.0));
	col.a *= opacities[0];
	for(int i = 1; i < textureSize(layers, 0).z; i++) // Loops through every layer
	{
		col = blend(blend_modes[i], texture(layers, vec3(UV - origins[i], float(i))), col, opacities[i]);
	}
	COLOR = col;
}
