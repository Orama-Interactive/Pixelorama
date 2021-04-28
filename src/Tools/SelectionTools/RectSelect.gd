extends "res://src/Tools/SelectionTools/SelectionTool.gd"


var _rect := Rect2(0, 0, 0, 0)
var _start_pos := Vector2.ZERO
var _offset := Vector2.ZERO
var _move := false

var _square := false # Mouse Click + Shift
var _expand_from_center := false # Mouse Click + Ctrl


func _input(event : InputEvent) -> void:
	if !_move and !_rect.has_no_area():
		if event.is_action_pressed("shift"):
			_square = true
		elif event.is_action_released("shift"):
			_square = false
		if event.is_action_pressed("ctrl"):
			_expand_from_center = true
		elif event.is_action_released("ctrl"):
			_expand_from_center = false


func draw_start(position : Vector2) -> void:
	.draw_start(position)
	var selection_position : Vector2 = Global.canvas.selection.big_bounding_rectangle.position
	var offsetted_pos := position
	if selection_position.x < 0:
		offsetted_pos.x -= selection_position.x
	if selection_position.y < 0:
		offsetted_pos.y -= selection_position.y
	if offsetted_pos.x >= 0 and offsetted_pos.y >= 0 and Global.current_project.selection_bitmap.get_bit(offsetted_pos) and !Tools.control and !Tools.shift:
		# Move current selection
		_move = true
		_offset = position
		Global.canvas.selection.move_borders_start()
	else:
		_start_pos = position


func draw_move(position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders(position - _offset)
		_offset = position
		_set_cursor_text(Global.canvas.selection.big_bounding_rectangle)
	else:
		_rect = _get_result_rect(_start_pos, position)
		_set_cursor_text(_rect)
		Global.canvas.selection.drawn_rect = _rect
		Global.canvas.selection.update()


func draw_end(_position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders_end()
	else:
		if !_add and !_subtract and !_intersect:
			Global.canvas.selection.clear_selection()
			if _rect.size == Vector2.ZERO and Global.current_project.has_selection:
				Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
		if _rect.size != Vector2.ZERO:
			var operation := 0
			if _subtract:
				operation = 1
			elif _intersect:
				operation = 2
			Global.canvas.selection.select_rect(_rect, operation)
			Global.canvas.selection.commit_undo("Rectangle Select", undo_data)

	_move = false
	cursor_text = ""
	_rect = Rect2(0, 0, 0, 0)
	Global.canvas.selection.drawn_rect = _rect
	Global.canvas.selection.update()
	_square = false
	_expand_from_center = false


# Given an origin point and destination point, returns a rect representing where the shape will be drawn and what it's size
func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	# Center the rect on the mouse
	if _expand_from_center:
		var new_size := (dest - origin).floor()
		# Make rect 1:1 while centering it on the mouse
		if _square:
			var _square_size := max(abs(new_size.x), abs(new_size.y))
			new_size = Vector2(_square_size, _square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if _square:
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE

	return rect


func _set_cursor_text(rect : Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]
