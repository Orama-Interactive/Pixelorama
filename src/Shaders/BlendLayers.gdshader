shader_type canvas_item;
render_mode unshaded;

const float HCV_EPSILON = 1e-10;
const float HSL_EPSILON = 1e-10;

uniform sampler2DArray layers : filter_nearest;
// Nx4 texture, where N is the number of layers and the first row are the blend modes,
// the second are the opacities, the third are the origins and the fourth are the
// clipping mask booleans.
uniform sampler2D metadata : filter_nearest;
uniform bool origin_x_positive = true;
uniform bool origin_y_positive = true;

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
	current_color.a *= opacity;  // Combine the layer opacity
	if (current_color.a <= 0.001) {
		return prev_color;
	}
	vec4 result;
	bool should_blend_alpha = true;
	switch(blend_type) {
		case 1: // Erase
			result = prev_color;
			result.a -= current_color.a;  // clamping will be done at the end so not doing it here.
			should_blend_alpha = false;
			break;
		case 2: // Darken
			result.rgb = min(prev_color.rgb, current_color.rgb);
			break;
		case 3: // Multiply
			result.rgb = prev_color.rgb * current_color.rgb;
			break;
		case 4: // Color burn
			result.rgb = 1.0 - (1.0 - prev_color.rgb) / current_color.rgb;
			break;
		case 5: // Linear burn
			result.rgb = prev_color.rgb + current_color.rgb - 1.0;
			break;
		case 6: // Lighten
			result.rgb = max(prev_color.rgb, current_color.rgb);
			break;
		case 7: // Screen
			result.rgb = 1.0 - (1.0 - prev_color.rgb) * (1.0 - current_color.rgb);
			break;
		case 8: // Color dodge
			result.rgb = prev_color.rgb / (1.0 - current_color.rgb);
			break;
		case 9: // Add (linear dodge)
			result.rgb = prev_color.rgb + current_color.rgb;
			break;
		case 10: // Overlay
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(prev_color.rgb));
			break;
		case 11: // Soft light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb + prev_color.rgb * prev_color.rgb * (1.0 - 2.0 * current_color.rgb), sqrt(prev_color.rgb) * (2.0 * current_color.rgb - 1.0) + (2.0 * prev_color.rgb) * (1.0 - current_color.rgb), round(prev_color.rgb));
			break;
		case 12: // Hard light
			result.rgb = mix(2.0 * prev_color.rgb * current_color.rgb, 1.0 - 2.0 * (1.0 - current_color.rgb) * (1.0 - prev_color.rgb), round(current_color.rgb));
			break;
		case 13: // Difference
			result.rgb = abs(prev_color.rgb - current_color.rgb);
			break;
		case 14: // Exclusion
			result.rgb = prev_color.rgb + current_color.rgb - 2.0 * prev_color.rgb * current_color.rgb;
			break;
		case 15: // Subtract
			result.rgb = prev_color.rgb - current_color.rgb;
			break;
		case 16: // Divide
			result.rgb = prev_color.rgb / current_color.rgb;
			break;
		case 17: // Hue
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(current_hsl.r, prev_hsl.g, prev_hsl.b));
			break;
		case 18: // Saturation
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(prev_hsl.r, current_hsl.g, prev_hsl.b));
			break;
		case 19: // Color
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(current_hsl.r, current_hsl.g, prev_hsl.b));
			break;
		case 20: // Luminosity
			vec3 current_hsl = rgb_to_hsl(current_color.rgb);
			vec3 prev_hsl = rgb_to_hsl(prev_color.rgb);
			result.rgb = hsl_to_rgb(vec3(prev_hsl.r, prev_hsl.g, current_hsl.b));
			break;
		default: // Normal (case 0)
			result.rgb = current_color.rgb;
			break;
	}
	result.rgb = mix(prev_color.rgb, result.rgb, current_color.a);
	if (should_blend_alpha){
		result.a = prev_color.a * (1.0 - current_color.a) + current_color.a;
	}
	result = clamp(result, 0.0, 1.0);
	return mix(current_color, result, prev_color.a);
}


// Zeroes the alpha values of textures when UV < 0 and UV > 1
float border_trim(vec4 color, vec2 uv) {
	return min(step(uv.x, 1.0) * step(0.0, uv.x) * step(uv.y, 1.0) * step(0.0, uv.y), color.a);
}


int find_previous_opaque_layer(int index, vec2 metadata_size_float) {
	for (int i = index - 1; i > 0; i--) {
		float layer_index = float(i) / metadata_size_float.x;
		float clipping_mask = texture(metadata, vec2(layer_index, 3.0 / metadata_size_float.y)).r;
		// If the red value is ~0.2, it means that it should be skipped.
		// Otherwise, return the index.
		if (clipping_mask > 0.25 || clipping_mask < 0.15) {
			return i;
		}
	}
	return 0;
}


void fragment() {
	ivec2 metadata_size = textureSize(metadata, 0) - 1;
	vec2 metadata_size_float = vec2(metadata_size);
	vec2 first_origin = texture(metadata, vec2(0.0, 2.0 / metadata_size_float.y)).rg;
	if (!origin_x_positive) {
		first_origin.x = -first_origin.x;
	}
	if (!origin_y_positive) {
		first_origin.y = -first_origin.y;
	}
	float first_opacity = texture(metadata, vec2(0.0, 1.0 / metadata_size_float.y)).r;
	vec4 result_color = texture(layers, vec3(UV - first_origin, 0.0));
	result_color.a = border_trim(result_color, UV - first_origin);
	result_color.a *= first_opacity;
	for(int i = 1; i < metadata_size.x + 1; i++) // Loops through every layer
	{
		float layer_index = float(i) / metadata_size_float.x;
		float blend_mode_float = texture(metadata, vec2(layer_index, 0.0)).r;
		// Blend modes are being stored as integers divided by 255, so convert them back to
		// their integer form
		int current_blend_mode = int(floor(blend_mode_float * 255.0));
		vec2 current_origin = texture(metadata, vec2(layer_index, 2.0 / metadata_size_float.y)).rg;
		if (!origin_x_positive) {
			current_origin.x = -current_origin.x;
		}
		if (!origin_y_positive) {
			current_origin.y = -current_origin.y;
		}
		// get origin of previous layer (used for clipping masks to work correctly)
		float clipping_mask_index = float(find_previous_opaque_layer(i, metadata_size_float));
		vec2 prev_origin = texture(metadata, vec2(clipping_mask_index, 2.0 / metadata_size_float.y)).rg;
		if (!origin_x_positive) {
			prev_origin.x = -prev_origin.x;
		}
		if (!origin_y_positive) {
			prev_origin.y = -prev_origin.y;
		}
		float current_opacity = texture(metadata, vec2(layer_index, 1.0 / metadata_size_float.y)).r;
		vec2 uv = UV - current_origin;
		vec4 layer_color = texture(layers, vec3(uv, float(i)));
		vec4 prev_layer_color = texture(layers, vec3(UV - prev_origin, clipping_mask_index));
		float clipping_mask = texture(metadata, vec2(layer_index, 3.0 / metadata_size_float.y)).r;
		layer_color.a *= prev_layer_color.a * step(0.5, clipping_mask) + 1.0 * step(clipping_mask, 0.5);
		layer_color.a = border_trim(layer_color, uv);
		result_color = blend(current_blend_mode, layer_color, result_color, current_opacity);
	}
	COLOR = result_color;
}
