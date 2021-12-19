tool
extends Control

const MARGIN_NONE = -1

var _hover_margin = MARGIN_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_margin = MARGIN_NONE
	elif what == NOTIFICATION_DRAG_BEGIN:
		_hover_margin = MARGIN_NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_find_hover_margin(event.position)
		update()


func _draw() -> void:
	var rect
	if _hover_margin == MARGIN_NONE:
		return
	elif _hover_margin == MARGIN_LEFT:
		rect = Rect2(0, 0, rect_size.x * 0.5, rect_size.y)
	elif _hover_margin == MARGIN_TOP:
		rect = Rect2(0, 0, rect_size.x, rect_size.y * 0.5)
	elif _hover_margin == MARGIN_RIGHT:
		var half_width = rect_size.x * 0.5
		rect = Rect2(half_width, 0, half_width, rect_size.y)
	elif _hover_margin == MARGIN_BOTTOM:
		var half_height = rect_size.y * 0.5
		rect = Rect2(0, half_height, rect_size.x, half_height)
	var stylebox = get_stylebox("panel", "TooltipPanel")
	draw_style_box(stylebox, rect)


func get_hover_margin() -> int:
	return _hover_margin


func _find_hover_margin(point: Vector2):
	var half_size = rect_size * 0.5

	var left = point.distance_squared_to(Vector2(0, half_size.y))
	var lesser = left
	var lesser_margin = MARGIN_LEFT

	var top = point.distance_squared_to(Vector2(half_size.x, 0))
	if lesser > top:
		lesser = top
		lesser_margin = MARGIN_TOP

	var right = point.distance_squared_to(Vector2(rect_size.x, half_size.y))
	if lesser > right:
		lesser = right
		lesser_margin = MARGIN_RIGHT

	var bottom = point.distance_squared_to(Vector2(half_size.x, rect_size.y))
	if lesser > bottom:
		#lesser = bottom  # unused result
		lesser_margin = MARGIN_BOTTOM
	_hover_margin = lesser_margin
