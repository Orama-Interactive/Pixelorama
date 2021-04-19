shader_type canvas_item;
render_mode unshaded;

uniform bool red;
uniform bool blue;
uniform bool green;
uniform bool alpha;
uniform sampler2D selection;
uniform bool affect_selection;
uniform bool has_selection;

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
	float gray = hsb.z;
    if (red)
        col.x = gray;
    if (green)
        col.y = gray;
    if (blue)
        col.z = gray;

	vec3 output;
	if(affect_selection && has_selection)
		output = mix(original_color.rgb, col, selection_color.a);
	else
		output = col;
    if (alpha)
	    COLOR = vec4(output.rgb, gray);
    else 
        COLOR = vec4(output.rgb, original_color.a);

}