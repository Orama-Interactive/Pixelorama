class_name PerspectiveLine
extends Line2D

const INPUT_WIDTH := 4
var hidden = false
var track_mouse := false
var angle := 0  # always negative
var length := 19999
var _vanishing_point: Node
var line_button: Node


func serialize() -> Dictionary:
	var data = {
		"angle": angle,
		"length": length
	}
	return data


func deserialize(data: Dictionary):
	if data.has("angle"):
		angle = data.angle
	if data.has("length"):
		length = data.length


func initiate(data: Dictionary, vanishing_point: Node):
	_vanishing_point = vanishing_point
	width = Global.camera.zoom.x * 2
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
		points[1] = (
			start
			+ Vector2(length * cos(deg2rad(angle)), length * sin(deg2rad(angle)))
		)


func hide_perspective_line():
	var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	points[1] = start
	hidden = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if track_mouse:
			if !Global.can_draw or !Global.has_focus:
				hide_perspective_line()
				return
			default_color.a = 0.5
			var tmp_transform = get_canvas_transform().affine_inverse()
			var tmp_position = Global.main_viewport.get_local_mouse_position()
			var mouse_point = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin
			var project_size = Global.current_project.size
			if Rect2(Vector2.ZERO, project_size).has_point(mouse_point):
				var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
				hidden = false
				draw_perspective_line()
				var rel_vector = mouse_point - start
				var test_vector = Vector2(start.x, 0)
				if sign(test_vector.x) == 0:
					test_vector.x += 0.5

				angle = rad2deg(test_vector.angle_to(rel_vector))
				if sign(test_vector.x) == -1:
					angle += 180

				points[1] = (
					start
					+ Vector2(
						length * cos(deg2rad(angle)),
						length * sin(deg2rad(angle))
					)
				)
			else:
				hide_perspective_line()
		update()


func _draw() -> void:
	var start = Vector2(_vanishing_point.pos_x.value, _vanishing_point.pos_y.value)
	draw_circle(start, Global.camera.zoom.x * 5, default_color)
	width = Global.camera.zoom.x * 2
	if hidden:  # Hidden line
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
	# If there's no intersection with a viewport edge, show string in top left corner
	draw_set_transform(viewport_poly[0], Global.camera.rotation, zoom * 2)
