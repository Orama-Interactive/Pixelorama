class_name SelectionTool extends BaseTool


var _move := false
var _move_content := true
var _offset := Vector2.ZERO
var _add := false # Shift + Mouse Click
var _subtract := false # Ctrl + Mouse Click
var _intersect := false # Shift + Ctrl + Mouse Click

var undo_data : Dictionary

onready var xspinbox : SpinBox = find_node("XSpinBox")
onready var yspinbox : SpinBox = find_node("YSpinBox")
onready var wspinbox : SpinBox = find_node("WSpinBox")
onready var hspinbox : SpinBox = find_node("HSpinBox")


func _ready() -> void:
	var select_rect : Rect2 = Global.canvas.selection.big_bounding_rectangle
	xspinbox.value = select_rect.position.x
	yspinbox.value = select_rect.position.y
	wspinbox.value = select_rect.size.x
	hspinbox.value = select_rect.size.y


func draw_start(position : Vector2) -> void:
	undo_data = Global.canvas.selection._get_undo_data(false)
	_intersect = Tools.shift && Tools.control
	_add = Tools.shift && !_intersect
	_subtract = Tools.control && !_intersect
	_offset = position

	var selection_position : Vector2 = Global.canvas.selection.big_bounding_rectangle.position
	var offsetted_pos := position
	if selection_position.x < 0:
		offsetted_pos.x -= selection_position.x
	if selection_position.y < 0:
		offsetted_pos.y -= selection_position.y
	if offsetted_pos.x >= 0 and offsetted_pos.y >= 0 and Global.current_project.selection_bitmap.get_bit(offsetted_pos) and (!Tools.control or Tools.alt) and !Tools.shift:
		# Move current selection
		_move = true
		if Tools.control and Tools.alt: # Move selection without content
			Global.canvas.selection.transform_content_confirm()
			_move_content = false
			Global.canvas.selection.move_borders_start()
		else:
			_move_content = true
			Global.canvas.selection.transform_content_start()
	else:
		Global.canvas.selection.transform_content_confirm()


func draw_move(position : Vector2) -> void:
	if _move:
		if _move_content:
			Global.canvas.selection.move_content(position - _offset)
		else:
			Global.canvas.selection.move_borders(position - _offset)
		_offset = position
		_set_cursor_text(Global.canvas.selection.big_bounding_rectangle)


func draw_end(_position : Vector2) -> void:
	if _move:
		Global.canvas.selection.move_borders_end(!_move_content)
	else:
		apply_selection(_position)

	_move = false
	cursor_text = ""


func apply_selection(_position : Vector2) -> void:
	pass


func _set_cursor_text(rect : Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]


func _on_XSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or Global.canvas.selection.big_bounding_rectangle.position.x == value:
		return
	Global.canvas.selection.big_bounding_rectangle.position.x = value

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	project.move_bitmap_values(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()


func _on_YSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or Global.canvas.selection.big_bounding_rectangle.position.y == value:
		return
	Global.canvas.selection.big_bounding_rectangle.position.y = value

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	project.move_bitmap_values(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()


func _on_WSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or Global.canvas.selection.big_bounding_rectangle.size.x == value or Global.canvas.selection.big_bounding_rectangle.size.x <= 0:
		return
	Global.canvas.selection.big_bounding_rectangle.size.x = value
	resize_selection()


func _on_HSpinBox_value_changed(value : float) -> void:
	var project : Project = Global.current_project
	if !project.has_selection or Global.canvas.selection.big_bounding_rectangle.size.y == value or Global.canvas.selection.big_bounding_rectangle.size.y <= 0:
		return
	Global.canvas.selection.big_bounding_rectangle.size.y = value
	resize_selection()


func resize_selection() -> void:
	var project : Project = Global.current_project
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap_values(project.selection_bitmap, Global.canvas.selection.big_bounding_rectangle.size, false, false)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()

	if Global.canvas.selection.is_moving_content:
		var preview_image : Image = Global.canvas.selection.preview_image
		preview_image.copy_from(Global.canvas.selection.original_preview_image)
		preview_image.resize(Global.canvas.selection.big_bounding_rectangle.size.x, Global.canvas.selection.big_bounding_rectangle.size.y, Image.INTERPOLATE_NEAREST)
		Global.canvas.selection.preview_image_texture.create_from_image(preview_image, 0)
