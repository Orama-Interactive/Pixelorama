shader_type canvas_item;

uniform float alpha = 0.0;

uniform vec2 screen_resolution = vec2(1280, 720);
uniform vec2 position = vec2(100.0, 100.0);
uniform vec2 size = vec2(100.0, 100.0);


void fragment(){

	if (
	SCREEN_UV.x >= (position.x)/(screen_resolution.x)
	&& (SCREEN_UV.y) >= (position.y)/(screen_resolution.y)

	&& SCREEN_UV.x <= (position.x + size.x)/(screen_resolution.x)
	&& (SCREEN_UV.y) <= (position.y + size.y)/(screen_resolution.y)
	){
		COLOR.a = alpha;
	}
}
