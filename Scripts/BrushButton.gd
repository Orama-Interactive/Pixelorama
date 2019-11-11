extends Button

var brush_type = Global.BRUSH_TYPES.PIXEL
var custom_brush_index := -1

func _on_BrushButton_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.current_left_brush_type = brush_type
		Global.left_brush_indicator.get_parent().remove_child(Global.left_brush_indicator)
		add_child(Global.left_brush_indicator)
		if custom_brush_index > -1:
			Global.custom_left_brush_index = custom_brush_index
			Global.update_left_custom_brush()

	elif Input.is_action_just_released("right_mouse"):
		Global.current_right_brush_type = brush_type
		Global.right_brush_indicator.get_parent().remove_child(Global.right_brush_indicator)
		add_child(Global.right_brush_indicator)
		if custom_brush_index > -1:
			Global.custom_right_brush_index = custom_brush_index
			Global.update_right_custom_brush()

func _on_DeleteButton_pressed() -> void:
	var file_hbox_container := Global.find_node_by_name(get_tree().get_root(), "BrushHBoxContainer")
	var custom_hbox_container := Global.find_node_by_name(get_tree().get_root(), "CustomBrushHBoxContainer")
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		if Global.custom_left_brush_index == custom_brush_index:
			Global.custom_left_brush_index = -1
			Global.current_left_brush_type = Global.BRUSH_TYPES.PIXEL
			remove_child(Global.left_brush_indicator)
			file_hbox_container.get_child(0).add_child(Global.left_brush_indicator)
		if Global.custom_right_brush_index == custom_brush_index:
			Global.custom_right_brush_index = -1
			Global.current_right_brush_type = Global.BRUSH_TYPES.PIXEL
			remove_child(Global.right_brush_indicator)
			file_hbox_container.get_child(0).add_child(Global.right_brush_indicator)

		for i in range(custom_brush_index - 1, custom_hbox_container.get_child_count()):
			if Global.custom_left_brush_index == custom_hbox_container.get_child(i).custom_brush_index:
				Global.custom_left_brush_index -= 1
			if Global.custom_right_brush_index == custom_hbox_container.get_child(i).custom_brush_index:
				Global.custom_right_brush_index -= 1
			custom_hbox_container.get_child(i).custom_brush_index -= 1

		Global.custom_brushes.remove(custom_brush_index)
		queue_free()

func _on_BrushButton_mouse_entered() -> void:
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		$DeleteButton.visible = true

func _on_BrushButton_mouse_exited() -> void:
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		$DeleteButton.visible = false
