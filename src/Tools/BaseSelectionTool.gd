class_name BaseSelectionTool
extends BaseTool

enum Mode { DEFAULT, ADD, SUBTRACT, INTERSECT }

var undo_data: Dictionary
var _move := false
var _start_pos := Vector2i.ZERO
var _offset := Vector2i.ZERO
## For tools such as the Polygon selection tool where you have to
## click multiple times to create a selection
var _ongoing_selection := false

var _mode_selected := 0
var _add := false  ## Shift + Mouse Click
var _subtract := false  ## Ctrl + Mouse Click
var _intersect := false  ## Shift + Ctrl + Mouse Click

var _skip_slider_logic := false

@onready var selection_node := Global.canvas.selection
@onready var transformation_handles := selection_node.transformation_handles
@onready var algorithm_option_button := $Algorithm as OptionButton
@onready var position_sliders := $Position as ValueSliderV2
@onready var size_sliders := $Size as ValueSliderV2
@onready var rotation_slider := $Rotation as ValueSlider
@onready var shear_slider := $Shear as ValueSlider


func _ready() -> void:
	super._ready()
	algorithm_option_button.add_item("Nearest Neighbor")
	algorithm_option_button.add_item("cleanEdge", DrawingAlgos.RotationAlgorithm.CLEANEDGE)
	algorithm_option_button.add_item("OmniScale", DrawingAlgos.RotationAlgorithm.OMNISCALE)
	algorithm_option_button.select(0)
	set_confirm_buttons_visibility()
	set_spinbox_values()
	refresh_options()
	transformation_handles.preview_transform_changed.connect(set_confirm_buttons_visibility)


func set_confirm_buttons_visibility() -> void:
	await get_tree().process_frame
	set_spinbox_values()
	get_tree().set_group(
		&"ShowOnActiveTransformation", "visible", transformation_handles.is_transforming_content()
	)


## Ensure all items are added when we are selecting an option.
func refresh_options() -> void:
	$Modes.clear()
	$Modes.add_item("Replace selection")
	$Modes.add_item("Add to selection")
	$Modes.add_item("Subtract from selection")
	$Modes.add_item("Intersection of selections")
	$Modes.select(_mode_selected)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["mode_selected"] = _mode_selected
	return config


func set_config(config: Dictionary) -> void:
	_mode_selected = config.get("mode_selected", 0)


func update_config() -> void:
	refresh_options()


