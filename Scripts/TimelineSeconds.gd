extends Control

const RULER_WIDTH := 16

var font := preload("res://Assets/Fonts/Roboto-Small.tres")
var major_subdivision := 2
var minor_subdivision := 3

var first : Vector2
var last : Vector2

# warning-ignore:unused_argument
func _process(delta) -> void:
	update()

#Code taken and modified from Godot's source code
func _draw() -> void:
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var fps = Global.control.fps
	var horizontal_scroll = get_parent().get_node("FrameAndButtonContainer").get_node("ScrollContainer").scroll_horizontal
	var starting_pos := Vector2(26, 26)
	transform.x = Vector2(fps, fps) / 2.52

	transform.origin = starting_pos - Vector2(horizontal_scroll, horizontal_scroll)

	var basic_rule := 100.0
	while(basic_rule * fps > 100):
		basic_rule /= 2.0
	while(basic_rule * fps < 100):
		basic_rule *= 2.0

	ruler_transform = ruler_transform.scaled(Vector2(basic_rule, basic_rule))

	major_subdivide = major_subdivide.scaled(Vector2(1.0 / major_subdivision, 1.0 / major_subdivision))
	minor_subdivide = minor_subdivide.scaled(Vector2(1.0 / minor_subdivision, 1.0 / minor_subdivision))

	first = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(starting_pos)
	last = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(rect_size - starting_pos)

	for i in range(ceil(first.x), last.x):
		var position : Vector2 = (transform * ruler_transform * major_subdivide * minor_subdivide).xform(Vector2(i, 0))
		if i % (major_subdivision * minor_subdivision) == 0:
			draw_line(Vector2(position.x + RULER_WIDTH, 0), Vector2(position.x + RULER_WIDTH, RULER_WIDTH), Color.white)
			var val = (ruler_transform * major_subdivide * minor_subdivide).xform(Vector2(i, 0)).x / 100
			val = stepify(val, 0.01)
			draw_string(font, Vector2(position.x + RULER_WIDTH + 2, font.get_height() - 6), str(val))
		else:
			if i % minor_subdivision == 0:
				draw_line(Vector2(position.x + RULER_WIDTH, RULER_WIDTH * 0.33), Vector2(position.x + RULER_WIDTH, RULER_WIDTH), Color.white)
			else:
				draw_line(Vector2(position.x + RULER_WIDTH, RULER_WIDTH * 0.66), Vector2(position.x + RULER_WIDTH, RULER_WIDTH), Color.white)