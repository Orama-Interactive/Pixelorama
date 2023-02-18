class_name PerspectiveLine
extends Line2D

const LINE_WIDTH := 2
const CIRCLE_RAD := 4

var angle := 0
var length := 19999

var hidden = false
var has_focus := false
var track_mouse := false
var change_length = false

var line_button: Node
var _vanishing_point: Node


func serialize() -> Dictionary:
	var data = {"angle": angle, "length": length}
	return data


func deserialize(data: Dictionary):
	if data.has("angle"):
		angle = data.angle
	if data.has("length"):
		length = data.length


func initiate(data: Dictionary, vanishing_point: Node):
	_vanishing_point = vanishing_point
	width = Global.camera.zoom.x * LINE_WIDTH
	Global.canvas.add_child(self)
	deserialize(data)
	refresh()


func refresh():
	default_color = _vanishing_point.color
	draw_perspective_line()


func draw_perspective_line():
	var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	points[0] = start
	if hidden:
		points[1] = start
	else:
		points[1] = (start + Vector2(length * cos(deg2rad(angle)), length * sin(deg2rad(angle))))


func hide_perspective_line():
	var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	points[1] = start
	hidden = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var mouse_point = Global.canvas.current_pixel
		var project_size = Global.current_project.size

		if track_mouse:
			if !Global.can_draw or !Global.has_focus or Global.perspective_editor.tracker_disabled:
				hide_perspective_line()
				return
			default_color.a = 0.5
			if Rect2(Vector2.ZERO, project_size).has_point(mouse_point):
				var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
				hidden = false
				draw_perspective_line()
				angle = rad2deg(mouse_point.angle_to_point(points[0]))
				if angle < 0:
					angle += 360

				points[1] = (
					start
					+ Vector2(length * cos(deg2rad(angle)), length * sin(deg2rad(angle)))
				)
			else:
				hide_perspective_line()
		else:
			try_rotate_scale()
		update()


func try_rotate_scale():
	var mouse_point = Global.canvas.current_pixel
	var project_size = Global.current_project.size
	var test_line := (points[1] - points[0]).rotated(deg2rad(90)).normalized()
	var from_a = mouse_point - test_line * Global.camera.zoom.x * LINE_WIDTH * 2
	var from_b = mouse_point + test_line * Global.camera.zoom.x * LINE_WIDTH * 2
	if Input.is_action_just_pressed("left_mouse") and Global.can_draw and Global.has_focus:
		if (
			Geometry.segment_intersects_segment_2d(from_a, from_b, points[0], points[1])
			or mouse_point.distance_to(points[1]) < Global.camera.zoom.x * CIRCLE_RAD * 2
		):
			if (
				!Rect2(Vector2.ZERO, project_size).has_point(mouse_point)
				or Global.move_guides_on_canvas
			):
				if mouse_point.distance_to(points[1]) < Global.camera.zoom.x * CIRCLE_RAD * 2:
					change_length = true
				has_focus = true
				Global.has_focus = false
				update()
	if has_focus:
		if Input.is_action_pressed("left_mouse"):
			# rotation code here
			if line_button:
				var new_angle = rad2deg(mouse_point.angle_to_point(points[0]))
				if new_angle < 0:
					new_angle += 360
				_vanishing_point.angle_changed(new_angle, line_button)
				if change_length:
					var new_length = mouse_point.distance_to(points[0])
					_vanishing_point.length_changed(new_length, line_button)

		elif Input.is_action_just_released("left_mouse"):
			Global.has_focus = true
			has_focus = false
			change_length = false
			update()


func _draw() -> void:
	var mouse_point = Global.canvas.current_pixel
	var arc_points = []
	draw_circle(points[0], Global.camera.zoom.x * CIRCLE_RAD, default_color)  # Starting circle
	if !track_mouse and mouse_point.distance_to(points[0]) < Global.camera.zoom.x * CIRCLE_RAD * 2:
		if (
			!Rect2(Vector2.ZERO, Global.current_project.size).has_point(mouse_point)
			or Global.move_guides_on_canvas
			or has_focus
		):
			arc_points.append(points[0])
	if (
		mouse_point.distance_to(points[1]) < Global.camera.zoom.x * CIRCLE_RAD * 2
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
		draw_arc(point, Global.camera.zoom.x * CIRCLE_RAD * 2, 0, 360, 360, default_color, 0.5)

	width = Global.camera.zoom.x * LINE_WIDTH
	if hidden:  # Hidden line
		return
