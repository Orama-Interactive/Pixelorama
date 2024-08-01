// Shader from https://godotshaders.com/shader/color-manipulator/
// Licensed under CC0
shader_type canvas_item;
render_mode unshaded;

uniform float brightness : hint_range(-1, 1) = 0;
uniform float contrast : hint_range(0, 3) = 1.0;
uniform float saturation : hint_range(0, 3) = 1.0;

uniform float red_value : hint_range(0, 1) = 1.0;
uniform float green_value : hint_range(0, 1) = 1.0;
uniform float blue_value : hint_range(0, 1) = 1.0;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_effect_factor : hint_range(0, 1) = 0.0;

uniform sampler2D selection : filter_nearest;

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

mat4 saturationMatrix( float _saturation )
{
	vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
	float oneMinusSat = 1.0 - _saturation;

	vec3 red = vec3( luminance.x * oneMinusSat );
	red+= vec3(_saturation, 0, 0) * red_value;
	vec3 green = vec3( luminance.y * oneMinusSat );
	green += vec3(0, _saturation, 0) * green_value;
	vec3 blue = vec3( luminance.z * oneMinusSat );
	blue += vec3(0, 0, _saturation ) * blue_value;

	return mat4(vec4(red, 0), vec4(green, 0), vec4(blue, 0), vec4(0, 0, 0, 1));
}

void fragment()
{
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 c2 = original_color * tint_color;
	vec4 col = brightnessMatrix(brightness) * contrastMatrix(contrast) * saturationMatrix(saturation) * mix(original_color, c2, tint_effect_factor);
	vec3 output = mix(original_color.rgb, col.rgb, selection_color.a);
	COLOR = vec4(output.rgb, original_color.a);
}
