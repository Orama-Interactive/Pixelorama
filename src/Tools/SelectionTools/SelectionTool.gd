class_name SelectionTool
extends BaseTool

enum Mode { DEFAULT, ADD, SUBTRACT, INTERSECT }

var undo_data: Dictionary
var _move := false
var _move_content := true
var _start_pos := Vector2.ZERO
var _offset := Vector2.ZERO
# For tools such as the Polygon selection @tool where you have to
# click multiple times to create a selection
var _ongoing_selection := false

var _mode_selected := 0
var _add := false  # Shift + Mouse Click
var _subtract := false  # Ctrl + Mouse Click
var _intersect := false  # Shift + Ctrl + Mouse Click

# Used to check if the state of content transformation has been changed
# while draw_move() is being called. For example, pressing Enter while still moving content
var _content_transformation_check := false

@onready var selection_node: Node2D = Global.canvas.selection
@onready var xspinbox: ValueSlider = $XSpinBox
@onready var yspinbox: ValueSlider = $YSpinBox
@onready var wspinbox: ValueSlider = $WSpinBox
@onready var hspinbox: ValueSlider = $HSpinBox
@onready var timer: Timer = $Timer


func _ready() -> void:
	super._ready()
	set_spinbox_values()
	refresh_options()


func refresh_options():
	# The existence of this function is to ensure all items
	# are added when we are selecting an option (Bad things will happen if i dont do this...)
	$Modes.clear()
	$Modes.add_item("Default (New Selection)")
	$Modes.add_item("Add to Selection")
	$Modes.add_item("Subtract from Selection")
	$Modes.add_item("Intersection of Selections")
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
	var select_rect: Rect2 = selection_node.big_bounding_rectangle
	xspinbox.editable = select_rect.has_area()
	yspinbox.editable = xspinbox.editable
	wspinbox.editable = xspinbox.editable
	hspinbox.editable = xspinbox.editable

	xspinbox.value = select_rect.position.x
	yspinbox.value = select_rect.position.y
	wspinbox.value = select_rect.size.x
	hspinbox.value = select_rect.size.y


func draw_start(pos: Vector2) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if selection_node.arrow_key_move:
		return
	var project: Project = Global.current_project
	undo_data = selection_node.get_undo_data(false)
	_intersect = Input.is_action_pressed("selection_intersect", true)
	_add = Input.is_action_pressed("selection_add", true)
	_subtract = Input.is_action_pressed("selection_subtract", true)
	_start_pos = pos
	_offset = pos

	var selection_position: Vector2 = selection_node.big_bounding_rectangle.position
	var offsetted_pos := pos
	if selection_position.x < 0:
		offsetted_pos.x -= selection_position.x
	if selection_position.y < 0:
		offsetted_pos.y -= selection_position.y

	var quick_copy: bool = Input.is_action_pressed("transform_copy_selection_content", true)
	if (
		offsetted_pos.x >= 0
		and offsetted_pos.y >= 0
		and project.selection_map.is_pixel_selected(offsetted_pos)
		and (!_add and !_subtract and !_intersect or quick_copy)
		and !_ongoing_selection
	):
		if !(
			Global
			. current_project
			. layers[Global.current_project.current_layer]
			. can_layer_get_drawn()
		):
			return
		# Move current selection
		_move = true
		if quick_copy:  # Move selection without cutting it from the original position (quick copy)
			_move_content = true
			if selection_node.is_moving_content:
				for image in _get_selected_draw_images():
					image.blit_rect_mask(
						selection_node.preview_image,
						selection_node.preview_image,
						Rect2(Vector2.ZERO, project.selection_map.get_size()),
						selection_node.big_bounding_rectangle.position
					)

				var selection_map_copy := SelectionMap.new()
				selection_map_copy.copy_from(project.selection_map)
				selection_map_copy.move_bitmap_values(project)

				project.selection_map = selection_map_copy
				selection_node.commit_undo("Move Selection", selection_node.undo_data)
				selection_node.undo_data = selection_node.get_undo_data(true)
			else:
				selection_node.transform_content_start()
				for image in _get_selected_draw_images():
					image.blit_rect_mask(
						selection_node.preview_image,
						selection_node.preview_image,
						Rect2(Vector2.ZERO, project.selection_map.get_size()),
						selection_node.big_bounding_rectangle.position
					)
				Global.canvas.update_selected_cels_textures()

		elif Input.is_action_pressed("transform_move_selection_only", true):  # Doesn't move content
			selection_node.transform_content_confirm()
			_move_content = false
			selection_node.move_borders_start()
		else:  # Move selection and content normally
			_move_content = true
			selection_node.transform_content_start()

	else:  # No moving
		selection_node.transform_content_confirm()

	_content_transformation_check = selection_node.is_moving_content


