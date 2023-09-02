extends Button

const RULER_WIDTH := 16

var major_subdivision := 2
var minor_subdivision := 4

var first: Vector2
var last: Vector2


func _ready() -> void:
	Global.project_changed.connect(queue_redraw)
	Global.main_viewport.item_rect_changed.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	for guide in Global.current_project.guides:
		guide.force_input(event)


# Code taken and modified from Godot's source code
func _draw() -> void:
	var font: Font = Global.control.theme.default_font
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var zoom := Global.camera.zoom.x
	transform.y = Vector2(zoom, zoom)

	# This tracks the "true" top left corner of the drawing:
	transform.origin = (
		Global.main_viewport.size / 2
		+ Global.camera.offset.rotated(-Global.camera.rotation) * -zoom
	)

	var proj_size := Global.current_project.size

	# Calculating the rotated corners of the image, use min to find the top one
	var a := Vector2.ZERO  # Top left
	var b := Vector2(proj_size.x, 0).rotated(-Global.camera.rotation)  # Top right
	var c := Vector2(0, proj_size.y).rotated(-Global.camera.rotation)  # Bottom left
	var d := Vector2(proj_size.x, proj_size.y).rotated(-Global.camera.rotation)  # Bottom right
	transform.origin.y += minf(minf(a.y, b.y), minf(c.y, d.y)) * zoom

	var basic_rule := 100.0
	var i := 0
	while basic_rule * zoom > 100:
		basic_rule /= 5.0 if i % 2 else 2.0
		i += 1
	i = 0
	while basic_rule * zoom < 100:
		basic_rule *= 2.0 if i % 2 else 5.0
		i += 1

	ruler_transform = ruler_transform.scaled(Vector2(basic_rule, basic_rule))

	major_subdivide = major_subdivide.scaled(
		Vector2(1.0 / major_subdivision, 1.0 / major_subdivision)
	)
	minor_subdivide = minor_subdivide.scaled(
		Vector2(1.0 / minor_subdivision, 1.0 / minor_subdivision)
	)

	first = (
		(transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse()
		* (Vector2.ZERO)
	)
	last = (
		(transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse()
		* (Global.main_viewport.size)
	)

	for j in range(ceili(first.y), ceili(last.y)):
		var pos: Vector2 = (
			(transform * ruler_transform * major_subdivide * minor_subdivide) * (Vector2(0, j))
		)
		if j % (major_subdivision * minor_subdivision) == 0:
			draw_line(Vector2(0, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE)
			var text_xform := Transform2D(-PI / 2, Vector2(font.get_height() - 4, pos.y - 2))
			draw_set_transform_matrix(get_transform() * text_xform)
			var val := ((ruler_transform * major_subdivide * minor_subdivide) * Vector2(0, j)).y
			draw_string(font, Vector2(), str(snappedf(val, 0.1)))
			draw_set_transform_matrix(get_transform())
		else:
			if j % minor_subdivision == 0:
				draw_line(
					Vector2(RULER_WIDTH * 0.33, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE
				)
			else:
				draw_line(
					Vector2(RULER_WIDTH * 0.66, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE
				)


func _on_VerticalRuler_pressed() -> void:
	create_guide()


func create_guide() -> void:
	if !Global.show_guides:
		return
	var guide := Guide.new()
	if absf(Global.camera.rotation_degrees) < 45 or absf(Global.camera.rotation_degrees) > 135:
		guide.type = guide.Types.VERTICAL
		guide.add_point(Vector2(Global.canvas.current_pixel.x, -19999))
		guide.add_point(Vector2(Global.canvas.current_pixel.x, 19999))
	else:
		guide.type = guide.Types.HORIZONTAL
		guide.add_point(Vector2(-19999, Global.canvas.current_pixel.y))
		guide.add_point(Vector2(19999, Global.canvas.current_pixel.y))
	Global.canvas.add_child(guide)
	queue_redraw()
