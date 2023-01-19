extends BaseButton

var brush = Global.brushes_popup.Brush.new()


func _on_BrushButton_item_rect_changed():
	$HBoxContainer/Name.text = hint_tooltip
	if brush.type == Global.brushes_popup.RANDOM_FILE:
		$HBoxContainer/Name.text += " (Random)"
	if brush.type == Global.brushes_popup.CUSTOM:
		$HBoxContainer/Name.text = "Project Brush %s" % str(get_index() + 1)


func _on_BrushButton_pressed() -> void:
	# Delete the brush on middle mouse press
	if Input.is_action_just_released("middle_mouse"):
		_on_DeleteButton_pressed()
	else:
		Global.brushes_popup.select_brush(brush)


func _on_DeleteButton_pressed() -> void:
	if brush.type != Global.brushes_popup.CUSTOM:
		return

	Global.brushes_popup.remove_brush(self)


func _on_BrushButton_mouse_entered() -> void:
	if brush.type == Global.brushes_popup.CUSTOM:
		$HBoxContainer/DeleteButton.visible = true


func _on_BrushButton_mouse_exited() -> void:
	if brush.type == Global.brushes_popup.CUSTOM:
		$HBoxContainer/DeleteButton.visible = false
