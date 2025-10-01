extends Line2D

enum Types { VERTICAL, HORIZONTAL }
const INPUT_WIDTH := 4
const DOTTED_LINE_TEXTURE := preload("res://assets/graphics/dotted_line.png")

@export var type := 0
var track_mouse := true


func _ready() -> void:
	# Add a subtle difference to the normal guide color by mixing in some green
	default_color = Global.guide_color.lerp(Color(0.2, 0.92, 0.2), .6)
	texture = DOTTED_LINE_TEXTURE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_mode = Line2D.LINE_TEXTURE_TILE
	await get_tree().process_frame
	await get_tree().process_frame
	width = 2.0 / get_viewport().canvas_transform.get_scale().x
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
	var viewport_size := get_viewport_rect().size
	var half_size := viewport_size * 0.5
	var zoom := get_viewport().canvas_transform.get_scale()
	var canvas_rotation := -get_viewport().canvas_transform.get_rotation()
	var origin := get_viewport().canvas_transform.get_origin()
	var pure_origin := (origin / zoom).rotated(canvas_rotation)
	var zoom_scale := Vector2.ONE / zoom
	var offset := -pure_origin + (half_size * zoom_scale).rotated(canvas_rotation)
	width = 2.0 / zoom.x

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
