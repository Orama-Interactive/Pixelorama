#include "drawing_algos.hpp"

#include <godot_cpp/variant/utility_functions.hpp>

void DrawingAlgosCpp::_bind_methods()
{
    godot::ClassDB::bind_method(godot::D_METHOD("get_ellipse_points", "pos", "size"), &DrawingAlgosCpp::GetEllipsePoints);
}

DrawingAlgosCpp::DrawingAlgosCpp()
{
}

godot::Array DrawingAlgosCpp::GetEllipsePoints(godot::Vector2i pos, godot::Vector2i size)
{
    godot::Array array;
    int x0 = pos.x;
    int x1 = pos.x + (size.x - 1);
	int y0 = pos.y;
	int y1 = pos.y + (size.y - 1);
	int a = godot::UtilityFunctions::absi(x1 - x0);
	int b = godot::UtilityFunctions::absi(y1 - y0);
	int b1 = b & 1;
	int dx = 4 * (1 - a) * b * b;
	int dy = 4 * (b1 + 1) * a * a;
	int err = dx + dy + b1 * a * a;
	int e2 = 0;

    if (x0 > x1)
    {
        x0 = x1;
		x1 += a;
    }

	if (y0 > y1)    
		y0 = y1;

	y0 += (b + 1) / 2;
	y1 = y0 - b1;
	a *= 8 * a;
	b1 = 8 * b * b;

    while (x0 <= x1)
    {
		godot::Vector2i v1 = godot::Vector2i(x1, y0);
		godot::Vector2i v2 = godot::Vector2i(x0, y0);
		godot::Vector2i v3 = godot::Vector2i(x0, y1);
		godot::Vector2i v4 = godot::Vector2i(x1, y1);
		array.append(v1);
		array.append(v2);
		array.append(v3);
		array.append(v4);

		e2 = 2 * err;
		if (e2 <= dy)
        {
			y0 += 1;
			y1 -= 1;
			dy += a;
			err += dy;
        }

		if (e2 >= dx || 2 * err > dy)
        {
			x0 += 1;
			x1 -= 1;
			dx += b1;
			err += dx;
        }
    }

	while (y0 - y1 < b)
    {
		godot::Vector2i v1 = godot::Vector2i(x0 - 1, y0);
		godot::Vector2i v2 = godot::Vector2i(x1 + 1, y0);
		godot::Vector2i v3 = godot::Vector2i(x0 - 1, y1);
		godot::Vector2i v4 = godot::Vector2i(x1 + 1, y1);
		array.append(v1);
		array.append(v2);
		array.append(v3);
		array.append(v4);
		y0 += 1;
		y1 -= 1;
    }

    return array;
}