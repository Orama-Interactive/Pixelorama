extends BaseTool


var _start_pos : Vector2
var _offset : Vector2

# Used to check if the state of content transformation has been changed
# while draw_move() is being called. For example, pressing Enter while still moving content
var _content_transformation_check := false

onready var selection_node : Node2D = Global.canvas.selection


func draw_start(position : Vector2) -> void:
	_start_pos = position
	_offset = position
	if Global.current_project.has_selection:
		selection_node.transform_content_start()
	_content_transformation_check = selection_node.is_moving_content


func draw_move(position : Vector2) -> void:
	# This is true if content transformation has been confirmed (pressed Enter for example)
	# while the content is being moved
	if _content_transformation_check != selection_node.is_moving_content:
		return
	if Tools.shift: # Snap to axis
		var angle := position.angle_to_point(_start_pos)
		if abs(angle) <= PI / 4 or abs(angle) >= 3*PI / 4:
			position.y = _start_pos.y
		else:
			position.x = _start_pos.x
	if Tools.control: # Snap to grid
		position = position.snapped(Vector2(Global.grid_width, Global.grid_height))

	if Global.current_project.has_selection:
		selection_node.move_content(position - _offset)
		_offset = position
	else:
		Global.canvas.move_preview_location = position - _start_pos
	_offset = position


func draw_end(position : Vector2) -> void:
	if _start_pos != Vector2.INF and _content_transformation_check == selection_node.is_moving_content:
		if Tools.shift: # Snap to axis
			var angle := position.angle_to_point(_start_pos)
			if abs(angle) <= PI / 4 or abs(angle) >= 3*PI / 4:
				position.y = _start_pos.y
			else:
				position.x = _start_pos.x
		var pixel_diff : Vector2 = position - _start_pos
		var project : Project = Global.current_project
		var image : Image = _get_draw_image()

		if project.has_selection:
			selection_node.move_borders_end()
		else:
			Global.canvas.move_preview_location = Vector2.ZERO
			var image_copy := Image.new()
			image_copy.copy_from(image)
			Global.canvas.handle_undo("Draw")
			image.fill(Color(0, 0, 0, 0))
			image.blit_rect(image_copy, Rect2(Vector2.ZERO, project.size), pixel_diff)

			Global.canvas.handle_redo("Draw")

	_start_pos = Vector2.INF
