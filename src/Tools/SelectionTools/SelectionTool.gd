class_name SelectionTool extends BaseTool


var _move := false
var _move_content := true
var _start_pos := Vector2.ZERO
var _offset := Vector2.ZERO

var _add := false # Shift + Mouse Click
var _subtract := false # Ctrl + Mouse Click
var _intersect := false # Shift + Ctrl + Mouse Click
var _snap_to_grid := false # Mouse Click + Ctrl

# Used to check if the state of content transformation has been changed
# while draw_move() is being called. For example, pressing Enter while still moving content
var _content_transformation_check := false
var undo_data : Dictionary

onready var selection_node : Node2D = Global.canvas.selection
onready var xspinbox : SpinBox = find_node("XSpinBox")
onready var yspinbox : SpinBox = find_node("YSpinBox")
onready var wspinbox : SpinBox = find_node("WSpinBox")
onready var hspinbox : SpinBox = find_node("HSpinBox")
onready var timer : Timer = $Timer


func _ready() -> void:
	set_spinbox_values()


func _input(event : InputEvent) -> void:
	if _move:
		if event.is_action_pressed("ctrl"):
			_snap_to_grid = true
			var grid_size := Vector2(Global.grid_width, Global.grid_height)
			_offset = _offset.snapped(grid_size)
			var prev_pos = selection_node.big_bounding_rectangle.position
			selection_node.big_bounding_rectangle.position = selection_node.big_bounding_rectangle.position.snapped(grid_size)
			selection_node.marching_ants_outline.offset += selection_node.big_bounding_rectangle.position - prev_pos
		elif event.is_action_released("ctrl"):
			_snap_to_grid = false


func set_spinbox_values() -> void:
	var select_rect : Rect2 = selection_node.big_bounding_rectangle
	xspinbox.editable = !select_rect.has_no_area()
	yspinbox.editable = !select_rect.has_no_area()
	wspinbox.editable = !select_rect.has_no_area()
	hspinbox.editable = !select_rect.has_no_area()

	xspinbox.value = select_rect.position.x
	yspinbox.value = select_rect.position.y
	wspinbox.value = select_rect.size.x
	hspinbox.value = select_rect.size.y


func draw_start(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	var project : Project = Global.current_project
	undo_data = selection_node._get_undo_data(false)
	_intersect = Tools.shift && Tools.control
	_add = Tools.shift && !_intersect
	_subtract = Tools.control && !_intersect
	_start_pos = position
	_offset = position

	var selection_position : Vector2 = selection_node.big_bounding_rectangle.position
	var offsetted_pos := position
	if selection_position.x < 0:
		offsetted_pos.x -= selection_position.x
	if selection_position.y < 0:
		offsetted_pos.y -= selection_position.y
	if offsetted_pos.x >= 0 and offsetted_pos.y >= 0 and project.selection_bitmap.get_bit(offsetted_pos) and (!Tools.control or Tools.alt) and !Tools.shift:
		# Move current selection
		_move = true
		if Tools.control and Tools.alt: # Move selection without content
			selection_node.transform_content_confirm()
			_move_content = false
			selection_node.move_borders_start()
		else:
			_move_content = true
			if Tools.alt: # Move the selection without cutting it from the original position / makes a quick copy of it
				selection_node.transform_content_confirm()
			selection_node.transform_content_start()
			if Tools.alt: # Continuation of the above
				var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
				cel_image.blit_rect_mask(selection_node.preview_image, selection_node.preview_image, Rect2(Vector2.ZERO, project.selection_bitmap.get_size()), selection_node.big_bounding_rectangle.position)

	else:
		selection_node.transform_content_confirm()

	_content_transformation_check = selection_node.is_moving_content


func draw_move(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	# This is true if content transformation has been confirmed (pressed Enter for example)
	# while the content is being moved
	if _content_transformation_check != selection_node.is_moving_content:
		return
	if _move:
		if Tools.shift: # Snap to axis
			var angle := position.angle_to_point(_start_pos)
			if abs(angle) <= PI / 4 or abs(angle) >= 3*PI / 4:
				position.y = _start_pos.y
			else:
				position.x = _start_pos.x
		if _snap_to_grid:
			position = position.snapped(Vector2(Global.grid_width, Global.grid_height))

		if _move_content:
			selection_node.move_content(position - _offset)
		else:
			selection_node.move_borders(position - _offset)

		_offset = position
		_set_cursor_text(selection_node.big_bounding_rectangle)


func draw_end(_position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	if _content_transformation_check == selection_node.is_moving_content:
		if _move:
			selection_node.move_borders_end()
		else:
			apply_selection(_position)

	_move = false
	_snap_to_grid = false
	cursor_text = ""


func apply_selection(_position : Vector2) -> void:
	pass


func _set_cursor_text(rect : Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]


func _on_XSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or selection_node.big_bounding_rectangle.position.x == value:
		return
	if timer.is_stopped():
		undo_data = selection_node._get_undo_data(false)
	timer.start()
	selection_node.big_bounding_rectangle.position.x = value

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	project.move_bitmap_values(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()


func _on_YSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or selection_node.big_bounding_rectangle.position.y == value:
		return
	if timer.is_stopped():
		undo_data = selection_node._get_undo_data(false)
	timer.start()
	selection_node.big_bounding_rectangle.position.y = value

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	project.move_bitmap_values(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()


func _on_WSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or selection_node.big_bounding_rectangle.size.x == value or selection_node.big_bounding_rectangle.size.x <= 0:
		return
	if timer.is_stopped():
		undo_data = selection_node._get_undo_data(false)
	timer.start()
	selection_node.big_bounding_rectangle.size.x = value
	resize_selection()


func _on_HSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or selection_node.big_bounding_rectangle.size.y == value or selection_node.big_bounding_rectangle.size.y <= 0:
		return
	if timer.is_stopped():
		undo_data = selection_node._get_undo_data(false)
	timer.start()
	selection_node.big_bounding_rectangle.size.y = value
	resize_selection()


func resize_selection() -> void:
	var project : Project = Global.current_project
	var bitmap : BitMap = project.selection_bitmap
	if selection_node.is_moving_content:
		bitmap = selection_node.original_bitmap
		var preview_image : Image = selection_node.preview_image
		preview_image.copy_from(selection_node.original_preview_image)
		preview_image.resize(selection_node.big_bounding_rectangle.size.x, selection_node.big_bounding_rectangle.size.y, Image.INTERPOLATE_NEAREST)
		selection_node.preview_image_texture.create_from_image(preview_image, 0)

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap_values(bitmap, selection_node.big_bounding_rectangle.size, false, false)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()


func _on_Timer_timeout() -> void:
	if !selection_node.is_moving_content:
		selection_node.commit_undo("Move Selection", undo_data)
