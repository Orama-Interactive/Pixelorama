// https://godotshaders.com/shader/color-reduction-and-dither/
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection : filter_nearest;
uniform float colors : hint_range(1.0, 255.0) = 2.0;
uniform float dither_intensity : hint_range(0.0, 0.5) = 0.0;

void fragment()
{
	vec4 color = texture(TEXTURE, UV);
	vec4 selection_color = texture(selection, UV);

	float a = floor(mod(UV.x / TEXTURE_PIXEL_SIZE.x, 2.0));
	float b = floor(mod(UV.y / TEXTURE_PIXEL_SIZE.y, 2.0));
	float c = mod(a + b, 2.0);
	vec4 col;
	col.r = (round(color.r * colors + dither_intensity) / colors) * c;
	col.g = (round(color.g * colors + dither_intensity) / colors) * c;
	col.b = (round(color.b * colors + dither_intensity) / colors) * c;
	c = 1.0 - c;
	col.r += (round(color.r * colors - dither_intensity) / colors) * c;
	col.g += (round(color.g * colors - dither_intensity) / colors) * c;
	col.b += (round(color.b * colors - dither_intensity) / colors) * c;
	col.a = color.a;
	vec4 output = mix(color.rgba, col, selection_color.a);
	COLOR = output;
}
