class_name Guide
extends Line2D

enum Types { HORIZONTAL, VERTICAL }

const INPUT_WIDTH := 4

var font := preload("res://assets/fonts/Roboto-Regular.tres")
var has_focus := true
var mouse_pos := Vector2.ZERO
var type: int = Types.HORIZONTAL
var project = Global.current_project


func _ready() -> void:
	width = Global.camera.zoom.x * 2
	default_color = Global.guide_color
	project.guides.append(self)
	if _outside_canvas():
		modulate.a = 0.5


func _input(_event: InputEvent) -> void:
	if !visible:
		return
	var tmp_transform := get_canvas_transform().affine_inverse()
	var tmp_position: Vector2 = Global.main_viewport.get_local_mouse_position()
	mouse_pos = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	var point0 := points[0]
	var point1 := points[1]
	if type == Types.HORIZONTAL:
		point0.y -= width * INPUT_WIDTH
		point1.y += width * INPUT_WIDTH
	else:
		point0.x -= width * INPUT_WIDTH
		point1.x += width * INPUT_WIDTH
	var rect := Rect2()
	rect.position = point0
	rect.end = point1
	if (
		Input.is_action_just_pressed("left_mouse")
		and Global.can_draw
		and Global.has_focus
		and rect.has_point(mouse_pos)
	):
		if (
			!Rect2(Vector2.ZERO, project.size).has_point(Global.canvas.current_pixel)
			or Global.move_guides_on_canvas
		):
			has_focus = true
			Global.has_focus = false
			update()
	if has_focus:
		if Input.is_action_pressed("left_mouse"):
			if type == Types.HORIZONTAL:
				var yy := stepify(mouse_pos.y, 0.5)
				points[0].y = yy
				points[1].y = yy
			else:
				var xx := stepify(mouse_pos.x, 0.5)
				points[0].x = xx
				points[1].x = xx
			modulate.a = 0.5 if _outside_canvas() else 1.0
		elif Input.is_action_just_released("left_mouse"):
			Global.has_focus = true
			has_focus = false
			if _outside_canvas():
				project.guides.erase(self)
				queue_free()
			else:
				update()


func _draw() -> void:
	if !has_focus:
		return
	var viewport_size: Vector2 = Global.main_viewport.rect_size
	var zoom: Vector2 = Global.camera.zoom

	# viewport_poly is an array of the points that make up the corners of the viewport
	var viewport_poly := [
		Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)
	]
	# Adjusting viewport_poly to take into account the camera offset, zoom, and rotation
	for p in range(viewport_poly.size()):
		viewport_poly[p] = (
			viewport_poly[p].rotated(Global.camera.rotation) * zoom
			+ Vector2(
				(
					Global.camera.offset.x
					- (viewport_size.rotated(Global.camera.rotation).x / 2) * zoom.x
				),
				(
					Global.camera.offset.y
					- (viewport_size.rotated(Global.camera.rotation).y / 2) * zoom.y
				)
			)
		)

	var string := (
		"%spx"
		% str(stepify(mouse_pos.y if type == Types.HORIZONTAL else mouse_pos.x, 0.5))
	)
	var color: Color = Global.control.theme.get_color("font_color", "Label")
	# X and Y offsets for nicer looking spacing
	var x_offset := 5
	var y_offset := -7  # Only used where the string is above the guide

	var font_string_size := font.get_string_size(string)
	var font_height := font.get_height()
	# Draw the string where the guide intersects with the viewport poly
	# Priority is top edge, then left, then right
	var intersection = Geometry.segment_intersects_segment_2d(
		points[0], points[1], viewport_poly[0], viewport_poly[1]
	)

	if intersection:
		draw_set_transform(intersection, Global.camera.rotation, zoom * 2)
		if (
			intersection.distance_squared_to(viewport_poly[0])
			< intersection.distance_squared_to(viewport_poly[1])
		):
			draw_string(font, Vector2(x_offset, font_height), string, color)
		else:
			draw_string(font, Vector2(-font_string_size.x - x_offset, font_height), string, color)
		return

	intersection = Geometry.segment_intersects_segment_2d(
		points[0], points[1], viewport_poly[3], viewport_poly[0]
	)
	if intersection:
		draw_set_transform(intersection, Global.camera.rotation, zoom * 2)
		if (
			intersection.distance_squared_to(viewport_poly[3])
			< intersection.distance_squared_to(viewport_poly[0])
		):
			draw_string(font, Vector2(x_offset, y_offset), string, color)
		else:
			draw_string(font, Vector2(x_offset, font_height), string, color)
		return

	intersection = Geometry.segment_intersects_segment_2d(
		points[0], points[1], viewport_poly[1], viewport_poly[2]
	)

	if intersection:
		draw_set_transform(intersection, Global.camera.rotation, zoom * 2)
		if (
			intersection.distance_squared_to(viewport_poly[1])
			< intersection.distance_squared_to(viewport_poly[2])
		):
			draw_string(font, Vector2(-font_string_size.x - x_offset, font_height), string, color)
		else:
			draw_string(font, Vector2(-font_string_size.x - x_offset, y_offset), string, color)
		return

	# If there's no intersection with a viewport edge, show string in top left corner
	draw_set_transform(viewport_poly[0], Global.camera.rotation, zoom * 2)
	draw_string(font, Vector2(x_offset, font_height), string, color)


func _outside_canvas() -> bool:
	if type == Types.HORIZONTAL:
		return points[0].y < 0 || points[0].y > project.size.y
	else:
		return points[0].x < 0 || points[0].x > project.size.x
