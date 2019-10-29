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