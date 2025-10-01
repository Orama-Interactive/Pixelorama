class_name Guide
extends Line2D

enum Types { HORIZONTAL, VERTICAL, XY, X_MINUS_Y }

const INPUT_WIDTH := 4

var font := Themes.get_font()
var has_focus := true
var mouse_pos := Vector2.ZERO
var type := Types.HORIZONTAL
var project := Global.current_project


func _ready() -> void:
	Global.project_switched.connect(_project_switched)
	width = 2.0 / get_viewport().canvas_transform.get_scale().x
	default_color = Global.guide_color
	project.guides.append(self)
	if _outside_canvas():
		modulate.a = 0.5


func _input(_event: InputEvent) -> void:
	if not visible:
		return
	mouse_pos = get_local_mouse_position()

	var point0 := points[0]
	var point1 := points[1]
	if type == Types.HORIZONTAL:
		point0.y -= width * INPUT_WIDTH
		point1.y += width * INPUT_WIDTH
	elif type == Types.VERTICAL:
		point0.x -= width * INPUT_WIDTH
		point1.x += width * INPUT_WIDTH
	var rect := Rect2()
	rect.position = point0
	rect.end = point1
	rect = rect.abs()
	if (
		Input.is_action_just_pressed(&"left_mouse")
		and Global.can_draw
		and rect.has_point(mouse_pos)
	):
		if (
			!Rect2i(Vector2i.ZERO, project.size).has_point(Global.canvas.current_pixel)
			or Global.move_guides_on_canvas
		):
			has_focus = true
			Global.can_draw = false
			queue_redraw()
	if has_focus:
		if Input.is_action_pressed(&"left_mouse"):
			if type == Types.HORIZONTAL:
				var yy := snappedf(mouse_pos.y, 0.5)
				points[0].y = yy
				points[1].y = yy
			elif type == Types.VERTICAL:
				var xx := snappedf(mouse_pos.x, 0.5)
				points[0].x = xx
				points[1].x = xx
			modulate.a = 0.5 if _outside_canvas() else 1.0
		elif Input.is_action_just_released(&"left_mouse"):
			Global.can_draw = true
			has_focus = false
			if _outside_canvas():
				project.guides.erase(self)
				queue_free()
			else:
				queue_redraw()


func _draw() -> void:
	if !has_focus:
		return
	var viewport_size := get_viewport_rect().size
	var half_size := viewport_size * 0.5
	var zoom := get_viewport().canvas_transform.get_scale()
	var canvas_rotation := -get_viewport().canvas_transform.get_rotation()
	var origin := get_viewport().canvas_transform.get_origin()
	var pure_origin := (origin / zoom).rotated(canvas_rotation)
	var zoom_scale := Vector2.ONE / zoom
	var offset := -pure_origin + (half_size * zoom_scale).rotated(canvas_rotation)

	# An array of the points that make up the corners of the viewport
	var viewport_poly := PackedVector2Array(
		[Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]
	)
	# Adjusting viewport_poly to take into account the camera offset, zoom, and rotation
	for p in range(viewport_poly.size()):
		viewport_poly[p] = (
			viewport_poly[p].rotated(canvas_rotation) * zoom
			+ Vector2(
				offset.x - (viewport_size.rotated(canvas_rotation).x / 2) / zoom.x,
				offset.y - (viewport_size.rotated(canvas_rotation).y / 2) / zoom.y
			)
		)

	var string := (
		"%spx" % str(snappedf(mouse_pos.y if type == Types.HORIZONTAL else mouse_pos.x, 0.5))
	)
	var color: Color = Global.control.theme.get_color("font_color", "Label")
	# X and Y offsets for nicer looking spacing
	var x_offset := 5
	var y_offset := -7  # Only used where the string is above the guide

	var font_string_size := font.get_string_size(string)
	var font_height := font.get_height()
	# Draw the string where the guide intersects with the viewport poly
	# Priority is top edge, then left, then right
	var intersection = Geometry2D.segment_intersects_segment(
		points[0], points[1], viewport_poly[0], viewport_poly[1]
	)

	if intersection:
		draw_set_transform(intersection, canvas_rotation, Vector2(2.0, 2.0) / zoom)
		if (
			intersection.distance_squared_to(viewport_poly[0])
			< intersection.distance_squared_to(viewport_poly[1])
		):
			draw_string(
				font,
				Vector2(x_offset, font_height),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		else:
			draw_string(
				font,
				Vector2(-font_string_size.x - x_offset, font_height),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		return

	intersection = Geometry2D.segment_intersects_segment(
		points[0], points[1], viewport_poly[3], viewport_poly[0]
	)
	if intersection:
		draw_set_transform(intersection, canvas_rotation, Vector2(2.0, 2.0) / zoom)
		if (
			intersection.distance_squared_to(viewport_poly[3])
			< intersection.distance_squared_to(viewport_poly[0])
		):
			draw_string(
				font,
				Vector2(x_offset, y_offset),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		else:
			draw_string(
				font,
				Vector2(x_offset, font_height),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		return

	intersection = Geometry2D.segment_intersects_segment(
		points[0], points[1], viewport_poly[1], viewport_poly[2]
	)

	if intersection:
		draw_set_transform(intersection, canvas_rotation, Vector2(2.0, 2.0) / zoom)
		if (
			intersection.distance_squared_to(viewport_poly[1])
			< intersection.distance_squared_to(viewport_poly[2])
		):
			draw_string(
				font,
				Vector2(-font_string_size.x - x_offset, font_height),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		else:
			draw_string(
				font,
				Vector2(-font_string_size.x - x_offset, y_offset),
				string,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				Themes.get_font_size(),
				color
			)
		return

	# If there's no intersection with a viewport edge, show string in top left corner
	draw_set_transform(viewport_poly[0], canvas_rotation, Vector2(2.0, 2.0) / zoom)
	draw_string(
		font,
		Vector2(x_offset, font_height),
		string,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		Themes.get_font_size(),
		color
	)


func force_input(event: InputEvent) -> void:
	_input(event)


func set_color(color: Color) -> void:
	default_color = color


func get_direction() -> Vector2:
	return points[0].direction_to(points[1])


func _project_switched() -> void:
	if self in Global.current_project.guides:
		visible = Global.show_guides
		if self is SymmetryGuide:
			if type == Types.HORIZONTAL:
				visible = Global.show_x_symmetry_axis and Global.show_guides
			elif type == Types.VERTICAL:
				visible = Global.show_y_symmetry_axis and Global.show_guides
			elif type == Types.XY:
				visible = Global.show_xy_symmetry_axis and Global.show_guides
			elif type == Types.X_MINUS_Y:
				visible = Global.show_x_minus_y_symmetry_axis and Global.show_guides
	else:
		visible = false


func _outside_canvas() -> bool:
	if type == Types.HORIZONTAL:
		return points[0].y < 0 || points[0].y > project.size.y
	else:
		return points[0].x < 0 || points[0].x > project.size.x
