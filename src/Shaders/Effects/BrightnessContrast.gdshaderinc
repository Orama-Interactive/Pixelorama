// Shader from https://godotshaders.com/shader/color-manipulator/
// Licensed under CC0

// @uniform float brightness : hint_range(-1, 1) = 0;
// @uniform float contrast : hint_range(0, 3) = 1.0;

// @uniform float saturation : hint_range(0, 3) = 1.0;
// @uniform float red_value : hint_range(0, 1) = 1.0;  // Red contribution in saturation.
// @uniform float green_value : hint_range(0, 1) = 1.0;  // Green contribution in saturation.
// @uniform float blue_value : hint_range(0, 1) = 1.0;  // Blue contribution in saturation.

// @uniform float red_shift : hint_range(-1, 1) = 0.0;
// @uniform float green_shift : hint_range(-1, 1) = 0.0;
// @uniform float blue_shift : hint_range(-1, 1) = 0.0;

// @uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// @uniform float tint_effect_factor : hint_range(0, 1) = 0.0;

// @uniform bool wrap_overflowing = false;

bool is_equal_approx(float a, float b) {
	return abs(a - b) <= 0.0001;
}

mat4 contrastMatrix( float _contrast )
{
	float t = ( 1.0 - _contrast ) / 2.0;
	return mat4(
		vec4(_contrast, 0, 0, 0),
		vec4(0, _contrast, 0, 0),
		vec4(0, 0, _contrast, 0),
		vec4(t, t, t, 1));
}

mat4 brightnessMatrix( float _brightness )
{
	return mat4( vec4(1, 0, 0, 0),
				 vec4(0, 1, 0, 0),
				 vec4(0, 0, 1, 0),
				 vec4(_brightness, _brightness, _brightness, 1));
}

mat4 saturationMatrix( float _saturation, float red_value, float green_value, float blue_value )
{
	vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
	float oneMinusSat = 1.0 - _saturation;

	vec3 red = vec3( luminance.x * oneMinusSat );
	red += vec3(_saturation, 0, 0) * red_value;
	vec3 green = vec3( luminance.y * oneMinusSat );
	green += vec3(0, _saturation, 0) * green_value;
	vec3 blue = vec3( luminance.z * oneMinusSat );
	blue += vec3(0, 0, _saturation ) * blue_value;

	return mat4(vec4(red, 0), vec4(green, 0), vec4(blue, 0), vec4(0, 0, 0, 1));
}

vec4 apply_effect(
	sampler2D source_texture,
	vec2 uv,
	sampler2D selection,
	float brightness,
	float contrast,
	float saturation,
	float red_value,
	float green_value,
	float blue_value,
	float red_shift,
	float green_shift,
	float blue_shift,
	vec4 tint_color,
	float tint_effect_factor,
	bool wrap_overflowing
) {
	vec4 original_color = texture(source_texture, uv);

	vec4 c_shift = original_color;
	if (!is_equal_approx(red_shift, 0.0)){
		if (wrap_overflowing && (c_shift.r + red_shift > 1.0 || c_shift.r + red_shift < 0.0)){
			c_shift.r = mod(c_shift.r + red_shift, 1.0);
		}
		else c_shift.r = clamp(c_shift.r + red_shift, 0.0, 1.0);
	}
	if (!is_equal_approx(green_shift, 0.0)){
		if (wrap_overflowing && (c_shift.g + green_shift > 1.0 || c_shift.g + green_shift < 0.0)){
			c_shift.g = mod(c_shift.g + green_shift, 1.0);
		}
		else c_shift.g = clamp(c_shift.g + green_shift, 0, 1.0);
	}
	if (!is_equal_approx(blue_shift, 0.0)){
		if (wrap_overflowing && (c_shift.b + blue_shift > 1.0 || c_shift.b + blue_shift < 0.0)){
			c_shift.b = mod(c_shift.b + blue_shift, 1.0);
		}
		else c_shift.b = clamp(c_shift.b + blue_shift, 0.0, 1.0);
	}

	vec4 selection_color = texture(selection, uv);
	vec4 c2 = c_shift * tint_color;
	mat4 sat_matrix = saturationMatrix(saturation, red_value, green_value, blue_value);
	vec4 col = brightnessMatrix(brightness) * contrastMatrix(contrast) * sat_matrix * mix(c_shift, c2, tint_effect_factor);
	vec3 output = mix(original_color.rgb, col.rgb, selection_color.a);
	return vec4(output.rgb, original_color.a);
}
