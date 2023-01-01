extends Button

const RULER_WIDTH := 16

var font := preload("res://assets/fonts/Roboto-Small.tres")
var major_subdivision := 2
var minor_subdivision := 4

var first: Vector2
var last: Vector2


func _ready() -> void:
	Global.main_viewport.connect("item_rect_changed", self, "update")


# Code taken and modified from Godot's source code
func _draw() -> void:
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var zoom: float = 1 / Global.camera.zoom.x
	transform.x = Vector2(zoom, zoom)

	# This tracks the "true" top left corner of the drawing:
	transform.origin = (
		Global.main_viewport.rect_size / 2
		+ Global.camera.offset.rotated(-Global.camera.rotation) * -zoom
	)

	var proj_size := Global.current_project.size

	# Calculating the rotated corners of the image, use min to find the farthest left
	var a := Vector2.ZERO  # Top left
	var b := Vector2(proj_size.x, 0).rotated(-Global.camera.rotation)  # Top right
	var c := Vector2(0, proj_size.y).rotated(-Global.camera.rotation)  # Bottom left
	var d := Vector2(proj_size.x, proj_size.y).rotated(-Global.camera.rotation)  # Bottom right
	transform.origin.x += min(min(a.x, b.x), min(c.x, d.x)) * zoom

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

	first = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(
		Vector2.ZERO
	)
	last = (transform * ruler_transform * major_subdivide * minor_subdivide).affine_inverse().xform(
		Global.main_viewport.rect_size
	)

	for j in range(ceil(first.x), ceil(last.x)):
		var position: Vector2 = (transform * ruler_transform * major_subdivide * minor_subdivide).xform(
			Vector2(j, 0)
		)
		if j % (major_subdivision * minor_subdivision) == 0:
			draw_line(
				Vector2(position.x + RULER_WIDTH, 0),
				Vector2(position.x + RULER_WIDTH, RULER_WIDTH),
				Color.white
			)
			var val = (ruler_transform * major_subdivide * minor_subdivide).xform(Vector2(j, 0)).x
			draw_string(
				font,
				Vector2(position.x + RULER_WIDTH + 2, font.get_height() - 4),
				str(stepify(val, 0.1))
			)
		else:
			if j % minor_subdivision == 0:
				draw_line(
					Vector2(position.x + RULER_WIDTH, RULER_WIDTH * 0.33),
					Vector2(position.x + RULER_WIDTH, RULER_WIDTH),
					Color.white
				)
			else:
				draw_line(
					Vector2(position.x + RULER_WIDTH, RULER_WIDTH * 0.66),
					Vector2(position.x + RULER_WIDTH, RULER_WIDTH),
					Color.white
				)


func _on_HorizontalRuler_pressed() -> void:
	create_guide()


func create_guide() -> void:
	if !Global.show_guides:
		return
	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x < RULER_WIDTH:  # For double guides
		Global.vertical_ruler.create_guide()
	var guide := Guide.new()
	if abs(Global.camera.rotation_degrees) < 45 or abs(Global.camera.rotation_degrees) > 135:
		guide.type = guide.Types.HORIZONTAL
		guide.add_point(Vector2(-19999, Global.canvas.current_pixel.y))
		guide.add_point(Vector2(19999, Global.canvas.current_pixel.y))
	else:
		guide.type = guide.Types.VERTICAL
		guide.add_point(Vector2(Global.canvas.current_pixel.x, -19999))
		guide.add_point(Vector2(Global.canvas.current_pixel.x, 19999))
	Global.canvas.add_child(guide)
	Global.has_focus = false
	update()


func _on_HorizontalRuler_mouse_entered() -> void:
	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x < RULER_WIDTH:  # For double guides
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	else:
		mouse_default_cursor_shape = Control.CURSOR_VSPLIT
