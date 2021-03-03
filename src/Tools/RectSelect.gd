extends BaseTool


var current_selection
var start_position := Vector2.INF
var _start := Rect2(0, 0, 0, 0)
var _offset := Vector2.ZERO
var _drag := false
var _move := false


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.move_content_end()
	for selection in Global.canvas.selection.polygons:
		if selection.rect_outline.has_point(position):
			current_selection = selection

	if !current_selection:
		if !Tools.shift and !Tools.control:
			for p in Global.canvas.selection.polygons:
				p.selected_pixels = []
			Global.canvas.selection.polygons.clear()
		_start = Rect2(position, Vector2.ZERO)
		var new_selection = Global.canvas.selection.SelectionPolygon.new(_start)
		Global.canvas.selection.polygons.append(new_selection)
		current_selection = new_selection
#			for selection in Global.current_project.selections:
#				selection.queue_free()
#			current_selection_id = 0
#		else:
#			current_selection_id = Global.current_project.selections.size()
#		var selection_shape := preload("res://src/Tools/SelectionShape.tscn").instance()
#		current_selection = selection_shape
##		Global.current_project.selections.append(selection_shape)
#		Global.canvas.selection.add_child(selection_shape)
#		_start = Rect2(position, Vector2.ZERO)
#		selection_shape.set_rect(_start)
	else:
		_move = true
		_offset = position
		start_position = position
		Global.canvas.selection.move_borders_start()
#		_set_cursor_text(selection.get_rect())
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
	if _move:
		Global.canvas.selection.move_borders(position - _offset)
		_offset = position
#		_set_cursor_text(selection.get_rect())
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
#		var undo_data = Global.canvas.selection._get_undo_data(false)
#		current_selection.select_rect(!Tools.control)
#		Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
#	_drag = false
#	Global.canvas.selection.move_borders_end(position, start_position)
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
