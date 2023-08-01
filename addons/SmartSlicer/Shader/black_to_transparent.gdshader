shader_type canvas_item;


void fragment()
{
	vec4 uv = texture(TEXTURE, UV);
	if (uv.rgba == vec4(0.0, 0.0, 0.0, 1.0))
	{
		COLOR.a = 0.0;
	}
	else{
		COLOR = uv
	}
}