func set_spinbox_values() -> void:
	_skip_slider_logic = true
	var project := Global.current_project
	var select_rect := project.selection_map.get_selection_rect(project)
	var has_selection := select_rect.has_area()
	if not has_selection:
		size_sliders.press_ratio_button(false)
	position_sliders.editable = has_selection
	size_sliders.editable = has_selection
	if transformation_handles.is_transforming_content():
		select_rect = selection_node.preview_selection_map.get_selection_rect(project)
		rotation_slider.value = rad_to_deg(transformation_handles.preview_transform.get_rotation())
		shear_slider.value = rad_to_deg(transformation_handles.preview_transform.get_skew())
	position_sliders.value = select_rect.position
	size_sliders.value = select_rect.size
	_skip_slider_logic = false


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if transformation_handles.arrow_key_move:
		return
	var project := Global.current_project
	_intersect = Input.is_action_pressed("selection_intersect", true)
	_add = Input.is_action_pressed("selection_add", true)
	_subtract = Input.is_action_pressed("selection_subtract", true)
	_start_pos = pos
	_offset = pos

	var quick_copy := Input.is_action_pressed("transform_copy_selection_content", true)
	if (
		selection_node.preview_selection_map.is_pixel_selected(pos)
		and (!_add and !_subtract and !_intersect or quick_copy)
		and !_ongoing_selection
	):
		if not project.layers[project.current_layer].can_layer_get_drawn():
			return
		# Move current selection
		_move = true
		if quick_copy:  # Move selection without cutting it from the original position (quick copy)
			if transformation_handles.is_transforming_content():
				selection_node.transform_content_confirm()
			transformation_handles.begin_transform(null, project, true)
			var select_rect := project.selection_map.get_selection_rect(project)
			for cel in _get_selected_draw_unlocked_cels():
				var image := cel.get_image()
				image.blit_rect_mask(
					cel.transformed_content,
					cel.transformed_content,
					Rect2i(Vector2i.ZERO, project.selection_map.get_size()),
					select_rect.position
				)
			Global.canvas.queue_redraw()

		else:
			transformation_handles.begin_transform()

	else:  # No moving
		selection_node.transform_content_confirm()
	undo_data = selection_node.get_undo_data(false)


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if transformation_handles.arrow_key_move:
		return
	if not _move:
		return
	var project := Global.current_project
	var select_rect := project.selection_map.get_selection_rect(project)
	if Tools.is_placing_tiles():
		var cel := project.get_current_cel() as CelTileMap
		var grid_size := cel.get_tile_size()
		var offset := cel.offset % grid_size
		pos = Tools.snap_to_rectangular_grid_boundary(pos, grid_size, offset)
	if Input.is_action_pressed("transform_snap_axis"):  # Snap to axis
		var angle := Vector2(pos).angle_to_point(_start_pos)
		if absf(angle) <= PI / 4 or absf(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if Input.is_action_pressed("transform_snap_grid"):
		_offset = _offset.snapped(Global.grids[0].grid_size)
		var prev_pos: Vector2i = select_rect.position
		selection_node.marching_ants_outline.offset += Vector2(select_rect.position - prev_pos)
		pos = pos.snapped(Global.grids[0].grid_size)
		var grid_offset := Global.grids[0].grid_offset
		grid_offset = Vector2i(
			fmod(grid_offset.x, Global.grids[0].grid_size.x),
			fmod(grid_offset.y, Global.grids[0].grid_size.y)
		)
		pos += grid_offset

	transformation_handles.move_transform(pos - _offset)
	_offset = pos
	_set_cursor_text(select_rect)


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_end(pos)
	if transformation_handles.arrow_key_move:
		return
	if not _move:
		apply_selection(pos)

	_move = false
	cursor_text = ""


func apply_selection(_position: Vector2i) -> void:
	# if a shortcut is activated then that will be obeyed instead
	match _mode_selected:
		Mode.ADD:
			if !_subtract && !_intersect:
				_add = true
		Mode.SUBTRACT:
			if !_add && !_intersect:
				_subtract = true
		Mode.INTERSECT:
			if !_add && !_subtract:
				_intersect = true


func select_tilemap_cell(
	cel: CelTileMap, cell_position: Vector2i, selection: SelectionMap, select: bool
) -> void:
	var rect := Rect2i(cell_position + cel.offset, cel.get_tile_size())
	selection.select_rect(rect, select)


func _get_selected_draw_unlocked_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel]
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if not project.layers[cel_index[1]].can_layer_get_drawn():
			continue
		cels.append(cel)
	return cels


func _on_confirm_button_pressed() -> void:
	selection_node.transform_content_confirm()


func _on_cancel_button_pressed() -> void:
	selection_node.transform_content_cancel()


func _on_modes_item_selected(index: int) -> void:
	_mode_selected = index
	save_config()


func _on_algorithm_item_selected(index: int) -> void:
	var id := algorithm_option_button.get_item_id(index)
	transformation_handles.transformation_algorithm = id


func _set_cursor_text(rect: Rect2i) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]


func _on_position_value_changed(value: Vector2) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming_content():
		transformation_handles.begin_transform()
	transformation_handles.move_transform(value - transformation_handles.preview_transform.origin)


func _on_size_value_changed(value: Vector2i) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming_content():
		transformation_handles.begin_transform()
	var image_size := selection_node.preview_selection_map.get_used_rect().size
	var delta := value - image_size
	transformation_handles.resize_transform(delta)


func _on_rotation_value_changed(value: float) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming_content():
		transformation_handles.begin_transform()
	var angle := deg_to_rad(value)
	transformation_handles.rotate_transform(angle)


func _on_shear_value_changed(value: float) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming_content():
		transformation_handles.begin_transform()
	var angle := deg_to_rad(value)
	transformation_handles.shear_transform(angle)
