extends BaseButton


var brush := Brushes.Brush.new()


func _on_BrushButton_pressed() -> void:
	# Delete the brush on middle mouse press
	if Input.is_action_just_released("middle_mouse"):
		_on_DeleteButton_pressed()
	else:
		Global.brushes_popup.select_brush(brush)


func _on_DeleteButton_pressed() -> void:
	if brush.type != Brushes.CUSTOM:
		return

	Global.brushes_popup.remove_brush(self)


func _on_BrushButton_mouse_entered() -> void:
	if brush.type == Brushes.CUSTOM:
		$DeleteButton.visible = true


func _on_BrushButton_mouse_exited() -> void:
	if brush.type == Brushes.CUSTOM:
		$DeleteButton.visible = false
