// Taken and modified from https://godotshaders.com/shader/2d-outline-inline/
// Also thanks to https://andreashackel.de/tech-art/stripes-shader-1/ for the stripe tutorial
shader_type canvas_item;

#include "CanvasCommon.gdshaderinc"
uniform vec4 first_color : source_color = vec4(1.0);
uniform vec4 second_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool animated = true;
uniform float frequency = 50.0;
uniform float stripe_direction : hint_range(0, 1) = 0.5;


void fragment() {
	vec2 ts = TEXTURE_PIXEL_SIZE;

	if (COLOR.a > 0.0 && has_contrary_neighbour(UV, ts, TEXTURE)) {
		vec2 ratio = (ts.x > ts.y) ? vec2(ts.y / ts.x, 1) : vec2(1, ts.x / ts.y);
		vec2 uv = UV * ratio;
		if(animated)
			uv -= TIME / frequency;
		// Generate diagonal stripes
		float pos = mix(uv.x, uv.y, stripe_direction) * frequency;
		float value = floor(fract(pos) + 0.5);
		COLOR = mix(first_color, second_color, step(1.0, mod(value, 2.0)));
	}
	else { // Erase the texture's pixels in order to only keep the outline visible
		COLOR.a = 0.0;
	}
}
