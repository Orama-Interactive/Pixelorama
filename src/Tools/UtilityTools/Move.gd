extends BaseTool

var _start_pos: Vector2i
var _offset: Vector2i
var _snap_to_grid := false  ## Mouse Click + Ctrl
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
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_start_pos = pos
	_offset = pos
	_undo_data = _get_undo_data()
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			(cel as CelTileMap).prev_offset = (cel as CelTileMap).offset
	else:
		if Global.current_project.has_selection:
			selection_node.transformation_handles.begin_transform()
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.MOVE)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	pos = _snap_position(pos)

	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			(cel as CelTileMap).change_offset(cel.offset + pos - _offset)
		Global.canvas.move_preview_location = pos - _start_pos
	else:
		if Global.current_project.has_selection:
			selection_node.transformation_handles.move_transform(pos - _offset)
		else:
			Global.canvas.move_preview_location = pos - _start_pos
	_offset = pos
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.MOVE)


func draw_end(pos: Vector2i) -> void:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		super.draw_end(pos)
		return
	if _start_pos != Vector2i(Vector2.INF):
		pos = _snap_position(pos)
		if not (Global.current_project.has_selection and not Tools.is_placing_tiles()):
			var pixel_diff := pos - _start_pos
			Global.canvas.move_preview_location = Vector2i.ZERO
			var images := _get_selected_draw_images()
			for image in images:
				_move_image(image, pixel_diff)
				_move_image(image.indices_image, pixel_diff)
			_commit_undo("Draw")

	_start_pos = Vector2.INF
	_snap_to_grid = false
	Global.canvas.sprite_changed_this_frame = true
	Global.canvas.measurements.update_measurement(Global.MeasurementMode.NONE)
	super.draw_end(pos)


func _move_image(image: Image, pixel_diff: Vector2i) -> void:
	var image_copy := Image.new()
	image_copy.copy_from(image)
	image.fill(Color(0, 0, 0, 0))
	image.blit_rect(image_copy, Rect2i(Vector2i.ZERO, image.get_size()), pixel_diff)


func _snap_position(pos: Vector2) -> Vector2:
	if Input.is_action_pressed("transform_snap_axis"):
		var angle := pos.angle_to_point(_start_pos)
		if absf(angle) <= PI / 4 or absf(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if _snap_to_grid:  # Snap to grid
		pos = pos.snapped(Global.grids[0].grid_size)
		# The part below only corrects the offset for situations when there is no selection
		# Offsets when there is selection is controlled in _input() function
		if !Global.current_project.has_selection:
			var move_offset := Vector2.ZERO
			move_offset.x = (
				_start_pos.x
				- (_start_pos.x / Global.grids[0].grid_size.x) * Global.grids[0].grid_size.x
			)
			move_offset.y = (
				_start_pos.y
				- (_start_pos.y / Global.grids[0].grid_size.y) * Global.grids[0].grid_size.y
			)
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
		for cel_index in project.selected_cels:
			cels.append(project.frames[cel_index[0]].cels[cel_index[1]])
	else:
		for frame in project.frames:
			var cel := frame.cels[project.current_layer]
			cels.append(cel)
	project.serialize_cel_undo_data(cels, data)
	return data
