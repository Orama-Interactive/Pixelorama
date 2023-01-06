extends Line2D

enum Types { VERTICAL, HORIZONTAL }
const INPUT_WIDTH := 4
export var type := 0
var track_mouse := true


func _ready() -> void:
	# Add a subtle difference to the normal guide color by mixing in some green
	default_color = Global.guide_color.linear_interpolate(Color(0.2, 0.92, 0.2), .6)
	width = Global.camera.zoom.x * 2
	draw_guide_line()


func draw_guide_line():
	if type == Types.HORIZONTAL:
		points[0] = Vector2(-19999, 0)
		points[1] = Vector2(19999, 0)
	else:
		points[0] = Vector2(0, 19999)
		points[1] = Vector2(0, -19999)


func _input(event: InputEvent) -> void:
	if !Global.show_mouse_guides or !Global.can_draw or !Global.has_focus:
		visible = false
		return
	visible = true
	if event is InputEventMouseMotion:
		var tmp_transform = get_canvas_transform().affine_inverse()
		var tmp_position = Global.main_viewport.get_local_mouse_position()
		var mouse_point = (tmp_transform.basis_xform(tmp_position) + tmp_transform.origin).snapped(
			Vector2(0.5, 0.5)
		)

		var project_size = Global.current_project.size
		if Rect2(Vector2.ZERO, project_size).has_point(mouse_point):
			visible = true
		else:
			visible = false
			return
		if type == Types.HORIZONTAL:
			points[0].y = mouse_point.y
			points[1].y = mouse_point.y
		else:
			points[0].x = mouse_point.x
			points[1].x = mouse_point.x
	update()


func _draw() -> void:
	width = Global.camera.zoom.x * 2
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

	draw_set_transform(viewport_poly[0], Global.camera.rotation, zoom * 2)
