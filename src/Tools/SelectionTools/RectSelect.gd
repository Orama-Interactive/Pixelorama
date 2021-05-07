extends SelectionTool


var _rect := Rect2(0, 0, 0, 0)

var _square := false # Mouse Click + Shift
var _expand_from_center := false # Mouse Click + Ctrl
var _displace_origin = false # Mouse Click + Alt


func _input(event : InputEvent) -> void:
	._input(event)
	if !_move and !_rect.has_no_area():
		if event.is_action_pressed("shift"):
			_square = true
		elif event.is_action_released("shift"):
			_square = false
		if event.is_action_pressed("ctrl"):
			_expand_from_center = true
		elif event.is_action_released("ctrl"):
			_expand_from_center = false
		if event.is_action_pressed("alt"):
			_displace_origin = true
		elif event.is_action_released("alt"):
			_displace_origin = false


func draw_move(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	.draw_move(position)
	if !_move:
		if _displace_origin:
			_start_pos += position - _offset
		_rect = _get_result_rect(_start_pos, position)
		_set_cursor_text(_rect)
		_offset = position


func draw_end(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	.draw_end(position)
	_rect = Rect2(0, 0, 0, 0)
	_square = false
	_expand_from_center = false
	_displace_origin = false


func draw_preview() -> void:
	if !_move:
		var canvas : Node2D = Global.canvas.previews
		var _position := canvas.position
		var _scale := canvas.scale
		if Global.mirror_view:
			_position.x = _position.x + Global.current_project.size.x
			_scale.x = -1
		canvas.draw_set_transform(_position, canvas.rotation, _scale)
		canvas.draw_rect(_rect, Color.black, false)

		# Handle mirroring
		if tool_slot.horizontal_mirror:
			var mirror_x_rect := _rect
			mirror_x_rect.position.x = Global.current_project.x_symmetry_point - _rect.position.x
			mirror_x_rect.end.x = Global.current_project.x_symmetry_point - _rect.end.x
			canvas.draw_rect(mirror_x_rect, Color.black, false)
			if tool_slot.vertical_mirror:
				var mirror_xy_rect := mirror_x_rect
				mirror_xy_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
				mirror_xy_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
				canvas.draw_rect(mirror_xy_rect, Color.black, false)
		if tool_slot.vertical_mirror:
			var mirror_y_rect := _rect
			mirror_y_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
			mirror_y_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
			canvas.draw_rect(mirror_y_rect, Color.black, false)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


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

		# Handle mirroring
		if tool_slot.horizontal_mirror:
			var mirror_x_rect := _rect
			mirror_x_rect.position.x = Global.current_project.x_symmetry_point - _rect.position.x
			mirror_x_rect.end.x = Global.current_project.x_symmetry_point - _rect.end.x
			Global.canvas.selection.select_rect(mirror_x_rect.abs(), operation)
			if tool_slot.vertical_mirror:
				var mirror_xy_rect := mirror_x_rect
				mirror_xy_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
				mirror_xy_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
				Global.canvas.selection.select_rect(mirror_xy_rect.abs(), operation)
		if tool_slot.vertical_mirror:
			var mirror_y_rect := _rect
			mirror_y_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
			mirror_y_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
			Global.canvas.selection.select_rect(mirror_y_rect.abs(), operation)

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
