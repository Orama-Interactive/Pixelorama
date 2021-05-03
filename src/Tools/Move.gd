extends BaseTool


var _start_pos : Vector2
var _offset : Vector2


func draw_start(position : Vector2) -> void:
	_start_pos = position
	_offset = position
	if Global.current_project.has_selection:
		Global.canvas.selection.transform_content_start()


func draw_move(position : Vector2) -> void:
	if Tools.shift: # Snap to axis
		var angle := position.angle_to_point(_start_pos)
		if abs(angle) <= PI / 4 or abs(angle) >= 3*PI / 4:
			position.y = _start_pos.y
		else:
			position.x = _start_pos.x
	if Global.current_project.has_selection:
		Global.canvas.selection.move_content(position - _offset)
		_offset = position
	else:
		Global.canvas.move_preview_location = position - _start_pos
	_offset = position


func draw_end(position : Vector2) -> void:
	if _start_pos != Vector2.INF:
		if Tools.shift: # Snap to axis
			var angle := position.angle_to_point(_start_pos)
			if abs(angle) <= PI / 4 or abs(angle) >= 3*PI / 4:
				position.y = _start_pos.y
			else:
				position.x = _start_pos.x
		var pixel_diff : Vector2 = position - _start_pos
		var project : Project = Global.current_project
		var image : Image = _get_draw_image()

		if !project.has_selection:
			Global.canvas.move_preview_location = Vector2.ZERO
			var image_copy := Image.new()
			image_copy.copy_from(image)
			Global.canvas.handle_undo("Draw")
			image.fill(Color(0, 0, 0, 0))
			image.blit_rect(image_copy, Rect2(Vector2.ZERO, project.size), pixel_diff)

			Global.canvas.handle_redo("Draw")

	_start_pos = Vector2.INF
