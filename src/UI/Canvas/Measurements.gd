extends Node2D

const WIDTH = 1

var font: Font
var line_color = Global.guide_color
var mode = Global.MeasurementMode.NONE
var apparent_width = WIDTH
var rect_bounds: Rect2i


func _ready() -> void:
	font = Global.control.theme.default_font


func update_measurement(mode_idx := Global.MeasurementMode.NONE):
	mode = mode_idx
	queue_redraw()


func _draw() -> void:
	match mode:
		Global.MeasurementMode.MOVE:
			_prepare_movement_rect()
			draw_move_measurement()
		_:
			rect_bounds = Rect2i()


func draw_move_measurement():
	var p_size = Global.current_project.size
	var dashed_color = line_color
	dashed_color.a = 0.5
	# Draw boundary
	var boundary = Rect2i(rect_bounds)
	boundary.position += Global.canvas.move_preview_location
	draw_rect(boundary, line_color, false, apparent_width)
	# calculate lines
	var top = Vector2(boundary.get_center().x, boundary.position.y)
	var bottom = Vector2(boundary.get_center().x, boundary.end.y)
	var left = Vector2(boundary.position.x, boundary.get_center().y)
	var right = Vector2(boundary.end.x, boundary.get_center().y)
	var p_vertical = [Vector2(top.x, 0), Vector2(bottom.x, p_size.y)]  # top, bottom
	var p_horizontal = [Vector2(0, left.y), Vector2(p_size.x, right.y)]  # left, right
	var lines = []
	if left.x > -boundary.size.x:  # left side
		if left.x < p_size.x:
			lines.append([left, p_horizontal[0]])
		else:
			lines.append([left, p_horizontal[1]])
	if right.x < p_size.x + boundary.size.x:  # right side
		if right.x > 0:
			lines.append([right, p_horizontal[1]])
		else:
			lines.append([right, p_horizontal[0]])
	if top.y > -boundary.size.y:  # top side
		if top.y < p_size.y:
			lines.append([top, p_vertical[0]])
		else:
			lines.append([top, p_vertical[1]])
	if bottom.y < p_size.y + boundary.size.y:  # bottom side
		if bottom.y > 0:
			lines.append([bottom, p_vertical[1]])
		else:
			lines.append([bottom, p_vertical[0]])
	for line in lines:
		if !Rect2i(Vector2.ZERO, p_size + Vector2i.ONE).has_point(line[1]):
			var point_a := Vector2.ZERO
			var point_b := Vector2.ZERO
			# project lines if needed
			if line[1] == p_vertical[0]:  # upper horizontal projection
				point_a = Vector2(p_size.x / 2, 0)
				point_b = Vector2(top.x, 0)
			elif line[1] == p_vertical[1]:  # lower horizontal projection
				point_a = Vector2(p_size.x / 2, p_size.y)
				point_b = Vector2(bottom.x, p_size.y)
			elif line[1] == p_horizontal[0]:  # left vertical projection
				point_a = Vector2(0, p_size.y / 2)
				point_b = Vector2(0, left.y)
			elif line[1] == p_horizontal[1]:  # right vertical projection
				point_a = Vector2(p_size.x, p_size.y / 2)
				point_b = Vector2(p_size.x, right.y)
			var offset = (point_b - point_a).normalized() * (boundary.size / 2.0)
			draw_dashed_line(point_a + offset, point_b + offset, dashed_color, apparent_width)
		draw_line(line[0], line[1], line_color, apparent_width)
		var string_vec = line[0] + (line[1] - line[0]) / 2
		draw_set_transform(Vector2.ZERO, Global.camera.rotation, Vector2.ONE / Global.camera.zoom)
		draw_string(
			font,
			string_vec * Global.camera.zoom,
			str(line[0].distance_to(line[1]), "px"),
			HORIZONTAL_ALIGNMENT_LEFT
		)
		draw_set_transform(Vector2.ZERO, Global.camera.rotation, Vector2.ONE)


func _input(_event: InputEvent) -> void:
	apparent_width = WIDTH / Global.camera.zoom.x


func _prepare_movement_rect():
	var project := Global.current_project
	if project.has_selection:
		rect_bounds = Global.canvas.selection.preview_image.get_used_rect()
		rect_bounds.position += Vector2i(
			Global.canvas.selection.big_bounding_rectangle.position
		)
		return
	if rect_bounds.has_area():
		return
	var selected_cels = Global.current_project.selected_cels
	var frames = []
	for selected_cel in selected_cels:
		if not selected_cel[0] in frames:
			frames.append(selected_cel[0])
	for frame in frames:
		# Find used rect of the current frame (across all of the layers)
		var used_rect := Rect2i()
		for cel_idx in project.frames[frame].cels.size():
			if not [frame, cel_idx] in selected_cels:
				continue
			var cel = project.frames[frame].cels[cel_idx]
			if not cel is PixelCel:
				continue
			var cel_rect := cel.get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
		if not used_rect.has_area():
			continue
		if !rect_bounds.has_area():
			rect_bounds = used_rect
		else:
			rect_bounds = rect_bounds.merge(used_rect)
	if not rect_bounds.has_area():
		rect_bounds = Rect2(Vector2.ZERO, project.size)
