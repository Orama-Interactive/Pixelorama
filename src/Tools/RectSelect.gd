extends BaseTool


var _rect := Rect2(0, 0, 0, 0)
var _start := Rect2(0, 0, 0, 0)
var _offset := Vector2.ZERO
var _move := false
var undo_data : Dictionary


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.move_content_confirm()
	undo_data = Global.canvas.selection._get_undo_data(false)
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
		_start = Rect2(position, Vector2.ZERO)


func draw_move(position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders(position - _offset)
		_offset = position
		_set_cursor_text(Global.canvas.selection.big_bounding_rectangle)
	else:
		_rect = _start.expand(position).abs()
		_rect = _rect.grow_individual(0, 0, 1, 1)
		_set_cursor_text(_rect)
		Global.canvas.selection.drawn_rect = _rect
		Global.canvas.selection.update()


func draw_end(_position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders_end()
	else:
		if !Tools.shift and !Tools.control:
			Global.canvas.selection.clear_selection()
			if _rect.size == Vector2.ZERO and Global.current_project.has_selection:
				Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
		if _rect.size != Vector2.ZERO:
			Global.canvas.selection.select_rect(_rect, !Tools.control)
			Global.canvas.selection.commit_undo("Rectangle Select", undo_data)

	_move = false
	cursor_text = ""
	_rect = Rect2(0, 0, 0, 0)
	Global.canvas.selection.drawn_rect = _rect
	Global.canvas.selection.update()


func _set_cursor_text(rect : Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]
