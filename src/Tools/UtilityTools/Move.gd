extends BaseTool

var _start_pos: Vector2i
var _offset: Vector2i
var _snap_to_grid := false  ## Holding Ctrl while moving.
var _undo_data := {}

@onready var selection_node := Global.canvas.selection


func _input(event: InputEvent) -> void:
	if _start_pos == Vector2i(Vector2.INF):
		return
	if event.is_action_pressed("transform_snap_grid"):
		_snap_to_grid = true
		_offset = _offset.snapped(Global.grids[0].grid_size)
	elif event.is_action_released("transform_snap_grid"):
		_snap_to_grid = false


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	var project := Global.current_project
	if not _can_layer_be_moved(project.layers[project.current_layer]):
		return
	_start_pos = pos
	_offset = pos
	_undo_data = _get_undo_data()
	if Tools.is_placing_tiles():
		# Clear selection if it it present (i tried moving the selection proview only but the)
		# code for it gets too complex so i chose to clear it instead
		if project.has_selection:
			Global.canvas.selection.clear_selection(true)
			project.selection_map_changed()
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			(cel as CelTileMap).prev_offset = (cel as CelTileMap).offset
	else:
		if project.has_selection:
			selection_node.transformation_handles.begin_transform()
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.MOVE)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	var project := Global.current_project
	if not _can_layer_be_moved(project.layers[project.current_layer]):
		return
	pos = _snap_position(pos)

	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			(cel as CelTileMap).change_offset(cel.offset + pos - _offset)
		Global.canvas.move_preview_location = pos - _start_pos
	else:
		if project.has_selection:
			selection_node.transformation_handles.move_transform(pos - _offset)
		else:
			Global.canvas.move_preview_location = pos - _start_pos
	_offset = pos
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.MOVE)


func draw_end(pos: Vector2i) -> void:
	var project := Global.current_project
	if not _can_layer_be_moved(project.layers[project.current_layer]):
		super.draw_end(pos)
		return
	if _start_pos != Vector2i(Vector2.INF):
		pos = _snap_position(pos)
		if not (project.has_selection and not Tools.is_placing_tiles()):
			var pixel_diff := pos - _start_pos
			Global.canvas.move_preview_location = Vector2i.ZERO
			for cel in _get_affected_cels():
				var image := cel.get_image()
				_move_image(image, pixel_diff)
				_move_image(image.indices_image, pixel_diff)
			_commit_undo("Draw")

	_start_pos = Vector2.INF
	_snap_to_grid = false
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.NONE)
	super.draw_end(pos)


func _get_affected_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel]
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var frame := project.frames[cel_index[0]]
		var cel: BaseCel = frame.cels[cel_index[1]]
		var layer: BaseLayer = project.layers[cel_index[1]]
		if not _can_layer_be_moved(layer):
			continue
		if cel is PixelCel:
			if not cels.has(cel):
				cels.append(cel)
		elif cel is GroupCel:
			for child in layer.get_children(true):
				var child_cel := frame.cels[child.index]
				if not _can_layer_be_moved(child):
					continue
				if child_cel is PixelCel:
					if not cels.has(child_cel):
						cels.append(child_cel)
	return cels


func _move_image(image: Image, pixel_diff: Vector2i) -> void:
	var image_copy := Image.new()
	image_copy.copy_from(image)
	image.fill(Color(0, 0, 0, 0))
	image.blit_rect(image_copy, Rect2i(Vector2i.ZERO, image.get_size()), pixel_diff)


func _can_layer_be_moved(layer: BaseLayer) -> bool:
	if layer.can_layer_get_drawn():
		return true
	if layer is GroupLayer and layer.can_layer_be_modified():
		return true
	return false


func _snap_position(pos: Vector2) -> Vector2:
	if Input.is_action_pressed("transform_snap_axis"):
		var angle := pos.angle_to_point(_start_pos)
		if absf(angle) <= PI / 4 or absf(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if _snap_to_grid:  # Snap to grid
		var grid_size := Global.grids[0].grid_size
		pos = pos.snapped(grid_size)
		# The part below only corrects the offset for situations when there is no selection
		# Offsets when there is selection is controlled in _input() function
		if not Global.current_project.has_selection:
			var move_offset: Vector2 = _start_pos - (_start_pos / grid_size) * grid_size
			pos += move_offset

	return pos


func _commit_undo(action: String) -> void:
	var project := Global.current_project
	project.update_tilemaps(_undo_data, TileSetPanel.TileEditingMode.AUTO)
	var redo_data := _get_undo_data()
	var frame := -1
	var layer := -1
	if Global.animation_timeline.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		if project.get_current_cel() is not GroupCel:
			layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	project.deserialize_cel_undo_data(redo_data, _undo_data)
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			project.undo_redo.add_do_method(cel.change_offset.bind(cel.offset))
			project.undo_redo.add_do_method(cel.re_order_tilemap)
			project.undo_redo.add_undo_method(cel.change_offset.bind(cel.prev_offset))
			project.undo_redo.add_undo_method(cel.re_order_tilemap)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame, layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame, layer))
	project.undo_redo.commit_action()
	_undo_data.clear()


func _get_undo_data() -> Dictionary:
	var data := {}
	var project := Global.current_project
	var cels: Array[BaseCel] = []
	if Global.animation_timeline.animation_timer.is_stopped():
		for cel in _get_affected_cels():
			cels.append(cel)
	else:
		for frame in project.frames:
			var cel := frame.cels[project.current_layer]
			cels.append(cel)
	project.serialize_cel_undo_data(cels, data)
	return data
