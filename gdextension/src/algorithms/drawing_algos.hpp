#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

class DrawingAlgosCpp : public godot::Node
{
    GDCLASS(DrawingAlgosCpp, Node)

public:
    DrawingAlgosCpp();
    ~DrawingAlgosCpp() = default;

    godot::Array GetEllipsePoints(godot::Vector2i pos, godot::Vector2i size);

protected:
    static void _bind_methods();
};
