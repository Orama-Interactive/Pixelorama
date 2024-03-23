extends Line2D

enum Types { VERTICAL, HORIZONTAL }
const INPUT_WIDTH := 4
@export var type := 0
var track_mouse := true
var _texture := preload("res://assets/graphics/dotted_line.png")


func _ready() -> void:
	# Add a subtle difference to the normal guide color by mixing in some green
	default_color = Global.guide_color.lerp(Color(0.2, 0.92, 0.2), .6)
	texture = _texture
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_mode = Line2D.LINE_TEXTURE_TILE
	await get_tree().process_frame
	await get_tree().process_frame
	width = 2.0 / Global.camera.zoom.x
	draw_guide_line()


func draw_guide_line() -> void:
	if type == Types.HORIZONTAL:
		points[0] = Vector2(-19999, 0)
		points[1] = Vector2(19999, 0)
	else:
		points[0] = Vector2(0, 19999)
		points[1] = Vector2(0, -19999)


func _input(event: InputEvent) -> void:
	if !Global.show_mouse_guides or !Global.can_draw:
		visible = false
		return
	visible = true
	if event is InputEventMouseMotion:
		var mouse_point := get_local_mouse_position().snapped(Vector2(0.5, 0.5))
		var project_size := Global.current_project.size
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
	queue_redraw()


func _draw() -> void:
	width = 2.0 / Global.camera.zoom.x
	var viewport_size := get_viewport_rect().size
	var zoom := Global.camera.zoom

	# An array of the points that make up the corners of the viewport
	var viewport_poly := PackedVector2Array(
		[Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]
	)
	# Adjusting viewport_poly to take into account the camera offset, zoom, and rotation
	for p in range(viewport_poly.size()):
		viewport_poly[p] = (
			viewport_poly[p].rotated(Global.camera.rotation) * zoom
			+ Vector2(
				(
					Global.camera.offset.x
					- (viewport_size.rotated(Global.camera.rotation).x / 2) / zoom.x
				),
				(
					Global.camera.offset.y
					- (viewport_size.rotated(Global.camera.rotation).y / 2) / zoom.y
				)
			)
		)
