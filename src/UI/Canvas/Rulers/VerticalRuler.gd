extends Button

const RULER_WIDTH := 16

var font := preload("res://assets/fonts/Roboto-Small.tres")
var major_subdivision := 2
var minor_subdivision := 4

var first : Vector2
var last : Vector2


func _ready() -> void:
	Global.main_viewport.connect("item_rect_changed", self, "update")


# Code taken and modified from Godot's source code
func _draw() -> void:
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var zoom: float = 1 / Global.camera.zoom.x
	transform.y = Vector2(zoom, zoom)

	transform.origin = Global.main_viewport.rect_size / 2 + Global.camera.offset * -zoom

	var basic_rule := 100.0
	var i := 0
	while(basic_rule * zoom > 100):
		basic_rule /= 5.0 if i % 2 else 2.0
		i += 1
	i = 0
	while(basic_rule * zoom < 100):
		basic_rule *= 2.0 if i % 2 else 5.0
		i += 1

	ruler_transform = ruler_transform.scaled(Vector2(basic_rule, basic_rule))

	major_subdivide = major_subdivide.scaled(Vector2(1.0 / major_subdivision, 1.0 / major_subdivision))
	minor_subdivide = minor_subdivide.scaled(Vector2(1.0 / minor_subdivision, 1.0 / minor_subdivision))

	first = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(Vector2.ZERO)
	last = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(Global.main_viewport.rect_size)

	for j in range(ceil(first.y), ceil(last.y)):
		var position : Vector2 = (transform * ruler_transform * major_subdivide * minor_subdivide).xform(Vector2(0, j))
		if j % (major_subdivision * minor_subdivision) == 0:
			draw_line(Vector2(0, position.y), Vector2(RULER_WIDTH, position.y), Color.white)
			var text_xform = Transform2D(-PI / 2, Vector2(font.get_height() - 4, position.y - 2))
			draw_set_transform_matrix(get_transform() * text_xform)
			var val = (ruler_transform * major_subdivide * minor_subdivide).xform(Vector2(0, j)).y
			draw_string(font, Vector2(), str(int(val)))
			draw_set_transform_matrix(get_transform())
		else:
			if j % minor_subdivision == 0:
				draw_line(Vector2(RULER_WIDTH * 0.33, position.y), Vector2(RULER_WIDTH, position.y), Color.white)
			else:
				draw_line(Vector2(RULER_WIDTH * 0.66, position.y), Vector2(RULER_WIDTH, position.y), Color.white)


func _on_VerticalRuler_pressed() -> void:
	if !Global.show_guides:
		return
	var guide := Guide.new()
	guide.type = guide.Types.VERTICAL
	guide.add_point(Vector2(Global.canvas.current_pixel.x, -19999))
	guide.add_point(Vector2(Global.canvas.current_pixel.x, 19999))
	if guide.points.size() < 2:
		guide.queue_free()
		return
	Global.canvas.add_child(guide)
	Global.has_focus = false
	update()
