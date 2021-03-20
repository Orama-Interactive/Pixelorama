extends BaseTool


var current_selection
var start_position := Vector2.INF
var _start := Rect2(0, 0, 0, 0)
var _offset := Vector2.ZERO
var _drag := false
var _move := false
var undo_data : Dictionary


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.move_content_confirm()
	undo_data = Global.canvas.selection._get_undo_data(false)
	for selection in Global.current_project.selections:
		if selection.rect_outline.has_point(position):
			current_selection = selection

	if !current_selection:
		if !Tools.shift and !Tools.control:
			Global.canvas.selection.clear_selection()
		_start = Rect2(position, Vector2.ZERO)
		var new_selection = Global.canvas.selection.SelectionPolygon.new(_start)
		var selections : Array = Global.current_project.selections.duplicate()
		selections.append(new_selection)
		current_selection = new_selection
		Global.current_project.selections = selections
	else:
		_move = true
		_offset = position
		start_position = position
		Global.canvas.selection.move_borders_start()
		_set_cursor_text(Global.canvas.selection.big_bounding_rectangle)


func draw_move(position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders(position - _offset)
		_offset = position
		_set_cursor_text(Global.canvas.selection.big_bounding_rectangle)
	else:
		var rect := _start.expand(position).abs()
		rect = rect.grow_individual(0, 0, 1, 1)
		current_selection.set_rect(rect)
		_set_cursor_text(rect)


func draw_end(position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders_end(position, start_position)
	else:
		Global.canvas.selection.select_rect(!Tools.control)
		Global.canvas.selection.commit_undo("Rectangle Select", undo_data)

	_move = false
	cursor_text = ""
	start_position = Vector2.INF
	current_selection = null


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
