extends BaseTool

var _undo_data := {}
var _start_pos: Vector2
var _offset: Vector2

# Used to check if the state of content transformation has been changed
# while draw_move() is being called. For example, pressing Enter while still moving content
var _content_transformation_check := false
var _snap_to_grid := false  # Mouse Click + Ctrl

onready var selection_node: Node2D = Global.canvas.selection


func _input(event: InputEvent) -> void:
	if _start_pos != Vector2.INF:
		if event.is_action_pressed("transform_snap_grid"):
			_snap_to_grid = true
			var grid_size := Vector2(Global.grid_width, Global.grid_height)
			_offset = _offset.snapped(grid_size)
			if Global.current_project.has_selection:
				if selection_node.is_moving_content:
					var prev_pos: Vector2 = selection_node.big_bounding_rectangle.position
					selection_node.big_bounding_rectangle.position = prev_pos.snapped(grid_size)
					# The first time transform_snap_grid is enabled then _snap_position() is not called
					# and the selection had wrong offset, so do selection offsetting here
					var grid_offset := Vector2(Global.grid_offset_x, Global.grid_offset_y)
					grid_offset = Vector2(
						fmod(grid_offset.x, grid_size.x), fmod(grid_offset.y, grid_size.y)
					)
					selection_node.big_bounding_rectangle.position += grid_offset
					selection_node.marching_ants_outline.offset += (
						selection_node.big_bounding_rectangle.position
						- prev_pos
					)
		elif event.is_action_released("transform_snap_grid"):
			_snap_to_grid = false


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_start_pos = position
	_offset = position
	_undo_data = _get_undo_data()
	if Global.current_project.has_selection:
		selection_node.transform_content_start()
	_content_transformation_check = selection_node.is_moving_content


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	# This is true if content transformation has been confirmed (pressed Enter for example)
	# while the content is being moved
	if _content_transformation_check != selection_node.is_moving_content:
		return
	position = _snap_position(position)

	if Global.current_project.has_selection:
		selection_node.move_content(position - _offset)
	else:
		Global.canvas.move_preview_location = position - _start_pos
	_offset = position


func draw_end(position: Vector2) -> void:
	.draw_end(position)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if (
		_start_pos != Vector2.INF
		and _content_transformation_check == selection_node.is_moving_content
	):
		position = _snap_position(position)
		var project: Project = Global.current_project

		if project.has_selection:
			selection_node.move_borders_end()
		else:
			var pixel_diff: Vector2 = position - _start_pos
			Global.canvas.move_preview_location = Vector2.ZERO
			var images := _get_selected_draw_images()
			for image in images:
				var image_copy := Image.new()
				image_copy.copy_from(image)
				image.fill(Color(0, 0, 0, 0))
				image.blit_rect(image_copy, Rect2(Vector2.ZERO, project.size), pixel_diff)

			commit_undo("Draw")

	_start_pos = Vector2.INF
	_snap_to_grid = false


func _snap_position(position: Vector2) -> Vector2:
	if Input.is_action_pressed("transform_snap_axis"):
		var angle := position.angle_to_point(_start_pos)
		if abs(angle) <= PI / 4 or abs(angle) >= 3 * PI / 4:
			position.y = _start_pos.y
		else:
			position.x = _start_pos.x
	if _snap_to_grid:  # Snap to grid
		var grid_size := Vector2(Global.grid_width, Global.grid_height)
		position = position.snapped(grid_size)
		# The part below only corrects the offset for situations when there is no selection
		# Offsets when there is selection is controlled in _input() function
		if !Global.current_project.has_selection:
			var move_offset := Vector2.ZERO
			move_offset.x = (
				_start_pos.x
				- int(_start_pos.x / Global.grid_width) * Global.grid_width
			)
			move_offset.y = (
				_start_pos.y
				- int(_start_pos.y / Global.grid_height) * Global.grid_height
			)
			position += move_offset

	return position


func commit_undo(action: String) -> void:
	var redo_data := _get_undo_data()
	var project: Project = Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
		image.unlock()
	for image in _undo_data:
		project.undo_redo.add_undo_property(image, "data", _undo_data[image])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, frame, layer)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, frame, layer)
	project.undo_redo.commit_action()

	_undo_data.clear()


func _get_undo_data() -> Dictionary:
	var data := {}
	var project: Project = Global.current_project
	var cels := []  # Array of Cels
	if Global.animation_timer.is_stopped():
		for cel_index in project.selected_cels:
			cels.append(project.frames[cel_index[0]].cels[cel_index[1]])
	else:
		for frame in project.frames:
			var cel: PixelCel = frame.cels[project.current_layer]
			cels.append(cel)
	for cel in cels:
		if not cel is PixelCel:
			continue
		var image: Image = cel.image
		image.unlock()
		data[image] = image.data
		image.lock()
	return data