func draw_move(pos: Vector2) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if selection_node.arrow_key_move:
		return
	# This is true if content transformation has been confirmed (pressed Enter for example)
	# while the content is being moved
	if _content_transformation_check != selection_node.is_moving_content:
		return
	if not _move:
		return

	if Input.is_action_pressed("transform_snap_axis"):  # Snap to axis
		var angle := pos.angle_to_point(_start_pos)
		if abs(angle) <= PI / 4 or abs(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if Input.is_action_pressed("transform_snap_grid"):
		var grid_size := Vector2(Global.grid_width, Global.grid_height)
		_offset = _offset.snapped(grid_size)
		var prev_pos = selection_node.big_bounding_rectangle.position
		selection_node.big_bounding_rectangle.position = prev_pos.snapped(grid_size)
		selection_node.marching_ants_outline.offset += (
			selection_node.big_bounding_rectangle.position - prev_pos
		)
		pos = pos.snapped(grid_size)
		var grid_offset := Vector2(Global.grid_offset_x, Global.grid_offset_y)
		grid_offset = Vector2(fmod(grid_offset.x, grid_size.x), fmod(grid_offset.y, grid_size.y))
		pos += grid_offset

	if _move_content:
		selection_node.move_content(pos - _offset)
	else:
		selection_node.move_borders(pos - _offset)

	_offset = pos
	_set_cursor_text(selection_node.big_bounding_rectangle)


func draw_end(pos: Vector2) -> void:
	pos = snap_position(pos)
	super.draw_end(pos)
	if selection_node.arrow_key_move:
		return
	if _content_transformation_check == selection_node.is_moving_content:
		if _move:
			selection_node.move_borders_end()
		else:
			apply_selection(pos)

	_move = false
	cursor_text = ""


func apply_selection(_pos: Vector2) -> void:
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


func _on_Modes_item_selected(index: int) -> void:
	_mode_selected = index
	save_config()


func _set_cursor_text(rect: Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]


func _on_position_value_changed(value: float, horizontal: bool) -> void:
	if horizontal:
		if selection_node.big_bounding_rectangle.position.x == value:
			return
	else:
		if selection_node.big_bounding_rectangle.position.y == value:
			return
	var project: Project = Global.current_project
	if !project.has_selection:
		return

	if timer.is_stopped():
		undo_data = selection_node.get_undo_data(false)
	timer.start()
	if horizontal:
		selection_node.big_bounding_rectangle.position.x = value
	else:
		selection_node.big_bounding_rectangle.position.y = value

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	selection_map_copy.move_bitmap_values(project)
	project.selection_map = selection_map_copy
	project.selection_map_changed()


func _on_size_value_changed(value: float, horizontal: bool) -> void:
	if horizontal:
		if (
			selection_node.big_bounding_rectangle.size.x == value
			or selection_node.big_bounding_rectangle.size.x <= 0
		):
			return
	else:
		if (
			selection_node.big_bounding_rectangle.size.y == value
			or selection_node.big_bounding_rectangle.size.y <= 0
		):
			return
	if !Global.current_project.has_selection:
		return

	if timer.is_stopped():
		undo_data = selection_node.get_undo_data(false)
	timer.start()
	if horizontal:
		selection_node.big_bounding_rectangle.size.x = value
	else:
		selection_node.big_bounding_rectangle.size.y = value
	selection_node.resize_selection()


func _on_Timer_timeout() -> void:
	if !selection_node.is_moving_content:
		selection_node.commit_undo("Move Selection", undo_data)
