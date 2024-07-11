class_name PerspectiveLine
extends Line2D

const LINE_WIDTH := 2
const CIRCLE_RAD := 4

var angle := 0
var length := 19999

var is_hidden := false
var has_focus := false
var track_mouse := false
var change_length := false

var line_button: Node
var _vanishing_point: Node


func serialize() -> Dictionary:
	return {"angle": angle, "length": length}


func deserialize(data: Dictionary) -> void:
	if data.has("angle"):
		angle = data.angle
	if data.has("length"):
		length = data.length


func initiate(data: Dictionary, vanishing_point: Node) -> void:
	_vanishing_point = vanishing_point
	Global.canvas.add_child(self)
	deserialize(data)
	# a small delay is needed for Global.camera.zoom to have correct value
	await get_tree().process_frame
	width = LINE_WIDTH / Global.camera.zoom.x
	refresh()


func refresh() -> void:
	default_color = _vanishing_point.color
	draw_perspective_line()


func draw_perspective_line() -> void:
	var start := Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	points[0] = start
	if is_hidden:
		points[1] = start
	else:
		points[1] = (
			start + Vector2(length * cos(deg_to_rad(angle)), length * sin(deg_to_rad(angle)))
		)


func hide_perspective_line() -> void:
	var start := Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	points[1] = start
	is_hidden = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var mouse_point := Global.canvas.current_pixel
		var project_size := Global.current_project.size

		if track_mouse:
			if !Global.can_draw or Global.perspective_editor.tracker_disabled:
				hide_perspective_line()
				return
			default_color.a = 0.5
			if Rect2(Vector2.ZERO, project_size).has_point(mouse_point):
				var start := Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
				is_hidden = false
				draw_perspective_line()
				angle = rad_to_deg(points[0].angle_to_point(mouse_point))
				if angle < 0:
					angle += 360

				points[1] = (
					start
					+ Vector2(length * cos(deg_to_rad(angle)), length * sin(deg_to_rad(angle)))
				)
			else:
				hide_perspective_line()
		else:
			try_rotate_scale()
		queue_redraw()


func try_rotate_scale() -> void:
	var mouse_point := Global.canvas.current_pixel
	var project_size := Global.current_project.size
	var test_line := (points[1] - points[0]).rotated(deg_to_rad(90)).normalized()
	var from_a := mouse_point - test_line * CIRCLE_RAD * 2 / Global.camera.zoom.x
	var from_b := mouse_point + test_line * CIRCLE_RAD * 2 / Global.camera.zoom.x
	if Input.is_action_just_pressed("left_mouse") and Global.can_draw:
		if (
			Geometry2D.segment_intersects_segment(from_a, from_b, points[0], points[1])
			or mouse_point.distance_to(points[1]) < CIRCLE_RAD * 2 / Global.camera.zoom.x
		):
			if (
				!Rect2(Vector2.ZERO, project_size).has_point(mouse_point)
				or Global.move_guides_on_canvas
			):
				if mouse_point.distance_to(points[1]) < CIRCLE_RAD * 2 / Global.camera.zoom.x:
					change_length = true
				has_focus = true
				Global.can_draw = false
				queue_redraw()
	if has_focus:
		if Input.is_action_pressed("left_mouse"):
			# rotation code here
			if line_button:
				var new_angle := rad_to_deg(points[0].angle_to_point(mouse_point))
				if new_angle < 0:
					new_angle += 360
				_vanishing_point.angle_changed(new_angle, line_button)
				if change_length:
					var new_length := mouse_point.distance_to(points[0])
					_vanishing_point.length_changed(new_length, line_button)

		elif Input.is_action_just_released("left_mouse"):
			Global.can_draw = true
			has_focus = false
			change_length = false
			queue_redraw()


func _draw() -> void:
	width = LINE_WIDTH / Global.camera.zoom.x
	var mouse_point := Global.canvas.current_pixel
	var arc_points := PackedVector2Array()
	draw_circle(points[0], CIRCLE_RAD / Global.camera.zoom.x, default_color)  # Starting circle
	if !track_mouse and mouse_point.distance_to(points[0]) < CIRCLE_RAD * 2 / Global.camera.zoom.x:
		if (
			!Rect2(Vector2.ZERO, Global.current_project.size).has_point(mouse_point)
			or Global.move_guides_on_canvas
			or has_focus
		):
			arc_points.append(points[0])
	if (
		mouse_point.distance_to(points[1]) < CIRCLE_RAD * 2 / Global.camera.zoom.x
		or (has_focus and Input.is_action_pressed("left_mouse"))
	):
		if (
			!Rect2(Vector2.ZERO, Global.current_project.size).has_point(mouse_point)
			or Global.move_guides_on_canvas
			or has_focus
		):
			if !arc_points.has(points[0]):
				arc_points.append(points[0])
			arc_points.append(points[1])

	for point in arc_points:
		# if we put width <= -1, then the arc line will automatically adjust itself to remain thin
		# in 0.x this behavior was achieved at  width <= 1
		draw_arc(point, CIRCLE_RAD * 2 / Global.camera.zoom.x, 0, 360, 360, default_color)
