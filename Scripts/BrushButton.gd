extends BaseButton

var brush_type = Global.BRUSH_TYPES.PIXEL
var custom_brush_index := -1

func _on_BrushButton_pressed() -> void:
	if Global.brushes_popup.rect_global_position == Global.left_brush_type_button.rect_global_position:
		Global.current_left_brush_type = brush_type
		Global.left_brush_indicator.get_parent().remove_child(Global.left_brush_indicator)
		add_child(Global.left_brush_indicator)
		if custom_brush_index > -1: #Custom brush
			Global.custom_left_brush_index = custom_brush_index
			if hint_tooltip == "":
				Global.left_brush_type_label.text = "Custom brush"
			else:
				Global.left_brush_type_label.text = "Brush: %s" % hint_tooltip
		else: #Pixel brush
			Global.left_brush_type_label.text = "Brush: Pixel"

		Global.update_left_custom_brush()

	else:
		Global.current_right_brush_type = brush_type
		Global.right_brush_indicator.get_parent().remove_child(Global.right_brush_indicator)
		add_child(Global.right_brush_indicator)
		if custom_brush_index > -1:
			Global.custom_right_brush_index = custom_brush_index
			if hint_tooltip == "":
				Global.right_brush_type_label.text = "Custom brush"
			else:
				Global.right_brush_type_label.text = "Brush: %s" % hint_tooltip
		else: #Pixel brush
			Global.right_brush_type_label.text = "Brush: Pixel"

		Global.update_right_custom_brush()

func _on_DeleteButton_pressed() -> void:
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		if Global.custom_left_brush_index == custom_brush_index:
			Global.custom_left_brush_index = -1
			Global.current_left_brush_type = Global.BRUSH_TYPES.PIXEL
			remove_child(Global.left_brush_indicator)
			Global.file_brush_container.get_child(0).add_child(Global.left_brush_indicator)
		if Global.custom_right_brush_index == custom_brush_index:
			Global.custom_right_brush_index = -1
			Global.current_right_brush_type = Global.BRUSH_TYPES.PIXEL
			remove_child(Global.right_brush_indicator)
			Global.file_brush_container.get_child(0).add_child(Global.right_brush_indicator)

		Global.undos += 1
		Global.undo_redo.create_action("Delete Custom Brush")
		for i in range(custom_brush_index - 1, Global.project_brush_container.get_child_count()):
			var bb = Global.project_brush_container.get_child(i)
			if Global.custom_left_brush_index == bb.custom_brush_index:
				Global.custom_left_brush_index -= 1
			if Global.custom_right_brush_index == bb.custom_brush_index:
				Global.custom_right_brush_index -= 1

			Global.undo_redo.add_do_property(bb, "custom_brush_index", bb.custom_brush_index - 1)
			Global.undo_redo.add_undo_property(bb, "custom_brush_index", bb.custom_brush_index)

		var custom_brushes := Global.custom_brushes.duplicate()
		custom_brushes.remove(custom_brush_index)

		Global.undo_redo.add_do_property(Global, "custom_brushes", custom_brushes)
		Global.undo_redo.add_undo_property(Global, "custom_brushes", Global.custom_brushes)
		Global.undo_redo.add_do_method(Global, "redo_custom_brush", self)
		Global.undo_redo.add_undo_method(Global, "undo_custom_brush", self)
		Global.undo_redo.commit_action()

func _on_BrushButton_mouse_entered() -> void:
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		$DeleteButton.visible = true

func _on_BrushButton_mouse_exited() -> void:
	if brush_type == Global.BRUSH_TYPES.CUSTOM:
		$DeleteButton.visible = false
