shader_type canvas_item;
render_mode unshaded;

uniform float hue_shift : hint_range(-1, 1);
uniform float sat_shift : hint_range(-1, 1);
uniform float val_shift : hint_range(-1, 1);
uniform sampler2D selection;

vec3 rgb2hsb(vec3 c){
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

vec3 hsb2rgb(vec3 c){
	vec3 rgb = clamp(abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),
					6.0)-3.0)-1.0,
					0.0,
					1.0 );
	rgb = rgb*rgb*(3.0-2.0*rgb);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	// Get color from the sprite texture at the current pixel we are rendering
	vec4 original_color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	vec3 col = original_color.rgb;
	vec3 hsb = rgb2hsb(col);
	// If not greyscale
	if(col[0] != col[1] || col[1] != col[2]) {
		// Shift the color by shift_amount, but rolling over the value goes over 1
		hsb.x = mod(hsb.x + hue_shift, 1.0);
	}
	if(sat_shift > 0.0) {
		hsb.y =  mix(hsb.y, 1 , sat_shift);
	}
	else if (sat_shift < 0.0) {
		hsb.y =  mix(0, hsb.y , 1.0 - abs(sat_shift));
	}

	if(val_shift > 0.0) {
		hsb.z =  mix(hsb.z, 1 , val_shift);
	}
	else if (val_shift < 0.0) {
		hsb.z =  mix(0, hsb.z , 1.0 - abs(val_shift));
	}

	col = hsb2rgb(hsb);
	vec3 output = mix(original_color.rgb, col, selection_color.a);
	COLOR = vec4(output.rgb, original_color.a);
}
