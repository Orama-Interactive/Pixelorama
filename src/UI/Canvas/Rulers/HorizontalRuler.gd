extends Button

const RULER_WIDTH := 16

var major_subdivision := 2
var minor_subdivision := 4

var first: Vector2
var last: Vector2

@onready var vertical_ruler := $"../ViewportandVerticalRuler/VerticalRuler" as Button


func _ready() -> void:
	Global.project_switched.connect(queue_redraw)
	Global.camera.zoom_changed.connect(queue_redraw)
	Global.camera.rotation_changed.connect(queue_redraw)
	Global.camera.offset_changed.connect(queue_redraw)
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	for guide in Global.current_project.guides:
		guide.force_input(event)


# Code taken and modified from Godot's source code
func _draw() -> void:
	var font := Themes.get_font()
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var zoom := Global.camera.zoom.x
	transform.x = Vector2(zoom, zoom)

	# This tracks the "true" top left corner of the drawing:
	transform.origin = (
		Global.main_viewport.size / 2
		+ Global.camera.offset.rotated(-Global.camera.rotation) * -zoom
	)

	var proj_size := Global.current_project.size

	# Calculating the rotated corners of the image, use min to find the farthest left
	var a := Vector2.ZERO  # Top left
	var b := Vector2(proj_size.x, 0).rotated(-Global.camera.rotation)  # Top right
	var c := Vector2(0, proj_size.y).rotated(-Global.camera.rotation)  # Bottom left
	var d := Vector2(proj_size.x, proj_size.y).rotated(-Global.camera.rotation)  # Bottom right
	transform.origin.x += minf(minf(a.x, b.x), minf(c.x, d.x)) * zoom

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

	for j in range(ceili(first.x), ceili(last.x)):
		var pos: Vector2 = (
			(transform * ruler_transform * major_subdivide * minor_subdivide) * (Vector2(j, 0))
		)
		if j % (major_subdivision * minor_subdivision) == 0:
			draw_line(
				Vector2(pos.x + RULER_WIDTH, 0),
				Vector2(pos.x + RULER_WIDTH, RULER_WIDTH),
				Color.WHITE
			)
			var val := ((ruler_transform * major_subdivide * minor_subdivide) * Vector2(j, 0)).x
			draw_string(
				font,
				Vector2(pos.x + RULER_WIDTH + 2, font.get_height() - 4),
				str(snappedf(val, 0.1)),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size()
			)
		else:
			if j % minor_subdivision == 0:
				draw_line(
					Vector2(pos.x + RULER_WIDTH, RULER_WIDTH * 0.33),
					Vector2(pos.x + RULER_WIDTH, RULER_WIDTH),
					Color.WHITE
				)
			else:
				draw_line(
					Vector2(pos.x + RULER_WIDTH, RULER_WIDTH * 0.66),
					Vector2(pos.x + RULER_WIDTH, RULER_WIDTH),
					Color.WHITE
				)


func _on_HorizontalRuler_pressed() -> void:
	create_guide()


func create_guide() -> void:
	if !Global.show_guides:
		return
	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x < RULER_WIDTH:  # For double guides
		vertical_ruler.create_guide()
	var guide := Guide.new()
	if absf(Global.camera.rotation_degrees) < 45 or absf(Global.camera.rotation_degrees) > 135:
		guide.type = guide.Types.HORIZONTAL
		guide.add_point(Vector2(-19999, Global.canvas.current_pixel.y))
		guide.add_point(Vector2(19999, Global.canvas.current_pixel.y))
	else:
		guide.type = guide.Types.VERTICAL
		guide.add_point(Vector2(Global.canvas.current_pixel.x, -19999))
		guide.add_point(Vector2(Global.canvas.current_pixel.x, 19999))
	Global.canvas.add_child(guide)
	queue_redraw()


func _on_HorizontalRuler_mouse_entered() -> void:
	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x < RULER_WIDTH:  # For double guides
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	else:
		mouse_default_cursor_shape = Control.CURSOR_VSPLIT
