extends SelectionTool


var _rect := Rect2(0, 0, 0, 0)
var _start_pos := Vector2.ZERO

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
	if !_move:
		_start_pos = position


func draw_move(position : Vector2) -> void:
	.draw_move(position)
	if !_move:
		_rect = _get_result_rect(_start_pos, position)
		_set_cursor_text(_rect)
		Global.canvas.selection.drawn_rect = _rect
		Global.canvas.selection.update()


func draw_end(position : Vector2) -> void:
	.draw_end(position)
	_rect = Rect2(0, 0, 0, 0)
	Global.canvas.selection.drawn_rect = _rect
	Global.canvas.selection.update()
	_square = false
	_expand_from_center = false


func apply_selection(_position) -> void:
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
