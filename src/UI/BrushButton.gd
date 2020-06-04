extends BaseButton


export var brush_type = 0 # Global.Brush_Types.PIXEL
export var custom_brush_index := -3
var random_brushes := []


func _on_BrushButton_pressed() -> void:
	# Delete the brush on middle mouse press
	if Input.is_action_just_released("middle_mouse"):
		_on_DeleteButton_pressed()
		return

	# Change brush
	Global.current_brush_types[Global.brush_type_window_position] = brush_type
	Global.custom_brush_indexes[Global.brush_type_window_position] = custom_brush_index
	if custom_brush_index > -1: # Custom brush
		if Global.current_tools[Global.brush_type_window_position] == Global.Tools.PENCIL:
			Global.color_interpolation_containers[Global.brush_type_window_position].visible = true
#			if hint_tooltip == "":
#				Global.left_brush_type_label.text = tr("Custom brush")
#			else:
#				Global.left_brush_type_label.text = tr("Brush:") + " %s" % hint_tooltip
	elif custom_brush_index == -3: # Pixel brush
		Global.color_interpolation_containers[Global.brush_type_window_position].visible = false
#			Global.left_brush_type_label.text = tr("Brush: Pixel")
	elif custom_brush_index == -2: # Circle brush
		Global.color_interpolation_containers[Global.brush_type_window_position].visible = false
#			Global.left_brush_type_label.text = tr("Brush: Circle")
	elif custom_brush_index == -1: # Filled Circle brush
		Global.color_interpolation_containers[Global.brush_type_window_position].visible = false
#			Global.left_brush_type_label.text = tr("Brush: Filled Circle")

	Global.update_custom_brush(Global.brush_type_window_position)
	Global.brushes_popup.hide()


func _on_DeleteButton_pressed() -> void:
	if brush_type == Global.Brush_Types.CUSTOM:
		if Global.custom_brush_indexes[0] == custom_brush_index:
			Global.custom_brush_indexes[0] = -3
			Global.current_brush_types[0] = Global.Brush_Types.PIXEL
#			Global.left_brush_type_label.text = "Brush: Pixel"
			Global.update_custom_brush(0)
		if Global.custom_brush_indexes[1] == custom_brush_index:
			Global.custom_brush_indexes[1] = -3
			Global.current_brush_types[1] = Global.Brush_Types.PIXEL
#			Global.right_brush_type_label.text = "Brush: Pixel"
			Global.update_custom_brush(1)

		var project_brush_index = custom_brush_index - Global.brushes_from_files
		Global.current_project.undos += 1
		Global.current_project.undo_redo.create_action("Delete Custom Brush")
		for i in range(project_brush_index, Global.project_brush_container.get_child_count()):
			var bb = Global.project_brush_container.get_child(i)
			if Global.custom_brush_indexes[0] == bb.custom_brush_index:
				Global.custom_brush_indexes[0] -= 1
			if Global.custom_brush_indexes[1] == bb.custom_brush_index:
				Global.custom_brush_indexes[1] -= 1

			Global.current_project.undo_redo.add_do_property(bb, "custom_brush_index", bb.custom_brush_index - 1)
			Global.current_project.undo_redo.add_undo_property(bb, "custom_brush_index", bb.custom_brush_index)

		var custom_brushes: Array = Global.current_project.brushes.duplicate()
		custom_brushes.remove(custom_brush_index)

		Global.current_project.undo_redo.add_do_property(Global.current_project, "brushes", custom_brushes)
		Global.current_project.undo_redo.add_undo_property(Global.current_project, "brushes", Global.current_project.brushes)
		Global.current_project.undo_redo.add_do_method(Global, "redo_custom_brush", self)
		Global.current_project.undo_redo.add_undo_method(Global, "undo_custom_brush", self)
		Global.current_project.undo_redo.commit_action()


func _on_BrushButton_mouse_entered() -> void:
	if brush_type == Global.Brush_Types.CUSTOM:
		$DeleteButton.visible = true


func _on_BrushButton_mouse_exited() -> void:
	if brush_type == Global.Brush_Types.CUSTOM:
		$DeleteButton.visible = false
