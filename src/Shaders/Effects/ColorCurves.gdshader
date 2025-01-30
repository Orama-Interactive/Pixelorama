shader_type canvas_item;

uniform sampler2D selection : filter_nearest;
// CurveTexture(s)
group_uniforms channel;
uniform sampler2D curve_rgb;
uniform sampler2D curve_red;
uniform sampler2D curve_green;
uniform sampler2D curve_blue;
uniform sampler2D curve_alpha;
uniform sampler2D curve_hue;
uniform sampler2D curve_sat;
uniform sampler2D curve_value;


vec3 rgb2hsb(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz),
				vec4(c.gb, K.xy),
				step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r),
				vec4(c.r, p.yzx),
				step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
				d / (q.x + e),
				q.x);
}

vec3 hsb2rgb(vec3 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);
	vec4 col;
	float red_curve_color = texture(curve_red, vec2(COLOR.r, 0.0)).r;
	float green_curve_color = texture(curve_green, vec2(COLOR.g, 0.0)).r;
	float blue_curve_color = texture(curve_blue, vec2(COLOR.b, 0.0)).r;
	float alpha_curve_color = texture(curve_alpha, vec2(COLOR.a, 0.0)).r;
	col.r = red_curve_color;
	col.g = green_curve_color;
	col.b = blue_curve_color;
	col.a = alpha_curve_color;

	vec3 hsb = rgb2hsb(col.rgb);
	float hue_curve_color = texture(curve_hue, vec2(hsb.r, 0.0)).r;
	float sat_curve_color = texture(curve_sat, vec2(hsb.g, 0.0)).r;
	float value_curve_color = texture(curve_value, vec2(hsb.b, 0.0)).r;
	hsb.r = hue_curve_color;
	hsb.g = sat_curve_color;
	hsb.b = value_curve_color;

	col.rgb = hsb2rgb(hsb);

	float rgb_curve_color_r = texture(curve_rgb, vec2(col.r, 0.0)).r;
	float rgb_curve_color_g = texture(curve_rgb, vec2(col.g, 0.0)).r;
	float rgb_curve_color_b = texture(curve_rgb, vec2(col.b, 0.0)).r;
	col.rgb = vec3(rgb_curve_color_r, rgb_curve_color_g, rgb_curve_color_b);
	vec4 output = mix(original_color.rgba, col, selection_color.a);
	COLOR = output;
}
