class_name PerspectiveLine
extends Line2D

const INPUT_WIDTH := 4
var hidden = false
var track_mouse := false
var _data = {"start": Vector2.ZERO, "angle": 0, "length": 19999, "color": Color.black}


func initiate(data: Dictionary):
	width = Global.camera.zoom.x * 2
	Global.canvas.add_child(self)
	refresh(data)


func refresh(data: Dictionary):
	_data = data
	default_color = data.color
	draw_perspective_line()


func draw_perspective_line():
	points[0] = _data.start
	if hidden:
		points[1] = _data.start
	else:
		points[1] = (
			_data.start
			+ Vector2(
				_data.length * cos(deg2rad(_data.angle)), _data.length * sin(deg2rad(_data.angle))
			)
		)


func hide_perspective_line():
	points[1] = _data.start
	hidden = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if track_mouse:
			if !Global.can_draw:
				return
			default_color.a = 0.5
			var tmp_transform = get_canvas_transform().affine_inverse()
			var tmp_position = Global.main_viewport.get_local_mouse_position()
			var mouse_point = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin
			var project_size = Global.current_project.size
			if Rect2(Vector2.ZERO, project_size).has_point(mouse_point):
				hidden = false
				draw_perspective_line()
				var rel_vector = mouse_point - _data.start
				var test_vector = Vector2(_data.start.x, 0)
				if sign(test_vector.x) == 0:
					test_vector.x += 0.5

				_data.angle = rad2deg(test_vector.angle_to(rel_vector))
				if sign(test_vector.x) == -1:
					_data.angle += 180

				points[1] = (
					_data.start
					+ Vector2(
						_data.length * cos(deg2rad(_data.angle)),
						_data.length * sin(deg2rad(_data.angle))
					)
				)
			else:
				hide_perspective_line()

		update()


func _draw() -> void:
	draw_circle(_data.start, Global.camera.zoom.x * 5, default_color)
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
