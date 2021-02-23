extends BaseTool


var current_selection_id := -1
var start_position := Vector2.INF
var _start := Rect2(0, 0, 0, 0)
var _offset := Vector2.ZERO
var _drag := false
var _move := false


func draw_start(position : Vector2) -> void:
	var i := 0
	for selection in Global.current_project.selections:
		if selection.has_point(position):
			current_selection_id = i
		i += 1

	if current_selection_id == -1:
		if !Tools.shift and !Tools.control:
			for selection in Global.current_project.selections:
				selection.queue_free()
			current_selection_id = 0
		else:
			current_selection_id = Global.current_project.selections.size()
		var selection_shape := preload("res://src/Tools/SelectionShape.tscn").instance()
		Global.current_project.selections.append(selection_shape)
		Global.canvas.selection.add_child(selection_shape)
		_start = Rect2(position, Vector2.ZERO)
		selection_shape.set_rect(_start)
	else:
		var selection : SelectionShape = Global.current_project.selections[current_selection_id]
		_move = true
		_offset = position
		start_position = position
		_set_cursor_text(selection.get_rect())
#	if Global.selection_rectangle.has_point(position):
#		_move = true
#		_offset = position
#		Global.selection_rectangle.move_start(Tools.shift)
#		_set_cursor_text(Global.selection_rectangle.get_rect())
#	else:
#		_drag = true
#		_start = Rect2(position, Vector2.ZERO)
#		Global.selection_rectangle.set_rect(_start)


func draw_move(position : Vector2) -> void:
	var selection : SelectionShape = Global.current_project.selections[current_selection_id]

	if _move:
		Global.canvas.selection.move_borders(position - _offset)
		_offset = position
		_set_cursor_text(selection.get_rect())
	else:
		var rect := _start.expand(position).abs()
		rect = rect.grow_individual(0, 0, 1, 1)
		selection.set_rect(rect)
		_set_cursor_text(rect)


func draw_end(position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders_end(position, start_position)
	else:
		var selection : SelectionShape = Global.current_project.selections[current_selection_id]
		selection.select_rect(!Tools.control)
#	_drag = false
	_move = false
	cursor_text = ""
	start_position = Vector2.INF
	current_selection_id = -1


func cursor_move(_position : Vector2) -> void:
	pass
#	if _drag:
#		_cursor = Vector2.INF
#	elif Global.selection_rectangle.has_point(position):
#		_cursor = Vector2.INF
#		Global.main_viewport.mouse_default_cursor_shape = Input.CURSOR_MOVE
#		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#	else:
#		_cursor = position
#		Global.main_viewport.mouse_default_cursor_shape = Input.CURSOR_CROSS


func _set_cursor_text(rect : Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]
