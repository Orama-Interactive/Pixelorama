extends Node2D

const WIDTH := 2

var font: Font
var line_color := Global.guide_color
var mode := Global.MeasurementMode.NONE
var apparent_width: float = WIDTH
var rect_bounds: Rect2i

@onready var canvas := get_parent() as Canvas


func _ready() -> void:
	font = Themes.get_font()


func update_measurement(mode_idx := Global.MeasurementMode.NONE) -> void:
	mode = mode_idx
	queue_redraw()


func _draw() -> void:
	match mode:
		Global.MeasurementMode.MOVE:
			_prepare_movement_rect()
			_draw_move_measurement()
		_:
			rect_bounds = Rect2i()


func _input(_event: InputEvent) -> void:
	apparent_width = WIDTH / Global.camera.zoom.x


func _prepare_movement_rect() -> void:
	var project := Global.current_project
	if project.has_selection:
		rect_bounds = canvas.selection.preview_image.get_used_rect()
		rect_bounds.position += Vector2i(canvas.selection.big_bounding_rectangle.position)
		if !rect_bounds.has_area():
			rect_bounds = canvas.selection.big_bounding_rectangle
		return
	if rect_bounds.has_area():
		return
	var selected_cels := Global.current_project.selected_cels
	var frames := []
	for selected_cel in selected_cels:
		if not selected_cel[0] in frames:
			frames.append(selected_cel[0])
	for frame in frames:
		# Find used rect of the current frame (across all of the layers)
		var used_rect := Rect2i()
		for cel_idx in project.frames[frame].cels.size():
			if not [frame, cel_idx] in selected_cels:
				continue
			var cel := project.frames[frame].cels[cel_idx]
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
		rect_bounds = Rect2i(Vector2i.ZERO, project.size)


func _draw_move_measurement() -> void:
	var p_size := Global.current_project.size
	var dashed_color := line_color
	dashed_color.a = 0.5
	# Draw boundary
	var boundary := Rect2i(rect_bounds)
	boundary.position += canvas.move_preview_location
	draw_rect(boundary, line_color, false, apparent_width)
	# calculate lines
	var top := Vector2(boundary.get_center().x, boundary.position.y)
	var bottom := Vector2(boundary.get_center().x, boundary.end.y)
	var left := Vector2(boundary.position.x, boundary.get_center().y)
	var right := Vector2(boundary.end.x, boundary.get_center().y)
	# Top, bottom
	var p_vertical := PackedVector2Array([Vector2(top.x, 0), Vector2(bottom.x, p_size.y)])
	# Left, right
	var p_horizontal := PackedVector2Array([Vector2(0, left.y), Vector2(p_size.x, right.y)])
	var lines: Array[PackedVector2Array] = []
	if left.x > -boundary.size.x:  # Left side
		if left.x < p_size.x:
			lines.append(PackedVector2Array([left, p_horizontal[0]]))
		else:
			lines.append(PackedVector2Array([left, p_horizontal[1]]))
	if right.x < p_size.x + boundary.size.x:  # Right side
		if right.x > 0:
			lines.append(PackedVector2Array([right, p_horizontal[1]]))
		else:
			lines.append(PackedVector2Array([right, p_horizontal[0]]))
	if top.y > -boundary.size.y:  # Top side
		if top.y < p_size.y:
			lines.append(PackedVector2Array([top, p_vertical[0]]))
		else:
			lines.append(PackedVector2Array([top, p_vertical[1]]))
	if bottom.y < p_size.y + boundary.size.y:  # Bottom side
		if bottom.y > 0:
			lines.append(PackedVector2Array([bottom, p_vertical[1]]))
		else:
			lines.append(PackedVector2Array([bottom, p_vertical[0]]))
	for line in lines:
		if !Rect2i(Vector2i.ZERO, p_size + Vector2i.ONE).has_point(line[1]):
			var point_a := Vector2.ZERO
			var point_b := Vector2.ZERO
			# Project lines if needed
			if line[1] == p_vertical[0]:  # Upper horizontal projection
				point_a = Vector2(p_size.x / 2.0, 0)
				point_b = Vector2(top.x, 0)
			elif line[1] == p_vertical[1]:  # Lower horizontal projection
				point_a = Vector2(p_size.x / 2.0, p_size.y)
				point_b = Vector2(bottom.x, p_size.y)
			elif line[1] == p_horizontal[0]:  # Left vertical projection
				point_a = Vector2(0, p_size.y / 2.0)
				point_b = Vector2(0, left.y)
			elif line[1] == p_horizontal[1]:  # Right vertical projection
				point_a = Vector2(p_size.x, p_size.y / 2.0)
				point_b = Vector2(p_size.x, right.y)
			var offset := (point_b - point_a).normalized() * (boundary.size / 2.0)
			draw_dashed_line(point_a + offset, point_b + offset, dashed_color, apparent_width)
		draw_line(line[0], line[1], line_color, apparent_width)
		var string_vec := line[0] + (line[1] - line[0]) / 2.0
		draw_set_transform(Vector2.ZERO, Global.camera.rotation, Vector2.ONE / Global.camera.zoom)
		draw_string(font, string_vec * Global.camera.zoom, str(line[0].distance_to(line[1]), "px"))
		draw_set_transform(Vector2.ZERO, Global.camera.rotation, Vector2.ONE)
