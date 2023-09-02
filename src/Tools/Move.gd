extends BaseTool

var _undo_data := {}
var _start_pos: Vector2i
var _offset: Vector2i

## Used to check if the state of content transformation has been changed
## while draw_move() is being called. For example, pressing Enter while still moving content
var _content_transformation_check := false
var _snap_to_grid := false  ## Mouse Click + Ctrl

@onready var selection_node: Node2D = Global.canvas.selection


func _input(event: InputEvent) -> void:
	if _start_pos == Vector2i(Vector2.INF):
		return
	if event.is_action_pressed("transform_snap_grid"):
		_snap_to_grid = true
		_offset = _offset.snapped(Global.grid_size)
		if Global.current_project.has_selection and selection_node.is_moving_content:
			var prev_pos: Vector2 = selection_node.big_bounding_rectangle.position
			selection_node.big_bounding_rectangle.position = prev_pos.snapped(Global.grid_size)
			# The first time transform_snap_grid is enabled then _snap_position() is not called
			# and the selection had wrong offset, so do selection offsetting here
			var grid_offset := Global.grid_offset
			grid_offset = Vector2(
				fmod(grid_offset.x, Global.grid_size.x), fmod(grid_offset.y, Global.grid_size.y)
			)
			selection_node.big_bounding_rectangle.position += grid_offset
			selection_node.marching_ants_outline.offset += (
				selection_node.big_bounding_rectangle.position - prev_pos
			)
	elif event.is_action_released("transform_snap_grid"):
		_snap_to_grid = false


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_start_pos = pos
	_offset = pos
	_undo_data = _get_undo_data()
	if Global.current_project.has_selection:
		selection_node.transform_content_start()
	_content_transformation_check = selection_node.is_moving_content


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	# This is true if content transformation has been confirmed (pressed Enter for example)
	# while the content is being moved
	if _content_transformation_check != selection_node.is_moving_content:
		return
	pos = _snap_position(pos)

	if Global.current_project.has_selection:
		selection_node.move_content(pos - _offset)
	else:
		Global.canvas.move_preview_location = pos - _start_pos
	_offset = pos


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if (
		_start_pos != Vector2i(Vector2.INF)
		and _content_transformation_check == selection_node.is_moving_content
	):
		pos = _snap_position(pos)
		var project := Global.current_project

		if project.has_selection:
			selection_node.move_borders_end()
		else:
			var pixel_diff := pos - _start_pos
			Global.canvas.move_preview_location = Vector2i.ZERO
			var images := _get_selected_draw_images()
			for image in images:
				var image_copy := Image.new()
				image_copy.copy_from(image)
				image.fill(Color(0, 0, 0, 0))
				image.blit_rect(image_copy, Rect2i(Vector2i.ZERO, project.size), pixel_diff)

			commit_undo("Draw")

	_start_pos = Vector2.INF
	_snap_to_grid = false


func _snap_position(pos: Vector2) -> Vector2:
	if Input.is_action_pressed("transform_snap_axis"):
		var angle := pos.angle_to_point(_start_pos)
		if absf(angle) <= PI / 4 or absf(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if _snap_to_grid:  # Snap to grid
		pos = pos.snapped(Global.grid_size)
		# The part below only corrects the offset for situations when there is no selection
		# Offsets when there is selection is controlled in _input() function
		if !Global.current_project.has_selection:
			var move_offset := Vector2.ZERO
			move_offset.x = (
				_start_pos.x - (_start_pos.x / Global.grid_size.x) * Global.grid_size.x
			)
			move_offset.y = (
				_start_pos.y - (_start_pos.y / Global.grid_size.y) * Global.grid_size.y
			)
			pos += move_offset

	return pos


func commit_undo(action: String) -> void:
	var redo_data := _get_undo_data()
	var project := Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in _undo_data:
		project.undo_redo.add_undo_property(image, "data", _undo_data[image])
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame, layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame, layer))
	project.undo_redo.commit_action()

	_undo_data.clear()


func _get_undo_data() -> Dictionary:
	var data := {}
	var project := Global.current_project
	var cels: Array[BaseCel] = []
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
		data[image] = image.data
	return data
