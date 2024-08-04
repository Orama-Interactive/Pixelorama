shader_type canvas_item;
#include "CanvasCommon.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture;
uniform bool hollow_shapes = true;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec3 inverted = vec3(1.0) - color.rgb;
	vec3 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float screen_avg = (screen_color.r + screen_color.g + screen_color.b) / 3.0;

	color.rgb = inverted * step(0.5, screen_avg) + color.rgb * step(screen_avg, 0.5);
	if (hollow_shapes) {
		if (COLOR.a > 0.0 && has_contrary_neighbour(UV, TEXTURE_PIXEL_SIZE, TEXTURE)) {
			COLOR = color;
		}
		else { // Erase the texture's pixels in order to only keep the outline visible
			COLOR.a = 0.0;
		}
	}
	else {
		COLOR = color;
	}
}
